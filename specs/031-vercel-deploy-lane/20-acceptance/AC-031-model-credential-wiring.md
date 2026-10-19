# AC-031: Model and credential wiring

## AC-031-06 — opencode.json entry uses env reference
Given `opencode.json` has been updated
When the `agent` block is read
Then it contains `"spec-deployer": { "model": "{env:SPEC_DEPLOYER_MODEL}" }` with no literal model id

## AC-031-07 — model.local.env.example carries committed default
Given `config/model.local.env.example` has been updated
When the file is read
Then it contains a line `SPEC_DEPLOYER_MODEL=bailian-token-plan-personal/qwen3.8-flash`

## AC-031-08 — agent.local.env.example carries Vercel placeholders
Given `config/agent.local.env.example` has been updated
When the file is read
Then it contains commented placeholder lines for `VERCEL_TOKEN`, `VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID` using the angle-bracket convention (e.g. `# VERCEL_TOKEN=<your-vercel-token>`)

## AC-031-09 — No real credential values in tracked files
Given the wiring changes have been made
When `scripts/check-no-hardcoded-secrets.sh` is run
Then it exits 0 with no findings

## AC-031-10 — guard-env.sh still passes
Given no new tracked env files have been added
When `scripts/guard-env.sh` is run
Then it exits 0 (no real env file in the tracked set)
