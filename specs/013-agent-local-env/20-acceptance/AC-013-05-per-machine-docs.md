# AC-013-05: AGENTS.md / README documents the per-machine setup

## AC-013-05-01 — The setup walk-through is documented
Given the repo root
When `AGENTS.md` and `README.md` are read
Then at least one of them contains a "per-machine agent environment" (or equivalent) section
And that section instructs: copy `config/agent.local.env.example` to `config/agent.local.env`, fill real values, never commit the real file
And it instructs sourcing `scripts/load-env.sh` in the shell where `/spec` and `/build` run
And it mentions the `scripts/load-env.ps1` twin for Windows shells

## AC-013-05-02 — The section names the real credentials and the enforcement
Given the per-machine section from AC-013-05-01
When it is read
Then it names `GITHUB_TOKEN` and `GH_TOKEN` and their purposes
And it references `scripts/guard-env.sh` and `scripts/check-no-hardcoded-secrets.sh` as the enforcement that makes "never commit" structural
