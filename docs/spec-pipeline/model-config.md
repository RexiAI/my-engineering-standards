# Model configuration and PR review wiring (shared)

Shared reference. Read it from the stage file that names it; the index is
`docs/SPEC_PIPELINE.md`.

## Model configuration

Shipped agents (`agents/spec-*.md`) intentionally ship **without** a `model:` key.
Per opencode's documented config precedence, `.opencode/agents/` (where these land
via the submodule symlink) is loaded *after* your project's `opencode.json` — so if
a shipped agent file pinned a model, your `opencode.json` could not override it. Only
by leaving `model:` unset does `agent.<name>.model` in your own `opencode.json` take
effect. Verified directly against `opencode debug config` (not assumed from the
docs): a `.md` with no `model:` resolves to whatever `opencode.json` sets; a `.md`
that does pin `model:` silently wins over `opencode.json` every time.

With nothing configured, each subagent inherits the model of whichever primary
agent invoked it — no vendor coupling, works with any provider you already use.

Per-stage differentiation works through a **per-machine direnv mechanism** — no
editing and committing `opencode.json` is involved. `opencode.json` (repo root)
resolves every `agent.<name>.model` from an `{env:SPEC_*_MODEL}` reference, and
the committed `config/model.local.env.example` carries placeholder defaults that
you override per machine. The
reasoning behind the default split (Specifier, UX Designer, Verifier, and
Architect do the pipeline's highest-judgment work — detecting ambiguity,
inferring design direction from a brief, adversarially checking prior stages'
claims, and reasoning about surviving mutants — while Coder, Refactorer, and
the orchestrator do more bounded, well-specified work; a weak Verifier is worse
than none) is encoded as placeholder defaults in `config/model.local.env.example`,
not as literals in `opencode.json`.

### One-time setup (per machine)

0. **Start the optional local judgment backend** (step 0; optional but
   recommended where a GPU is available): `make judgment-up`. It serves the
   opt-in typed-judgment fast-path described in
   `docs/spec-pipeline/typed-judgment.md §Typed-judgment layer`; skip it
   freely on machines without the backend, every consumer falls back to its
   stock procedure. Token caveat, measured: judgment classification calls are
   negligible next to this machine's ~95% cache-read token spend, so the local
   backend is a reliability and cost-hygiene feature, not the main token
   lever.

1. **Install direnv and wire the hook once** so every shell loads the env
   automatically before opencode launches:

   ```bash
   eval "$(direnv hook bash)"   # or your shell's hook (zsh, fish, …)
   ```

2. **Copy the parent `.envrc` template and allow it:**

   ```bash
   cp templates/.envrc.example .envrc
   direnv allow
   ```

   The repo-root `.envrc` is **per-machine and gitignored** — never committed.
   It is the only committed-adjacent wiring: the committed surface is the
   template (`templates/.envrc.example`), and it loads, in order via
   `dotenv_if_exists`:

   | Line | File | Role |
   |---|---|---|
   | 1 | `config/model.local.env.example` | placeholder defaults for the 10 `SPEC_*_MODEL` vars |
   | 2 | `config/model.local.env` | gitignored per-machine override |
   | 3 | `config/agent.local.env` | gitignored per-machine credentials (`GITHUB_TOKEN`, `GH_TOKEN`) |

3. **Only if you want to override a model** (otherwise skip this entirely):

   ```bash
   cp config/model.local.env.example config/model.local.env
   # edit config/model.local.env, fill in the model ids you want
   ```

   Then **restart opencode** — config is read once at startup, so a restart is
   required after any change. **No commit, no PR** — `config/model.local.env`
   is gitignored and can never be committed.

**Child repos** (this repo consumed as a `.standards/` submodule) get the same
shape from `scripts/bootstrap.sh`: it copies `templates/.envrc.child` to the
child's root `.envrc` when absent (and appends `.envrc` to the child's root
`.gitignore`), and writes/keeps a child `config/.gitignore` covering
`model.local.env` and `agent.local.env`. The child template's first
`dotenv_if_exists` line points at
`.standards/config/model.local.env.example` — the **parent's committed**
defaults. The submodule never carries gitignored files, so a parent's
per-machine override never propagates to children; a child's own
`config/model.local.env` override wins over the parent defaults.

**Precedence** (per var): later `dotenv_if_exists` lines win. A dotenv line
**clobbers** any pre-existing value — pre-exported shell vars included. This is
accepted and documented: the `.envrc` is the per-directory source of truth.
The example loads first, which is what prevents the empty-string failure:
`{env:VAR}` with an unset var resolves to empty — this opencode build has
**no default syntax** (`{env:VAR:-default}`, `{env:VAR|default}`, and
`{env:VAR=default}` all resolve to `""` when unset) — so the defaults must
arrive via the first dotenv line.

**Boundary, honestly documented**: the supported launch path is a shell loaded
by direnv — interactive shells, and shells spawned from them (`opencode run`,
`/spec`, `/build`, subagents), all inherit the loaded vars. A GUI or
daemon-launched opencode that spawns no direnv-loaded shell will resolve the
`{env:SPEC_*_MODEL}` references to empty — surfaced as empty model resolution,
not a loud failure.

**Structural enforcement**: `scripts/check-model-env.sh` is the gate — every
`agent.*.model` in the `agent` block must be an `{env:SPEC_*_MODEL}` reference
(no literal model id anywhere outside provider blocks; every agent — the
standalone reviewer included — resolves through the `{env:SPEC_*_MODEL}`
roster, see `§PR review model wiring` below), `config/model.local.env`
and `config/agent.local.env` must never be tracked by git, and the example must
define exactly the referenced vars. Self-ci additionally runs
`scripts/model-env.selftest.sh` (hermetic dotenv-emulation regressions) and
downloads a pinned opencode binary to run `scripts/model-env.runtime-check.sh`
against a scratch project, verifying the actual resolution behavior in three
cases (example loaded → defaults; file override + untouched pre-exported var;
nothing loaded → empty).

