# AC-002: Characterization tests for pure gate scripts

## AC-002-01 — detect-saga-outbox happy path detects saga file
Given a temp repo containing a file with a saga annotation (`@SagaHandler` or `sagaStep(`)
When `scripts/detect-saga-outbox.sh` is run against that dir
Then it exits 0
And stdout signals `SAGA_DETECTED=true` (or equivalent marker the CI gate consumes)

## AC-002-02 — detect-saga-outbox no-saga repo yields negative signal
Given a temp repo containing no saga or outbox markers
When `scripts/detect-saga-outbox.sh` is run
Then it exits 0
And the output signals `SAGA_DETECTED=false` and `OUTBOX_DETECTED=false`

## AC-002-03 — check-scenario-traceability happy path passes when IDs align
Given a temp `specs/001-foo/20-acceptance/AC-001-foo.md` with heading `## AC-001-01 — ...`
And a temp test file containing `AC-001-01` in its name or string
When `scripts/check-scenario-traceability.sh` is run with those dirs
Then it exits 0
And output contains `every scenario traced` (or equivalent success)

## AC-002-04 — check-scenario-traceability fails on orphan scenario
Given a temp spec containing `## AC-002-99 — orphan` with no test referencing it
When `scripts/check-scenario-traceability.sh` is run
Then it exits 1
And output mentions `AC-002-99` as orphaned/missing

## AC-002-05 — check-scenario-traceability fails on dangling test reference
Given a temp test file referencing `AC-999-01` that does not exist in any spec
When `scripts/check-scenario-traceability.sh` is run
Then it exits 1
And output mentions `AC-999-01` as dangling/unresolved

## AC-002-06 — Missing args or unreadable dir yields exit 2 with error
Given no arguments or an unreadable specs dir
When `scripts/check-scenario-traceability.sh` is invoked with that input
Then it exits 2
And stderr contains an error line (not a silent PASS)

## AC-002-07 — Guard script preserves exit contract
Given `scripts/guard-env.sh` (or `check-specs-archived.sh`) with no violations
When the script is run
Then it exits 0
And a run with a violation exits 1 with a `FAIL` line mentioning the offending file

## AC-002-08 — Tests are hermetic and use temp dirs
Given the bats tests for this task
When they run
Then no test mutates `scripts/` or the real repo
And each test cleans its temp dir via trap or `teardown`
