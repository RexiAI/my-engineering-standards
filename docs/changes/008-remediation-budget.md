# 008-remediation-budget

> Spec pipeline archive. Original source: `specs/008-remediation-budget/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Bounded remediation budget

Every gate-failure loop is bounded. Two independent phases:

- **Phase 1 — Pre-PR loop** (local gates + design gates; Verifier BLOCK →
  Coder/Refactorer): max 3.
- **Phase 2 — Post-PR loop** (CI gates, after push): max 3, independent of Phase 1.

On exhausting either budget: stop, emit the failing gate IDs + last evidence,
escalate to the human. "Re-run until green" is forbidden phrasing. On a BLOCK,
the Verifier re-runs only the failing gates (scoped re-verification), not the
whole suite.

## Acceptance criteria

- AC-001: docs/SPEC_PIPELINE.md documents both phases with the max-3 budgets and
  the independent-counter rule.
- AC-002: spec-verifier.md and spec-coder.md encode the budget (verifier stops
  relaying BLOCKs after 3; coder stops re-fixing after 3).
- AC-003: "re-run until green is forbidden phrasing" appears verbatim in the
  pipeline docs.
- AC-004: 30-report.md records which phase and attempt count a BLOCK was resolved
  at, so budget exhaustion is auditable.

## Tasks

# Tasks — Bounded remediation budget

Formalization of `specs/008-remediation-budget/00-informal.md`. Goal: every
gate-failure loop in the spec pipeline is bounded — max 3 fix attempts per
phase, two independent phases (pre-PR and post-PR), exhaustion stops the
pipeline and escalates to the human with the failing gate IDs and last
evidence. This is a prompts/docs-only spec: it changes the pipeline's
prompts and documentation, and touches no new infrastructure.

## Grounded reality (verified against this repo)

- **The phase-1 loop lives in two places, and today it is not a loop.** Both
  `commands/build.md` (lines 11-18) and `agents/spec-pipeline.md` (lines
  20-30) describe the `/build` flow as: coder → refactorer → verifier →
  mutation-runner → pr-opener, with a **one-shot stop** on Verifier FAIL —
  "stop and relay its report; do not attempt to fix the failure yourself".
  There is no re-delegation back to Coder/Refactorer and no attempt cap. The
  bounded loop the informal spec describes must be written into these two
  files; that is where the budget becomes enforceable, not just documented.
- **`agents/spec-verifier.md` has no budget and no scoped re-verification.**
  Its "On failure" section (lines 90-94) says the human or "a re-run of
  Coder/Refactorer" re-triggers it — with no cap and no instruction to re-run
  only the failing gates on a re-trigger. The verifier's only edit permission
  is `specs/*/25-verification.md` (frontmatter lines 8-9), so recording a
  re-verification attempt index there needs no permission change.
- **`agents/spec-coder.md` and `agents/spec-refactorer.md` have no re-fix cap.**
  Neither prompt mentions re-fixing a Verifier BLOCK at all. The informal
  spec's loop names both as the fixers ("Verifier BLOCK → Coder/Refactorer"),
  so both need the "stop re-fixing after 3" language. AC-002 names only the
  Coder; the Refactorer's inclusion is implied by the loop description — see
  open question 3.
- **`agents/spec-mutation-runner.md` writes `30-report.md`** (description,
  lines 2 and 64-70) and is the only writer of it; `spec-pr-opener` reads it
  as its precondition and `scripts/archive-spec.sh` consumes it. The phase +
  attempt record (informal AC-004) must be added to the Report section of
  this prompt. The record can be carried from the verifier's `25-verification.md`
  attempt entries (task 2) — nothing about the report's other sections changes.
- **`docs/SPEC_PIPELINE.md` has no remediation-budget section.** The
  "Commit and push carve-out" (line 172) says "Any gate failure halts the
  pipeline. Nothing is committed." — that halt now means *after budget
  exhaustion*, so the new section must reconcile with that wording to keep
  the doc internally consistent. The artifact-layout line for `30-report.md`
  (line 57) says "mutation score, complexity, gate results" — it may also
  gain the remediation record, but the authoritative statement lives in the
  new section.
- **No "re-run until green" phrasing exists anywhere in agents/, commands/,
  or docs/ today** (verified by repo-wide grep). AC-003 only *adds* the
  prohibition; nothing needs to be removed.
- **Spec 014 (`specs/014-ci-failure-remediation/00-informal.md`, exists)
  implements the post-PR CI loop** and explicitly says "mirror the
  remediation-budget spec". 008 is the budget *policy* (both phases, both
  counters, exhaustion behavior, audit record); 014 is the phase-2 loop
  *mechanism* (query CI, read logs, fix-and-repush). 008 must document the
  phase-2 budget and the independent-counter rule, but must not build the
  CI-query machinery — that would duplicate 014. See open question 2.

## Tasks

### Task 1 — Document the remediation budget in `docs/SPEC_PIPELINE.md`

Add a section (e.g. `## Remediation budget`, placed after "Commit and push
carve-out" so it reads as the continuation of the halt rule) that states the
policy the informal spec requires. No other doc changes.

Acceptance criteria:
- The section names **Phase 1 — Pre-PR loop** (local gates and design gates;
  a Verifier BLOCK hands back to Coder/Refactorer) and states its budget is
  **max 3**.
- The section names **Phase 2 — Post-PR loop** (CI gates, after the push)
  and states its budget is **max 3**, with the counter **independent of
  Phase 1**.
- The section states that exhausting either budget stops the pipeline, emits
  the failing gate IDs and the last evidence, and escalates to the human.
- The exact string `re-run until green is forbidden phrasing` appears
  verbatim in the section (informal AC-003 requires the verbatim phrase).
- The section states that on a BLOCK the Verifier re-runs **only the failing
  gates** (scoped re-verification), not the whole suite.
- The section states that `30-report.md` records which phase and attempt
  count each BLOCK was resolved at, so budget exhaustion is auditable.
- The section reconciles with the "Commit and push carve-out" wording
  (docs/SPEC_PIPELINE.md:172, "Any gate failure halts the pipeline") so the
  doc reads consistently: a gate failure triggers remediation up to the cap,
  and only the post-exhaustion stop is the halt the carve-out describes.
- The section describes the *policy* for Phase 2 only — it must not specify
  CI-query or log-reading mechanics (that is spec 014's territory).
- No other sections of the file change beyond this addition and, if the
  Coder chooses, the `30-report.md` artifact-layout line (line 57).

Scenarios: `20-acceptance/AC-008-01-remediation-budget-doc.md`

### Task 2 — Encode the budget and scoped re-verification in `agents/spec-verifier.md`

Update the Verifier prompt so the budget and the scoped re-verification rule
are part of its instructions.

Acceptance criteria:
- The prompt states the Verifier stops relaying BLOCKs after **3** per phase
  (phase-1 cap): it must not expect or accept a 4th re-verification of the
  same BLOCK.
- The prompt states that on a re-trigger it performs **scoped re-verification**:
  it reads its prior `25-verification.md`, re-runs only the gates that
  previously failed, and records per-gate results for just those gates.
- The prompt requires recording the **re-verification attempt index and
  phase** in `25-verification.md` on every re-verification, so the attempt
  count is auditable and `30-report.md` (task 5) can carry it forward.
- The prompt's "On failure" section keeps "stop the pipeline / do not fix
  anything yourself" but reflects the cap: the final BLOCK report names the
  failing gate IDs and the last evidence, and states the phase-1 budget is
  exhausted (this is what the orchestrator escalates verbatim).
- The verifier's frontmatter is unchanged — no permission changes; the
  existing `edit: specs/*/25-verification.md` allowance already covers the
  attempt-record write.
- The prompt does not gain "re-run until green" or any equivalent
  open-ended re-run phrasing.

Scenarios: `20-acceptance/AC-008-02-verifier-budget.md`

### Task 3 — Encode the re-fix cap in `agents/spec-coder.md` and `agents/spec-refactorer.md`

Add the bounded re-fix rule to both fixer prompts.

Acceptance criteria:
- `agents/spec-coder.md` states the Coder stops re-fixing after **3** attempts
  per BLOCK: on the 3rd fix that still fails, it does not accept another
  re-fix request, and hands back with the failing gate IDs and the last
  evidence for escalation.
- `agents/spec-refactorer.md` states the same cap for structural re-fixes:
  max 3 per BLOCK, exhaustion = report and do not accept further re-fix
  requests.
- Neither prompt changes its frontmatter or permission rules.
- Neither prompt gains "re-run until green" or any equivalent open-ended
  re-run phrasing.
- The existing "do not commit or push" constraints in both prompts are
  unchanged.

Scenarios: `20-acceptance/AC-008-03-fixer-budget.md`

### Task 4 — Make the Phase-1 loop bounded in `commands/build.md` and `agents/spec-pipeline.md`

Replace the one-shot stop-on-FAIL with a bounded loop, in both the `/build`
command and the orchestrator prompt. These are the files that actually run
the loop, so this task is where the budget is enforced.

Acceptance criteria:
- Both `commands/build.md` and `agents/spec-pipeline.md` describe a bounded
  phase-1 loop: on a Verifier BLOCK, re-delegate the failing fix back (Coder
  for behavior failures, Refactorer for structural/complexity failures), then
  re-invoke the Verifier for scoped re-verification — up to **3** cycles.
- Both files state that on the 3rd BLOCK the pipeline stops, relays the
  failing gate IDs and the last evidence from `25-verification.md` verbatim,
  and escalates to the human; there is no 4th re-delegation.
- Neither file contains "re-run until green" phrasing.
- Stage-5 agents (mutation-runner, pr-opener) still run only after a Verifier
  PASS — which, under the budget, may now be a post-remediation PASS.
- The phase-1 loop language must not contradict the phase-2 budget: the files
  acknowledge (at most one sentence) that a separate post-PR CI loop exists
  with its own independent max-3 budget, but they do not implement that loop
  (spec 014's territory).
- No new files, agents, or infrastructure are introduced.

Scenarios: `20-acceptance/AC-008-04-orchestrator-loop.md`

### Task 5 — Record phase + attempt count in `30-report.md` via `agents/spec-mutation-runner.md`

Add the remediation record to the report the Mutation Runner writes.

Acceptance criteria:
- The Report section of `agents/spec-mutation-runner.md` (lines 64-70)
  requires a **remediation record** in `30-report.md`: for each BLOCK that
  occurred during the run, the phase (1 or 2) and the attempt count at which
  it was resolved; or an explicit `none` when no BLOCK occurred.
- The prompt instructs the Mutation Runner to carry the record forward from
  `25-verification.md` (the verifier's attempt-index entries from task 2) and
  from the orchestrator's loop summary — not to invent or guess it.
- The prompt states that if no `25-verification.md` attempt information is
  present, the record says so rather than fabricating a phase/attempt.
- No other Report section items change (verifier verdict, mutation score,
  complexity summary, equivalent mutants, final test status all stay).
- The frontmatter and the stage-5a responsibilities ("does not commit, push,
  or open PRs") are unchanged.

Scenarios: `20-acceptance/AC-008-05-report-remediation-record.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 docs document both phases, max-3 budgets, independent-counter rule | 1 | `AC-008-01-remediation-budget-doc.md` |
| AC-002 spec-verifier.md and spec-coder.md encode the budget | 2, 3 | `AC-008-02-verifier-budget.md`, `AC-008-03-fixer-budget.md` |
| AC-003 "re-run until green is forbidden phrasing" verbatim in pipeline docs | 1 | `AC-008-01-remediation-budget-doc.md` |
| AC-004 30-report.md records phase + attempt count | 1 (policy), 5 (implementation) | `AC-008-01-remediation-budget-doc.md`, `AC-008-05-report-remediation-record.md` |

