# Architecture Decision Record (ADR)

## Title

Pure direnv dotenv for spec-pipeline model configuration and credentials

## Status

Accepted

## Context

The spec pipeline's agents resolve their model from `{env:SPEC_*_MODEL}`
references in `opencode.json` and consume two GitHub credentials
(`GITHUB_TOKEN`, `GH_TOKEN`) per machine. These values are per-machine and must
never be committed, yet the earlier mechanism was loader-based: a committed
repo-root `.envrc` that evaluated `scripts/load-model-env.sh --emit` /
`scripts/load-env.sh --emit`, with the `.envrc` tracked by git. That design had
two structural weaknesses: the `.envrc` itself was committed (so per-machine
wiring and provenance were conflated with the repo's own history), and the
loaders implemented a first-non-empty precedence that a plain dotenv cannot
express. Spec 020 introduced the loader-based design; this decision replaces
it. The environment arrives in the shell via direnv, and the committed surface
is templates, not a live `.envrc`.

## Decision

Use **pure direnv dotenv** as the per-machine model/credential mechanism:

- The repo-root `.envrc` is **per-machine and gitignored**, copied from the
  committed `templates/.envrc.example`. `templates/.envrc.child` is the
  corresponding template for child repos consuming this repo as a
  `.standards/` submodule. Templates are the only committed `.envrc` surface.
- Each template's executable lines are exactly three `dotenv_if_exists` lines,
  loaded in order:
  1. the committed defaults example (`config/model.local.env.example`, or
     `.standards/config/model.local.env.example` in a child),
  2. the gitignored per-machine override (`config/model.local.env`),
  3. the gitignored per-machine credentials (`config/agent.local.env`).
- There are **no loaders and no `--emit`** — `scripts/load-env.sh` and
  `scripts/load-model-env.sh` are deleted, and every live reference to them is
  purged. The PR Opener's defensive credential step becomes a presence check
  (`$GITHUB_TOKEN` / `$GH_TOKEN` non-empty or stop).
- **Precedence is later-lines-win**: a `dotenv_if_exists` line clobbers any
  pre-existing value, pre-exported shell vars included. The `.envrc` is the
  per-directory source of truth. The example loads first so all 8
  `SPEC_*_MODEL` vars are non-empty when opencode launches (`{env:VAR}`
  resolves empty when unset; this opencode build has no default syntax).
- **Parent/child inheritance**: a child defaults to the parent's committed
  defaults via `.standards/config/model.local.env.example`; the submodule
  never carries gitignored files, so a parent's per-machine override never
  propagates; the child's own override wins.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| shell-profile status quo (source a script from `~/.bashrc`) | No new tool; works with any shell | Env state is invisible and machine-global; no per-directory scoping; every shell pays the cost; precedence and provenance are implicit |
| Loader + `--emit` design (the design this decision replaces) | Explicit export order; first-non-empty precedence; fail-loudly branch | The `.envrc` was committed, conflating per-machine state with repo history; two loaders to maintain; `--emit` machinery; precedence semantics that plain dotenv could not express and that clobber-based reasoning could not explain |
| Pure direnv `dotenv_if_exists` (chosen) | Per-directory source of truth; committed surface is templates only; later-wins precedence is simple and documented; child repos inherit parent committed defaults for free | Requires direnv installed and its hook wired once per machine; GUI/daemon-launched opencode resolves empty models instead of failing loudly |

## Consequences

- Per-machine wiring becomes local and disposable: delete `.envrc` /
  `config/model.local.env` / `config/agent.local.env` to reset; nothing about
  a machine's model choices or credentials ever enters git history.
- The launch boundary is narrower and documented: opencode must launch from a
  direnv-loaded shell; GUI/daemon launches surface as empty model resolution.
- Credentials loading is uniform with model loading (the third dotenv line),
  so `scripts/guard-env.sh` and `scripts/check-model-env.sh`'s untracked-file
  checks cover both real env files.
- Children get the same mechanism from `scripts/bootstrap.sh`, which owns
  writing the child `.envrc`, appending `.envrc` to the child root
  `.gitignore`, and writing/keeping the child `config/.gitignore`.

## Compliance

- `scripts/check-model-env.sh` — structural gate: no literal model id in
  `opencode.json`, neither real env file tracked, example wired to the
  references.
- `scripts/model-env.selftest.sh` — hermetic regressions emulating
  `dotenv_if_exists` (no direnv binary needed), covering template shape,
  parent/child precedence, clobber, credentials, gitignore, purge invariants,
  docs, and self-ci wiring; direnv-requiring cases skip with a PASS-noted
  status when the binary is absent.
- `scripts/model-env.runtime-check.sh` — proves real `{env:SPEC_*_MODEL}`
  resolution with a pinned opencode binary in three cases.
- All three run in the self-ci `validate` job with no `continue-on-error`.

## Notes

- 2026-08-19: Decision recorded (spec 025; replaces the loader-based design
  from spec 020).