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
