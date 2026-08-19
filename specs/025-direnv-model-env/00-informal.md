# Spec 025 — direnv for spec-pipeline model config and credentials

## What

Replace the shell-profile + loader mechanism that supplies the spec-pipeline
model configuration and agent credentials with a pure direnv (`.envrc`) design.

Today `load-model-env.sh` (8 `SPEC_*_MODEL` vars) and `load-env.sh`
(`GITHUB_TOKEN`, `GH_TOKEN`) are sourced from `~/.bashrc` machine-globally. We
want:

1. Per-directory, automatic loading via direnv.
2. `.envrc` is **per-machine and gitignored** — it is the per-project editable
   surface, and it may hold secrets. Never committed.
3. A committed template (`.envrc.example`) that users copy; the default values
   live in committed files so a child repo defaults to the parent's config.
4. Child repos (this repo as a `.standards/` submodule) default to the parent's
   **committed** model defaults, overridable per child, per-machine.
5. No loaders: direnv `dotenv_if_exists` replaces `load-env.sh` and
   `load-model-env.sh` entirely.

## Key mechanics

- **Committed defaults**: `config/model.local.env.example` carries the 8
  `SPEC_*_MODEL` committed defaults (the sole source of truth; travels via the
  submodule). `config/agent.local.env.example` is a committed template naming
  `GITHUB_TOKEN` / `GH_TOKEN`. Neither contains secrets.
- **Parent `.envrc`** (gitignored, copied from `templates/.envrc.example`):
  ```bash
  dotenv_if_exists config/model.local.env.example   # committed defaults
  dotenv_if_exists config/model.local.env            # per-machine override
  dotenv_if_exists config/agent.local.env            # per-machine credentials
  ```
- **Child `.envrc`** (gitignored, written by `scripts/bootstrap.sh`):
  ```bash
  dotenv_if_exists .standards/config/model.local.env.example   # parent committed defaults
  dotenv_if_exists config/model.local.env                       # child override
  dotenv_if_exists config/agent.local.env                       # child credentials
  ```
- **The `.standards/` submodule never carries gitignored files**, so a parent's
  per-machine override does not propagate to children — intended. "Default to
  the parent" means the parent's committed `config/model.local.env.example`.
- **Precedence**: later `dotenv_if_exists` wins, so a child's
  `config/model.local.env` beats the parent defaults, and credentials load last.
  A `dotenv` line **clobbers** a pre-exported shell var — accepted and
  documented (the `.envrc` is the per-directory source of truth).
- **Empty-var safety**: `{env:SPEC_*_MODEL}` resolves empty when unset, so the
  committed example is loaded first to guarantee non-empty values; the
  structural gate guarantees the example defines exactly the referenced vars.

## Removed machinery

- `scripts/load-env.sh` and `scripts/load-model-env.sh` (and their `--emit`
  mode) — replaced by `dotenv_if_exists`.
- The loader-focused test cases in `scripts/model-env.selftest.sh` and
  `scripts/model-env.runtime-check.sh` — reworked or dropped.

## Kept

- `scripts/check-model-env.sh` — structural gate: no literal model id in
  `opencode.json`, real env files (`config/model.local.env`,
  `config/agent.local.env`) never tracked, committed example wired with exactly
  the referenced vars. Now the primary enforcement.
- Governance constraint: the committed example stays trackable; gitignored
  files hold secrets.

## Not in scope

- No model-id values, `opencode.json`, or the `AGENTS.md` model table change.
- Reworks the mechanism from spec 020 (`model-config-env`); committed defaults
  and governance constraints are unchanged.

## Definition of done

- A shell that `cd`'s into the standards repo or a child repo has the model
  vars and credentials loaded by direnv (after `direnv allow`); `.envrc` is
  gitignored and never committed.
- A child repo with no override resolves to the parent's committed model
  defaults (differentiated per-stage).
- A child override wins; the parent's other defaults stay.
- `load-env.sh` and `load-model-env.sh` are gone; nothing references them.
- `scripts/check-model-env.sh` passes; `model-env.selftest.sh` and
  `model-env.runtime-check.sh` are updated to the dotenv design and pass.
- Governance: an ADR records the decision.
