# AC-020-06: `scripts/model-env.selftest.sh` + `scripts/model-env.runtime-check.sh` prove the behavior and run in self-ci

## AC-020-06-01 — The selftest and runtime-check scripts exist under scripts/
Given the repo root
When `scripts/model-env.selftest.sh` and `scripts/model-env.runtime-check.sh` are checked
Then both exist
And each is a bash script with `set -euo pipefail` and fixtures built in `mktemp -d` with `trap` cleanup

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
And it asserts a fixture whose example lacks one referenced var makes it exit 1 naming the mismatch
And it asserts a scratch repo with `config/model.local.env` tracked makes it exit 1
And no fixture uses an inline literal model-id value that would trip the check it proves (model ids are constructed at runtime)

## AC-020-06-04 — The runtime check proves real opencode resolution in three cases
Given `scripts/model-env.runtime-check.sh` and a pinned opencode binary
When it runs the binary against a scratch project (fixture `opencode.json` with 8 `{env:SPEC_*_MODEL}` refs and a fixture example, outside the repo checkout, each case in a subshell with all 8 vars unset)
Then case 1 (loader sourced, no local file) resolves every agent's model via `opencode debug agent` to the fixture example default, none null/empty
And case 2 (loader sourced, local file overriding one var and a pre-set env var overriding another) resolves the overrides and keeps the remaining agents at defaults
And case 3 (loader not sourced) resolves the model to null/empty, proving the loader is what carries the defaults
And all fixture model ids are constructed at runtime (no inline literal model-id values)

## AC-020-06-05 — Both scripts and the pinned binary run in self-ci and a regression fails the job
Given `.github/workflows/self-ci.yml` has a `validate` job
When the job runs
Then one step downloads the pinned opencode release tarball from `https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz` (public URL, no token)
And the same step or adjacent steps run `bash scripts/check-model-env.sh`, `bash scripts/model-env.selftest.sh`, and `bash scripts/model-env.runtime-check.sh` with the downloaded binary (no `continue-on-error`)
And a hypothetical loader, gate, or wiring regression makes one of those scripts exit non-zero and the `validate` job fails
