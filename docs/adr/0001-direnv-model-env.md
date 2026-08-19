# Use direnv for per-machine spec-pipeline model config and credentials

## Status

Proposed

## Context

The spec-pipeline agents resolve every `agent.*.model` from an
`{env:SPEC_*_MODEL}` reference in `opencode.json`; the 8 vars are carried by
`scripts/load-model-env.sh` (committed defaults in `config/model.local.env.example`,
gitignored per-machine override in `config/model.local.env`). Agent credentials
(`GITHUB_TOKEN`, `GH_TOKEN`) live in the gitignored `config/agent.local.env` and
are loaded by `scripts/load-env.sh`.

Both loaders were sourced from the shell profile (`~/.bashrc`/`~/.zshrc`) — a
machine-global wiring that (a) applies to every shell whether or not it is in a
repo that needs the vars, and (b) has no notion of a repo hierarchy. Child repos
consume this repo as a `.standards/` git submodule; each had to reproduce the
same global profile wiring by hand.

We want per-directory, automatic loading (direnv), and a clean default: a child
repo uses the parent standards repo's committed model config by default, with a
per-child, per-machine override. Per-governance, changing the model-assignment
mechanism requires an ADR.

## Decision

Adopt direnv as the loader trigger. A committed `.envrc` at the standards repo
root runs both existing loaders in `--emit` mode — a new loader mode that
prints `export VAR=value` lines to stdout instead of exporting in-place — and
`eval`s the output. The loaders already derive their repo root from their own
location:

```bash
# .envrc (standards repo root)
eval "$(bash scripts/load-model-env.sh --emit)"
eval "$(bash scripts/load-env.sh --emit)"
```

`--emit` exists because sourcing the loaders inside direnv is unsafe: their
"leave no trace" `unset` cleanup collides with direnv's function-wrapped shell
state (bash `pop_var_context` errors and mid-run variable loss). Running the
loader in a clean subshell (command substitution) and `eval`-ing its output
keeps the loader as the single resolution engine for both trigger mechanisms
(profile sourcing and direnv) while avoiding the collision.

Child repos get `templates/.envrc.child` (copied by `scripts/bootstrap.sh`),
which runs the submodule loader for the parent's committed defaults, then
applies per-child, per-machine overrides via direnv's `dotenv_if_exists`:

```bash
# .envrc (child repo root)
eval "$(bash .standards/scripts/load-model-env.sh --emit)"
dotenv_if_exists config/model.local.env
dotenv_if_exists config/agent.local.env
```

Precedence is unchanged from the shell-profile mechanism: per var, an
already-exported env var > `config/model.local.env` > the committed
`config/model.local.env.example` defaults. The loaders keep their no-clobber
behavior and fail-loudly branch.

Two properties are explicit:

- **The `.standards/` submodule never carries gitignored files.** A parent's
  `config/model.local.env` / `config/agent.local.env` are not in the committed
  tree and therefore not in the submodule checkout. "Default to the parent"
  therefore means the parent's **committed defaults** — which is correct; a
  per-machine override on one machine should not propagate to children.
- **Children load their own credentials.** A child's agent creds come from its
  own gitignored `config/agent.local.env` via `dotenv_if_exists` (the submodule
  loader would fail loudly there because the submodule has the `.example` but
  not the real file).

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep shell-profile sourcing (status quo) | No new dependency; precedence proven | Machine-global, not per-repo; no parent/child default model; manual per-child wiring |
| Native direnv `dotenv`/`source_env` instead of the loaders | More idiomatic direnv | `dotenv`/`source_env` relative-path resolution across the submodule boundary is unverified; direnv clobbers shell vars, changing the no-clobber precedence; abandons the tested loaders |
| Sourcing the loaders directly in `.envrc` | No loader change | **Tested and rejected** — the loaders' `unset` cleanup collides with direnv's shell state (`pop_var_context`, vars lost) |
| Global ancestor `.envrc` (e.g. `~/` ) for machine defaults | Single machine-wide source | Does not express "child defaults to the parent standards repo"; direnv loads it for every directory, defeating the per-repo intent |

## Consequences

- Every machine that runs the pipeline needs direnv installed with its shell
  hook wired, and `direnv allow` per repo. This replaces the one-time `source
  scripts/load-*.sh` profile lines.
- `.envrc` files are **committed** (they are the default wiring); per-machine
  overrides stay in the gitignored `config/*.env` files, so secret/override
  hygiene is unchanged.
- The supported launch boundary is unchanged: opencode must launch from a
  direnv-loaded shell (a GUI/daemon-launched opencode still lacks the vars and
  fails loudly, not silently).
- No model ids, `opencode.json`, or `AGENTS.md` model-table values change; the
  same-commit rule is unaffected.

## Compliance

- `scripts/check-model-env.sh` continues to enforce: no literal model id in
  `opencode.json`, `config/model.local.env` never tracked, and the committed
  example wired with exactly the 8 referenced vars.
- Self-ci `scripts/model-env.selftest.sh` and the pinned-opencode
  `scripts/model-env.runtime-check.sh` continue to verify loader resolution
  (defaults, overrides win, loader-absent → empty). Both source the loaders
  (not `--emit`), whose resolution behavior is unchanged; `--emit` is additive
  and covered by live `direnv exec` verification during adoption.
- direnv is self-enforcing per directory: without `direnv allow` the vars are
  unset and `{env:VAR}` resolves empty, surfacing via the loader's fail-loudly
  branch rather than silently. `direnv status`/`direnv allow` is the manual
  verification for the `.envrc` layer.
- `scripts/bootstrap.sh` copies `templates/.envrc.child` into child repos and
  writes the child `config/.gitignore` for the two per-machine env files.

## Notes

- 2026-08-19: Decision recorded (Proposed).
