# Verification — spec 012: Gate self-tests + run telemetry

- Branch: `spec/012-gate-selftests-telemetry` (base `3013d8d`)
- Verifier: stage 4, independent re-run of all prior-stage claims
- Scope verified against: `10-tasks.md` + `20-acceptance/*.md` only (00-informal.md not read)
- Date: 2026-08-15

## Verdict: **PASS** — Architect may proceed.

Every gate below passed. One review hint (json_escape strictness) is recorded for the
Architect; it is explicitly not a failure — see Check 4 and Check 3.5 notes.

---

## Check 1 — Scenario traceability — PASS (spec-012 scope clean)

Command: `bash scripts/check-scenario-traceability.sh specs .`

Full-repo exit code: **1** (123 violations). All 123 are the documented mid-pipeline
condition: archived/sibling specs whose `specs/*/20-acceptance/` dirs are gone but whose
IDs are still cited (AC-006-03..06, AC-016-01..05, AC-020-01..07, AC-021-01..08,
AC-022-01..04, etc., from `docs/changes/*` and merged-main code). Zero AC-012 refs among
them. Representative output:

```
FAIL AC-006-03 — referenced in a test but no matching scenario heading exists ...
FAIL AC-016-01 — referenced in a test but no matching scenario heading exists ...
✘ Scenario traceability check: 123 violation(s).
```

Scoped AC-012 result (independent 44-sub-ID audit, not just the script's coarse
AC-012-0N match):

- All 8 main scenario IDs traced: `PASS AC-012-01` .. `PASS AC-012-08 — traced to a test`
- 44/44 sub-IDs (`AC-012-01-01` .. `AC-012-08-03`) have headings in `20-acceptance/`
  and are each referenced in source (`scripts/`, `agents/`, `.github/workflows/`,
  `docs/`); `comm` both directions: zero headings-not-referenced, zero refs-without-heading.
- No AC-012 ref dangles anywhere.

AC-012 scope judged clean. Full-repo exit 1 is pre-existing and attributable only to
sibling/archived specs, not to 012.

## Check 2 — Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n` × 8 changed/new scripts (gate-report-lib.sh, gate-stats.sh, record-gate-run.sh, both selftests, tests/gate-telemetry.selftest.sh, check-code-principles.sh, check-scenario-traceability.sh) | 0 each | all `SYNTAX-OK` |
| `bash scripts/check-scenario-traceability.selftest.sh` | **0** | pass/orphan/dangle all assert correctly |
| `bash scripts/tests/gate-telemetry.selftest.sh` | **0** | 38 assertions passed, 1 NOTE (AC-012-04-02, 007 dependency — not claimed as a pass) |
| `bash scripts/check-code-principles.selftest.sh` | **1 — EXPECTED** | documented 007 fail-fast: "This selftest requires spec 007's --gates flag for fixture isolation (specs/007-verifier-discipline). Land 012 in the same batch as 007..." — matches AC-012-01-09 and 10-tasks.md Open question 2. Recorded as expected/documented condition, NOT a failure. |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all checks pass; 1 pre-existing unrelated WARN (skills/hallmark/SKILL.md 562 lines) |
| `make lint` | 0 | every YAML [OK], incl. `gate-stats-weekly.yml` and `self-ci.yml` |
| PyYAML parse of `self-ci.yml` + `gate-stats-weekly.yml` | 0 each | both parse |

Selftest exit-code evidence (real outputs): traceability selftest printed 3 PASS and
`✔ ... 3 cases passed.`; telemetry selftest printed the full AC-012-03..08 matrix
(38 PASS, 0 FAIL) and `✔ gate-telemetry selftest: 38 assertions passed, 1 noted
(spec 007 dependency).`; principles selftest printed exactly the documented fail-fast
message (AC-012-01-09 verified by running the probe: checker rejects `--gates` with
`Unknown option: --gates` / exit 2 because 007 is on a sibling PR branch not merged).

## Check 3 — Complexity gate — PASS

The repo's automated complexity gate (`check-code-principles.sh`) scans Java/Go/TS only
— bash has no automated cyclomatic gate here, so the Refactorer's ≤6 claim was checked
by per-function decision-point count in every changed/new function:

- `gate-report-lib.sh`: strip_dashes (CC≈2), json_escape (1), json_array (3),
  emit_json_report (3) — all ≤6
