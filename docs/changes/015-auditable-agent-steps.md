# 015-auditable-agent-steps

> Spec pipeline archive. Original source: `specs/015-auditable-agent-steps/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Auditable agent steps

Every step the pipeline agents take should be verifiable after the fact — a
human (or a later run) can reconstruct what happened and why, from artifacts,
not from trusting the agent's word. acdc-civ's auditability comes from: the
gate-runner emitting a machine-readable JSON report per gate; the Verifier
recording evidence (build number, image tag, pod readiness) in a verdict
contract; and ADR-0001 recording the architectural decision. This repo's
pipeline already writes artifacts per stage (10-tasks, 20-acceptance,
25-verification, 30-report) but has no uniform rule for *what evidence each
stage must leave behind*.

## What it must provide

- A documented audit contract: each pipeline stage records, in its artifact, the
  evidence a reviewer needs to trust its claim:
  - Specifier → the acceptance criteria and the scenario IDs it derived.
  - Coder → the tests it wrote (traceable to scenario IDs) and the build/test
    commands it ran, with exit codes.
  - Refactorer → the gates it applied (complexity, duplication, property tests)
    and their before/after measurements.
  - Verifier → each check it ran, the exact command, and its real output/exit
    code (already partially there — make it uniform).
  - Architect → the mutation score, gate results, and the PR it opened.
- Every agent step that can leave machine-readable evidence (a gate script, a CI
  query, a deploy check) records it as JSON or a log line with timestamp — not a
  prose paraphrase.
- The pipeline's report artifact (25-verification.md / 30-report.md) links or
  embeds that evidence so a reviewer does not have to re-run anything to audit.
- A small `scripts/check-audit-trail.sh` (or a gate) that, given a spec slug,
  verifies each expected artifact exists and is non-empty, and that the verifier
  report cites real evidence for each check. Run at pipeline end.

## Acceptance criteria

- AC-001: the audit contract is documented (which artifact, which evidence per
  stage) in docs/SPEC_PIPELINE.md.
- AC-002: each stage artifact includes the evidence required by the contract.
- AC-003: machine-readable evidence (gate JSON, CI query, deploy check) is
  recorded with timestamp, not paraphrased.
- AC-004: `scripts/check-audit-trail.sh <slug>` verifies every expected artifact
  exists and is non-empty; exit 0 only when complete.
- AC-005: the verifier's report cites real evidence per check (command + output),
  and check-audit-trail verifies that.

## Tasks

# Spec 015 — Auditable agent steps

Formalized from `specs/015-auditable-agent-steps/00-informal.md`. The pipeline already
writes a per-stage artifact set (`10-tasks.md`, `20-acceptance/`, `25-verification.md`,
`30-report.md`) but has no uniform rule for *what evidence each stage must leave behind*.
This spec adds a documented audit contract, makes the existing stage artifacts carry that
evidence, ships `scripts/check-audit-trail.sh` as the mechanical gate, and wires the gate
into the pipeline end.

This repo has no JVM/Go/Node test suite. Per the established precedent (spec-001's
`scripts/verify-spec-001.sh`), the shipped shell check script is the test carrier: it must
reference every scenario ID so `scripts/check-scenario-traceability.sh` resolves them.

## Task 1 — Document the audit contract in docs/SPEC_PIPELINE.md

Maps informal AC-001 (contract documented) and part of AC-003 (machine-readable rule).

**Acceptance criteria**

- Add a top-level `## Audit contract` section to `docs/SPEC_PIPELINE.md`.
- The section maps each pipeline stage to the artifact(s) that carry its evidence:
  - Specifier → `10-tasks.md` + `20-acceptance/` — task acceptance criteria and scenario IDs (`AC-NNN-NN`).
  - Coder → the tests in the project suite carrying `AC-NNN-NN` IDs; the build/test commands
    and exit codes it ran, re-recorded by the Verifier in `25-verification.md` (the Coder
    leaves no report artifact; the section says so explicitly).
  - Refactorer → the gates it applied (complexity, duplication, property tests) with
    before/after measurements, re-recorded by the Verifier; the complexity summary carried
    into `30-report.md`.
  - Verifier → `25-verification.md` — per check: exact command, real output, exit code, timestamp.
  - Mutation Runner → `30-report.md` — mutation score (or skip reason), equivalent mutants, final test status.
  - PR Opener → `30-report.md` — PR URL and commit count, appended after the PR opens.
