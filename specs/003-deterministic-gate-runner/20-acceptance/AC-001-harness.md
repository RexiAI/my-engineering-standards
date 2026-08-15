# AC-001: Author the gate-runner harness

## AC-001-01 — `find-harness.sh` exists and resolves
Given a clean clone of the repository
When `bash scripts/gates/find-harness.sh` is run
Then it prints an absolute path containing `scripts/gates`
And it exits `0`

## AC-001-02 — `find-harness.sh` honors `CIV_GATES_DIR` override
Given `CIV_GATES_DIR=/custom/path`
And given `/custom/path/gate-runner.sh` exists
When `bash scripts/gates/find-harness.sh` is run
Then it prints `/custom/path`
And it exits `0`

## AC-001-03 — `find-harness.sh` fails loudly on bad override
Given `CIV_GATES_DIR=/custom/path`
And given no `gate-runner.sh` under `/custom/path`
When `bash scripts/gates/find-harness.sh` is run
Then it prints a one-line error to stderr
And it exits non-zero

## AC-001-04 — `gate-runner.sh -Phase local` runs on a clean repo
Given the repository has a clean working tree
When `bash scripts/gates/gate-runner.sh -Phase local -RepoPath .
-BaseRef HEAD` is run
Then it exits `0`

## AC-001-05 — Scoped re-verification runs only requested gates
Given a previous full run produced a gate report
When `bash scripts/gates/gate-runner.sh -Phase all -Gates G0` is run
Then only the G0 phase executes
And the output JSON has the same schema as the full run

## AC-001-06 — `README.md` documents usage
Given `scripts/gates/README.md`
When it is read
Then it documents the flag set
And it documents the JSON report path (`<RepoPath>/.civ/gate-report.json`)
And it documents the SKIP-not-pass rule
