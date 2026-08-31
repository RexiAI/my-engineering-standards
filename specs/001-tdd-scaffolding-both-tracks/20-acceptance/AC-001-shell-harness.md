# AC-001: Shell TDD harness foundation

## AC-001-01 — Harness runs a passing bats test
Given bats-core ≥1.10 is installed
And `scripts/tests/test_helper.bash` exists
When `make test-scripts` (or `make test-shell`) is invoked on a fixture containing one passing bats test
Then the command exits 0
And TAP output contains `ok 1`

## AC-001-02 — Failing bats test fails the target
Given a bats test that asserts `false`
When `make test-scripts` is invoked
Then the command exits non-zero
And TAP output contains `not ok`

## AC-001-03 — Helper safely sources shared libs
Given `scripts/tests/test_helper.bash` is sourced by a bats test
When the test references `gate-report-lib.sh` functions (`json_escape`, `json_array`)
Then the test does not error on sourcing
And repeated sourcing does not redefine functions (guarded)

## AC-001-04 — Missing bats binary yields actionable error
Given bats is not on PATH
When `make test-scripts` is invoked
Then the command exits non-zero
And stderr contains `bats` and an install hint

## AC-001-05 — No secrets in harness or fixtures
Given the harness helper and any fixture files under `scripts/tests/`
When `scripts/check-no-hardcoded-secrets.sh` is run
Then it exits 0
And no finding mentions `scripts/tests/`

## AC-001-06 — CI invokes the harness
Given the CI validate job configuration (`.github/workflows/self-ci.yml` or equivalent)
When the workflow is inspected
Then it contains a step invoking `make test-scripts` or `bats scripts/tests`
And that step has no `continue-on-error: true`