## Open questions (need a human answer before /build)

1. **How are the acceptance scenarios tested?** This spec changes only
   markdown prompts/docs, and its scenarios assert file *content* (e.g. "the
   file contains the string ..."). This repo's existing test surface is shell
   checks (`scripts/check-orchestration.sh`, `make validate-refs`) wired into
   self-ci. Options: (a) add a small `scripts/check-remediation-budget.sh`
   (grep-based content assertions) wired into `.github/workflows/self-ci.yml`
   — the traceability gate then has real tests, mirroring spec 006; or (b) no
   script, tests assert via the repo's existing harness. Option (a) is new
   infrastructure, which the informal spec says to avoid unless implied —
   but the pipeline's traceability gate requires scenario IDs cited by real
   tests, and grep-asserting a docs change is the repo's established pattern.
   My recommendation: (a). Confirm before `/build`.
2. **Boundary with spec 014 (`014-ci-failure-remediation`).** 014 (informal,
   present) will implement the post-PR CI loop mechanics and says "mirror the
   remediation-budget spec". Confirm 008 defines budget *policy* for both
   phases plus the phase-1 prompt changes and the `30-report.md` record, and
   that 014 lands the phase-2 loop *mechanism* — and that 008 should land
   first (014 depends on its language).
3. **Refactorer inclusion.** Informal AC-002 names `spec-verifier.md` and
   `spec-coder.md` only, but the loop description explicitly routes BLOCKs to
   "Coder/Refactorer". Task 3 extends the cap to `spec-refactorer.md` on that
   implication. Confirm that is the intended reading; drop it if the budget
   is meant to apply only to the Coder.
4. **Who owns the attempt counter.** The informal spec says the verifier
   "stops relaying BLOCKs after 3" — either the orchestrator stops
   re-invoking it (counter in build.md/spec-pipeline.md, verifier just
   records the index) or the verifier itself refuses a 4th invocation. My
   recommendation: orchestrator-owned counter (task 4) with the verifier
   recording the index (task 2) — otherwise the verifier has no reliable way
   to know its attempt number without state. Confirm.
5. **Exhaustion leaves no `30-report.md`.** If phase 1 exhausts its budget,
   mutation-runner and pr-opener never run, so `30-report.md` is never
   written — the audit trail for *exhaustion* lives in the verifier's final
   `25-verification.md` BLOCK report plus the orchestrator's escalation
   summary. Informal AC-004 covers the "resolved at phase/attempt" record;
   exhaustion is a different artifact. Confirm that split is acceptable, or
   say the orchestrator should write a minimal `30-report.md` on exhaustion.

## Acceptance scenarios

## AC-008-01-01 — Phase 1 documented with a max-3 budget (AC-001)
## AC-008-01-02 — Phase 2 documented with an independent max-3 budget (AC-001)
## AC-008-01-03 — Budget exhaustion stops the pipeline and escalates to the human
## AC-008-01-04 — The forbidden phrasing appears verbatim (AC-003)
## AC-008-01-05 — Scoped re-verification on BLOCK
## AC-008-01-06 — 30-report.md records phase and attempt count (AC-004)
## AC-008-01-07 — The section reconciles with the carve-out halt rule
## AC-008-01-08 — The section does not specify Phase 2 loop mechanics
## AC-008-02-01 — Verifier stops relaying BLOCKs after 3 (AC-002)
## AC-008-02-02 — Re-trigger means scoped re-verification, not the whole suite
## AC-008-02-03 — Re-verification attempt index and phase are recorded
## AC-008-02-04 — Final BLOCK report carries the escalation payload
## AC-008-02-05 — Frontmatter and permissions are unchanged
## AC-008-02-06 — No open-ended re-run phrasing is added
## AC-008-03-01 — Coder stops re-fixing after 3 (AC-002)
## AC-008-03-02 — Coder hands back with failing gate IDs and last evidence
## AC-008-03-03 — Refactorer mirrors the cap
## AC-008-03-04 — No frontmatter or permission changes
## AC-008-03-05 — No open-ended re-run phrasing in either fixer prompt
## AC-008-04-01 — commands/build.md describes a bounded phase-1 loop
## AC-008-04-02 — agents/spec-pipeline.md describes the same bounded loop
## AC-008-04-03 — Exhaustion stops the pipeline with the escalation payload
## AC-008-04-04 — Stage-5 agents still require a Verifier PASS
## AC-008-04-05 — Phase-2 independence is acknowledged but not implemented
## AC-008-04-06 — No open-ended re-run phrasing in the loop
## AC-008-04-07 — No new infrastructure is introduced
## AC-008-05-01 — The Report section requires a remediation record (AC-004)
## AC-008-05-02 — The record is carried forward, not invented
## AC-008-05-03 — Missing attempt information is reported, not fabricated
## AC-008-05-04 — Other Report items are unchanged
## AC-008-05-05 — Stage-5a responsibilities are unchanged

## Verification

# Verification Report — spec 008: Bounded remediation budget

Stage: 4 (Verifier). Attempt 1, phase 1 (first full run).
Date: 2026-08-15. Branch: `spec/008-remediation-budget`.
Scope of changes under test: `docs/SPEC_PIPELINE.md`, `agents/spec-verifier.md`,
`agents/spec-coder.md`, `agents/spec-refactorer.md`, `agents/spec-pipeline.md`,
`agents/spec-mutation-runner.md`, `commands/build.md`,
`.github/workflows/self-ci.yml`, and the new untracked
`scripts/check-remediation-budget.sh` (test carrier).

No production code was written; the only write is this file.

---

## 1. Scenario traceability — PASS (scoped AC-008 clean; full-repo exit 1, pre-existing)

Command: `scripts/check-scenario-traceability.sh`
Full-repo exit code: **1** (126 violations).

The full-repo failure is the known mid-pipeline state, not a spec-008 defect:

- Defined-but-untraced: AC-007-01..04, AC-009..AC-019 (sibling in-flight specs
  with no test carrier yet).
- Referenced-but-no-heading (stale/archived): AC-001..AC-006, AC-016, AC-020..AC-022
  (archived-spec citations in existing checks, matching `docs/changes/` history).

AC-008 scoped result (verbatim from the run):

```
PASS AC-008-01 — traced to a test
PASS AC-008-02 — traced to a test
PASS AC-008-03 — traced to a test
PASS AC-008-04 — traced to a test
PASS AC-008-05 — traced to a test
```

No FAIL line in the entire run contains `AC-008` — all five of spec 008's
scenarios are traced to real tests (the `AC-008-NN` assertion calls in
`scripts/check-remediation-budget.sh`), and no AC-008 reference dangles.
Judgment: **AC-008 scope is clean.**

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-remediation-budget.sh` | 0 | syntax valid |
| `./scripts/check-remediation-budget.sh` | 0 | every check passed (84/84 PASS, `✔ Remediation budget check: every check passed.`) |
| `./scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all 35 required files present, cross-refs valid (1 pre-existing WARN: `skills/hallmark/SKILL.md` >500 lines, unrelated) |
| `make lint` | 0 | all JSON/YAML valid, incl. `.github/workflows/self-ci.yml` |
| `python3 -c "import yaml...; yaml.safe_load(...)" .github/workflows/self-ci.yml` | 0 | `YAML_OK` — workflow still parses |

The new self-ci step is present in `.github/workflows/self-ci.yml` (verbatim
context):

```yaml
      - name: Check remediation budget
        run: ./scripts/check-remediation-budget.sh
```

(placed before "Install shellcheck"; the workflow's `validate` job also still
runs the orchestration and model-env checks — nothing displaced.)

## 3. Complexity gate — NOT APPLICABLE to this change (recorded, not invented)

No cyclomatic-complexity linter is configured for shell in this repo. The
repo's complexity tooling (`pmd`, `golangci-lint` cyclop/gocognit, ESLint
`complexity`) covers Java/Go/JS/TS only, and this spec changed **no
Java/Go/TS/JS files** — the diff is 7 `.md` + 1 `.yml` + 1 new `.sh`.
`check-code-principles.sh` (run below) confirms the same: it analyzes java/go/node
and reported zero violations outside pre-existing `ci/templates/*` state.

