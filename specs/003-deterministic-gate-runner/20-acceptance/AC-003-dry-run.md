# AC-003: Dry-run proves the harness with throwaway fixtures

## AC-003-01 — Default dry-run is portable
Given a fresh machine with only `bash`, `git`, and `jq` installed
When `bash scripts/gates/dry-run.sh` is run
Then it exits `0`
And it writes `.civ-dryrun/dry-run-summary.json`
And no other files outside `.civ-dryrun/` are touched

## AC-003-02 — Each fixture scenario produces a known status
Given the dry-run script
When it is run
Then the library fixture is reported with `projectType: library`
And the microservices-shaped fixture is reported with
`projectType: microservice`
And the ambiguous fixture is reported with
`projectTypeConfirmed: false`

## AC-003-03 — SKIP is not a blocking failure
Given the dry-run script
When it is run on the microservices fixture with the deploy phase
And there is no `kubectl` or cluster
Then G7 is reported as `SKIP`
And the overall dry-run result remains `PASS`
