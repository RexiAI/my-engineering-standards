# Verifier stage file (stage 4)

Index: `docs/SPEC_PIPELINE.md` — §Stages, §Artifact layout, §Stop-and-Ask matrix,
§Remediation budget.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before writing `25-verification.md`.

## Checks in order

Run every check yourself; a prior stage's summary is no substitute.

| # | Check | How it is run | Gate ID |
|---|---|---|---|
| 1 | Scenario traceability | `scripts/check-scenario-traceability.sh` (or `.standards/` twin); 0 = clean, 1 = findings, 2 = tooling failure | `traceability` |
| 2 | Full test suite | the project's real test command, via `scripts/agent-test-summary.sh --run` (§Test-log capture); a skipped test is a failure | `test-suite` |
| 3 | Complexity gate | the real linter (`golangci-lint run`, `pmd check`, `eslint`) on the changed files | `complexity` |
| 3.5 | Design-principles gate | `scripts/check-code-principles.sh`; every FAIL stops the pipeline, a WARN is recorded and flagged | `design-principles` |
| 4 | Spot check | 2+ random scenarios from `20-acceptance/`, assertions read against their Given/When/Then — a passing test asserting the wrong thing is a false green | `spot-check` |
| 5 | No unaccounted behavior | skim the diff for logic that traces to no task or scenario; flag it to be justified | `unaccounted` |

Gates 1 and 3.5: the `--json` transcript plus the exit code is the verdict.

## Test-log capture

Test output is captured, never pasted. Run the suite through
`scripts/agent-test-summary.sh --run "${TMPDIR:-/tmp}/pipeline/<slug>-<stage>-<check>.log" -- <real command>`
and read only its stdout (signal lines + `SUMMARY:`), never the log file. Append
the full log with this recipe:

```
{ printf '## Raw log: <check>\n\ncommand: %s\nexit: %s\nat: %s\n\n' "$CMD" "$XC" "$AT"; cat "$LOG"; } >> specs/NNN-slug/25-verification.md
```

The `## Evidence: <check>` body is the `SUMMARY:` line, the signal lines, and
`full log: §Raw log: <check>`. `command:` carries the real command verbatim
after `--`; `exit:` is the wrapped command's status, unchanged. For the suite the
pointer is `full log: §Raw log: full test suite`. Only the test-suite lane is
filtered: the design-principles gate and the complexity linters are invoked
directly, so every `FAIL` and `WARN` line must be recorded verbatim.

## Telemetry record

After every completed run — PASS, FAIL, or BLOCK — append one record to
`runs.jsonl` via `scripts/record-gate-run.sh` (no `permission.edit` widening).
Fields: `specSlug`, `gatesFailed`, `warnings`, `durationSec`, `outcome` — `block`
if any gate BLOCKed, else `fail` if the verdict is FAIL, else `pass`. `runId`,
`loopCount` and retry counts come from `SPEC_*` (spec 008). A failed append is a
warning, never a fabricated record.

## Report format

One block per check in the `audit-contract.md §Evidence block format` shape; a
missing marker fails `scripts/check-audit-trail.sh`.

For the suite, immediately after `at:` record `Test-run hash: <64-hex>` from
`scripts/test-run-reuse.sh --print-hash`, computed **after** the run; a differing
pre-run hash adds `tree-changed-during-run` naming both, and the post-run hash is
recorded. This stage always runs the suite and never reuses a prior run.

Verdict from exit codes, never from your reading of the diff:

- **PASS** — every gate ran, no findings (the Architect may proceed).
- **FAIL** — a gate produced findings (the pipeline stops; list every reason).
- **BLOCK** — a gate could not run, or exited non-zero for a non-finding reason
  (missing tool, unreadable tree); name the failure with stderr.

## Scoped re-verification

A re-trigger re-runs the failing gate(s) only; unchanged gates' results stand.
Narrow further where supported: `scripts/check-code-principles.sh --gates <name>`
(one category) and `scripts/check-scenario-traceability.sh --checks <1|2>` (one
traceability check). Checks 2, 3, 4 re-run whole. A re-run appends to its gate in
`25-verification.md`: full run + delta, never a rewrite.

## Lite mode

In `lite` the checks are unchanged — see `docs/spec-pipeline/lite-mode.md`. This
stage also authors `specs/NNN-slug/30-report.md` (no Mutation Runner): record
`Pipeline mode: lite` and, for each skipped stage, a `## <stage>` section plus the
mutation score line reading `skipped (lite)`.
