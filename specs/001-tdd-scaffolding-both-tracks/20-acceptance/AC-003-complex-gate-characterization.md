# AC-003: Characterization tests for complex analysis gate

## AC-003-01 — Complexity >6 triggers FAIL with file:line
Given a temp Java file containing a method with >6 decision points (if/for/while/&&)
When `scripts/check-code-principles.sh` is run against that dir
Then it exits 1
And stdout contains `FAIL` and `Cyclomatic complexity >6` and `file:line` evidence

## AC-003-02 — Method >20 lines triggers WARN (not FAIL by default)
Given a temp method with 25 lines and complexity ≤6
When `scripts/check-code-principles.sh` is run
Then it exits 0 (WARN-only gate)
And stdout contains `WARN` and `Method body >20 lines`

## AC-003-03 — Duplicate 4-line block triggers DRY WARN
Given two temp files sharing an identical 4-line block
When `scripts/check-code-principles.sh` is run
Then stdout contains `WARN` and `Possible duplication` (or `DRY`)

## AC-003-04 — --gates filters which checks run
Given a fixture that would FAIL on complexity
When `scripts/check-code-principles.sh --gates dry` is run
Then it exits 0 (complexity gate not selected)
And output indicates `gates: dry` (or equivalent)

## AC-003-05 — --json emits valid JSON with required keys
Given any temp source dir
When `scripts/check-code-principles.sh --json` is run
Then stdout is valid JSON
And it contains keys `tier`, `gates`, `fails`, `warns`

## AC-003-06 — -ReportPath writes JSON atomically
Given a temp path `/tmp/ac003-report.json`
When `scripts/check-code-principles.sh -ReportPath /tmp/ac003-report.json` is run
Then the file exists and is valid JSON
And stdout is unchanged (still human output)

## AC-003-07 — Tier mvp skips property-tests gate, production enforces it
Given a temp `AGENTS_FOO.md` declaring `Conformance tier: production` and no property test present
When `scripts/check-code-principles.sh --tier production` is run
Then it exits 1 and mentions `Property tests` and `required at production tier`
And with `--tier mvp` the same dir exits 0 with `skipped (project tier is mvp)`

## AC-003-08 — Tests complete quickly with minimal fixtures
Given the bats file for this task
When it runs with `time bats scripts/tests/check-code-principles.bats`
Then wall time is <5s
And no fixture exceeds 30 lines
