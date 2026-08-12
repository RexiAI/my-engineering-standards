# AC-020-07: docs describe the copy → fill → restart flow, no commit

## AC-020-07-01 — SPEC_PIPELINE.md documents the per-machine flow
Given `docs/SPEC_PIPELINE.md`
When the `Model configuration` section is read
Then it instructs: `cp config/model.local.env.example config/model.local.env` → fill in model ids → `source scripts/load-env.sh` in the shell that launches opencode (or add it to the shell profile) → restart opencode
And it states that config is read once at startup, so a restart is required after any change
And it states that no commit or PR is involved in switching a model
And it states the precedence: committed defaults when a var is unset, the gitignored file when present, a pre-existing exported var over the file
And it states that sourcing the loader is what prevents the empty-string failure (`{env:VAR}` with an unset var resolves to empty)

## AC-020-07-02 — AGENTS.md model table points at the local env file
Given `AGENTS.md`
When the "OpenCode Go Model Configuration" section's model table is read
Then it notes that per-machine model values come from the gitignored `config/model.local.env` via `scripts/load-env.sh`
And it states that switching a model means editing the local file and restarting opencode, not committing

## AC-020-07-03 — Docs cite the structural enforcement
Given the updated `docs/SPEC_PIPELINE.md` `Model configuration` section
When it is read
Then it names `scripts/check-model-env.sh` as the enforcement that `opencode.json` keeps no literal model id and the real env file is never tracked
