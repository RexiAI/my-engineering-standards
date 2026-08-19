# 018-pr-babysitter-loop

> Spec pipeline archive. Original source: `specs/018-pr-babysitter-loop/` (deleted by this script).
> Archived: 2026-08-18

## Original ask

# PR Babysitter loop (watch PRs, keep them moving, keep the human in the seat)

A loop that reduces human time herding pull requests through review, CI, rebase,
and merge — while keeping the human in the judgment seat. Brings the
pr-babysitter pattern from cobusgreyling/loop-engineering.

## What it must provide

1. **Watcher.** Scheduled or event-triggered check of open PRs in this repo (or a
   child repo). For each PR: run a triage skill, record status of checks
   (passing / failing / pending / absent-unknown), required-check policy,
   review comments, mergeability, ready-to-merge state.

2. **Absent/unknown is not green.** Zero returned checks = absent/unknown; a PR is
   not ready until the repo's required-check policy is known and all gates are
   satisfied. Never assume green from a missing report.

3. **Actions.**
   - Failing checks → spawn a minimal-fix sub-agent → verifier confirms →
     propose a patch / comment on the PR (never merge).
   - Ready (policy satisfied, approvals present, no blocking comments, no
     conflict) → add a "ready to merge" label or ping the human.
   - Idle too long → suggest close or hand-off.

4. **Bounded and guarded.** Circuit breaker per PR: max N fixes without progress
   (e.g. 3) → escalate, stop commenting. Human gates always required for:
   high-risk refactors, security/auth/payments/infra, >N files.

5. **State.** `pr-babysitter-state.md` (or STATE.md section): watched PRs, last
   action + outcome, human overrides. Prune merged/closed PRs every run.

6. **Identity.** Loop's PR comments are clearly signed (e.g. "Loop Engineering —
   PR Babysitter").

## Acceptance criteria

- AC-001: a pr-review-triage skill exists defining this repo's review norms,
  required checks, and what "ready to merge" means.
- AC-002: the watcher records check status with the absent/unknown distinction;
  absent is never treated as green.
- AC-003: failing-check fixes are proposed by a separate implementer + verifier,
  never merged by the loop.
- AC-004: the loop adds "ready to merge" or pings the human only when policy is
  satisfied; ambiguous/high-risk items escalate with context.
- AC-005: remediation is bounded per PR; repeated failures escalate instead of
  repeating comments.
- AC-006: state is pruned each run; loop comments are signed.
- AC-007: cost guidance documented (early exit on empty watchlist).

## Tasks

# Task 10 — PR Babysitter loop

Formalization of `specs/018-pr-babysitter-loop/00-informal.md`. Adapted from the
`pr-babysitter` pattern in `cobusgreyling/loop-engineering/patterns/pr-babysitter.md`.

## Context the Coder must work from

This spec ships **configuration, a skill, a state convention, and a shell gate** — no
application code, no test suite in the usual sense. The "tests" for the acceptance
scenarios are the checks inside `scripts/check-pr-babysitter.sh` (task 8). Every
`AC-018-NN-NN` scenario ID in `20-acceptance/` must be cited by that script — that is
how `scripts/check-scenario-traceability.sh` traces this spec (see task 8).

### Cross-spec dependencies (do not re-specify)

- **Spec 016 (loop foundation) is a hard prerequisite.** It defines
  `docs/LOOP_ENGINEERING.md`, `templates/LOOP.md`, `STATE.md`, `loop-run-log.md`,
  `loop-budget.md`, `loop-constraints.md`, and `gate.yaml`. This spec **consumes**
  those files: the PR Babysitter writes its state into a `PR Babysitter` section of
  `STATE.md`, appends JSON entries to `loop-run-log.md`, spends from `loop-budget.md`,
  and honors the `gate.yaml` path denylist and no-auto-merge rule. It does not
  re-specify any of them.
- **Real PR lifecycle.** This repo's PRs are opened two ways: (a) the spec pipeline
  (`spec-pr-opener` opens **draft** PRs on `spec/NNN-slug` branches), and (b) humans
  pushing feature branches. The babysitter watches both. It never changes the spec
  pipeline's own gating, branch protection, or the repo's required-check policy.
