# AC-020-07: docs describe the one-time-setup flow, no commit

## AC-020-07-01 — SPEC_PIPELINE.md documents the per-machine mechanism
Given `docs/SPEC_PIPELINE.md`
When the `Model configuration` section is read
Then it instructs the one-time setup: add `source <repo>/scripts/load-model-env.sh` to the shell profile once (every shell then exports the model vars automatically — the loader is never sourced per-launch by hand), optionally `cp config/model.local.env.example config/model.local.env` + fill in model ids to override → restart opencode
And it states that config is read once at startup, so a restart is required after any change
And it states that no commit or PR is involved in switching a model
And it states the precedence: a pre-existing exported var wins, the gitignored local file when present, committed defaults (example) when the var is unset
And it states that the profile wiring is what prevents the empty-string failure (`{env:VAR}` with an unset var resolves to empty — no default syntax exists in this opencode build)
And it documents the boundary that the supported path is shell-launched opencode and the loader fails loudly (exit 1 naming the var) when its vars were never exported

## AC-020-07-02 — AGENTS.md model table points at the local env file and loader
Given `AGENTS.md`
When the "OpenCode Go Model Configuration" section's model table is read
Then it notes that per-machine model values come from the gitignored `config/model.local.env` via `scripts/load-model-env.sh`
And it states that switching a model means editing the local file and restarting opencode, not committing

## AC-020-07-03 — Docs cite the structural enforcement and the self-ci runtime verification
Given the updated `docs/SPEC_PIPELINE.md` `Model configuration` section
When it is read
Then it names `scripts/check-model-env.sh` as the enforcement that `opencode.json` keeps no literal model id and the real env file is never tracked
And it states that self-ci installs a pinned opencode binary and runs the runtime check to verify the resolution behavior
