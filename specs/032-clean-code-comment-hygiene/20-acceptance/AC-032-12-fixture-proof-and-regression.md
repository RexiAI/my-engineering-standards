# AC-032-12: Fixture proof, wiring, and no regression

## AC-032-12-01 — The selftest proves each new rule and each allowlist control
Given `scripts/check-code-principles.selftest.sh` with its new fixture groups
When `bash scripts/check-code-principles.selftest.sh` runs
Then it exits 0
And its output contains a PASS line for each of the fixture groups `comments-out-code`, `comments-restate`, `comments-advisory`, `comments-allowlist`, `naming-heuristics`, and `null-discipline`
And for every violating fixture the expected message fires at the expected severity
And for every near-miss or allowlisted control the message does not fire
And the script cites the `AC-032-` scenario IDs for those groups
And no fixture is written inside the repository tree (all fixtures live under `mktemp -d`)

## AC-032-12-02 — The new scenarios run as bats tests and are not vacuous
Given `scripts/tests/check-code-principles-clean-code.bats`
When `bats scripts/tests/check-code-principles-clean-code.bats` runs
Then it exits 0
And the file cites at least one `AC-032-NN-MM` ID per new-gate task
And `bash scripts/check-bats-assertions.sh` exits 0
And `make test-scripts` exits 0

## AC-032-12-03 — The new gates cannot turn the repository red on day one
Given the repository working tree
When `bash scripts/check-code-principles.sh --gates comments,naming,null-discipline .` runs
Then it exits 0
And its output contains no `FAIL` finding line
And it still reports at least one finding or PASS line per selected gate

## AC-032-12-04 — Existing gate behavior is unchanged
Given the original selftest fixtures
When the script runs with `--gates complexity` on a cyclomatic-complexity-7 fixture and on a complexity-6 fixture
Then the first exits 1 with `Cyclomatic complexity >6` and the second exits 0 with no such finding
And `bash scripts/check-code-principles.selftest.sh` exits 0
And `bash scripts/tests/check-code-principles-blame.sh` exits 0
And `bash scripts/check-gate-consistency.sh` exits 0
And `grep -q '> 6' scripts/check-code-principles.sh` succeeds
And the script exposes no `--threshold` or `--complexity <n>` override option