- **Real mechanisms (name these, do not invent others).** PRs and check runs are read
  through the **GitHub MCP server** and the **`gh` CLI**:
  - list open PRs: `gh pr list --state open --json number,title,headRefName,isDraft,mergeable,mergeStateStatus` or MCP `github_list_pull_requests`
  - read check runs: `gh pr checks <n>` / `gh api repos/{owner}/{repo}/commits/{head_sha}/check-runs` or MCP `github_pull_request_read` (method `get_check_runs` / `get_status`)
  - read reviews + review threads: `gh pr view <n> --json reviews` or MCP `github_pull_request_read` (methods `get_reviews` / `get_review_comments` / `get_comments`)
  - required-check policy: `gh api repos/{owner}/{repo}/branches/main/protection` (field `required_status_checks.contexts`), default branch resolved via `gh repo view --json defaultBranchRef`; the repo's own CI is defined in `.github/workflows/{self-ci,archive-spec,release}.yml`
  - comment on a PR: `gh pr comment <n>` or MCP `github_add_issue_comment`
  - add a label: `gh pr edit <n> --add-label "ready to merge"`
- **Spec-pipeline PR interaction (mandatory).** For PRs on `spec/NNN-slug` branches
  (draft, opened by `spec-pr-opener`), the babysitter must not: propose fixes for CI
  failures (the pipeline's own Verifier/Architect report and own those failures), add
  a "ready to merge" label while the PR is a draft, or duplicate the pipeline's own
  comments. It records state and may ping the human when the PR is green and
  undrafted. The babysitter also never edits `.github/workflows/*.yml`, branch
  protection, or required-check policy — it reads them.

### Info barrier

Per `docs/SPEC_PIPELINE.md`, the Coder must not read `00-informal.md`. This file and
`20-acceptance/` are the sole requirement sources.

---

## Task 1 — `pr-review-triage` skill

Create `skills/pr-review-triage/SKILL.md`, the triage skill the loop loads for every
watched PR (mirroring the structure of `skills/check-principles/SKILL.md`:
YAML frontmatter with `name`, `description`, `license`, `allowed-tools`; body with
When to use / Invocation / What it does sections).

Acceptance criteria:
- The file exists and has valid YAML frontmatter: `name: pr-review-triage`, a
  `description` naming when to use it, `license: See repo root`, and `allowed-tools`
  restricted to read/comment-only operations (e.g. `Bash(gh pr list:*)`,
  `Bash(gh pr checks:*)`, `Bash(gh pr comment:*)`, `Bash(gh pr edit:*)`,
  `Bash(gh api .../check-runs:*)`, `Bash(gh api .../protection:*)`, `Bash(gh pr view:*)`)
  — no `merge`, no `push`, no write to workflows.
- The skill defines this repo's **review norms** from `docs/GIT_WORKFLOW.md §PR
  Requirements`: title is conventional-commit format; at least one reviewer approval
  (`production`+ tier; `mvp` projects may self-approve per `docs/CONFORMANCE_TIERS.md`);
  no unresolved discussion threads; merge is squash-only.
- The skill defines the **required-check policy source of truth**: the branch
  protection rule on the default branch (`required_status_checks.contexts`), cross-checked
  against the workflow files in `.github/workflows/`. The policy is only "known" when
  both reads succeed; any read failure ⇒ policy is "unknown".
- The skill defines **"ready to merge"** as the conjunction of: required-check policy
  known and every required check passing; at least the tier-required approval present;
  no unresolved discussion threads; no merge conflict; PR is not a draft.
- The skill defines the **check-state taxonomy** used by every triage: `passing`,
  `failing`, `pending`, `absent-unknown`, and the rule that zero returned checks is
  `absent-unknown` and is **never** treated as green.

Acceptance scenarios: `20-acceptance/AC-018-01.md`.

## Task 2 — Watcher and check-state triage

The loop's per-PR triage behavior, driven by the task-1 skill. No new script — this is
the loop's operating procedure, documented in the skill and enforced by the check
script's greps.

Acceptance criteria:
- On each run, the loop enumerates open PRs with the real mechanism
  (`gh pr list --state open` or MCP `github_list_pull_requests`); a PR enters the
  watchlist exactly once per run regardless of which mechanism listed it.
- For each watched PR the loop records, in `STATE.md`: check status per check
  (`passing`/`failing`/`pending`/`absent-unknown`), whether the required-check policy
  is known, review state (approvals, unresolved threads), mergeability, and the
  resulting ready-to-merge verdict.
- **Absent/unknown is not green.** A check with no returned report is classified
  `absent-unknown`. A PR whose policy is unknown, or any required check is
  `absent-unknown`/`failing`/`pending`, is **not** ready.
- Spec-pipeline draft PRs (`spec/NNN-slug`, `isDraft: true`): the loop records state
  only. It does not propose fixes, does not add labels, and does not comment on the
  pipeline's own failures; when green and no longer a draft it may ping the human.

Acceptance scenarios: `20-acceptance/AC-018-02.md`.

## Task 3 — Failing-check remediation (separate implementer + verifier; never merge)

Procedure the loop follows when a watched PR has a `failing` check.

Acceptance criteria:
- The loop spawns a **separate minimal-fix sub-agent** to produce the smallest change
  that addresses the specific failing check, in an isolated worktree — never edits the
  PR branch in place.
- A **separate verifier sub-agent** (maker/checker split, per the 016 foundation) must
  independently confirm: the change addresses the failing check, no unrelated files
  were touched, and tests/lint still pass in the worktree. The implementer never marks
  its own work done.
- The loop **proposes** the fix — as a patch on the PR or a PR comment — and never
  merges. No auto-merge. MCP/gh permissions are read + comment only (016 least-privilege).
- The babysitter never modifies CI gating: `.github/workflows/*.yml`, branch
  protection, or the required-check policy are read-only inputs.

Acceptance scenarios: `20-acceptance/AC-018-03.md`.

## Task 4 — Ready-to-merge action

What the loop does when a PR's triage verdict is ready.

Acceptance criteria:
- Ready verdict ⇒ the loop adds the `"ready to merge"` label
  (`gh pr edit <n> --add-label "ready to merge"`); if label creation fails (label
  missing or no permission), it pings the human instead via a comment mentioning the
  PR author/reviewers.
- The label/ping is added **only** on a ready verdict. Unknown policy, any
  `absent-unknown`/`failing`/`pending` required check, missing approval, unresolved
  threads, conflict, or draft status all suppress the action.
- Ambiguous or high-risk cases escalate to the human with context (PR link, what is
  uncertain, why no label) instead of being labeled.

Acceptance scenarios: `20-acceptance/AC-018-04.md`.

## Task 5 — Bounded remediation and human gates

The circuit breaker and escalation rules per PR (016 "third failed attempt on same
item" safety rule, made concrete).

Acceptance criteria:
- **Circuit breaker per PR:** max 3 fix attempts without progress (no new commits from
  the author between attempts, or the same check failing at the same head SHA). On
  exhaustion the loop escalates to the human with the failing check + last attempt
  evidence and **stops commenting** on that PR.
- A repeated failure (same PR, same failing check, N×) escalates instead of repeating
  the same comment.
- **Human gates before any fix proposal:** high-risk refactor, changes touching
  security/auth/payments/infra (the 016 `gate.yaml` path denylist), or a PR touching
  more than 10 files. These never go to the fix sub-agent without a human decision.
- **Idle too long:** a watched PR with no commits and no loop/human action for > 3
  days gets a single suggestion to close or hand off, recorded in state, and is not
  re-pinged on later runs.

Acceptance scenarios: `20-acceptance/AC-018-05.md`.

## Task 6 — State, pruning, and identity

Acceptance criteria:
- A `## PR Babysitter` section exists in `STATE.md` (the 016 file, repo root) listing
  per-watched-PR: number, branch, check summary, last action + outcome, and any human
  overrides that changed loop behavior.
- **Prune every run:** PRs that are merged or closed are removed from the section on
  the run that observes them; the prune is recorded in the run-log.
- Every comment the loop writes on a PR is signed with the exact string
  `Loop Engineering — PR Babysitter`.
- Each run appends one JSON entry to `loop-run-log.md` in the 016 format
  (`{ run_id, pattern: "pr-babysitter", duration_s, items_found, actions_taken,
  escalations, tokens_estimate, outcome }`), including no-op runs.

Acceptance scenarios: `20-acceptance/AC-018-06.md`.

## Task 7 — Cost guidance

Acceptance criteria:
- **Early exit on empty watchlist:** documented in the skill — when `gh pr list
  --state open` returns zero PRs, the loop exits immediately after appending the
  no-op run-log entry; no triage, no sub-agent spawns, no comments.
- The skill documents the cost table (no-op ≈ 3k tokens, triage ≈ 80k, fix attempt ≈
  250k) and states that budget is spent from `loop-budget.md` (016) with the
  on-exceed/kill behavior defined there, not here.

Acceptance scenarios: `20-acceptance/AC-018-07.md`.

## Task 8 — Traceability shell gate (`scripts/check-pr-babysitter.sh`)

The behavioral gate that makes this spec verifiable, following the precedent of
`scripts/check-saga-timeouts.sh` (pass/fail lines, exit code 0/1, `set -euo pipefail`,
header comment citing standards references) and of 016's `check-loop-files.sh` being
wired into CI.

Acceptance criteria:
- `scripts/check-pr-babysitter.sh` exists, is executable, and exits `0` only when every
  check passes; exits `1` and prints a `FAIL` line per violation otherwise.
- The script contains **one check per acceptance scenario ID** — each `AC-018-NN-NN`
  ID from `20-acceptance/` appears in the script (in a comment, echo, or pass/fail
  label), so `scripts/check-scenario-traceability.sh` traces this spec and the script
  doubles as the spec's test suite. The checks are artifact/content greps: e.g.
  `AC-018-01-01` ⇒ `skills/pr-review-triage/SKILL.md` exists + frontmatter name;
  `AC-018-02-03` ⇒ skill/state contain the absent-unknown-never-green rule;
  `AC-018-03-03` ⇒ skill contains "never merge"/no auto-merge language;
  `AC-018-04-01` ⇒ `"ready to merge"` label string present; `AC-018-06-01` ⇒
  `STATE.md` has the `## PR Babysitter` section; `AC-018-06-03` ⇒ the sign-off string
  is present; `AC-018-07-01` ⇒ early-exit rule is present.
- The script is wired into CI by adding a step to the existing `Validate` job in
  `.github/workflows/self-ci.yml` (no new workflow file): `./scripts/check-pr-babysitter.sh`.

Acceptance scenarios: `20-acceptance/AC-018-08.md`.

---

## Open questions (answer before `/build` if possible)

1. **016 dependency ordering.** 018 assumes `STATE.md`, `loop-run-log.md`,
   `loop-budget.md`, `gate.yaml`, and `docs/LOOP_ENGINEERING.md` exist (spec 016).
   016 is still informal-only today. If 016 has not landed when `/build 018` runs,
   should the Coder block (recommended — the checks reference those files), or create
   minimal placeholder sections? Recommendation: **block**; surface it rather than
   guessing 016's schema.
2. **Scheduling.** The informal spec says "scheduled or event-triggered". This spec
   deliberately does not invent a scheduler: the loop runs under 016's `LOOP.md`
   cadence (short-cadence `opencode run` per `docs/LOOP_ENGINEERING.md`), reading PR
   state via the real GitHub mechanisms. Confirm that is the intended trigger rather
   than a new `.github/workflows/pr-babysitter.yml`.
3. **Constants.** Defaults chosen: max 3 fix attempts per PR, > 10 files triggers the
   human gate, > 3 days idle suggests close/hand-off. Confirm or override.

## Acceptance scenarios

## AC-018-01-01 — The triage skill file exists with valid frontmatter
## AC-018-01-02 — The skill defines the repo's review norms
## AC-018-01-03 — The skill defines the required-check policy source of truth
## AC-018-01-04 — The skill defines "ready to merge"
## AC-018-01-05 — The skill defines the check-state taxonomy
## AC-018-02-01 — The loop discovers open PRs with the real mechanism
## AC-018-02-02 — The loop records full triage state per PR
## AC-018-02-03 — Zero returned checks is absent/unknown, never green
## AC-018-02-04 — Any non-passing required check blocks readiness
## AC-018-02-05 — Spec-pipeline draft PRs are not fought
## AC-018-03-01 — A failing check spawns a separate minimal-fix sub-agent
## AC-018-03-02 — A separate verifier confirms the fix
## AC-018-03-03 — The loop proposes, never merges
## AC-018-03-04 — The babysitter never changes CI gating
## AC-018-04-01 — Ready verdict adds the "ready to merge" label or pings the human
## AC-018-04-02 — No label on any non-ready verdict
## AC-018-04-03 — Ambiguous or high-risk items escalate with context
## AC-018-05-01 — Circuit breaker caps fix attempts per PR
## AC-018-05-02 — Repeated failures escalate instead of repeating comments
## AC-018-05-03 — Human gate for high-risk changes
## AC-018-05-04 — Idle PRs get a single close/hand-off suggestion
## AC-018-06-01 — STATE.md keeps a PR Babysitter section
## AC-018-06-02 — Merged/closed PRs are pruned every run
## AC-018-06-03 — Every loop comment is signed
## AC-018-06-04 — Each run appends a run-log entry
## AC-018-07-01 — Empty watchlist exits early
## AC-018-07-02 — Cost table and budget consumption are documented
## AC-018-08-01 — The check script exists and gates on completeness
## AC-018-08-02 — Every scenario ID is cited by the script
## AC-018-08-03 — The script is wired into self-ci

## Verification

# 25 — Verification Report (spec 018: PR Babysitter loop)

Stage 4 of the spec pipeline. Independent re-verification of the Coder/Refactorer
deliverables for spec 018. Verifier model: `opencode-go/deepseek-v4-flash`.
Date: 2026-08-18. Branch: `spec/018-pr-babysitter-loop`.

Deliverables under verification:
- `scripts/check-pr-babysitter.sh` (Task 8 — traceability shell gate)
- `skills/pr-review-triage/SKILL.md` (Tasks 1–7)
- `STATE.md` root `## PR Babysitter` section (Task 6)
- `.github/workflows/self-ci.yml` step (Task 8, AC-018-08-03)

Verdict: **PASS** (AC-018 scope). Details per gate below; the two full-repo
exit-1 results (traceability, design-principles) are pre-existing conditions
outside AC-018 scope and are transcribed verbatim for the record.

---

## 1. Scenario traceability

### 1a. Full-repo run (transcript)

Command: `scripts/check-scenario-traceability.sh --json` — **exit code 1**.

The full-repo run exits 1. Every FAIL is in sibling/in-flight specs and stale
test references — **none is an AC-018 ID**:

- Passes (11): `AC-008-01, AC-015-07, AC-018-01, AC-018-02, AC-018-03,
  AC-018-04, AC-018-05, AC-018-06, AC-018-07, AC-018-08, AC-019-07` — each
  "traced to a test". **All 8 AC-018 scenario families trace.**
- Fails: orphaned scenarios `AC-008-02..05, AC-009-01..04, AC-010-01..06,
  AC-011-01..03, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..06,
  AC-015-08..16, AC-017-01..05, AC-019-01..06` and stale test references
  `AC-001-01..06, AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04,
  AC-006-01..06, AC-007-01..04, AC-016-01..05, AC-020-01..07, AC-021-01..08,
  AC-022-01..04, AC-998-01, AC-999-01, AC-999-99`.
- **No AC-018 reference dangles.** AC-018 does not appear in the fails list at all.

These fails are attributable to other in-flight specs (008–022) and pre-existing
test files referencing scenarios not present in this repo's `specs/*/20-acceptance/`.
Not a spec-018 defect.

### 1b. Scoped AC-018 run (transcript)

To isolate spec 018 I pointed SPECS_DIR at a scratch dir holding only spec 018's
`20-acceptance/` and SOURCE_DIR at a scratch dir holding only the four spec-018
deliverables (check script, skill, STATE.md, self-ci.yml). Scratch was removed
after the run.

Command: `scripts/check-scenario-traceability.sh --json <scratch-specs> <scratch-src>`
— **exit code 0**.

```
{
  "checks": [1, 2],
  "passes": ["AC-018-01 — traced to a test", "AC-018-02 — traced to a test",
             "AC-018-03 — traced to a test", "AC-018-04 — traced to a test",
             "AC-018-05 — traced to a test", "AC-018-06 — traced to a test",
             "AC-018-07 — traced to a test", "AC-018-08 — traced to a test"],
  "fails": []
}
```

**AC-018 scope: clean.** All 8 scenario families traced; zero fails; zero stale
references.

**Check 1: PASS** (AC-018 scope).

---

## 2. Full relevant suite

The spec ships configuration/skill/state/shell-gate, not application code. The
"test suite" for this spec is `scripts/check-pr-babysitter.sh` (per task 8).
All commands below ran for real with real exit codes.

| Command | Real exit | Result |
|---|---|---|
| `./scripts/check-pr-babysitter.sh` | **0** | **72 PASS** lines, 0 FAIL |
| `bash -n scripts/check-pr-babysitter.sh` | **0** | syntax clean |
| `scripts/check-orchestration.sh` | **0** | "All orchestration references valid." |
| `make validate-all` | **0** | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines — unrelated to spec 018) |
| `make lint` | **0** | all workflow files `[OK]` incl. `.github/workflows/self-ci.yml`; "Done." |
| `scripts/check-loop-files.sh` | **0** | "every check passed" (016 foundation bundle intact) |

`./scripts/check-pr-babysitter.sh` output summary (real): every AC-018 block
reported `PASS`; final line `✔ PR Babysitter check: every check passed.`; counted
PASS lines = **72**.

`scripts/check-pr-babysitter.sh` is executable (`-rwxr-xr-x`), per AC-018-08-01.

### self-ci.yml verification

PyYAML parse: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))"`
→ printed `YAML_PARSE_OK`, jobs = `['validate']`. Parse OK.

The Validate job contains the step:
- name: `Check PR Babysitter loop deliverables`
- run: `./scripts/check-pr-babysitter.sh`
- **no `continue-on-error`** (confirmed absent; value `None`).

Only diff to `.github/workflows/self-ci.yml` is this 5-line step (no other
change). No new workflow file added (AC-018-08-03 satisfied).

### STATE.md

`STATE.md` exists at repo root and contains the `## PR Babysitter` section
(AC-018-06-01) with per-PR columns `PR | Branch | Check summary | Last action |
Outcome | Human override` and a human-override explanation paragraph.

**Check 2: PASS.**

---

## 3. Complexity gate

The check script's only functions and their decision points (real read of the
file; CC = 1 + #decision points: `if`/`for`/`&&`/`||`/`case`):

| Function | Line | Decision points | CC |
|---|---|---|---|
| `fail()` | 67 | 0 | 1 |
| `pass()` | 68 | 0 | 1 |
| `require_file()` | 75 | 1 (`if [ -f ]`) | 2 |
| `require_grep()` | 84 | 2 (`if [ -f ] && grep`) | **3** |

Worst offender is `require_grep` at **CC 3** — matches the Refactorer's claim and
is well under the ≤6 limit.

Independent confirmation via the design-principles script's complexity gate on
the spec-018 files:

```
scripts/check-code-principles.sh --json --gates complexity <scratch-src>
tier: mvp  gates: ["complexity"]  fails: []  warns: []   → exit 0
```

**Check 3: PASS.**

---

## 3.5. Design-principles gate

### Scoped spec-018 run (transcript)

Command: `scripts/check-code-principles.sh --json <scratch-src>` (default mode,
auto-detected tier `mvp`). **Exit code 0.**

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "property-tests"],
  "fails": [],
  "warns": []
}
```

No FAIL, no WARN on any spec-018 file.

### Repo-root run (known pre-existing state, transcribed verbatim)

Command: `scripts/check-code-principles.sh --json` — **exit code 1**.

FAILs (5) — all in `ci/templates/*`, none in spec-018 files:
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8`
- `Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7`

WARNs — all in `ci/templates/*` (KISS_LINES and duplication in
`ci/templates/go-saga-lint.go`, `ci/templates/eslint-saga-rules/saga-compensation.js`,
empty method bodies in `ci/templates/archunit/{OutboxArchRules,SagaArchRules}.java`).

**Judgment:** every repo-root FAIL and WARN is confined to `ci/templates/*`
(the saga/outbox gate templates), pre-existing and unrelated to spec 018. No
FAIL or WARN is attributable to any spec-018 deliverable. The scoped spec-018 run
is clean (exit 0, 0 fails, 0 warns).

**Check 3.5: PASS** for AC-018 scope (repo-root exit 1 is a transcribed
pre-existing condition, not a spec-018 finding).

---

## 4. Scenario-to-behavior spot check

Picked 6 acceptance scenarios and manually confirmed the skill/STATE.md content
implements each Given/When/Then (not just that a check named the ID exists):

| Scenario | Required behavior | Found in deliverable | Verdict |
|---|---|---|---|
| **AC-018-05-01** | max 3 fix attempts; escalate + stop commenting on exhaustion | SKILL.md §Circuit breaker: "max 3 fix attempts without progress … escalates to the human … stops commenting on that PR" | ✓ |
| **AC-018-05-03** | >10 files human gate; gate.yaml denylist; no fix without human decision | SKILL.md §Human gates: "a PR touching more than 10 files. These never go to the fix sub-agent without a human decision" + `gate.yaml` denylist | ✓ |
| **AC-018-05-04** | >3 days idle → single close/hand-off suggestion, recorded, not re-pinged | SKILL.md §Idle PRs: "more than 3 days … recorded in state, and is not re-pinged on later runs" | ✓ |
| **AC-018-03-03** | loop proposes, never merges, no auto-merge | SKILL.md §Failing-check remediation: "never merges the PR; no auto-merge path exists" | ✓ |
| **AC-018-06-01** | STATE.md has `## PR Babysitter` section w/ per-PR fields + human overrides | STATE.md `## PR Babysitter` with columns PR/Branch/Check summary/Last action/Outcome/Human override | ✓ |
| **AC-018-06-03** | every comment signed exact string `Loop Engineering — PR Babysitter` | SKILL.md §Comment signing: "`Loop Engineering — PR Babysitter`" | ✓ |

### Negative fixture (script assertions reference real strings)

Injected a wrong string ("max 3 fix attempts" → "max 9 fix attempts") into a
scratch copy of `skills/pr-review-triage/SKILL.md` and re-ran the check script
against that fixture. Real output:

```
FAIL AC-018-05-01: circuit breaker: max 3 fix attempts per PR (expected "max 3 fix attempts" in .../SKILL.md)
✘ PR Babysitter check: 1 violation(s). Fix before merging.
```
→ exit code **1**. The script genuinely detects a violation; it is not a
pass-everything no-op. Fixture removed after the run.

**Check 4: PASS.**

---

## 5. No unaccounted behavior

Skim of the deliverable set against `10-tasks.md`:
- `scripts/check-pr-babysitter.sh` → Task 8 (AC-018-08). Every AC-018-NN-NN ID
  cited (self-checked by AC-018-08-02 and confirmed by the traceability scoped
  run: 8/8 families, 0 stale refs).
- `skills/pr-review-triage/SKILL.md` → Tasks 1–7 (AC-018-01..07). Content maps
  1:1 to the acceptance criteria.
- `STATE.md` `## PR Babysitter` section → Task 6 (AC-018-06-01).
- self-ci step → Task 8 / AC-018-08-03.

**Self-ci step scope check:** The Refactorer added the "Check PR Babysitter loop
deliverables" step to `.github/workflows/self-ci.yml`'s Validate job. This is
**required by Task 8** ("The script is wired into CI by adding a step to the
existing Validate job … `./scripts/check-pr-babysitter.sh`") and by
AC-018-08-03 ("The job runs `./scripts/check-pr-babysitter.sh` as a step / no new
workflow file"). It is not scope creep. It carries no `continue-on-error`, so a
missing deliverable fails the Validate job — the intended gate behavior.

No logic in the deliverables fails to trace to a task/scenario.

### mvp-tier claim

No `AGENTS_*.md` exists at the repo root (`ls AGENTS_*.md` → "No such file or
directory"). The design-principles gate auto-detected tier **`mvp`** in both
runs, confirming the property-test/mutation skips are correct for this tier.

**Check 5: PASS.**

---

## Overall verdict: **PASS**

Every gate ran for real. Spec-018 scope is clean on every check:

1. **Traceability (AC-018 scope): PASS** — scoped run exit 0, 8/8 families
   traced, 0 stale refs. (Full-repo exit 1 transcribed: fails confined to
   sibling specs 008–022 / stale test refs, none AC-018.)
2. **Full relevant suite: PASS** — check-pr-babysitter exit 0 / 72 PASS;
   bash -n 0; check-orchestration 0; make validate-all 0; make lint 0;
   check-loop-files 0; self-ci.yml parses (PyYAML) with the new step and no
   continue-on-error; STATE.md has the `## PR Babysitter` section.
3. **Complexity: PASS** — worst function `require_grep` CC 3 (≤6); complexity
   gate on spec-018 files exit 0.
3.5. **Design-principles (AC-018 scope): PASS** — scoped run exit 0, 0 FAIL /
   0 WARN. (Repo-root exit 1 transcribed: FAILs/WARNs confined to
   `ci/templates/*`, pre-existing, none attributable to spec 018.)
4. **Spot check: PASS** — 6 scenarios confirmed implemented; negative fixture
   correctly flagged the injected wrong string (exit 1).
5. **No unaccounted behavior: PASS** — all deliverables trace to tasks; self-ci
   step is task-mandated (AC-018-08-03), not scope creep; mvp tier confirmed.

Architect may proceed (mutation-testing gate skipped at `mvp` tier).

## Quality gates

# 30 — Mutation / Gate Report (spec 018: PR Babysitter loop)

Stage 5a of the spec pipeline. Mutation Runner.
Date: 2026-08-18. Branch: `spec/018-pr-babysitter-loop`.

## Verifier's verdict (carried forward)

**PASS** — carried from `specs/018-pr-babysitter-loop/25-verification.md`. All
gates passed for AC-018 scope (traceability 8/8 families, full relevant suite,
complexity, design-principles scoped run, spot check, no unaccounted behavior).
The two full-repo exit-1 results (traceability, design-principles) were
transcribed pre-existing conditions confined to sibling specs / `ci/templates/*`,
none attributable to spec 018.

## Mutation score

**Skipped — `mvp` tier.**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate. This repo is `mvp` tier (no `AGENTS_*.md` at repo root),
so mutation testing is skipped at this stage. The changed deliverables are a bash
check script (`scripts/check-pr-babysitter.sh`), skill markdown, STATE.md, and
workflow YAML — no mutation tooling exists for shell in this repo. No mutation
tests were written.

## Complexity summary (carried from Refactorer)

The check script's functions and decision points (CC = 1 + decision points):

| Function | Line | Decision points | CC |
|---|---|---|---|
| `fail()` | 67 | 0 | 1 |
| `pass()` | 68 | 0 | 1 |
| `require_file()` | 75 | 1 (`if [ -f ]`) | 2 |
| `require_grep()` | 84 | 2 (`if [ -f ] && grep`) | 3 |

All functions ≤3; worst offender `require_grep` at CC 3 — well under the ≤6
limit. Matches the Refactorer's claim and the Verifier's independent re-check.

## Equivalent mutants

**None.** Mutation testing was not run (skipped at `mvp` tier), so no mutants
were generated and no equivalent (un-killable) mutants were encountered.

## Final test status

Re-ran the full relevant suite one final time after all stage work (mutation
killing wrote no new test code at this tier, but re-confirmed per the agent
instructions). All green:

| Command | Exit | Result |
|---|---|---|
| `./scripts/check-pr-babysitter.sh` | **0** | **72 PASS**, 0 FAIL |
| `bash -n scripts/check-pr-babysitter.sh` | **0** | syntax clean |
| `scripts/check-orchestration.sh` | **0** | "All orchestration references valid." |
| `make validate-all` | **0** | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines — unrelated to spec 018) |
| `scripts/check-loop-files.sh` | **0** | "every check passed" (016 foundation bundle intact) |

`specs/018-pr-babysitter-loop/25-verification.md` exists with verdict **PASS**.

**Overall: GREEN.** No commit, push, or PR opened — that is the PR Opener's job
(stage 5b).
