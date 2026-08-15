# 014-ci-failure-remediation

> Spec pipeline archive. Original source: `specs/014-ci-failure-remediation/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# CI-failure check-and-remediate loop

After the pipeline pushes a feature branch and opens a PR, CI runs on it. When
that CI fails, the failure is the agent's to see and handle — not something it
pushes past and reports green. acdc-civ does this with a dedicated Verifier gate
(G6 CI = Jenkins build SUCCESS) plus a bounded post-PR remediation loop: on
failure, the Implementor fixes and re-pushes; the loop is capped (max 3) and
exhaustion escalates to the human.

This repo's pipeline (spec-* agents + commands) has no such loop: the PR Opener
opens the PR, then the run ends. A red CI on the just-opened PR is never checked
by an agent.

## What it must provide

- A post-PR CI check step: after the PR is opened, the pipeline queries CI status
  for the feature branch (GitHub Actions / the repo's CI) and records PASS/FAIL
  per check.
- On FAIL: the agent reads the failing job's logs, diagnoses, and feeds the
  concrete error back into a fix round.
- A bounded fix loop, independent per phase (mirror the remediation-budget spec):
  max 3 fix-and-repush rounds; each re-push re-triggers CI; exhaustion escalates
  to the human with the failing check IDs + last log evidence.
- The verdict recorded in the pipeline's report artifact (25-verification.md or
  30-report.md) so the outcome is auditable.

## Acceptance criteria

- AC-001: the pipeline has a defined post-PR CI status check (which command
  queries CI, how PASS/FAIL is parsed).
- AC-002: on CI FAIL, the pipeline reads the failing job's logs and records the
  failure reason in the report artifact.
- AC-003: fix rounds are bounded (max 3); each round re-pushes and re-checks CI.
- AC-004: budget exhaustion stops the pipeline with the failing check IDs and
  last log excerpt, escalated to the human — never a silent green.
- AC-005: the report artifact records CI outcome per check and per round.

## Tasks

# Tasks — CI-failure check-and-remediate loop

Formalization of `specs/014-ci-failure-remediation/00-informal.md`. Goal: after the
PR Opener opens the PR, the pipeline queries CI status for the feature branch,
records PASS/FAIL per check, and on FAIL runs a bounded fix-and-repush loop —
max 3 rounds, orchestrator-owned counter independent of spec 008's phase-1
budget — that re-triggers CI on every re-push and, on exhaustion, escalates to
the human with the failing check IDs and last log evidence. The verdict lands in
`25-verification.md` so the outcome is auditable. This is a prompts/docs-only
spec like 008: it changes the pipeline's prompts and documentation; it adds no
new agent and no new CI infrastructure.

## Grounded reality (verified against this repo)

- **Which CI actually runs on a feature-branch PR.** The repo's only CI that
  gates a `spec/NNN-slug` branch or its PR is `.github/workflows/self-ci.yml`
  (workflow name **Self CI**). Its `on:` block triggers on `push` (branches `**`)
  and `pull_request` (branches `**`) — so a branch push starts a push-triggered
  Self CI run, and opening the draft PR starts a second, `pull_request`-triggered
  run against the PR head. It has a single job, `Validate` (CRLF check, `bash -n`,
  `make validate-all`, `make lint`, YAML syntax). `.github/workflows/release.yml`
  fires only on push to `master`, and `.github/workflows/archive-spec.yml` only on
  `pull_request: closed` to `main` — neither gates a feature-branch PR. Default
  branch is `main` (confirmed via `gh repo view`). So "the repo's CI" in this spec
  means the Self CI workflow on GitHub Actions.
- **The query mechanism that exists here.** `gh` CLI (v2.96.0) is installed and
  authenticated against `github.com` with `repo` scope; the remote is
  `git@github.com:RexiAI/my-engineering-standards.git`. The post-PR status query is
  `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link` — the
  `bucket` field categorizes each check's `state` into `pass`/`fail`/`pending`
  (this is the PASS/FAIL parsing informal AC-001 asks to define). Polling is
  `--watch` (or a bounded re-query); exit code 8 means checks still pending.
  Failing check IDs come from the checks API:
  `gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`
  (check run `name` + `id`). Failing job logs come from the Actions runs API:
  `gh run list --branch spec/NNN-slug --workflow "Self CI"` (RUN column) then
  `gh run view <RUN-ID> --log-failed` (prints only failed steps' logs). All
  verified against `gh ... --help` in this environment.
- **The PR Opener is where the post-PR check attaches, and where the run ends
  today.** `agents/spec-pr-opener.md` (stage 5b) opens the draft PR and ends its
  turn (line 42); `commands/build.md` reports the PR URL and stops (lines 20-21).
  Nothing ever queries CI afterward — a red CI on the just-opened PR is never seen
  by an agent. The phase-2 loop must be inserted after stage 5b, in the two files
  that actually drive the run: `commands/build.md` and `agents/spec-pipeline.md`.
- **Who can push.** The pipeline's commit/push carve-out rests on
  `spec-pr-opener` — its frontmatter allows `git push*` with `ask`; `spec-coder`
  and `spec-refactorer` both deny `git push*`, and `spec-verifier` denies both
  `git commit*` and `git push*`. Therefore each fix round's re-push must be done
  by the PR Opener (task 5), not by the fixer. The orchestrator never commits or
  pushes (spec-pipeline.md line 34).
- **Who records the verdict.** `spec-verifier` is the pipeline's only
  independent checker and its sole write permission is
  `specs/*/25-verification.md` (frontmatter lines 8-9). The informal spec names
  `25-verification.md` first ("25-verification.md or 30-report.md"), and
  `30-report.md` is written exclusively by `spec-mutation-runner` before the PR
  opens — the verifier cannot write it without a permission change. So the
  phase-2 verdict record lives in `25-verification.md`. No permission changes are
  needed: `gh` is already permitted by the verifier's `bash: "*"` allow rule.
- **Dependency on spec 008 (`008-remediation-budget`).** 008 (task 1) will
  document the **Phase 2 — Post-PR loop** policy: max 3, counter **independent of
  Phase 1**, exhaustion emits failing gate IDs + last evidence and escalates to
  the human, and the verbatim phrase `re-run until green is forbidden phrasing`.
  014 is the phase-2 loop *mechanism* (query CI, read logs, fix-and-repush); it
  must build on 008's budget *language* rather than re-declare it. **008 must
  land first** — 014's docs and prompts reference the "Phase 2 / max 3 /
  independent counter" terms 008 introduces, and 014's task 4 and task 2 must not
  contradict or duplicate them. See open question 4.
- **No "re-run until green" phrasing exists in agents/, commands/, or docs/**
  (008's ground-truth grep) — 014 only *extends* the prohibition to the phase-2
  loop; nothing needs removing.

## Tasks

### Task 1 — Document the post-PR CI check loop in `docs/SPEC_PIPELINE.md`

Extend the remediation-budget section 008 adds (or, if 008's section is not yet
present, the nearest equivalent location after "Commit and push carve-out") with
a sub-section describing the phase-2 CI loop mechanism. 008's section defines the
budget *policy*; this sub-section defines the *mechanics* and must not restate the
budget.

Acceptance criteria:
- The sub-section names the exact CI query: after the PR Opener opens the PR, the
  pipeline runs `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`
  against the feature branch's PR and records PASS/FAIL per check, where the
  `bucket` field (`pass`/`fail`/`pending`) is the parse rule, and pending checks
  are polled (e.g. `--watch` or bounded re-query) until terminal.
- The sub-section states the CI is the repo's **Self CI** workflow
  (`.github/workflows/self-ci.yml`, GitHub Actions) and names the failing-log
  read: `gh run list --branch spec/NNN-slug --workflow "Self CI"` then
  `gh run view <RUN-ID> --log-failed`.
- The sub-section states that on FAIL the failing check IDs are captured from the
  checks API (`gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`)
  and the failure reason is recorded in `25-verification.md`.
- The sub-section states the loop runs at most **3** fix-and-repush rounds with a
  counter **independent of Phase 1** (referencing 008's budget section, not
  re-declaring it), and that each re-push re-triggers CI.
- The sub-section states that on exhaustion the pipeline stops and escalates to
  the human with the failing check IDs and the last log evidence — never a silent
  green.
- The sub-section states the outcome is recorded per check and per round in
  `25-verification.md`.
- The sub-section does not contradict 008's verbatim phrase; it must not contain
  `re-run until green` or any open-ended re-run instruction.
- The sub-section explicitly notes the ordering dependency: the phase-2 budget
  policy comes from 008, and 014's mechanism is only valid once 008's section
  exists.

Scenarios: `20-acceptance/AC-014-01-post-pr-ci-doc.md`

### Task 2 — Encode the post-PR CI check in `agents/spec-verifier.md`

Add a "post-PR CI check" to the Verifier's checklist so it is the agent that runs
the real CI query and records the verdict. This is the pipeline's independent
checker and its `bash: "*"` rule already permits `gh`.

Acceptance criteria:
- The prompt adds a check that runs `gh pr checks <PR_NUMBER> --json
  name,state,bucket,workflow,link` (repo inferred from the git remote; `--repo
  RexiAI/my-engineering-standards` if needed) and records PASS/FAIL per check from
  the `bucket` field.
- The prompt instructs the Verifier to poll pending checks until terminal (`gh pr
  checks --watch`, or bounded re-query) rather than treating `pending` as a pass
  or a fail.
- The prompt instructs the Verifier, on any FAIL, to capture the failing check
  IDs (`gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`,
  select `conclusion == "failure"`, record `name` + `id`) and read the failing job
  logs (`gh run list --branch spec/NNN-slug --workflow "Self CI"` → `gh run view
  <RUN-ID> --log-failed`), then record the concrete failure reason.
- The prompt requires a **Post-PR CI check** section in `25-verification.md`
  recording, per round: the round index, each check's PASS/FAIL, the failing
  check IDs, and the last log excerpt (informal AC-005 — per check and per round).
- The prompt instructs the Verifier to hand the diagnosis back to the orchestrator
  (which routes the fix), and that on a re-trigger it performs a **scoped re-check**
  of only the previously-failing checks (mirroring 008 task 2), reading its prior
  `25-verification.md` for the failing check IDs.
- The prompt's frontmatter is unchanged — no permission changes; the existing
  `edit: specs/*/25-verification.md` allowance covers the new section.
- The prompt does not gain `re-run until green` or any equivalent open-ended
  re-run phrasing, and keeps its "do not commit, push, or fix anything yourself"
  constraints.

Scenarios: `20-acceptance/AC-014-02-verifier-ci-check.md`

### Task 3 — Encode the fix-from-CI-error mode in `agents/spec-coder.md` and `agents/spec-refactorer.md`

Add the bounded re-fix rule for phase-2 CI failures to both fixer prompts,
mirroring 008 task 3's phase-1 cap.

Acceptance criteria:
- `agents/spec-coder.md` states the Coder may be re-invoked to fix a CI failure
  and must fix only the failing check's cause as diagnosed in `25-verification.md`,
  re-running the local suite to confirm the fix, and stopping (not re-fixing
  endlessly) — the round count is the orchestrator's, capped at **3**.
- `agents/spec-refactorer.md` states the same bounded re-fix rule for
  structural/complexity failures surfaced by CI.
- Both prompts keep their existing `git push*: deny` frontmatter — the fixer
  never pushes; the re-push is the PR Opener's job (task 5).
- Neither prompt gains `re-run until green` or any open-ended re-run phrasing.
- Neither prompt changes its information-barrier rules (Coder must not read
  `00-informal.md`; Refactorer must not read `specs/**`).

Scenarios: `20-acceptance/AC-014-03-fixer-ci-mode.md`

### Task 4 — Make the Phase-2 loop bounded in `commands/build.md` and `agents/spec-pipeline.md`

Replace the run-ends-at-PR behavior with a bounded phase-2 loop. These two files
drive the run, so this task is where the counter is enforced (orchestrator-owned,
mirroring 008's recommended design).

Acceptance criteria:
- Both files describe a bounded phase-2 loop that starts **after** the PR Opener
  reports the PR URL: the orchestrator invokes the Verifier for the post-PR CI
  check; on a FAIL it routes the diagnosed fix to the Coder (behavior) or
  Refactorer (structure), re-invokes the PR Opener to commit + push the fix round,
  then re-invokes the Verifier for a scoped re-check — up to **3** rounds.
- Both files state the phase-2 counter is **independent of Phase 1** and capped at
  **max 3**, referencing spec 008's budget section rather than re-declaring the
  budget.
- Both files state that on the 3rd FAIL the pipeline stops, relays the failing
  check IDs and the last log evidence from `25-verification.md` verbatim, and
  escalates to the human — never a silent green, and no 4th round.
- Both files keep the rule that each re-push re-triggers CI (the re-check waits
  for the re-triggered run).
- Neither file contains `re-run until green` or any equivalent open-ended re-run
  phrasing.
- The files do not move the existing phase-1 loop (008 task 4) and do not let the
  orchestrator commit, push, or run the `gh` queries itself — the verifier queries
  (task 2) and the PR Opener pushes (task 5).

Scenarios: `20-acceptance/AC-014-04-orchestrator-ci-loop.md`

### Task 5 — Encode the fix-round re-push in `agents/spec-pr-opener.md`

Give the PR Opener a scoped "fix-round re-push" mode so it can commit and push the
working-tree fix without opening a second PR or duplicating its other duties.

Acceptance criteria:
- The prompt states that when invoked for a fix round it commits the fix as a
  conventional commit (`fix: ...` referencing the failing check ID(s)) on the
  existing `spec/NNN-slug` branch and pushes it.
- The prompt states it does not open a new PR during a fix round — it confirms the
  existing PR (e.g. `gh pr view`) and pushes to its branch, which re-triggers the
  Self CI workflow.
- The prompt keeps its precondition behavior for the initial PR open
  (`30-report.md` must be green) and does not weaken the "never commit to
  main/master" and "never create tags" rules.
- The prompt's frontmatter is unchanged — `git push*: ask` already permits the
  re-push.
- The prompt does not gain `re-run until green` phrasing.

Scenarios: `20-acceptance/AC-014-05-pr-opener-repush.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 post-PR CI status check: which command, how PASS/FAIL parsed | 1, 2 | `AC-014-01-post-pr-ci-doc.md`, `AC-014-02-verifier-ci-check.md` |
| AC-002 on FAIL read logs, record failure reason in report artifact | 2 | `AC-014-02-verifier-ci-check.md` |
| AC-003 fix rounds bounded (max 3); each round re-pushes and re-checks CI | 4, 5 | `AC-014-04-orchestrator-ci-loop.md`, `AC-014-05-pr-opener-repush.md` |
| AC-004 exhaustion stops pipeline with failing check IDs + last log evidence, escalated to human, never silent green | 1, 4 | `AC-014-01-post-pr-ci-doc.md`, `AC-014-04-orchestrator-ci-loop.md` |
| AC-005 report artifact records CI outcome per check and per round | 1, 2 | `AC-014-01-post-pr-ci-doc.md`, `AC-014-02-verifier-ci-check.md` |

## Open questions (need a human answer before /build)

1. **How are the acceptance scenarios tested?** Like 008, this spec changes only
   markdown prompts/docs, and its scenarios assert file *content* (e.g. "the file
   contains the string `gh pr checks ...`"). The traceability gate requires every
   scenario ID be cited by a real test. Options: (a) a small
   `scripts/check-post-pr-ci-loop.sh` (grep-assert on the touched files) wired
   into `.github/workflows/self-ci.yml` — the repo's established pattern for
   docs-content assertions, mirroring 008's open question 1; or (b) assert via the
   existing harness only. My recommendation: (a). Confirm before `/build`.
2. **Should the final phase-2 verdict mirror into `30-report.md`?** The informal
   spec says "25-verification.md or 30-report.md". `30-report.md` is written
   exclusively by `spec-mutation-runner` before the PR opens; the PR body links it.
   Keeping the phase-2 verdict only in `25-verification.md` avoids a permission
   change but means the report the PR body links doesn't carry CI outcome. My
   recommendation: keep `25-verification.md` as the sole phase-2 audit artifact —
   it survives in the PR branch, satisfies the informal ACs, and keeps
   `spec-mutation-runner` the only writer of `30-report.md`. Confirm.
3. **Who owns the phase-2 counter.** Mirror 008's open question 4: the
   orchestrator owns the counter (build.md + spec-pipeline.md), the Verifier
   merely records the round index. I designed tasks 2 and 4 on that assumption.
   Confirm, or say the Verifier itself should refuse a 4th invocation.
4. **Ordering with 008.** 008 defines the phase-2 budget policy; 014 defines the
   phase-2 mechanics and references 008's terms ("Phase 2 — Post-PR loop", max 3,
   independent counter). If 008 lands after 014, task 1's sub-section has nothing
   to hang off and task 4's "reference 008" instruction is unresolvable. I
   recommend **008 first, then 014**. Confirm, or say 014 should restate the
   budget (which would contradict 008's "policy lives in 008" split).
5. **Draft PR vs CI.** The PR Opener opens the PR **as a draft**. GitHub Actions
   runs checks on draft PRs, so `gh pr checks` will report the Self CI checks — but
   if a future workflow is conditional on `draft: false`, the checks would never
   appear. Confirm the loop should query the draft PR's checks as-is (no change to
   the PR's draft state needed).

## Acceptance scenarios

## AC-014-01-01 — The exact CI query is named (AC-001)
## AC-014-01-02 — The CI platform and workflow are grounded in this repo
## AC-014-01-03 — Pending checks are polled, not misread
## AC-014-01-04 — Failing check IDs and log read are named (AC-002)
## AC-014-01-05 — Max 3 rounds, independent of Phase 1 (AC-003)
## AC-014-01-06 — Exhaustion escalates to the human (AC-004)
## AC-014-01-07 — Per-check and per-round outcome recorded (AC-005)
## AC-014-01-08 — No open-ended re-run phrasing
## AC-014-01-09 — Ordering dependency on 008 is stated
## AC-014-02-01 — The Verifier runs the real CI query (AC-001)
## AC-014-02-02 — Pending checks are polled to terminal
## AC-014-02-03 — On FAIL the Verifier reads the logs and records the reason (AC-002)
## AC-014-02-04 — Per-check and per-round record in 25-verification.md (AC-005)
## AC-014-02-05 — Diagnosis handed back, scoped re-check on re-trigger
## AC-014-02-06 — Frontmatter and permissions are unchanged
## AC-014-02-07 — No open-ended re-run phrasing is added
## AC-014-03-01 — Coder fixes only the diagnosed failing check
## AC-014-03-02 — Coder's re-fix is bounded by the orchestrator's counter (AC-003)
## AC-014-03-03 — Refactorer gets the same bounded rule
## AC-014-03-04 — Fixers never push
## AC-014-03-05 — Information barriers are unchanged
## AC-014-03-06 — No open-ended re-run phrasing is added
## AC-014-04-01 — commands/build.md describes a bounded post-PR CI loop
## AC-014-04-02 — agents/spec-pipeline.md describes the same bounded loop
## AC-014-04-03 — Counter independent of Phase 1, max 3 (AC-003)
## AC-014-04-04 — Exhaustion stops the pipeline with the escalation payload (AC-004)
## AC-014-04-05 — Never a silent green (AC-004)
## AC-014-04-06 — Each re-push re-triggers CI
## AC-014-04-07 — Orchestrator stays out of the mechanics
## AC-014-04-08 — No open-ended re-run phrasing in the loop
## AC-014-04-09 — No new infrastructure is introduced
## AC-014-05-01 — Fix-round re-push mode (AC-003)
## AC-014-05-02 — No second PR is opened
## AC-014-05-03 — Re-push re-triggers CI
## AC-014-05-04 — Initial-open and safety rules are unchanged
## AC-014-05-05 — Frontmatter is unchanged
## AC-014-05-06 — No open-ended re-run phrasing is added

## Verification

# Verification — spec 014 (CI-failure check-and-remediate loop)

**Verifier:** stage 4, independent re-run of Coder + Refactorer claims.
**Branch:** `spec/014-ci-failure-remediation`
**Date:** 2026-08-15
**Sources checked against:** `10-tasks.md`, `20-acceptance/AC-014-01..05` (37 sub-IDs).
`00-informal.md` was **not** read (information barrier).

---

## Check 1 — Scenario traceability — PASS (AC-014 scope clean)

**Command:** `bash scripts/check-scenario-traceability.sh`
**Full-repo exit code: 1** — 126 violations, all in sibling/archived specs. This is
the known mid-pipeline condition: in-flight specs 007–013, 015, 017–019 have
scenario headings with no test citations yet, and archived specs (001–006, 016,
020–022) have test citations whose scenario headings were removed from `specs/`
on archive. **Zero AC-014 entries appear in either FAIL group.**

Full-repo AC-014 result (representative excerpt):
```
PASS AC-014-01 — traced to a test
PASS AC-014-02 — traced to a test
PASS AC-014-03 — traced to a test
PASS AC-014-04 — traced to a test
PASS AC-014-05 — traced to a test
✘ Scenario traceability check: 126 violation(s).   (exit 1)
```

**Scoped AC-014 run** (scratch `SPECS_DIR` containing only
`014/20-acceptance/*.md` + the touched source files):
```
Scenario IDs found: 5
PASS AC-014-01 — traced to a test
PASS AC-014-02 — traced to a test
PASS AC-014-03 — traced to a test
PASS AC-014-04 — traced to a test
PASS AC-014-05 — traced to a test
✘ ... 3 violation(s).   (exit 1)
```
The scoped run's 3 check-2 violations are `AC-002-01`, `AC-002-02`, `AC-004-04`
— pre-existing citations in `docs/SPEC_PIPELINE.md` scenario-format examples
(lines 134/140/152, present on `main` before 014) and archived one-pagers. The
014 diff introduces **zero** non-014 AC citations (`git diff | grep '^+'` AC-ID
scan: empty).

**Sub-ID coverage (37 per the Coder — confirmed):**
```
sub-IDs defined in 20-acceptance: 37
sub-IDs asserted in check-post-pr-ci-loop.sh: 37
defined-but-not-asserted: (none)
asserted-but-not-defined: (none)
```
Every AC-014 sub-ID (9+7+6+9+6 = 37) is asserted by the test carrier, and every
asserted ID exists as a scenario heading. No AC-014 reference dangles.

**Judgment: AC-014 scope is clean.** The full-repo exit 1 is entirely
attributable to sibling/archived specs, not spec 014.

---

## Check 2 — Full relevant suite — PASS

Spec 014 is prompts/docs-only (no JVM/Go/Node stack); its "test suite" is the
shipped check script plus the repo gates. All executed for real:

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-post-pr-ci-loop.sh` | 0 | syntax OK |
| `bash scripts/check-post-pr-ci-loop.sh` | 0 | "Post-PR CI loop check: all assertions hold." |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | "All validations passed" (35 required files; 1 pre-existing SKILL.md WARN, skills/hallmark) |
| `make lint` | 0 | All JSON/YAML valid; `.github/workflows/self-ci.yml` `[OK]` |

`.github/workflows/self-ci.yml` parses (YAML validation `[OK]` in `make lint`)
and contains the new step, hard-gated (no `continue-on-error`):
```yaml
      - name: Check post-PR CI loop mechanics
        run: ./scripts/check-post-pr-ci-loop.sh
```

### Assertion-count reconciliation (Coder 92/92 vs Refactorer 125)

**Actual, measured from a real run** (ANSI-stripped):
```
PASS lines: 125     FAIL lines: 0
per task: task1=23  task2=19  task3=20  task4=51  task5=12   (sum 125)
```
**125 is the operative number and matches the Refactorer's report exactly.**
The Coder's "92/92 PASS" is **not reproducible from the current tree**: the
script is untracked (`?? scripts/check-post-pr-ci-loop.sh`), so no prior
revision exists to diff against. Both counts cannot describe the same script
state; the Coder's 92 is either a stale count from an earlier iteration or a
different counting convention. The Refactorer's "no assertions added or
removed" is likewise unverifiable from git history (untracked file), but its
**reported count (125) matches the live script's actual output exactly**, which
is the claim that matters for the gate. The assertion set is complete and
consistent: all 37 scenario sub-IDs are asserted, and the negative fixture
(Check 4) proves the assertions detect real violations.

---

## Check 3 — Complexity gate — PASS

Changed files are markdown prompts/docs + one bash script; no Go/Java/JS
changed, so the applicable real linters are `bash -n` (green, above) and the
design-principles gate (Check 3.5). For the check script, the Refactorer's
claims were verified directly:

- **All functions ≤2:** every function's bash-level cyclomatic complexity was
  counted: `pass`, `fail`, `section`, `contains`, `absent` = 1 (no branches);
  `frontmatter`, `str_contains`, `str_absent` = 2 (single if/else). The
  top-level agent-resolution `while` loop has one if/else (2). **Claim holds.**
- **contains/absent consolidated as thin delegates:** `contains()` and
  `absent()` are one-line wrappers delegating to `str_contains`/`str_absent`
  (lines 103–111). **Claim holds.**
- **SIGPIPE flake fix (pipes → here-strings):** `str_contains`/`str_absent`
  use `grep -q... <<< "$hay"` (here-string), not `... | grep -q`. The fix is
  technically sound: with `set -o pipefail`, `grep -q` exiting on first match
  SIGPIPEs the upstream producer, making the pipeline report failure for a
  pattern that IS present. The script documents this at lines 81–83.
- **Stress/stability:** 10 consecutive runs (plus ~15 total across this
  session) → **0 failures**, exit 0 every time. Stable, no flake reproduced.
- **Assertion semantics unchanged:** all 37 sub-IDs asserted; every asserted
  string verified present in the target files (the 125 PASS lines are real
  matches); negative fixture (Check 4) confirms wrong content is flagged.

---

## Check 3.5 — Design-principles gate — FAIL (pre-existing, NOT attributable to spec 014)

**Command:** `scripts/check-code-principles.sh` (default mode)
**Exit code: 1** — 5 FAIL(s), 17 WARN(s).

**Every FAIL/WARN is confined to `ci/templates/*`** — files untouched by spec
014. Verbatim FAIL lines:
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```
Verbatim WARN lines (17; excerpt covers all distinct sources):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): ...
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```
(Full duplication block bodies omitted here — all 17 WARNs are in
`ci/templates/go-saga-lint.go`, `eslint-saga-rules/saga-compensation.js`,
`archunit/OutboxArchRules.java`, `archunit/SagaArchRules.java`.)

**Attribution judgment:** zero FAIL/WARN references any spec-014 file
(`agents/*`, `commands/build.md`, `docs/SPEC_PIPELINE.md`,
`.github/workflows/self-ci.yml`, `scripts/check-post-pr-ci-loop.sh` — verified
by grep over the full output). This is the documented pre-existing repo state
(saga/outbox template lints). Per policy, a FAIL is a pipeline stop *if
attributable to the change*; here none is. Recorded as pre-existing; flagged
to the Architect for awareness (the `ci/templates/*` gate debt is outside 014's
scope).

**mvp-tier confirmation:** no `AGENTS_<PROJECT>.md` exists at repo root or in
`.standards/`. The gate itself printed `Property tests: skipped (project tier
is mvp — production+ required)` — tier detection works, so the property-test
skips (and the mutation-runner skip) are correct for this project.

---

## Check 4 — Scenario-to-behavior spot check — PASS

Two scenarios hand-verified against the actual files (content assertions, per
the 10-tasks.md test-carrier design):

**AC-014-05-01/02/04 (PR Opener re-push)** — `agents/spec-pr-opener.md` lines
72–85 contain the fix-round mode: commits "as one conventional commit
(`fix: ...` referencing the failing check ID(s))" on the existing
`spec/NNN-slug` branch (AC-014-05-01), "you do not open a new PR" + `gh pr view`
(AC-014-05-02), and preserves "`30-report.md` to be green", "never commit to
`main`/`master`", "never create git version tags" (AC-014-05-04). Frontmatter
line 10: `"git push*": ask` (AC-014-05-05). **Given/When/Then implemented.**

**AC-014-04-01/03/04/07 (bounded orchestrator loop)** — `commands/build.md`
lines 23–39: loop starts "After the PR Opener reports the PR URL", invokes
`spec-verifier`, routes to `spec-coder`/`spec-refactorer`, re-invokes
`spec-pr-opener`, scoped re-check, "at most 3 rounds", "independent of Phase 1
... per spec 008's remediation-budget section (do not re-declare the budget)",
"On the 3rd FAIL ... relay ... verbatim and escalate to the human — no 4th
round", "never reported as green without a fixing round". The step list does
not tell the orchestrator to run `gh` or `git commit/push` (AC-014-04-07 —
script asserts absence). **Given/When/Then implemented.**

**Also verified (from the check list):** `docs/SPEC_PIPELINE.md` lines 218–248
carry the exact `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`
query, the `bucket` parse rule, `--watch` polling, `gh api .../check-runs` +
`gh run view <RUN-ID> --log-failed`, "at most 3", "independent of Phase 1",
008 ordering dependency ("valid only once 008's section exists") — and no
"re-run until green" phrasing anywhere. `agents/spec-verifier.md` lines 90–114
have the phase-2 section with `--log-failed`, `conclusion == "failure"`,
scoped re-check on re-trigger, and unchanged frontmatter
(`edit: specs/*/25-verification.md` allow; `git commit*`/`git push*` deny).

**Negative fixture (assertion realism):** copied the touched tree to
`/tmp/opencode/014-neg`, injected two wrong strings into the copy of
`docs/SPEC_PIPELINE.md` (`gh pr checks` → `gh pr checkz`, `PASS/FAIL parse
rule` → `PASS/FAIL parse rulz`), ran
`scripts/check-post-pr-ci-loop.sh <scratch>`:
```
FAIL AC-014-01-01 — expected 'gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link' in ...
FAIL AC-014-01-01 — expected 'PASS/FAIL parse rule' in ...
5 assertion(s) failed!   (exit 1)
```
The injected wrong strings were flagged; the assertions reference real content
and detect deviations. Scratch removed afterward.

---

## Check 5 — No unaccounted behavior — PASS

Full diff skimmed (`git diff` = 8 files, +140 lines, 0 deletions; plus the new
untracked script). Every change traces to a task or a documented decision:

| Change | Traces to |
|---|---|
| `docs/SPEC_PIPELINE.md` +32 | Task 1 (AC-014-01) |
| `agents/spec-verifier.md` +26 | Task 2 (AC-014-02) |
| `agents/spec-coder.md` +14, `agents/spec-refactorer.md` +15 | Task 3 (AC-014-03) |
| `commands/build.md` +18, `agents/spec-pipeline.md` +14 | Task 4 (AC-014-04) |
| `agents/spec-pr-opener.md` +15 | Task 5 (AC-014-05) |
| `scripts/check-post-pr-ci-loop.sh` (new, untracked) | 10-tasks.md open question 1, recommendation (a) — test carrier |
| `.github/workflows/self-ci.yml` +6 (new hard-gated step) | 10-tasks.md open question 1, recommendation (a) — carrier wired into CI |

No new agents, no new CI infrastructure beyond the single check step, no
logic that lacks a task/scenario justification. The script's own negative
assertions ("banned phrase" patterns) are intentionally present in the script
itself but asserted absent from the checked files — documented at script lines
25–29, correct as written (the script is the test carrier, not an assertion
target).

---

## Overall verdict: **PASS**

Architect may proceed. All spec-014-attributable gates are green:

1. Traceability: AC-014-01..05 traced, 37/37 sub-IDs asserted bidirectionally,
   zero dangling AC-014 refs. Full-repo exit 1 is the documented sibling/archived
   condition, not 014.
2. Suite: check script exit 0 (125/125 PASS), `bash -n` OK, orchestration 0,
   `make validate-all` 0, `make lint` 0, self-ci.yml parses with the new
   hard-gated step.
3. Complexity: all functions ≤2, thin delegates, here-string SIGPIPE fix,
   stable across 10 runs, semantics proven by negative fixture.
3.5. Design-principles gate exits 1 — **all 5 FAILs / 17 WARNs confined to
   `ci/templates/*`, none attributable to spec 014** (pre-existing repo debt;
   flagged to Architect, not a stop for this spec).
4. Spot checks (AC-014-05, AC-014-04 + doc/verifier/pipeline sections) match
   Given/When/Then; negative fixture flags injected wrong content.
5. No unaccounted behavior in the diff.

**Discrepancy noted (non-blocking):** Coder's "92/92 PASS" is unreproducible
from the current tree (script untracked, no history); the Refactorer's 125
matches the live run exactly and is the authoritative count.

## Quality gates

# Mutation / Gate Report — spec 014 (CI-failure check-and-remediate loop)

**Stage:** 5a Mutation Runner
**Branch:** `spec/014-ci-failure-remediation`
**Date:** 2026-08-15

## Verifier's verdict (carried forward)

**PASS** — `specs/014-ci-failure-remediation/25-verification.md` (2026-08-15):
all spec-014-attributable gates green — traceability clean for AC-014 (37/37
sub-IDs asserted bidirectionally), suite green, complexity claims hold,
spot checks match Given/When/Then, no unaccounted behavior. The design-principles
gate's 5 FAIL / 17 WARN are confined to `ci/templates/*`, pre-existing repo debt
not attributable to 014.

## Mutation score

**Skipped — `mvp` tier.**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate; `mvp` runs the 4-stage pipeline (Specifier, Coder,
Refactorer, Verifier). No mutation tooling attempted. (Also, the changed code
is a bash check script + markdown prompts/docs + workflow YAML; this repo has
no mutation tooling for shell.)

## Complexity summary (carried from the Refactorer, re-verified by the Verifier)

- All functions ≤2 (no applicable complexity linter for shell):
  - `pass`, `fail`, `section`, `contains`, `absent` = 1 (no branches)
  - `frontmatter`, `str_contains`, `str_absent` = 2 (single if/else)
  - Top-level agent-resolution `while` loop = 2 (one if/else)
- `contains`/`absent` are thin one-line delegates to `str_contains`/`str_absent`.
- SIGPIPE flake fix: `grep -q ... <<< "$hay"` (here-strings) instead of pipes,
  with `set -o pipefail`.

## Equivalent mutants

**None.** No mutants generated (mutation testing not run at `mvp` tier), so no
un-killable equivalents to name.

## Final test status

Re-run 2026-08-15, all green:

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-post-pr-ci-loop.sh` | 0 | syntax OK |
| `bash scripts/check-post-pr-ci-loop.sh` | 0 | **125 PASS / 0 FAIL** — "all assertions hold" |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid" |
| `make validate-all` | 0 | "All validations passed" (1 pre-existing SKILL.md WARN, `skills/hallmark`) |
| `25-verification.md` present | — | verdict PASS |

### Assertion-count reconciliation

Live re-run (ANSI-stripped): **125 PASS, 0 FAIL** — per task
task1=23, task2=19, task3=20, task4=51, task5=12 (sum 125). This matches the
Refactorer's report and the Verifier's measured count exactly. The Coder's
"92/92 PASS" is unreproducible from the current tree (the script is untracked,
so no prior revision exists to diff against); recorded as a stale/inconsistent
count — non-blocking, and the authoritative gate number is 125. All 37
AC-014 sub-IDs are asserted; the Verifier's negative fixture proved the
assertions detect injected wrong content.

## Conclusion

GREEN for the `mvp` conformance tier. Stage 5b (PR Opener) may proceed: run
`scripts/archive-spec.sh 014-ci-failure-remediation`, push, open the draft PR.