For the record (manual count, not a tool): the four named functions each have
cyclomatic complexity 1–2 (`collapse_whitespace` CC=1, single pipeline;
`require_file` CC=2, single `if`; `assert_contains` CC=2, single `if`;
`assert_absent` CC=2, single `if`), consistent with the Refactorer's claim. Note:
self-ci runs `shellcheck scripts/*.sh` (with `continue-on-error: true`), which is
a correctness linter, not a complexity gate; shellcheck is not installed locally,
so it was not re-run here.

## 3.5. Design-principles gate — exit 1, all FAILs/WARNs pre-existing in `ci/templates/*`, none attributable to spec 008

Command: `scripts/check-code-principles.sh` (default mode, repo root)
Exit code: **1** — "5 FAIL(s), 17 WARN(s)." Property tests: skipped
("project tier is mvp — production+ required"), which confirms the mvp tier.

Every FAIL and WARN line, verbatim:

```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Every one is confined to `ci/templates/*` — a directory this spec did not touch.
Spec 008's changed files are `.md`/`.sh`/`.yml`, which the gate's analyzed
languages (java/go/node) do not cover. Judgment: **no FAIL or WARN is
attributable to spec 008's changes.** The pre-existing FAILs are flagged to the
Architect for awareness only (out of this spec's scope; pipeline does not stop on
pre-existing state the spec did not create — the gate's FAILs here are not
"Every FAIL is a pipeline stop" failures of *this* change).

## 4. Scenario-to-behavior spot check — PASS (3 scenarios + adversarial guard test)

**AC-008-01-04 — forbidden phrasing verbatim.** `docs/SPEC_PIPELINE.md` §Remediation
budget (line ~222) contains the exact string `re-run until green is forbidden
phrasing`. Confirmed by direct read, not only via the check script. Also verified
this is the *only* occurrence of `re-run until green` in docs/ — the five prompt
and command files (`spec-verifier.md`, `spec-coder.md`, `spec-refactorer.md`,
`spec-pipeline.md`, `commands/build.md`) contain it nowhere, satisfying the
`assert_absent` scenarios (AC-008-02-06, AC-008-03-05, AC-008-04-06).

**AC-008-04-01 — bounded loop in `commands/build.md`.** Direct read confirms the
command describes: Verifier BLOCK → re-delegate failing fix to `spec-coder`
(behavior) or `spec-refactorer` (structural/complexity) → re-invoke
`spec-verifier` for scoped re-verification → at most **3** cycles; on the 3rd
BLOCK, stop, relay failing gate IDs and last evidence from `25-verification.md`
verbatim, escalate to the human, no 4th re-delegation. Matches Given/When/Then
of AC-008-04-01 and AC-008-04-03.

**Forbidden-phrase guard actually fires (adversarial test).** Created a scratch
tree (`/tmp/opencode/rem-scratch/`) with copies of all touched files, appended
`re-run until green is the plan here` to the scratch `agents/spec-verifier.md`,
and ran `./scripts/check-remediation-budget.sh /tmp/opencode/rem-scratch`:

```
SCRATCH_RUN_EXIT=1
FAIL AC-008-02: no open-ended re-run phrasing — forbidden string 're-run until green' present in .../agents/spec-verifier.md
✘ Remediation budget check: 1 violation(s).
```

Guard verified. Scratch tree removed after the test.

**AC-008-02-05 / AC-008-03-04 — frontmatter and permissions unchanged.** Diff
review: the `agents/spec-verifier.md`, `spec-coder.md`, `spec-refactorer.md`,
`spec-mutation-runner.md` diffs show zero changes inside the YAML frontmatter
(grep for permission/edit/deny/allow lines in the diffs returns empty), and all
four still carry `"git push*": deny` / `"git commit*": deny` (asserted by the
script, which passes). The `edit: specs/*/25-verification.md` allowance is intact.

**Self-ci step present** — see check 2.

## 5. No unaccounted behavior — PASS

Full diff reviewed (8 files, +115/−15). Every hunk traces to a task:

- docs section + `30-report.md` artifact-layout line → Task 1 (artifact-layout
  change explicitly permitted by T1).
- `spec-verifier.md` additions → Task 2.
- `spec-coder.md` / `spec-refactorer.md` re-fix sections → Task 3.
- `commands/build.md` + `spec-pipeline.md` loop rewrite → Task 4 (one-sentence
  phase-2 acknowledgement only; no CI-query mechanics; no new agents/infra).
- `spec-mutation-runner.md` Remediation record bullet → Task 5.
- `self-ci.yml` step + `scripts/check-remediation-budget.sh` → open question 1,
  resolved to option (a) (grep-based content assertions, mirroring spec 006);
  the script is the test carrier that makes AC-008-01..05 traceable.

The new script is not a vacuous pass: 84 `assert_contains`/`assert_absent` calls
(not 86 — count verified by `grep -c`), each with a specific needle against a
specific file. The needles are real strings in the touched files — confirmed by
direct read of every target file during spot checks (e.g. `Phase 1 budget is
**max 3**`, `independent of **Phase 1**`, `re-run until green is forbidden
phrasing`, `failing gate IDs and the last evidence from \`25-verification.md\``),
and by the adversarial test above proving the negative assertions are not
tautological. Missing-file behavior is handled (`require_file` fails loudly, no
silent skip). Exit 0 on the clean tree.

