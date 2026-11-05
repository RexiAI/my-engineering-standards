# Verifier stage file (stage 4)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Artifact layout, §Stop-and-Ask
decision matrix, and §Remediation budget.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before writing `25-verification.md`.

Deliverable: `specs/NNN-slug/25-verification.md`; the evidence rules are in the
audit contract named above.

## Checks in order

Every check is a real execution; a prior stage's summary is no substitute.

| # | Check | How it is run | Gate ID |
|---|---|---|---|
| 1 | Scenario traceability | `scripts/check-scenario-traceability.sh` (or the `.standards/` twin); 0 = clean, 1 = findings, 2 = tooling failure | `traceability` |
| 2 | Full test suite | the project's real test command, captured with `scripts/agent-test-summary.sh --run` (§Test-log capture); a skipped test is a failure | `test-suite` |
| 3 | Complexity gate | the real linter (`golangci-lint run`, `pmd check`, `eslint`) on the changed files | `complexity` |
| 3.5 | Design-principles gate | `scripts/check-code-principles.sh`; every FAIL stops the pipeline, a WARN is recorded and flagged | `design-principles` |
| 4 | Spot check | 2+ scenarios picked at random from `20-acceptance/`, assertions read against their Given/When/Then — a passing test asserting the wrong thing is a false green | `spot-check` |
| 5 | No unaccounted behavior | skim the diff for logic that traces to no task or scenario; flag it to be justified | `unaccounted` |

For gates 1 and 3.5 the `--json` transcript plus the exit code is the verdict.

## Test-log capture

Test-suite output is captured, never pasted. Run the suite through
`scripts/agent-test-summary.sh --run "${TMPDIR:-/tmp}/pipeline/<slug>-<stage>-<check>.log" -- <real command>`
and read only its stdout (signal lines + `SUMMARY:`), never the log file. Append
the full log to the evidence file with this recipe:

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
Fields: `specSlug`; `gatesFailed`; `warnings`; `durationSec`; `outcome`
(`block` > `fail` > `pass`). Omit `runId`, `loopCount`,
`phase1Retries`, `phase2Retries` — the script generates the first and defaults the
rest to 0 from the orchestrator's `SPEC_*` exports (spec 008).

A FAIL or BLOCK still records; if the append fails, report a warning and never
fabricate a record.

## Report format

One evidence block per check, in the format of
`docs/spec-pipeline/audit-contract.md §Evidence block format` — heading, the
exact `command:`, the real output (or an excerpt, never a paraphrase), `exit:`,
and an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`. `scripts/check-audit-trail.sh`
parses those markers, so a missing marker fails that gate.

For the full test suite, immediately after `at:` record
`Test-run hash: <64-hex>` from `scripts/test-run-reuse.sh --print-hash`,
computed **after** the run. A differing pre-run hash adds the finding line
`tree-changed-during-run` naming both; the post-run hash is recorded. This stage
runs the suite itself every time and never reuses a prior run (`--print-hash`
only).

Each check reports PASS/FAIL/BLOCK with its command and real output; the spot
check names the scenarios it read. The verdict is transcribed from the exit
codes, never from your reading of the diff:

- **PASS** — every gate ran, no findings (the Architect may proceed).
- **FAIL** — a gate produced findings (the pipeline stops; list every reason).
- **BLOCK** — a gate could not run, or exited non-zero for a reason other than a
  finding (missing script or tool, unreadable tree); name the tooling failure with
  the script's stderr, so the fix targets the tooling, not the code.

## Scoped re-verification

A re-trigger after a fix re-runs the failing gate(s) only; unchanged gates' prior
results stand. Narrow further where the script supports a scoped flag:

- `scripts/check-code-principles.sh --gates <name>` — one category (`complexity`, `dry`, `yagni`, `solid`, `property-tests`).
- `scripts/check-scenario-traceability.sh --checks <1|2>` — one traceability check (1 = scenario-to-test, 2 = reference-to-scenario).

Checks 2, 3, 4 are re-run whole. The re-run appends to its gate in
`25-verification.md`: the report is full run + delta, never a rewrite.