- `gate-stats.sh` awk helpers: strval (2), numval (2), arr_items (4), metric_name (3),
  v (2), slice (3) — all ≤6
- `record-gate-run.sh`: err (1), inject_count (3)
- `emit_report` in both gate scripts (3 each)

Refactorer's structural claims confirmed by inspection: `gate-report-lib.sh` is sourced
by both gate scripts and holds the single copy of strip_dashes/json_escape/json_array/
emit_json_report (report-writer machinery 2→1, both scripts call the lib's functions,
neither defines its own); `metric_name`/`slice` helper functions exist in gate-stats.sh.

Note: gate-stats.sh's main body is one flat awk END block (a program, not a function);
its overall decision count is not gated by any tool in this repo. No FAIL.

## Check 3.5 — Design-principles gate — PASS (no finding attributable to 012)

Command: `bash scripts/check-code-principles.sh .` (repo root, default mode)

Exit code: **1** (5 FAILs, 17 WARNs). Every FAIL/WARN line, verbatim (confined to
`ci/templates/*`, untouched by this branch — `git status` shows no ci/templates
changes):

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): } /return violations /} /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): schema: [], /}, /create(context) { /},
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): return violations /} / /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): } /} /} /violations++
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): } /} /return violations /}
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): violations++ /} /} /pos, fn.Name.Name)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Attribution: every FAIL/WARN path is `./ci/templates/*` (go-saga-lint.go,
eslint-saga-rules/*.js, archunit/*.java) — all pre-existing files on `main`, none
touched by spec 012. Run against the spec-012 code itself:
`bash scripts/check-code-principles.sh scripts` → exit **0**, "No Java, Go, or JS/TS
source files found under scripts — nothing to check." **No FAIL or WARN attributable to
spec 012.**

MVP-tier claim confirmed: `AGENTS_*.md` count = 0, so tier auto-detects to `mvp`
(report JSON shows `"tier":"mvp"`); property-test and mutation gates are correctly
skipped per conformance tiers.

## Check 4 — Scenario-to-behavior spot checks — PASS (4 scenarios re-executed)

Picked independently, fixtures built from scratch in /tmp (cleaned afterward):

**AC-012-04-01 — `-ReportPath` on check-code-principles.sh.**
`bash scripts/check-code-principles.sh -ReportPath /tmp/rpt.json <scratch-cc-bad>` →
exit 1; `/tmp/rpt.json` = single JSON object
`{"tier":"mvp","gates":["complexity","dry","yagni","solid","property-tests"],
"fails":["Cyclomatic complexity >6 (java): ...:decide:CC=8"],"warns":[]}` —
tier/gates/fails/warns keys present, fails contains the CC violation, `json.loads`
parses, human stdout still shows the FAIL line (2 FAIL markers). Given/When/Then met.

**AC-012-04-03 — `-ReportPath` on check-scenario-traceability.sh.**
Scratch specs tree with orphaned `AC-999-99` → exit 1; report = `{"passes":[],"fails":["AC-999-99 — scenario defined in ... no test references it. ..."]}` —
passes/fails keys, orphan ID in fails, json.loads parses. Met.

**AC-012-05-01/05 — record-gate-run.sh append + validation.**
Valid record → exit 0, exactly one line, verbatim. Missing-`outcome` record → stderr
"missing required field 'outcome'", exit 1, **no file created**. runId auto-generated
(uuidgen) when omitted; loop fields default 0 without env. Met. (jiraKey-only accepted,
specSlug XOR jiraKey enforced — also covered by the telemetry selftest's 5 reject cases.)

**AC-012-07-01/04 — gate-stats.sh.**
Independent 3-record fixture (1 pass, 1 fail, 1 block): "Total runs: 3", breakdown with
percentages, "Failure rate (fail + block) / total: 67%", "Most-failed gate: complexity
(2 runs)", total warnings, avg/max/last-window for all 3 retry metrics, creep check with
both window averages. Positive creep independently confirmed on a 4-record fixture with
`-n 2`: `phase1Retries CREEP (recent 2.0, prior 1.0)`; non-creeping metrics not marked.
Missing file → stderr + exit 1. Met.

**AC-012-06-01/02 — Verifier append wiring.** Verified by direct read of
`agents/spec-verifier.md` (Telemetry section present: field mapping incl. gatesFailed/
warnings/durationSec/outcome/specSlug, runId generated by the script, "The step runs
even when the verdict is FAIL or BLOCK"); `permission.edit` still allows only
`specs/*/25-verification.md` (frontmatter read directly — append goes via the bash
helper, no permission change). `agents/spec-pipeline.md` exports SPEC_LOOP_COUNT /
SPEC_PHASE1_RETRIES / SPEC_PHASE2_RETRIES before delegating to the Verifier. Met.
(And this run itself appended the record — see Telemetry note below.)

**json_escape strictness (Refactorer's observation) — review hint, not a failure.**
Confirmed empirically: duplication WARN messages embed the matched block verbatim,
including literal `\n` (check-code-principles.sh line 279 joins with
`${win//$'\x1f'/ /}` where `win` retains line-ending newlines). A `-ReportPath` report
from the repo-root run failed `json.loads` ("Invalid control character ... at char
1164", the `\n` inside the go-saga-lint duplication WARN). Single-line findings
(complexity, KISS, empty-body, DIP, traceability passes/fails) parse fine (3/3 tested
reports parsed). **No AC-012 acceptance scenario requires strictly-valid JSON**: every
AC-012-04 assertion is grep-based ("contains a single JSON object with ... keys",
"the fails array contains ..."), and the telemetry selftest asserts via grep, not a JSON
parser. The record writer (record-gate-run.sh) validates its own input jq-free by design
(007's documented constraint) and is unaffected. Recorded for the Architect: if a future
consumer parses -ReportPath output with a strict JSON parser, extend json_escape to
escape control characters (`\n`, `\t`) — one-line change in gate-report-lib.sh.
Also noted (minor, no scenario implicated): traceability `-ReportPath` with a missing
SPECS_DIR early-exits 0 without writing a report; check-code-principles.sh has no
`set -e` so a failed report write would not change its exit code.

## Check 5 — No unaccounted behavior — PASS

Skimmed the full branch diff (5 modified files + 8 new files, all read in full):
- `-ReportPath` parsing, REPORT_PATH/FAILS_LIST/WARNS_LIST/PASSED_IDS/VIOLATIONS_LIST
  capture, `emit_report` in both gate scripts → Task 4 / AC-012-04-01..06.
- `strip_dashes` shared parser (accepts both `-` and `--` forms) → Task 4 acceptance
  criteria ("combines freely with the existing flags") + 10-tasks.md Open question 1's
  recommended reconciliation; 007's `--gates`/`--json` still rejected exit 2 until 007
  merges (documented fail-fast, exercised by both selftests).
- `gate-report-lib.sh` → shared machinery for Task 4 (DRY; Refactorer extraction).
- `record-gate-run.sh`, `runs.jsonl`, `gate-stats.sh` → Tasks 5/7; `gate-stats-weekly.yml`
  → Task 8; both selftests → Tasks 1/2; self-ci "Run gate selftests" step → Task 3;
  `spec-verifier.md` Telemetry + `spec-pipeline.md` SPEC_* exports → Task 6.
- The CI step also runs `scripts/tests/gate-telemetry.selftest.sh` (Task 3 names two
  selftests): this third script is the test carrier for the AC-012-04..08 scenarios
  (it cites those IDs, verified in Check 1) — accounted, not rogue.
- Parser widening in check-scenario-traceability.sh (`-*` now exits 2 instead of being
  treated as SPECS_DIR) matches the documented flag-style reconciliation; no scenario
  covers `-*` as a positional. Justified.

Nothing found that fails to trace to a task/scenario.

## Telemetry

Per agent instructions, one record was appended to the repo `runs.jsonl` via
`bash scripts/record-gate-run.sh` (exit 0) after all checks completed:
`{"specSlug":"012-gate-selftests-telemetry","gatesFailed":[],"warnings":["json_escape
review hint: ..."],"durationSec":1500,"outcome":"pass"}` — runId, loopCount,
phase1Retries, phase2Retries generated/defaulted by the script (0). durationSec is an
approximate wall-clock figure for the verification phase. The append itself succeeded;
no fabrication.

## Overall verdict

**PASS** — Architect may proceed. All six gates green for spec 012's scope; the two
non-zero exit codes observed (full-repo traceability 1, principles selftest 1) are the
documented pre-existing sibling/archived-spec and 007-ordering conditions respectively,
each verified to be outside 012's own scope. One review hint (json_escape multi-line
strictness) is flagged for the Architect — no acceptance scenario is violated by it.