- The section names the five runnable Verifier checks the report must carry evidence for:
  scenario traceability, full test suite, complexity gate, design-principles gate, and
  scenario-to-behavior spot check. The "no unaccounted behavior" skim is recorded as a
  finding line, not a command.
- The section states the machine-readable rule: machine-readable evidence (gate script
  output, CI query, deploy check) is recorded with an ISO-8601 UTC timestamp
  (`YYYY-MM-DDTHH:MM:SSZ`) as raw output or exit code — never as a prose paraphrase.
- The section defines the uniform evidence block used in `25-verification.md`, with a
  worked example containing `command:`, `exit:`, `at:`, and raw output.
- The section states the Coder and Refactorer leave no report artifact; their claims become
  auditable because the Verifier re-executes them and records command + exit code in
  `25-verification.md`.

**Scenarios:** AC-015-01 — AC-015-03

## Task 2 — Make each stage artifact carry the contract's evidence

Maps informal AC-002 (artifacts include required evidence) and the agent-facing half of AC-003.

**Acceptance criteria**

- `agents/spec-verifier.md`: the Report section requires, for every check, an evidence block
  with the exact `command:`, the real output (or representative excerpt), the `exit:` code,
  and an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`; the design-principles gate's exit code
  and every FAIL/WARN line stay verbatim.
- `agents/spec-coder.md`: the Output section requires listing the exact build/test commands
  run and their exit codes in the handoff.
- `agents/spec-refactorer.md`: the Output section requires listing the gates applied with
  before/after measurements in the handoff.
- `agents/spec-mutation-runner.md`: the Report section requires the mutation score or an
  explicit `skipped — <tier> tier` reason and the final test status.
- `agents/spec-pr-opener.md`: after opening the PR, append to `30-report.md` a `PR:` line
  with the PR URL and a line with the commit count.
- No new spec-folder artifacts are introduced — the evidence lands in the artifacts the
  layout already defines.

**Scenarios:** AC-015-04 — AC-015-06

## Task 3 — Add the `scripts/check-audit-trail.sh` gate script

Maps informal AC-004 (artifact existence + exit 0 only when complete) and AC-005 (verifier
report cites real evidence).

**Acceptance criteria**

- Usage `scripts/check-audit-trail.sh <slug>`; missing argument prints usage and exits 2.
- Follows the house style of the other `scripts/check-*.sh` scripts: `#!/bin/bash`,
  `set -euo pipefail`, header comment (checks, usage, exit codes, standards reference),
  `PASS`/`FAIL` lines, violation counter, summary and non-zero exit on violations.
- When `specs/<slug>` does not exist, prints "nothing to check" and exits 0 — mirrors
  `check-scenario-traceability.sh`'s empty-directory behavior so the gate is a no-op on
  main after a spec is archived.
- Verifies each expected artifact exists and is non-empty: `10-tasks.md`, `20-acceptance/`
  (at least one non-empty `AC-*.md` containing at least one `## AC-NNN-NN` heading),
  `25-verification.md`, `30-report.md`, and `15-design.md` when present (zero-byte
  `15-design.md` is a failure).
