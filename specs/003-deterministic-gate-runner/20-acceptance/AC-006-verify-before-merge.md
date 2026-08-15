# AC-006: Verify before merge

## AC-006-01 — Dry-run is green
Given a clean clone
When `bash scripts/gates/dry-run.sh` is run
Then it exits `0`
And `dry-run-summary.json` shows every expected assertion

## AC-006-02 — `gate-runner.sh -Phase local` is green on this repo
Given the repository's working tree is clean
When `bash scripts/gates/gate-runner.sh -Phase local -RepoPath .
-BaseRef HEAD` is run
Then it exits `0`
And `.civ/gate-report.json` exists

## AC-006-03 — README example output is reproducible
Given a clean clone
When the user follows the example commands in
`scripts/gates/README.md`
Then the produced output matches the README verbatim
