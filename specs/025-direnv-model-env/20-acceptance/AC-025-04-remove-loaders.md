# AC-025-04: Loaders and `--emit` removed; no lingering references in live surfaces

Live surface for these scenarios: `scripts/`, `templates/`, `agents/`, `.github/`,
`config/*.example`, `README.md`, `AGENTS.md`, `docs/SPEC_PIPELINE.md`.
`docs/changes/` (historical archives) and `specs/` (pipeline scratch) are exempt.

## AC-025-04-01 — The loader scripts are deleted
Given the git index and worktree of the standards repo
When `git ls-files` is checked for `scripts/load-env.sh` and `scripts/load-model-env.sh`
Then neither path appears
And neither file exists on disk

## AC-025-04-02 — `--emit` is gone from every live surface
Given the live-surface paths
When a recursive search for `--emit` runs across them
Then zero matches are found

## AC-025-04-03 — No loader name appears in any live surface
Given the live-surface paths
When a recursive search for `load-env` and `load-model-env` runs across them
Then zero matches are found

## AC-025-04-04 — Agents no longer cite the loaders; PR Opener checks presence instead
Given `agents/spec-pipeline.md` and `agents/spec-pr-opener.md`
When both files are searched for `load-env.sh` and `load-model-env.sh`
Then no match is found
And when the PR Opener prompt's pre-commit credential step is read
Then it verifies `$GITHUB_TOKEN` and `$GH_TOKEN` are non-empty and reports + stops when either is missing
And it does not source any loader

## AC-025-04-05 — CI sweeper loads committed defaults without the loader
Given `.github/workflows/ci-sweeper.yml`
When the workflow is searched for `load-model-env.sh` and `load-env.sh`
Then no match is found
And the headless run loads the committed defaults via the dotenv-equivalent (`set -a; . config/model.local.env.example; set +a`) before invoking opencode

## AC-025-04-06 — Config example headers document direnv, cite no loader
Given `config/model.local.env.example` and `config/agent.local.env.example`
When both headers are searched for `load-env.sh`, `load-model-env.sh`, and `--emit`
Then no match is found
And each header documents the direnv `dotenv_if_exists` flow instead

## AC-025-04-07 — Orchestration references still resolve after the removals
Given the loaders deleted and agents/AGENTS.md updated
When `bash scripts/check-orchestration.sh` runs
Then it exits 0 (every `scripts/...` path cited in `agents/`, `commands/`, and `AGENTS.md` resolves)