**mvp-tier claim confirmed:** no `AGENTS_*.md` exists at the repo root
(`ls AGENTS_*.md` → no such file). `check-code-principles.sh` derives the tier
from the `AGENTS_*.md` "Conformance tier:" declaration (script lines 40, 80);
absent → mvp. The gate itself printed `(tier: mvp)` and skipped property tests
("Project tier is mvp — production+ required"), so the Architect's
property-test/mutation skips for this spec are correct per the conformance table.

## WARNs to flag to the Architect (review hints, not stops)

1. Design-principles gate: 17 WARNs — all in `ci/templates/*` (go-saga-lint.go,
   eslint-saga-rules, archunit) — pre-existing, untouched by spec 008.
2. `make validate-all`: 1 WARN — `skills/hallmark/SKILL.md` body 562 lines
   (>500 limit) — pre-existing, unrelated.
3. Full-repo traceability exits 1 on sibling/archived specs (see check 1) —
   expected mid-pipeline state; will clear as sibling specs land.

## Verdict

**PASS** — Architect may proceed (mutation run skipped at mvp tier; PR Opener
may proceed per stage-5b).

Every check re-executed independently: AC-008 traceability clean (5/5 traced, no
dangles); new check script runs green (exit 0, 84/84); orchestration, validate-all,
lint, and self-ci YAML all exit 0 with the new "Check remediation budget" step
present; complexity gate not applicable to this shell/markdown-only change (no
Java/Go/TS/JS touched); design-principles gate exit 1 with all FAILs/WARNs
confined to untouched `ci/templates/*`; scenario-to-behavior spot checks match
(file content confirmed by direct read, adversarial forbidden-phrase test fires
with exit 1); diff fully accounted for; mvp-tier claim substantiated.