If you need to customize an agent's prompt or permissions, not just its model, run
`./scripts/bootstrap.sh --copy-agents` (or `make init-ai COPY_AGENTS=1`) to get real,
editable files in `.opencode/agents/` and `.opencode/commands/` instead of a
symlink. You own the copies after that — re-run with the same flag after a
submodule update to pull in changes; it will not overwrite or merge your edits.

### Consumer-side agent catalogs stay unpinned too

The no-`model:` rule covers every agent definition this repo ships **and** the
consumer-side catalogs those agents get copied into (global
`~/.config/opencode/agent/`, ECC-style installs). A frontmatter pin in a local
catalog silently wins over the consumer's `opencode.json` roster and
hard-couples every run to one vendor: on 2026-10-15 a catalog of 27 pinned
agents (`github-copilot/*`, `ollama/*`) broke every pinned-agent invocation on
a provider that does not serve those ids (`Model not found`), while unpinned
agents ran fine. Strip `model:` lines from catalog copies; the resolution order
is the consumer `opencode.json` `{env:SPEC_*_MODEL}` roster, then harness
inheritance. `scripts/check-agent-models.sh` enforces the repo surface in
self-ci (ADR 0011) and doubles as the audit tool for any catalog you install:
`check-agent-models.sh <catalog-root>`.

## PR review model wiring

No agent pins a model in tracked files (ADR 0003). The spec-pipeline agents
resolve `{env:SPEC_*_MODEL}` references via `§Model configuration`; the
standalone PR-review agent gets its runtime model per repo instead:

- **Provider config** — `opencode.json` may carry provider blocks (base URL,
  auth env var, available models). This repo ships one for DeepSeek official
  (`https://api.deepseek.com/v1`, `DEEPSEEK_API_KEY`) at the end of the file;
  other providers are each machine's/repo's own configuration (ADR 0023).
- **Model selection** — the shared review workflow defaults to
  `deepseek/deepseek-flash`, overridable with the `PR_REVIEW_MODEL` repository
  variable. Its default key is the `DEEPSEEK_API_KEY` secret; an explicit
  non-DeepSeek override uses `OPENCODE_API_KEY`. The review skips cleanly
  (green CI, no review) when both keys are unset or the provider rejects the
  credential.

**PR review agent model**: `agents/pr-review.md` (the PR review agent,
spec 024) ships without a `model:` key, same as every other agent. Its model
resolves through `{env:SPEC_PR_REVIEW_MODEL}` in `opencode.json`, with the
committed `deepseek/deepseek-flash` default in
`config/model.local.env.example` and an optional per-repo `PR_REVIEW_MODEL`
override in the shared workflow. The agent's scope
lock, permissions, secret handling, and cost bounds are documented in
`docs/CI_CD.md §PR Review Agent`, the authoritative reference for wiring it
into child repos (`init-ci.sh --with-pr-review`).

## Mechanical-stage model and effort guidance

Four pipeline seats do bounded, well-specified work: `spec-deployer`,
`spec-pr-opener`, `spec-mutation-runner`, and the `spec-pipeline` orchestrator
(driving `/spec` and `/build`). They are worth right-sizing separately from the
seats that carry judgment — the Specifier's ambiguity detection, the UX
Designer's design read, the Verifier's adversarial re-check, and the standalone
PR review agent's diff read.

| Stage | Work shape | Capability class | Preferred effort |
|---|---|---|---|
| `spec-deployer` | deterministic waits for the Vercel preview deployment, one HTTP health check, record assembly into `40-deploy.md` | smallest model that reliably follows a multi-step procedure | `low` |
| `spec-pr-opener` | git and gh invocations, one conventional commit per task, the archive move, PR body assembly | smallest model that reliably follows a multi-step procedure | `low` |
| `spec-mutation-runner` | mutation-tool runs, survivor triage, one targeted test per reachable survivor, `30-report.md` assembly | smallest model that reliably follows a multi-step procedure, with enough reasoning for survivor triage | `medium` |
| `spec-pipeline` (orchestrator) | queue dispatch, stage sequencing, gate routing, decision recording | smallest model that reliably follows a multi-step procedure | `low` |

### Where `effort` actually lives

`effort: xhigh` is set on the **provider model** options in `opencode.json`
(provider `models.<id>.options`), so it applies to every stage that resolves to
those model ids — not to "mechanical stages" as a class. The committed
`config/model.local.env.example` sets model ids only and contains no `effort`
key at all, so effort cannot be narrowed per stage from it.

### The verified per-agent lever

Per-agent effort is expressible at the config layer. On `opencode v2.2.5`,
against a throwaway project config, `opencode debug config` resolves
`agent.<name>.options: { "effort": "<level>" }` into
`agent.<name>.request.body.effort`, while an agent without `options` resolves to
no `request.body` key at all. A per-stage effort seat is therefore possible per
machine; it is not a shipped default (see the decision below).

### Decision: documented, not shipped

Shipped defaults stay byte-identical — no `effort` or model id is added to
`opencode.json` or to the committed example. A tracked per-stage model id is
vendor coupling that a child repo inherits without choosing it, and the
provider-level `effort` cannot be narrowed per stage from the committed example.
The supported route is per machine: put a real `<provider>/<model-id>` for the
stage in `config/model.local.env`, restart opencode (config is read once at
startup), and commit nothing. That per-machine file is gitignored by design, so
the lever never lands in a repository.
