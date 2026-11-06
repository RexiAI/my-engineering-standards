# Verifier stage file (stage 4)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Artifact layout, §Stop-and-Ask
decision matrix, and §Remediation budget.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before writing `25-verification.md`.

Deliverable: `specs/NNN-slug/25-verification.md`; the evidence rules are in the
audit contract named above.

## Checks in order

Every check is a real execution you run yourself; a prior stage's summary is no
substitute.

| # | Check | How it is run | Gate ID |
|---|---|---|---|
| 1 | Scenario traceability | `scripts/check-scenario-traceability.sh` (or the `.standards/` twin); 0 = clean, 1 = findings, 2 = tooling failure | `traceability` |
| 2 | Full test suite | the project's real test command (`go test ./...`, `mvn test`, `npm test`); a skipped test is a failure | `test-suite` |
| 3 | Complexity gate | the real linter (`golangci-lint run`, `pmd check`, `eslint`) on the changed files | `complexity` |
| 3.5 | Design-principles gate | `scripts/check-code-principles.sh`: KISS/DRY/YAGNI/SOLID + cyclomatic + property tests. Every FAIL stops the pipeline; a WARN is recorded and flagged | `design-principles` |
| 4 | Spot check | 2+ scenarios picked at random from `20-acceptance/`, assertions read against their Given/When/Then — a passing test asserting the wrong thing is a false green | `spot-check` |
| 5 | No unaccounted behavior | skim the diff for logic that traces to no task or scenario; flag it to be justified | `unaccounted` |

For gates 1 and 3.5 the `--json` transcript plus the exit code is the verdict.

## Telemetry record

After every completed run — PASS, FAIL, or BLOCK — append one record to
`runs.jsonl` via `scripts/record-gate-run.sh` (its own bash execution, so no
`permission.edit` widening). Fields: `specSlug`; `gatesFailed`; `warnings`;
`durationSec`; `outcome` — `block` if any gate BLOCKed, else `fail` if the
verdict is FAIL, else `pass`. `runId`, `loopCount` and retry counts are generated
or defaulted from `SPEC_*` (spec 008).

A FAIL or BLOCK still records; if the append fails, report it as a warning and
never fabricate a record.

## Report format

One evidence block per check, in `docs/spec-pipeline/audit-contract.md`
§Audit contract's format: a `## Evidence: <check name>` heading, the exact
`command:`, the real output (or an excerpt — never a paraphrase), the `exit:`
code, and an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`. `scripts/check-audit-trail.sh`
parses those markers.

Each check reports PASS/FAIL/BLOCK with its command and real output; the spot
check reports which scenarios you read and what you found, and "no unaccounted
behavior" is a finding line, not a command. The verdict is transcribed from the
exit codes, never from your reading of the diff:

- **PASS** — every gate ran, no findings (the Architect may proceed).
- **FAIL** — a gate produced findings (the pipeline stops; list every reason).
- **BLOCK** — a gate could not run, or exited non-zero for a reason other than a
  finding (missing script or tool, unreadable tree). Name the tooling failure with
  the script's stderr, so the fix targets the tooling, not the code.

## Scoped re-verification

A re-trigger after a fix re-runs the failing gate(s) only; unchanged gates' prior
results stand. Narrow further where the script supports a scoped flag:

- `scripts/check-code-principles.sh --gates <name>` — one category (`complexity`, `dry`, `yagni`, `solid`, `property-tests`).
- `scripts/check-scenario-traceability.sh --checks <1|2>` — one traceability check (1 = scenario-to-test, 2 = reference-to-scenario).

Checks 2, 3, 4 are re-run whole — still scoped relative to the full suite. The
re-run appends to its gate in `25-verification.md`, preserving the prior full run:
the report is full run + delta, never a rewrite, and the verdict reflects it.

## Lite mode

In `lite` (`docs/SPEC_PIPELINE.md §Lite mode`) the same hard gates run: full
suite, secrets scan, `scripts/check-code-principles.sh` (a FAIL blocks), and
traceability. This stage also authors `30-report.md`; the retained-gate list,
the `Pipeline mode: lite` / `skipped (lite)` markers, and the report format are
in `docs/spec-pipeline/lite-mode.md`.
