# AC-012-03: both selftests are wired into self-ci and fail the job on regression

## AC-012-03-01 — self-ci runs both selftests on every push and PR (AC-001)
Given `.github/workflows/self-ci.yml` has a `validate` job that triggers on push and pull_request
When the job runs
Then one step runs both `bash scripts/check-code-principles.selftest.sh` and `bash scripts/check-scenario-traceability.selftest.sh`
And neither step uses `continue-on-error`

## AC-012-03-02 — A selftest regression fails the job
Given a hypothetical regression where a gate no longer fires on its fixture (e.g. the complexity threshold is raised to >8)
When the selftest step runs in self-ci
Then the failing selftest exits 1
And the `validate` job fails

## AC-012-03-03 — The new scripts are covered by the existing parse and lint steps
Given the new selftest scripts end in `.sh` under `scripts/`
When the `bash -n` step runs over all `*.sh` files
Then both selftest scripts parse cleanly
And the shellcheck step's `scripts/*.sh` glob includes them (unchanged continue-on-error behavior)
