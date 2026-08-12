# AC-020-06: `scripts/model-env.selftest.sh` proves the behavior and runs in self-ci

## AC-020-06-01 — The selftest script exists under scripts/
Given the repo root
When `scripts/model-env.selftest.sh` is checked
Then it exists
And it is a bash script with `set -euo pipefail` and fixtures built in `mktemp -d` with `trap` cleanup

## AC-020-06-02 — The selftest proves the loader's precedence
Given `scripts/model-env.selftest.sh` exists
When it runs
Then it asserts process-env wins over local file (pre-set var not clobbered)
And it asserts local file wins over example for a defined var, and missing vars fall back to example defaults
And it asserts a var resolvable from no source exits 1 with a message naming the var

## AC-020-06-03 — The selftest proves the check script fires
Given `scripts/model-env.selftest.sh` exists
When it runs
Then it asserts an `opencode.json` fixture with a literal model id makes `scripts/check-model-env.sh` exit 1
And it asserts a fixture with all env references and no tracked real file makes it exit 0
And it asserts a scratch repo with `config/model.local.env` tracked makes it exit 1
And no fixture uses an inline literal model-id value that would trip the check it proves (model ids are constructed at runtime)

## AC-020-06-04 — Both scripts run in self-ci and a regression fails the job
Given `.github/workflows/self-ci.yml` has a `validate` job
When the job runs
Then one step runs `bash scripts/check-model-env.sh` and `bash scripts/model-env.selftest.sh` (no `continue-on-error`)
And a hypothetical loader or gate regression makes that step exit non-zero and the `validate` job fails
