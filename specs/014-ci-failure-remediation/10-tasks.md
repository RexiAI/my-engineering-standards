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