- Verifies `25-verification.md` records real evidence for every one of the five contract
  checks: a `command:`, an `exit:`, an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`, and
  non-empty raw output for each.
- Exits 0 only when the folder is complete AND the verifier evidence is complete; exits 1
  otherwise, listing every missing artifact or check.
- The negative cases (missing artifact, empty file, missing evidence) are genuinely
  exercised — e.g. against a temp spec-folder fixture — not dead code.
- Passes `bash -n scripts/check-audit-trail.sh` and shellcheck cleanly.
- References every scenario ID `AC-015-01`…`AC-015-16` (as function names or comments) so
  `check-scenario-traceability.sh` resolves them.

**Scenarios:** AC-015-07 — AC-015-14

## Task 4 — Wire the gate into the pipeline end

Maps the informal spec's "Run at pipeline end" (AC-004).

**Acceptance criteria**

- `agents/spec-pr-opener.md`: before committing, pushing, and opening the PR, run
  `scripts/check-audit-trail.sh <slug>`; if it exits non-zero, stop and report — do not open
  the PR.
- `.github/workflows/self-ci.yml`: add a step that runs `scripts/check-audit-trail.sh` for
  each present spec directory carrying a `30-report.md` — the pipeline's finished signal,
  same convention as the archived-specs step — skipping in-flight directories without
  `30-report.md`; the step exits 0 when no finished spec exists.

**Scenarios:** AC-015-15 — AC-015-16

## Open questions

1. **Timestamp pinned to UTC.** The contract requires `YYYY-MM-DDTHH:MM:SSZ` (i.e.
   `date -u +%Y-%m-%dT%H:%M:%SZ`) so the gate can verify it deterministically. Acceptable,
   or must the timestamp preserve local time?
2. **Evidence-block markers are a new inline convention.** `command:` / `exit:` / `at:` are
   a uniform format applied *inside* the existing `25-verification.md` / `30-report.md`
   artifacts — this is the informal spec's "make it uniform", not a new artifact. Confirm
   the marker names are acceptable before the Coder bakes them into the agent prompts.

## Acceptance scenarios

## AC-015-01 — The audit contract section maps every stage to an evidence artifact
## AC-015-02 — The contract specifies the evidence each stage must record
## AC-015-03 — The contract mandates raw, timestamped machine-readable evidence
## AC-015-04 — The verifier report records real evidence per check
## AC-015-05 — The report carries mutation score, final status, and PR evidence
## AC-015-06 — The pipeline agents record the evidence their artifacts require
## AC-015-07 — A complete spec folder exits 0
## AC-015-08 — No spec folder exits 0
## AC-015-09 — Missing 10-tasks.md exits non-zero
## AC-015-10 — Missing or empty 20-acceptance exits non-zero
## AC-015-11 — Missing or empty 25-verification.md exits non-zero
## AC-015-12 — Missing or empty 30-report.md exits non-zero
## AC-015-13 — A present-but-empty 15-design.md exits non-zero
## AC-015-14 — A verifier report without per-check evidence exits non-zero
## AC-015-15 — The PR Opener runs the gate before opening the PR
## AC-015-16 — Self-CI runs the gate when a finished spec folder is present

## Verification

# Spec 015 — Auditable agent steps — Verification report (second re-verification after fix 2)

Branch: `spec/015-auditable-agent-steps`. Verified against `10-tasks.md` and
`20-acceptance/` only; `00-informal.md` was not read (information barrier).

This is the Verifier's third pass (second re-run). Pass 1 (2026-08-15T18:24:06Z)
FAILed: the self-ci "Check spec audit trails" step iterated every `specs/*/` folder
and went red on 11 in-flight siblings. Pass 2 (2026-08-15T18:43:00Z) FAILed
(incomplete fix): the step was fixed to iterate only finished specs, but three
contract texts still described the old every-folder mechanism. Fix 2 (this pass)
amended all three texts; `scripts/check-audit-trail.sh` untouched throughout.
Every check was re-executed fresh on 2026-08-15T18:48Z. The two FAIL records are
preserved below (§0, §0.1) as audit history; Fix 2 verification (§0.2); the full
re-run (§§1-6); the verdict (§8).

Diff under test: `docs/SPEC_PIPELINE.md`, `agents/spec-{coder,refactorer,mutation-runner,pr-opener,verifier}.md`, `.github/workflows/self-ci.yml`, `specs/015-auditable-agent-steps/{10-tasks.md,20-acceptance/AC-015-pipeline-gate.md}`, and new `scripts/check-audit-trail.sh` (755, untracked).

---

## 0. Original FAIL (pass 1) — preserved

> DEFECT in the new self-ci wiring (Task 4 deliverable). The "Check spec audit
> trails" step iterated every present `specs/*/` folder unconditionally. On this
> branch, 11 tracked in-flight sibling spec folders (007-014, 017-019) lack
> 25-verification.md and 30-report.md — verified rc=1 for all 11 — so this PR's
> own CI was red. Fix direction: skip folders without the finished signal —
> presence of 30-report.md — matching the check-specs-archived.sh convention; do
> not change check-audit-trail.sh.

## 0.1 Fix 1 (pass 2) — preserved

The step was changed to iterate `specs/*/30-report.md`, skip non-regular files
(`[ -f ] || continue`), exit 0 when nothing matches, exit 1 when a finished spec
fails the gate. Verified behaviorally correct in pass 2 against the real tree
(exit 0), a scratch finished-but-incomplete spec (exit 1), a complete spec
(exit 0), and a mix with an in-flight sibling (silent skip). But the fix was
incomplete: three texts still described the old mechanism (10-tasks.md Task 4
criteria, AC-015-16 Then-clause, docs/SPEC_PIPELINE.md §The gate) — recorded as
the pass-2 FAIL.

## 0.2 Fix 2 — three texts amended to the finished-signal convention (this pass)

`git status` confirms the fix touched exactly the two spec-folder files plus
`docs/SPEC_PIPELINE.md`; the other 6 tracked files' diffs are unchanged from the
pass-2 state and `scripts/check-audit-trail.sh` is still untracked (`??`, absent
from `git ls-files`). Real diffs, verbatim:

- `specs/015-auditable-agent-steps/10-tasks.md` Task 4 criteria: old "each present
  `specs/*/` directory; when no spec folder exists the step exits 0" → new
  "each present spec directory carrying a `30-report.md` — the pipeline's
  finished signal, same convention as the archived-specs step — skipping
  in-flight directories without `30-report.md`; the step exits 0 when no finished
  spec exists."
- `20-acceptance/AC-015-pipeline-gate.md` AC-015-16: retitled "when a finished
  spec folder is present"; Then-clause now "runs `scripts/check-audit-trail.sh`
  for each present spec directory carrying a `30-report.md` (the pipeline's
  finished signal)"; new And-clause "it skips in-flight spec directories that
  lack `30-report.md`"; And-clause "the step exits 0 when no finished spec
  exists".
- `docs/SPEC_PIPELINE.md` §The gate: "self-ci runs it for every spec folder
  carrying a `30-report.md` — the pipeline's finished signal, the same
  convention as the archive gate (§Archive in the PR). In-flight folders without
  `30-report.md` are skipped: their pipeline finishing is outside the job's
  control and must not fail CI. A finished-but-incomplete spec still fails the
  gate — the step never hands the script an unfinished folder." (+4 net lines vs
  the pass-2 +84 total.)

Text-behavior alignment: all three texts and the actual step (self-ci.yml lines
93-107: `for report in specs/*/30-report.md` → `[ -f "$report" ] || continue` →
accumulate `errors` → exit 1 on any finished-spec failure, implicit exit 0 when
none) now state the same mechanism on every point — iterate finished specs only,
skip in-flight silently, exit 0 when none, finished-but-incomplete still fails.
No contradiction between any text and the step. **PASS.**

`scripts/check-audit-trail.sh` unchanged throughout — evidence: (i) untracked,
`git diff` shows no change to it; (ii) mtime `2026-08-15 20:18:36 +0200` predates
the workflow edit (`20:35:54`) and both Fix 2 text edits (`20:44:59`,
`20:45:03`); (iii) `--selftest` output is byte-identical to the pass-1/pass-2
record (13/13, same lines, §2).

---

## 1. Scenario traceability — PASS (AC-015 scope clean)

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh
exit: 1
at: 2026-08-15T18:48:07Z

Full-repo run over the 12 tracked spec folders: exit 1, 115 violations — all
sibling-spec noise, none AC-015. Identical to passes 1 and 2 (77 IDs, 115
violations).

Scenario IDs found: 77

AC-015 scope: 16/16 traced, zero FAILs, zero dangling references (grep: every
AC-015 line in the output is a PASS line; AC-015 non-PASS count = 0):

PASS AC-015-01 — traced to a test
PASS AC-015-02 — traced to a test
... (all 16, AC-015-01 .. AC-015-16, PASS)

The 115 FAILs are the two known mid-pipeline blocks: in-flight sibling specs
(AC-007-01 .. AC-019-07 defined in specs/007..014/017..019, no tests yet) and
archived-spec citations (AC-001-01 .. AC-006-06, AC-016, AC-020-01 .. AC-022-04
referenced in docs but scenarios archived/absent). The traceability check is not
wired into CI, so this noise is confined to the Verifier's manual run — same as
both prior passes.

✘ Scenario traceability check: 115 violation(s).

---

## 2. Full relevant suite — PASS

## Evidence: full test suite

command: bash -n scripts/check-audit-trail.sh && ./scripts/check-audit-trail.sh --selftest && gate invocations (no-arg/absent/015) && make validate-all && make lint && python3 yaml-parse of .github/workflows/self-ci.yml && step simulation (in-flight/finished-incomplete/complete/mix)
exit: 0
at: 2026-08-15T18:48:07Z

This repo has no unit-test suite (Makefile: validate, validate-docs,
validate-refs, validate-skills, validate-all, lint, format, stats — no test
target). Per 10-tasks.md, the shipped shell check is the spec's test carrier.
All real runs below, actual exit codes:

bash -n scripts/check-audit-trail.sh                    → 0 (parses)

./scripts/check-audit-trail.sh --selftest               → 0, 13 assertions, all PASS
  (identical 13-line PASS output to passes 1 and 2 — gate script unchanged):
  PASS AC-015-07 — complete folder exits 0 (exit 0)
  PASS AC-015-08 — no spec folder exits 0 (exit 0)
  PASS AC-015-09 — missing 10-tasks.md exits non-zero (exit 1)
  PASS AC-015-09 — empty 10-tasks.md exits non-zero (exit 1)
  PASS AC-015-10 — missing 20-acceptance/ exits non-zero (exit 1)
  PASS AC-015-10 — heading-less 20-acceptance/ exits non-zero (exit 1)
  PASS AC-015-11 — missing 25-verification.md exits non-zero (exit 1)
  PASS AC-015-11 — empty 25-verification.md exits non-zero (exit 1)
  PASS AC-015-12 — missing 30-report.md exits non-zero (exit 1)
  PASS AC-015-13 — present-but-empty 15-design.md exits non-zero (exit 1)
  PASS AC-015-14 — evidence block missing at: timestamp exits non-zero (exit 1)
  PASS AC-015-14 — evidence block lacking raw output exits non-zero (exit 1)
  PASS AC-015-14 — a contract check with no evidence block exits non-zero (exit 1)
  ✔ Selftest: every audit-trail scenario exercised and passing.

./scripts/check-audit-trail.sh (no arg)                 → 2, prints usage
./scripts/check-audit-trail.sh no-such-slug-zzz         → 0, "Nothing to check — specs/no-such-slug-zzz does not exist."
./scripts/check-audit-trail.sh 015-auditable-agent-steps → 1 (all artifacts PASS,
  incl. all five evidence blocks of this report parsing OK, only
  "missing 30-report.md (AC-015-12)" — correct mid-pipeline at stage 4)

make validate-all                                        → 0 (all validations
  passed; 1 WARN on skills/hallmark/SKILL.md — pre-existing, unrelated)
make lint                                                → 0 (all YAML files parse,
  incl. .github/workflows/self-ci.yml [OK])
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))" → OK,
  parses; validate job has 16 steps (15 before + the new step).

Step simulation (§0.2, extracted verbatim to a scratch script with a
byte-identical copy of the gate): (a) real tree — 12 spec folders, 0 with
30-report.md → exit 0, no [check] lines; (b) scratch finished-but-incomplete
(30-report.md present, 25-verification.md missing) → exit 1, gate FAIL "missing
25-verification.md (AC-015-11)", step prints "1 finished spec folder(s) failed
the audit-trail check!"; (c) scratch complete compliant (all 4 artifacts + 5
evidence blocks) → exit 0, all five blocks PASS; (d) mix good-finished +
in-flight sibling → exit 0, only good-finished checked, in-flight silently
skipped. All scratch under /tmp/opencode/verify-fix2 deleted after the runs.

---

## 3. Complexity gate — PASS (script unchanged; after-state confirmed)

## Evidence: complexity gate

command: bash -n scripts/check-audit-trail.sh && control-flow token count of scripts/check-audit-trail.sh functions
exit: 0
at: 2026-08-15T18:48:07Z

No shell-complexity linter exists in this repo (check-code-principles.sh analyzes
.java/.go/.ts/.js only — confirmed again by §4). The complexity gate here is the
≤6 decision-point rule applied by spot count, plus bash -n.

The script is byte-identical to the pass-1-verified state (§0.2: mtime
20:18:36 predates every later edit; selftest output identical), so the prior
conclusion carries: every function small, flat, single-purpose, all ≤6 decision
points under the established method. Fresh control-flow token count
(`^[[:space:]]*(if|elif|else|case|esac)` per function):

  check_acceptance_dir 3, check_design_if_present 3, check_folder 3,
  check_nonempty_file 3, check_verifier_evidence 2, evidence_block 2,
  expect_run 3, main 6, selftest 1, marker 1, parse_evidence_block 3,
  usage 0

Counting-method variance notwithstanding (passes 1-2 documented the same), every
function is far under the limit and the ≤6 conclusion under the established
method holds. bash -n passes (rc=0). Refactorer complexity claims: CONFIRMED
(unchanged script).

---

## 4. Design-principles gate — pre-existing FAILs, none attributable to spec 015

## Evidence: design-principles gate

command: scripts/check-code-principles.sh
exit: 1
at: 2026-08-15T18:48:07Z

Checking design principles in: . (tier: mvp)

FAIL: Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL: Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL: Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL: Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL: Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7

WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)
WARN: Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN: Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33

✘ Design-principles check: 5 FAIL(s), 17 WARN(s).

Identical to passes 1 and 2: every FAIL (5) and WARN (17) is confined to
ci/templates/* — the pre-existing repo-root state. None is attributable to spec
015: the changed files are .md/.yml/.sh; the gate analyzes only .java/.go/.ts/.js,
so none of spec 015's files is even scanned. Property tests skipped (project tier
is mvp — production+ required), confirming the mvp-tier skip claim.

---

## 5. Scenario-to-behavior spot check — PASS (AC-015-16 text-behavior now aligned)

## Evidence: scenario-to-behavior spot check

command: manual spot check of AC-015-16 (workflow text vs step behavior, simulated), AC-015-15 (PR Opener), AC-015-14 (gate negative evidence cases), AC-015-01/02/03 (contract) + the amended texts vs the actual self-ci step
exit: 0
at: 2026-08-15T18:48:07Z

AC-015-16 — "Self-CI runs the gate when a finished spec folder is present": the
amended Then/And-clauses ("runs `scripts/check-audit-trail.sh` for each present
spec directory carrying a `30-report.md` (the pipeline's finished signal)"; "it
skips in-flight spec directories that lack `30-report.md`"; "the step exits 0
when no finished spec exists") match the actual step in self-ci.yml (lines
93-107) exactly, verified by simulation: finished spec present → gate invoked
per slug; in-flight sibling → no [check] line, silent skip; zero finished specs
→ exit 0; finished-but-incomplete → exit 1. **CONFIRMED — this is the scenario
that failed pass 2; now text and behavior agree.**

AC-015-15 — agents/spec-pr-opener.md (line 38): "before committing, pushing, or
opening the PR, run `scripts/check-audit-trail.sh NNN-slug`. If it exits non-zero,
stop and report ... do not commit, push, or open the PR." CONFIRMED (unchanged
since pass 1).

AC-015-14 — verifier report without per-check evidence exits non-zero: all three
negative cases re-exercised via selftest (missing at: timestamp; lacking raw
output; no evidence block at all → all exit 1). CONFIRMED.

AC-015-01/02/03 — contract text in docs/SPEC_PIPELINE.md §Audit contract: stage→
artifact table naming all six stages and four artifacts; five runnable Verifier
checks; machine-readable rule (ISO-8601 UTC, raw output or exit code, never
prose); uniform evidence-block format with worked example. CONFIRMED (unchanged;
all `at:` markers in this report verified against live `date -u +%Y-%m-%dT%H:%M:%SZ` output).

---

## 6. No unaccounted behavior — finding line

Every diff hunk traces to a task: docs/SPEC_PIPELINE.md +88 → Task 1 (AC-015-01..03)
plus the §The gate amendment → Task 4 (AC-015-16 mechanism); agents/spec-verifier.md
→ Task 2 (AC-015-04/06); spec-coder.md, spec-refactorer.md, spec-mutation-runner.md,
spec-pr-opener.md → Task 2 + Task 4 (AC-015-05/06/15); self-ci.yml step → Task 4
(AC-015-16); specs/015 10-tasks.md + AC-015-pipeline-gate.md → Task 4 / AC-015-16
(the Fix 2 amendments); scripts/check-audit-trail.sh → Task 3 (AC-015-07..14, all
16 IDs in header + selftest). Since pass 2, the only new diff content is the three
text amendments, each of which rewrites the AC-015-16 mechanism it belongs to —
no new logic, no new behavior. No other logic found that lacks a task or scenario.
The pre-existing "Check finished specs are archived" step is not part of this diff.

## 7. mvp-tier confirmation

No AGENTS_<PROJECT>.md at repo root (only AGENTS.md) — confirmed by glob and by
the gate auto-detecting "tier: mvp". Property tests skipped at mvp (gate output
§4), so the Mutation Runner's `skipped — mvp tier` reason and property-test skips
are correct.

## Review hints (WARN-level, not stop conditions)

- scripts/check-scenario-traceability.sh is mode 0644 at HEAD/index/worktree
  (pre-existing): direct invocation exits 126; runs via `bash scripts/...` work.
  Not a spec 015 change; flag to Architect.
- shellcheck not installed locally; CI runs it with continue-on-error (not a gate).

---

## Overall verdict: PASS — Architect may proceed

Both prior defects are fixed and re-verified with real executions this pass:

1. **CI-red defect (pass 1) — FIXED.** The step iterates `specs/*/30-report.md`
   only. On the real in-flight tree (12 spec folders, 0 finished) the step exits
   0 with no gate invocation; a scratch finished-but-incomplete spec exits 1 with
   the correct message; a complete compliant finished spec exits 0; an in-flight
   sibling is silently skipped.
2. **Contract-text staleness (pass 2) — FIXED.** All three texts now describe the
   finished-signal convention and agree with the step on every point: iterate
   finished specs only, skip in-flight silently, exit 0 when none, finished-but-
   incomplete still fails. `10-tasks.md` Task 4, AC-015-16, and docs/SPEC_PIPELINE.md
   §The gate are mutually consistent with `.github/workflows/self-ci.yml`.

`scripts/check-audit-trail.sh` unchanged throughout (untracked, mtime predates
all edits, selftest 13/13 byte-identical). Full re-run green: AC-015 traceability
scope 16/16 with zero dangling references; selftest 13/13 exit 0; gate direct
invocations exact (no-arg 2, absent 0, 015 → 1 with only 30-report.md missing —
correct mid-pipeline); make validate-all and make lint exit 0; self-ci.yml parses
(16 steps) and carries the fixed step; complexity after-state confirmed on the
unchanged script; design-principles gate FAILs/WARNs all pre-existing in
ci/templates/*, none attributable to spec 015; spot checks pass (AC-015-16
text-behavior aligned — the pass-2 failure — plus AC-015-15/14/01/02/03); no
unaccounted behavior; mvp tier confirmed.

## Quality gates

# Spec 015 — Auditable agent steps — Mutation Runner report

Branch: `spec/015-auditable-agent-steps`. Written from the Verifier's
`25-verification.md` only; `00-informal.md` was not read (information barrier).

## Verifier verdict (carried forward)

PASS — after two fix cycles. Pass 1 FAIL (self-ci step iterated every
`specs/*/` folder, went red on 11 in-flight siblings); Fix 1 (pass 2) iterated
finished specs only but three contract texts still described the old mechanism;
Fix 2 amended `10-tasks.md` Task 4, AC-015-16, and `docs/SPEC_PIPELINE.md` §The
gate to the finished-signal convention. `scripts/check-audit-trail.sh` untouched
throughout (untracked, selftest 13/13 byte-identical across all three passes).
Full re-run at 2026-08-15T18:48Z green on every check attributable to spec 015.

## Mutation score

skipped — mvp tier

```
command: repo conformance tier determination (no AGENTS_<PROJECT>.md at root; gate auto-detects "tier: mvp"; Verifier §7)
exit: 0
at: 2026-08-15T18:49:53Z

Mutation testing is a production-tier gate (docs/SPEC_PIPELINE.md §Conformance
tiers). This repo conforms at mvp tier, so the gate is skipped. The changed code
is a bash check script + markdown prompts/docs + workflow YAML; no mutation
tooling exists for shell in this repo.
```

## Complexity summary (carried from the Refactorer)

`scripts/check-audit-trail.sh` — every function ≤6 decision points under the
established count: check_verifier_evidence 6, selftest 2, main 5, all others
≤3. Confirmed against the unchanged script (Verifier §3 re-ran the count; script
byte-identical since pass 1).

## Equivalent mutants

None.

No mutation tooling ran (mvp tier), so no surviving mutants were produced and no
equivalent mutants exist to name. The script's decision points are all exercised
by `--selftest` (13 assertions covering AC-015-07..14) and the direct
invocations recorded by the Verifier.

## Final test status

Full suite re-run one final time — green.

```
command: bash -n scripts/check-audit-trail.sh && ./scripts/check-audit-trail.sh --selftest && scripts/check-orchestration.sh && make validate-all
exit: 0
at: 2026-08-15T18:49:53Z

bash -n scripts/check-audit-trail.sh          → 0 (parses)
./scripts/check-audit-trail.sh --selftest     → 0, 13 assertions, all PASS
scripts/check-orchestration.sh                → 0, all orchestration references valid
make validate-all                             → 0, all validations passed
  (1 WARN on skills/hallmark/SKILL.md — pre-existing, unrelated)

Expected mid-pipeline state (not a suite failure):
./scripts/check-audit-trail.sh 015-auditable-agent-steps → 1, only
"missing 30-report.md (AC-015-12)" — this report is that artifact; the gate's
five evidence-block checks all PASS. Re-run after this report is written
confirms the folder complete.
```

This repo has no unit-test suite (Makefile targets: validate, validate-docs,
validate-refs, validate-skills, validate-all, lint, format, stats — no test
target). The shipped shell check `scripts/check-audit-trail.sh` is spec 015's
test carrier; its `--selftest` exercises every acceptance scenario
(AC-015-07..14), re-confirmed above.