## Quality gates

# Architect Report — spec 008: Bounded remediation budget

Stage: 5a (Mutation Runner). Date: 2026-08-15. Branch: `spec/008-remediation-budget`.

## Verifier's verdict (carried forward)

**PASS** — from `25-verification.md` (attempt 1, phase 1, first full run). Independent
re-check of stages 2–3: AC-008 traceability clean (5/5 traced, no dangles); the new
check script runs green (84/84); orchestration, validate-all, lint, and self-ci YAML
all exit 0 with the "Check remediation budget" step present; complexity gate not
applicable (no Java/Go/TS/JS touched); design-principles gate exit 1 with all
FAILs/WARNs confined to untouched `ci/templates/*`; scenario-to-behavior spot checks
match; diff fully accounted for; mvp tier substantiated (no `AGENTS_*.md`).

## Mutation score

**skipped — `mvp` tier.** Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation
testing is a `production`-tier gate; at `mvp` it is skipped. The changed code is
shell scripts plus markdown prompts/docs — no mutation tooling for shell exists in
this repo, and no Java/Go/TS/JS files were touched. No mutation run was attempted.

## Complexity summary (carried from the Refactorer, via verification check 3)

No cyclomatic-complexity linter is configured for shell in this repo (repo tooling
covers Java/Go/JS/TS only). Manual count of the four named functions in
`scripts/check-remediation-budget.sh`, all within the ≤6 guideline and consistent
with the Refactorer's claim:

| Function | CC |
|---|---|
| `collapse_whitespace` | 1 (single pipeline) |
| `require_file` | 2 (single `if`) |
| `assert_contains` | 2 (single `if`) |
| `assert_absent` | 2 (single `if`) |

## Equivalent mutants

**None.** Mutation testing was not run (mvp tier), so no surviving mutants — and no
equivalent mutants — were produced. Nothing to name.

## Final test status (re-run after the mutation-skip note)

Full relevant suite re-executed this run, all green:

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-remediation-budget.sh` | 0 | syntax valid |
| `scripts/check-remediation-budget.sh` | 0 | every check passed (84/84 PASS, `✔ Remediation budget check: every check passed.`) |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all 35 required files present, cross-refs valid (1 pre-existing WARN: `skills/hallmark/SKILL.md` >500 lines, unrelated) |

`specs/008-remediation-budget/25-verification.md` exists with verdict **PASS**
(confirmed by direct read before any other action).

## Remediation record (per `docs/SPEC_PIPELINE.md §Remediation budget`)

**none** — no BLOCK occurred during this run. `25-verification.md` records
"Attempt 1, phase 1 (first full run)" with no re-verification attempt entries, so
there is no phase/attempt count to carry forward. Nothing was re-delegated or
re-verified.
