# AC-017-05: Traceability check script carries the AC-017-NN IDs and gates CI

## AC-017-05-01 — The script exists and exits 0 only when the assertions hold
Given `scripts/check-ci-sweeper.sh` is created per task 5
When the script is run against a repo where all required strings are present
Then it exits 0

## AC-017-05-02 — The script carries every AC-017-NN-NN scenario ID
Given `scripts/check-ci-sweeper.sh` is created per task 5
When the script is read
Then it cites every scenario ID from `AC-017-01-01` through `AC-017-05-NN`
And it greps each scenario's required string in the relevant artifact (`skills/ci-triage/SKILL.md` and `.github/workflows/ci-sweeper.yml`)

## AC-017-05-03 — The script fails closed when a required string is missing
Given `scripts/check-ci-sweeper.sh` is created per task 5
When a required string is absent (e.g. the skill lacks `never auto-fix`, or the workflow lacks `workflow_run`)
Then the script exits non-zero
And a `--self-test` mode validates this against a temporary fixture so CI can prove the gate fails closed

## AC-017-05-04 — The script is wired into the CI it watches
Given `scripts/check-ci-sweeper.sh` is created per task 5
When `.github/workflows/self-ci.yml` is read
Then it invokes `scripts/check-ci-sweeper.sh` as a step alongside the existing CRLF and YAML-syntax checks
