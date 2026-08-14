# Per-machine model configuration via .env (no code change to switch models)

Today the spec pipeline's models are pinned in this repo's committed `opencode.json`
(`agent.<name>.model` for every spec-* agent). Switching a model means editing that
file and committing — the same "must commit to change" problem spec 013 solved for
secrets. This spec removes the commit from the model-change loop: a developer edits a
gitignored `.env`, restarts opencode, and the new model is live. No diff, no commit,
no PR.

## The problem

- `opencode.json` in this repo hardcodes one model per agent (spec-specifier,
  spec-ux, spec-verifier, spec-mutation-runner, spec-pr-opener, spec-coder,
  spec-refactorer, spec-pipeline).
- To test a different model you edit that file and commit — the full branch → PR →
  merge cycle, for a per-developer preference that shouldn't touch main at all.
- The opencode docs confirm `{env:VAR}` substitution works in config string values,
  including `model` (verified: `"model": "{env:SPECIFIER_MODEL}"` resolves from an
  exported env var). But a bare `.env` file is **not** auto-loaded into the config
  interpolation path by this opencode build (verified: env var set in `.env` stays
  unset inside a config hook). So the mechanism needs a loader step, not just
  `{env:...}` syntax.

## What it must provide

- A committed `.env.example` that lists one variable per modelable agent, with the
  current committed value as the default and a comment per variable.
- A gitignore rule that keeps the real `.env` (or a dedicated name like
  `config/model.local.env` to avoid clashing with app `.env` files) out of every
  commit — reuse the spec-013 pattern (`config/agent.local.env.example` +
  gitignored real file + loader).
- A loader (`scripts/load-env.sh` or a reuse of spec-013's loader) that the
  opencode startup path sources before config is read, so `{env:...}` interpolation
  sees the values. This must work non-interactively (subagents and `/spec`, `/build`
  commands don't get a human shell).
- Precedence that keeps working: committed defaults win when a variable is unset
  (no `.env` present → models fall back to today's committed values), and the
  gitignored file wins when present. A missing `.env` must never break config
  resolution to an empty string that opencode then rejects.
- Docs: `docs/SPEC_PIPELINE.md §Model configuration` and `AGENTS.md` (the OpenCode
  Go model table) updated to say "edit your local env file, restart, done — no
  commit".

## Design constraints / open questions

- Env var names must be namespaced (e.g. `SPEC_SPECIFIER_MODEL`, `SPEC_CODER_MODEL`)
  so they can't collide with app-level `.env` vars.
- Decide whether to keep the `{env:...}` defaults inline in `opencode.json` (nice:
  committed file stays readable and self-documenting) or drive the whole agent block
  from the env file.
- Restart is required after a change — config is read once at startup; document
  that, don't fight it.
- Verify the loader works under `opencode run` and in the subagent path, not just in
  an interactive TUI.

## Acceptance criteria

- AC-001: `opencode.json` (or equivalent config) resolves every spec-* agent model
  from an env var, falling back to today's committed value when the var is unset.
- AC-002: committed `.env.example` exists, one var per agent, with comments;
  real file gitignored.
- AC-003: a loader script exports the env file values; running it then `opencode
  debug config` shows the overridden model with no commit.
- AC-004: with no env file present, `opencode debug config` still resolves to the
  committed defaults (no empty-string breakage).
- AC-005: docs updated (`docs/SPEC_PIPELINE.md` + `AGENTS.md`) describing the
  copy-example → fill-values → restart flow.
- AC-006: no hardcoded model value that a developer is meant to change appears
  anywhere except the committed default in `.env.example` / `opencode.json`.
