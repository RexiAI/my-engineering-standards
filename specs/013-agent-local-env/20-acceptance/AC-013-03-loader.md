# AC-013-03: `scripts/load-env.sh` (+ `.ps1` twin) sources and exports the real env file

## AC-013-03-01 — Fails loudly when the real file is missing but the example exists
Given a scratch fixture directory containing `config/agent.local.env.example` but no `config/agent.local.env`
When `scripts/load-env.sh` is sourced/run against it
Then it exits 1
And prints to stderr a message naming the missing `config/agent.local.env` and the copy-fill step (`cp config/agent.local.env.example config/agent.local.env`)

## AC-013-03-02 — Sources the real file and exports every variable
Given a scratch fixture directory where `config/agent.local.env` defines `GITHUB_TOKEN=<real>`, `GH_TOKEN=<real>`, and `EXTRA_VAR=hello`
When `scripts/load-env.sh` runs against it
Then all three variables are exported in the resulting environment with the file's values

## AC-013-03-03 — Quiet no-op when both files are missing
Given a scratch fixture directory with neither `config/agent.local.env` nor `config/agent.local.env.example`
When `scripts/load-env.sh` runs against it
Then it exits 0 and prints nothing to stderr

## AC-013-03-04 — Does not clobber pre-existing exported variables
Given a shell environment where `GITHUB_TOKEN=already-set` is already exported
And a scratch `config/agent.local.env` that defines `GITHUB_TOKEN=file-value`
When `scripts/load-env.sh` runs against it
Then `GITHUB_TOKEN` is still `already-set` in the resulting environment

## AC-013-03-05 — The `.ps1` twin exists with a documented parity contract
Given the repo root
When `scripts/load-env.ps1` is checked
Then it exists
And the self-ci selftest asserts the file exists and its header documents the same behavior contract as the `.sh` (source real file, export vars, fail loudly when real missing + example present, no-op when both missing, do not clobber pre-set vars)
