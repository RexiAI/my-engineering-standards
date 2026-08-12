# AC-013-06: agents read credentials via the loader, never via literals

## AC-013-06-01 — The PR Opener sources the loader before committing and pushing
Given `agents/spec-pr-opener.md`
When it is read
Then it instructs sourcing `scripts/load-env.sh` before committing and pushing
And it instructs using `$GITHUB_TOKEN` / `$GH_TOKEN` from the environment
And it contains no literal credential value

## AC-013-06-02 — The orchestrator documents that the running shell has the env loaded
Given `agents/spec-pipeline.md`
When it is read
Then it states that the shell it runs in already has the env loaded per the per-machine setup in AGENTS.md/README
And the pipeline relies on the PR Opener's defensive sourcing rather than per-agent sourcing

## AC-013-06-03 — No literal credential value appears in any agent or command file
Given the files under `agents/` and `commands/`
When scanned for hardcoded credential values
Then none match the literal-token-prefix or secret-assignment patterns from AC-013-04
