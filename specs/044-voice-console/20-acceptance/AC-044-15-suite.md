# AC-044-15: Bats acceptance suite

## AC-044-15-01 — Every scenario is cited exactly once
Given `specs/044-voice-console/20-acceptance/`
When its scenario ids are collected
Then each id appears in exactly one `@test "AC-044-NN-MM: ..."` name in `scripts/tests/voice-console.bats`
And no test name cites an id that is not in the acceptance folder

## AC-044-15-02 — Traceability passes
Given the finished suite
When `scripts/check-scenario-traceability.sh` runs
Then exit code is 0

## AC-044-15-03 — No vacuous assertions
Given `scripts/tests/voice-console.bats`
When `scripts/check-bats-assertions.sh` runs
Then exit code is 0

## AC-044-15-04 — The suite runs without the optional runtime
Given Node installed and no Python, PyTorch, Pocket TTS, `arecord`, or `ffplay`
When `make test-scripts` runs
Then exit code is 0
And every absent-runtime test asserts exit code 3 rather than skipping
And only the device-mode operator scenarios are skipped

## AC-044-15-05 — The suite is hermetic
Given the suite runs
When network and filesystem activity is inspected
Then every socket connection targets `127.0.0.1`
And no model weights are downloaded
And no file is written outside `$TMPDIR_HELPER` or a temp `OPENCODE_CONFIG_DIR`

## AC-044-15-06 — Temp fixtures come from the shared helper
Given `scripts/tests/voice-console.bats`
When each test's setup is read
Then `setup_tmpdir` is called and `teardown_tmpdir` is registered for teardown
