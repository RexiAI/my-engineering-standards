# Report — spec 012: Gate self-tests + run telemetry

- Branch: `spec/012-gate-selftests-telemetry` (base `3013d8d`)
- Stage: 5a Mutation Runner
- Date: 2026-08-15

## Verifier verdict (carried forward)

**PASS** — carried from `25-verification.md`. All six Verifier gates green for spec
012's scope; the two non-zero exits observed there (full-repo traceability 1,
principles selftest 1) are documented pre-existing sibling/archived-spec and
007-ordering conditions, each verified outside 012's own scope.

## Mutation score

**skipped — `mvp` tier.**

This repo auto-detects to `mvp` conformance tier (no `AGENTS_*.md`; gate report JSON
shows `"tier":"mvp"`). Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation
testing is a `production`-tier gate and does not run at `mvp`. The changed code is
bash scripts + markdown + workflow YAML — no mutation tooling for shell exists in
this repo. No mutation run attempted.

## Complexity summary (carried from the Refactorer, re-confirmed by the Verifier)

- `scripts/gate-report-lib.sh` extracted the report-writer machinery 2→1: the single
  copy of `strip_dashes`/`json_escape`/`json_array`/`emit_json_report` now shared by
  both gate scripts (neither defines its own).
- All changed/new functions ≤6 decision points:
  - `gate-report-lib.sh`: strip_dashes (CC≈2), json_escape (1), json_array (3),
    emit_json_report (3)
  - `gate-stats.sh` awk helpers: strval (2), numval (2), arr_items (4),
    metric_name (3), v (2), slice (3)
  - `record-gate-run.sh`: err (1), inject_count (3)
  - `emit_report` in both gate scripts (3 each)
- No applicable complexity linter for shell in this repo (`check-code-principles.sh`
  scans Java/Go/TS only). `gate-stats.sh`'s main body is one flat awk END block — a
  program, not a function; not gated by any tool here.

## Equivalent mutants

None. Mutation testing skipped at `mvp` tier; no surviving mutants to classify.

## Final test status — GREEN (re-run at stage 5a)

| Check | Exit | Result |
|---|---|---|
| `bash -n` × 8 changed/new scripts | 0 each | all `SYNTAX-OK` |
| `bash scripts/check-scenario-traceability.selftest.sh` | 0 | 3 cases passed |
| `bash scripts/tests/gate-telemetry.selftest.sh` | 0 | 38 assertions passed, 1 NOTE (AC-012-04-02, 007 dependency — not claimed as a pass) |
| `bash scripts/check-code-principles.selftest.sh` | 1 — **EXPECTED** | documented 007 fail-fast: "This selftest requires spec 007's --gates flag..." (AC-012-01-09); by design, matches Verifier Check 2 |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all checks pass; 1 pre-existing unrelated WARN (skills/hallmark/SKILL.md 562 lines) |
| `specs/012-gate-selftests-telemetry/25-verification.md` exists | — | yes, verdict PASS |

No new test code was written at this stage (no mutation-killing work at `mvp`), so
the full-suite re-run covers exactly what the Verifier confirmed, re-executed
independently here. Every result above matches the Verifier's Check 1-5 claims.

## Architect notes (Verifier review hints, carried forward)

1. **json_escape strict-JSON caveat** (Verifier Check 4, confirmed empirically):
   duplication WARN messages embed the matched block verbatim, including literal
   `\n` (check-code-principles.sh line 279 joins with `${win//$'\x1f'/ /}` where
   `win` retains line-ending newlines). A `-ReportPath` report from the repo-root
   run fails a strict `json.loads` ("Invalid control character"). No AC-012
   acceptance scenario requires strictly-valid JSON — every AC-012-04 assertion is
   grep-based, and the telemetry selftest asserts via grep, not a JSON parser. If a
   future consumer parses `-ReportPath` output with a strict JSON parser, extend
   `json_escape` to escape control characters (`\n`, `\t`) — one-line change in
   `gate-report-lib.sh`. Not a failure.
2. **Traceability `-ReportPath` early-exit path** (Verifier Check 4, minor, no
   scenario implicated): traceability `-ReportPath` with a missing `SPECS_DIR`
   early-exits 0 without writing a report; `check-code-principles.sh` has no
   `set -e`, so a failed report write would not change its exit code. Flagged for
   future hardening; no AC-012 scenario covers either case.
