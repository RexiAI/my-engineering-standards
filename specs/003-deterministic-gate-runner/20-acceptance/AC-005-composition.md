# AC-005: Composition with existing scripts

## AC-005-01 — `S1` exit code matches the legacy script
Given `scripts/check-scenario-traceability.sh`
And given the runner's `S1` phase
When both are run with the same inputs
Then both exit with the same status code

## AC-005-02 — `S2` is invoked when `scripts/mutation.sh` exists
Given `scripts/mutation.sh` exists and exits `0`
When the runner's `S2` phase runs
Then the runner reports `S2: PASS`

## AC-005-03 — `S2` SKIPs when `scripts/mutation.sh` is absent
Given `scripts/mutation.sh` does not exist
When the runner's `S2` phase runs
Then the runner reports `S2: SKIP` with a note
And the runner exit code is `0`, not `1`

## AC-005-04 — Legacy scripts remain runnable directly
Given `scripts/check-saga-timeouts.sh` and `scripts/lint-outbox-schema.sh`
When either is invoked directly
Then it still exits `0` on a clean repo
