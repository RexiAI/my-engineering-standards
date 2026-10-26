# AC-033: Bats fixtures and regression gates

## AC-033-46 — bats fixtures run green
Given the new fixtures under `scripts/tests/`
When `make test-scripts` runs
Then it exits 0

## AC-033-47 — orchestration references resolve
Given the new catalog and script changes
When `scripts/check-orchestration.sh` runs
Then it exits 0

## AC-033-48 — skills and gate-consistency gates stay green
Given the change set
When `scripts/check-skills.sh` and `scripts/check-gate-consistency.sh` run
Then both exit 0

## AC-033-49 — no regression in default output or init-ci flags
Given a non-TTY run with no flags
When `bootstrap.sh` runs
Then it writes the same core-wiring files as before this change
And `init-ci.sh`'s existing flags (`--platform`, `--backend`, `--frontend`, `--with-saga`, `--with-deploy`, `--with-release`, `--with-pr-review`, `--deploy-tool`, `--registry`) behave as before
