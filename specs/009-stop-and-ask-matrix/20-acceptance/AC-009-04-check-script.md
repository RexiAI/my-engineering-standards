# AC-009-04: scripts/check-stop-and-ask-matrix.sh verifies the matrix

## AC-009-04-01 — Script exists and is executable

Given the repo root
When `scripts/check-stop-and-ask-matrix.sh` is inspected
Then the file exists and has the executable bit set

## AC-009-04-02 — Script passes on a compliant repo

Given the repo after Tasks 1–3 are implemented
When `scripts/check-stop-and-ask-matrix.sh` is run
Then it exits 0 and prints PASS for each check

## AC-009-04-03 — Script fails when the matrix section is missing

Given a copy of `docs/SPEC_PIPELINE.md` without the
`## Stop-and-Ask decision matrix` heading
When `scripts/check-stop-and-ask-matrix.sh` is run against it
Then it exits 1 and prints a FAIL naming the missing section

## AC-009-04-04 — Script fails when an agent lacks the matrix reference

Given a state where one of the 8 pipeline agent files no longer contains the
section title `Stop-and-Ask decision matrix`
When `scripts/check-stop-and-ask-matrix.sh` is run
Then it exits 1 and prints a FAIL naming the offending agent file

## AC-009-04-05 — Script fails when an agent may edit gate config

Given a state where a pipeline agent's `permission.edit` allows editing
`scripts/check-code-principles.sh` or a linter complexity config
When `scripts/check-stop-and-ask-matrix.sh` is run
Then it exits 1 and prints a FAIL naming the offending agent file and the
editable path

## AC-009-04-06 — Script fails when a Confluence row appears

Given a matrix containing a Confluence row
When `scripts/check-stop-and-ask-matrix.sh` is run
Then it exits 1 and prints a FAIL naming the forbidden row

## AC-009-04-07 — Script cites every scenario ID for traceability

Given the scenarios in `specs/009-stop-and-ask-matrix/20-acceptance/`
When the script is run
Then its output contains every `AC-009-01-0N`, `AC-009-02-0N`,
`AC-009-03-0N`, and `AC-009-04-0N` ID so
`scripts/check-scenario-traceability.sh` resolves each to a test

## AC-009-04-08 — Script is read-only

Given `scripts/check-stop-and-ask-matrix.sh`
When it is run against a compliant repo
Then no file in the repo is modified by its execution
