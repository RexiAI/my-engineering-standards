# Tasks — Per-machine model configuration via env (no commit to switch models)

Formalization of `specs/020-model-config-env/00-informal.md`. Remove the commit
from the model-change loop: `opencode.json` resolves every `spec-*` agent model
from a `{env:SPEC_*_MODEL}` reference; a gitignored `config/model.local.env`
overrides the committed defaults; a loader exports the values into the opencode
process environment before config is read.

One premise of the informal spec did **not** survive grounding against the real
tree and is corrected below (§Grounded reality): **spec-013's implementation
files do not exist in this repo.** `scripts/load-env.sh`, `config/`, and
`config/agent.local.env.example` are absent — only the spec-013 scratch under
`specs/013-agent-local-env/` is present. "Reuse the spec-013 pattern" therefore
means reuse the *approach and behavior contract*, not load an existing file. The
loader, `config/` directory, and gitignore rule are all created fresh here. The
loader is named `scripts/load-model-env.sh` so it cannot collide with spec-013's
spec'd `scripts/load-env.sh` (human decision 2, §Decisions).

## Grounded reality (verified against this repo and the opencode docs by executing the real tree)

### Repo facts the tasks must respect

- **`opencode.json`** (13 lines, repo root): `agent.<name>.model` for exactly 8
  agents — spec-specifier, spec-ux, spec-verifier, spec-mutation-runner,
  spec-pr-opener, spec-coder, spec-refactorer, spec-pipeline. Two distinct
  committed model ids today: `opencode-go/deepseek-v4-flash`
  (specifier/ux/coder/refactorer/pipeline) and `opencode-go/qwen3.7-plus`
  (verifier/mutation-runner/pr-opener).
- **`.gitignore`** (21 lines): ignores `.env`, `.env.local`, `.serena/` — but
  **no `config/` rule**. A rule for `config/model.local.env` must be added
  (Task 3). `config/` does not exist as a directory today; Task 2 creates it.
- **`scripts/load-env.sh` does not exist** in this repo, and neither does any
  `config/*.env*` file (verified via `git ls-files` + glob). The spec-013
  pattern is documented in `specs/013-agent-local-env/` only; it was never
  implemented here. Its loader contract (source real file, export vars, do not
  clobber pre-set vars) is reused as the *shape* for this spec's loader, with a
  deliberate difference: 013 fails loudly when the real file is missing, while
  this loader **falls back to the committed example** — the model defaults must
  apply automatically, so the example *is* the fallback, not an error.
- **`.github/workflows/self-ci.yml`** — one `validate` job (push/PR) with
  `permissions: contents: read` (no secrets). New `*.sh` scripts are covered by
  the existing `bash -n` step and the shellcheck step (`scripts/*.sh` glob,
  `continue-on-error`). New gates need an explicit step. The runner has no
  opencode binary, but the binary **can** be installed in the job: the pinned
  release tarball is downloadable from a public GitHub release URL with no auth
  (verified — see §Resolved mechanism, decision 4), so the `validate` job now
  installs it and runs the runtime verification (Task 6).
- **Script house style** (`scripts/check-scenario-traceability.sh`,
  `scripts/detect-saga-outbox.sh`): `#!/bin/bash`, `set -euo pipefail`, boxed
  header comment with usage + exit codes, colored `fail()`/`pass()` helpers,
  no new dependencies (bash + `grep`/`sed`/`awk`/`mktemp`, all present in the
  self-ci image).

### opencode behavior the tasks must respect (verified by executing this build, v1.18.18)

- **`{env:VAR}` has no default syntax — verified with the real binary.** Docs
  state: "If the environment variable is not set, it will be replaced with an
  empty string." Tested against the repo's own opencode build (1.18.18) with a
  scratch `opencode.json` and `opencode debug config`: `{env:VAR:-default}`,
  `{env:VAR|default}`, and `{env:VAR=default}` **all** resolve to `""` when the
  var is unset (three forms, same empty result). A literal committed fallback
  value cannot be expressed inline in `opencode.json`.
- **No auto-load of env files and no fallback block — verified.** (1) A
  top-level `env` block in `opencode.json` is **not** a config key (absent from
  the published config schema; a test block was silently ignored and the var
  stayed empty). (2) A `.env` file in the project root is **not** auto-loaded
  into the interpolation path (tested: var set in `.env` stayed unset).
  (3) `opencode run` has no `--env-file` flag. (4) The plugin system's
  `shell.env` hook injects vars into tool/user shells only, and plugins load
  *after* config — it cannot fix config-time interpolation. (5) `{file:path}`
  substitution exists but is unconditional — it cannot express "env var, else
  file default".
- **Agent-file `model:` beats `opencode.json` — verified.** A `model:` key in
  `.opencode/agents/*.md` frontmatter silently wins over
  `agent.<name>.model` in `opencode.json` (tested: agent file value resolved,
  JSON value ignored). Therefore the fallback **cannot** live on shipped agent
  copies (`bootstrap.sh --copy-agents` path): a literal `model:` there would
  permanently defeat the `{env:...}` override, and an `{env:...}` reference
  there would have the same no-default problem.
- **Config is read once at process start** from the process environment only.
  The vars must be exported **before** opencode launches. Restart is required
  after any change to the local env file. The subagent/`opencode run` path
  inherits the process environment, so exporting at shell level covers
  `/spec`, `/build`, and subagents — nothing per-agent is needed.
- **Config precedence** (opencode docs): project `opencode.json` is loaded
  *after* global config but *before* `.opencode/agents/`, so
  `agent.<name>.model` in this repo's `opencode.json` remains the effective
  source for shipped agents (which carry no `model:` key). Env interpolation
  happens during that load. No precedence change is required.

### Resolved mechanism (human decision 3 — "add a default", real mechanism, not prose)

Every candidate opencode-native fallback was tested and eliminated (§opencode
behavior above): no default syntax, no `env` block, no `.env` auto-load, no
`--env-file`, no agent-file fallback (would beat the override), no plugin hook
(runs after config). The **only** thing `{env:VAR}` reads is the process
environment at launch. The mechanism is therefore a **documented one-time setup**
that puts the vars into every shell that launches opencode, automatically:

1. **Wire the loader into the shell profile once.** Append
   `source <repo>/scripts/load-model-env.sh` to `~/.bashrc` (or `~/.zshrc`).
   Every interactive shell then auto-exports the 8 `SPEC_*_MODEL` vars — with
   committed defaults when no override file exists — before any opencode
   launch. The loader is **never** sourced per-launch by hand.
2. **Optional per-machine override (only when a dev wants a different model):**
   `cp config/model.local.env.example config/model.local.env`, edit the copy.
   The loader's precedence (env > local file > example) makes the gitignored
   file win. When the file is absent, the committed example carries the
   defaults — so "no env file present → committed defaults" holds in the steady
   state, which is what AC-004 requires (no empty-string breakage).

Boundary, documented honestly: the supported launch path is a shell that has
the profile line (interactive shells, and shells spawned from them — covers the
TUI, `opencode run`, `/spec`, `/build`, subagents). A GUI/daemon-launched
opencode that spawns no interactive shell will not have the vars; the loader's
fail-loudly branch (exit 1, naming the var) surfaces that state instead of
silently shipping empty models.

### Env file name

Chosen and confirmed: **`config/model.local.env`** (+ `.env.example`), the
informal spec's dedicated-name option. `config/agent.local.env` is reserved for
spec-013's secrets and does not exist here yet. Namespaced var names
(`SPEC_*_MODEL`) already prevent collision with app-level `.env` vars.
(Human decision 1.)

## Tasks

### Task 1 — `opencode.json`: model per agent resolved from `{env:SPEC_*_MODEL}`

Replace every hardcoded `agent.<name>.model` value with an env reference. No
literal model id remains in the file.

Var name mapping (agent → env var), one per modelable agent:

| Agent | Env var |
|---|---|
| spec-specifier | `SPEC_SPECIFIER_MODEL` |
| spec-ux | `SPEC_UX_MODEL` |
| spec-verifier | `SPEC_VERIFIER_MODEL` |
| spec-mutation-runner | `SPEC_MUTATION_RUNNER_MODEL` |
| spec-pr-opener | `SPEC_PR_OPENER_MODEL` |
| spec-coder | `SPEC_CODER_MODEL` |
| spec-refactorer | `SPEC_REFACTORER_MODEL` |
| spec-pipeline | `SPEC_PIPELINE_MODEL` |

Acceptance criteria:
- Every one of the 8 agents has exactly one `model` value of the form
  `"{env:SPEC_<AGENT>_MODEL}"` with the var name from the table above — nothing
  else, no literal provider/model id anywhere in `opencode.json`.
- The `agent` block contains no other keys (unchanged from today).
- `opencode.json` remains valid JSON per the existing `$schema` (verified with a
  JSON parse, not just visual inspection).
- No shipped agent file (`.opencode/agents/` symlink target, `agents/*.md`)
  gains a `model:` key — an agent-file model would silently beat this
  `{env:...}` reference (verified precedence).

Scenarios: `20-acceptance/AC-020-01-opencode-env.md`

### Task 2 — `config/model.local.env.example`: committed template, one var per agent, comment per var, committed defaults

Create `config/` and a committed `config/model.local.env.example`.

Acceptance criteria:
- One `SPEC_*_MODEL=<model-id>` line per modelable agent — exactly the 8 vars
  in Task 1's table, no more, no duplicates.
- Each var's value is the **current committed default** for that agent:
  `opencode-go/deepseek-v4-flash` for spec-specifier, spec-ux, spec-coder,
  spec-refactorer, spec-pipeline; `opencode-go/qwen3.7-plus` for spec-verifier,
  spec-mutation-runner, spec-pr-opener.
- A comment line directly above each var explains which agent the var drives
  and that the model is the committed default until overridden locally.
- A header comment block instructs: **one-time setup** — (1) wire
  `source <repo>/scripts/load-model-env.sh` into the shell profile so every
  shell exports these vars automatically, and (2) only if overriding, copy this
  file to `config/model.local.env`, fill in real values, restart opencode
  (config is read once at startup), and never commit the real file.
- The file is tracked by git (`git ls-files --error-unmatch` exits 0).
- No secrets or credentials appear in the file (models are provider ids only).

Scenarios: `20-acceptance/AC-020-02-example-template.md`

### Task 3 — `.gitignore` rule keeping the real file out of every commit

Add a rule so `config/model.local.env` can never be committed.

Acceptance criteria:
- `.gitignore` gains an entry matching `config/model.local.env` such that
  `git check-ignore config/model.local.env` exits 0 **even when the file does
  not exist on disk**.
- The committed `config/model.local.env.example` is **not** ignored — it stays
  trackable (`git check-ignore` on it exits non-zero).

Scenarios: `20-acceptance/AC-020-03-gitignore.md`

### Task 4 — `scripts/load-model-env.sh`: exports every model var with env > local-file > example precedence

Bash-only loader, created fresh (spec-013's same-named loader does not exist in
this repo, so this one is named `load-model-env.sh` — human decision 2). Exports
the 8 `SPEC_*_MODEL` vars so that opencode's `{env:...}` interpolation in
`opencode.json` always sees a non-empty value. This script is the **default
mechanism**: wired into the shell profile once (human decision 3), it runs in
every shell automatically; it is never intended to be sourced per-launch by
hand.

Acceptance criteria:
- For each of the 8 `SPEC_*_MODEL` vars, the resolved value comes from the
  first non-empty source, in this precedence order:
  1. the variable already exported in the process environment (a machine-level
     override survives — never clobbered),
  2. `config/model.local.env` (the gitignored per-machine file) if it exists,
  3. `config/model.local.env.example` (the committed defaults) if it exists.
- After running, all 8 vars are **set and exported** in the calling shell. A
  var missing from the local file (partial file) still resolves to its example
  default; a var present in the local file overrides the example.
- If a var is unset after all three sources (only reachable when the committed
  example is missing or broken), print a loud error to stderr naming the var
  and exit 1.
- Accepts an optional first positional argument: the project root whose
  `config/` directory holds the env files (needed by the selftest and the CI
  runtime check to run against scratch fixtures). Defaults to the repo root,
  derived from the script's own location — so it works from any cwd and when
  sourced through `.standards/scripts/` in a child repo it still resolves the
  standards repo's `config/`.
- Runs **non-interactively**: no prompts, no TTY requirement — works under
  `/spec`, `/build`, and subagent shells that inherit the process env.
- Bash-only, no new dependencies; the fixture-root resolution is documented in
  the header.
- Idempotent: running it twice yields the same exports as running it once.

Scenarios: `20-acceptance/AC-020-04-loader.md`

### Task 5 — `scripts/check-model-env.sh`: static gate proving AC-001 + AC-006 + the fallback source is wired

Standalone bash gate, exit 1 on a violation, enforcing that opencode.json
contains no literal model id, the real env file is never tracked, and the
committed fallback source exists and matches the references. This is the
hermetic, binary-free half of the self-ci coverage (human decision 4).

Acceptance criteria:
- Checks `opencode.json`: every `agent.*.model` value must match the exact
  pattern `{env:SPEC_*_MODEL}` — any literal model id (e.g.
  `opencode-go/deepseek-v4-flash`) anywhere in the file exits 1 and prints the
  offending `agent` name. Exits 0 when all 8 model values are env references.
- Checks `git ls-files`: exits 1 with a message naming the offending path if
  `config/model.local.env` is tracked (a forced-add or a previously-committed
  real file). Exits 0 otherwise.
- **Fallback source wired (new, decision 4):** asserts `config/model.local.env.example`
  exists and defines exactly the 8 `SPEC_*_MODEL` var names, and that the set
  of var names referenced by `opencode.json` equals the set defined by the
  example — a reference with no example default, or an example var with no
  reference, exits 1 naming the mismatch. This proves the default mechanism's
  source exists and is connected without needing the opencode binary.
- Clean repo (all env refs, no tracked real file, example wired): exit 0,
  brief PASS line.
- Model-free, no new dependencies. Works against a scratch repo in `/tmp` when
  the caller points `GIT_DIR`/`--git-dir` at it (so the selftest in Task 6 can
  exercise the tracked-file branch without touching this repo).

Scenarios: `20-acceptance/AC-020-05-check-model-env.md`

### Task 6 — `scripts/model-env.selftest.sh` + `scripts/model-env.runtime-check.sh` wired into self-ci

Two model-free regression nets, both run in the `validate` job:

- `scripts/model-env.selftest.sh` — fixtures in `mktemp -d`, `trap` cleanup;
  proves the loader's precedence and the check script's branches without any
  opencode binary.
- `scripts/model-env.runtime-check.sh` — proves the actual opencode resolution
  end-to-end against a scratch project using a pinned opencode binary. This is
  what makes AC-003/AC-004 CI-verified instead of dev-only (human decision 4).

Acceptance criteria:
- Selftest covers the loader's precedence: process env wins over local file;
  local file wins over example; a partial local file leaves missing vars at
  their example defaults; a var set nowhere (fixture with no example and no
  local and no pre-set value) exits 1 with a message naming the var. All loader
  cases run with the fixture-root argument against scratch dirs.
- Selftest covers the check script: an `opencode.json` fixture with a literal
  model id → exit 1; a fixture with all env references → exit 0; a fixture
  whose example lacks one of the referenced vars → exit 1 naming the mismatch;
  a scratch repo with `config/model.local.env` tracked → exit 1; a scratch repo
  without it tracked → exit 0.
- **Runtime check** runs `opencode debug agent spec-<name>` (JSON output)
  against a scratch project outside the repo checkout, with a fixture
  `opencode.json` (8 agents, `{env:SPEC_*_MODEL}` refs) and a fixture example
  file, in three cases, each in a subshell with all 8 vars unset first so the
  result is independent of the invoking environment:
  1. loader sourced with no local file → every agent's resolved model equals
     the fixture example default, none null/empty;
  2. loader sourced with a local file overriding one var and a pre-set env var
     overriding another → override values win, remaining agents stay at
     defaults;
  3. loader **not** sourced → `opencode debug agent` resolves the model to
     null/empty, proving the loader is what carries the defaults (regression:
     a broken or removed loader fails the job).
- **Self-trip constraint**: fixture model ids must be constructed at runtime
  (string concatenation, e.g. `"opencode-go/""${RANDOM}"` or a name built in
  the fixture dir) so the fixtures do not themselves trip the check or any
  hardcoded-secret-style scan. No inline literal model-id fixture values.
- `.github/workflows/self-ci.yml` `validate` job gains a step that downloads
  the **pinned** opencode release tarball from the public GitHub release URL
  (`https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz`,
  verified: extracts to a standalone `opencode` binary, `--version` reports
  `1.18.18`, and it resolves `{env:...}` refs identically to the local install)
  and then runs `bash scripts/check-model-env.sh`,
  `bash scripts/model-env.selftest.sh`, and
  `bash scripts/model-env.runtime-check.sh /tmp/opencode` in a single `run:`
  block or adjacent steps, **no `continue-on-error`** — a regression fails the
  job. No `GITHUB_TOKEN`, no secrets: the asset URL is public and unauthenticated.
  Existing `bash -n` and shellcheck steps pick up the new scripts unchanged.

Scenarios: `20-acceptance/AC-020-06-selftest-selfci.md`

### Task 7 — Docs: `docs/SPEC_PIPELINE.md §Model configuration` and `AGENTS.md`

Update both docs to the one-time-setup flow (profile wiring + optional
override file + restart), replacing the "edit opencode.json and commit" framing.

Acceptance criteria:
- `docs/SPEC_PIPELINE.md` `§Model configuration` (current lines ~199-243)
  gains a subsection describing the mechanism: **one-time setup** — add
  `source <repo>/scripts/load-model-env.sh` to the shell profile once (every
  shell then exports the model vars automatically; the loader is never sourced
  per-launch by hand), optionally `cp config/model.local.env.example
  config/model.local.env` + fill in model ids to override → restart opencode →
  done, **no commit, no PR**. States that config is read once at startup so a
  restart is required after any change.
- The subsection states the precedence: a pre-existing exported var wins; the
  gitignored local file wins when present; committed defaults (example) apply
  when the var is unset. States that the profile wiring is what prevents the
  empty-string failure (`{env:VAR}` with an unset var resolves to empty — no
  default syntax exists in this opencode build).
- The subsection documents the boundary honestly: the supported path is
  shell-launched opencode (interactive shells, `opencode run`, `/spec`,
  `/build`, subagents inherit the process env); a GUI/daemon launch that spawns
  no interactive shell will not have the vars, and the loader's fail-loudly
  branch (exit 1 naming the var) surfaces that state.
- `AGENTS.md` (the "OpenCode Go Model Configuration" section, current lines
  ~49-70) model table gains a note that the per-machine values come from
  `config/model.local.env` via `scripts/load-model-env.sh`, and that switching
  a model means editing the local file + restart, not committing.
- Both docs mention `scripts/check-model-env.sh` as the structural enforcement
  of "no literal model id in opencode.json" and "real file never tracked", and
  that self-ci additionally runs a pinned opencode binary to verify the
  resolution behavior.

Scenarios: `20-acceptance/AC-020-07-docs.md`

## Acceptance criteria mapping

| Informal AC | Task(s) | Scenario file |
|---|---|---|
| AC-001 every spec-* agent model resolves from an env var, falls back to committed value when unset | 1 + 4 (fallback) + 5 (gate) | `AC-020-01-opencode-env.md`, `AC-020-04-loader.md`, `AC-020-05-check-model-env.md` |
| AC-002 committed `.env.example` one var per agent with comments; real file gitignored | 2 + 3 | `AC-020-02-example-template.md`, `AC-020-03-gitignore.md` |
| AC-003 loader exports values; loader + `opencode debug config` shows overridden model with no commit | 4 + 1 + 6 (runtime check) | `AC-020-04-loader.md`, `AC-020-01-opencode-env.md`, `AC-020-06-selftest-selfci.md` |
| AC-004 no env file → config still resolves to committed defaults (no empty-string breakage) | 4 (example fallback) + 6 (runtime check, cases 1 + 3) | `AC-020-04-loader.md`, `AC-020-06-selftest-selfci.md`, `AC-020-01-opencode-env.md` |
| AC-005 docs updated with copy → fill → restart flow | 7 | `AC-020-07-docs.md` |
| AC-006 no hardcoded model value a dev is meant to change outside `.env.example` / `opencode.json` | 5 + 6 | `AC-020-05-check-model-env.md`, `AC-020-06-selftest-selfci.md` |

## Decisions (human-confirmed; all questions resolved — no open questions remain)

1. **Env file name — RESOLVED (human: OK, keep as chosen).**
   `config/model.local.env` (+ `.env.example`) confirmed over plain `.env` and
   over reusing `config/agent.local.env`. `.env` is already gitignored but
   would clash with app-level env files; `config/agent.local.env` is spec-013's
   secrets file. The dedicated name keeps model preferences separate from
   secrets. No change.
2. **Loader name — RESOLVED (human: option (b)).** The loader is
   `scripts/load-model-env.sh`, NOT `scripts/load-env.sh`. Spec-013's spec'd
   `scripts/load-env.sh` is not implemented in this repo, but if it ever is,
   the two loaders would conflict (013 sources `config/agent.local.env` for
   secrets; this one sources `config/model.local.env` for models). Dedicated
   names avoid the collision. Every reference in this file and in
   `20-acceptance/` uses `scripts/load-model-env.sh`.
3. **Empty-string boundary — RESOLVED (human: add a default, real mechanism).**
   Do not accept "document that the loader must be sourced". The mechanism is
   the **one-time setup** in §Resolved mechanism: the loader is wired into the
   shell profile once and auto-exports env > local file > example defaults in
   every shell, so `opencode debug config`/model resolution always sees a
   non-empty value in the steady state — no per-launch manual sourcing, and
   with no env file present the committed example carries the defaults. All
   opencode-native fallback candidates were tested and eliminated (no default
   syntax in `{env:}` — `:-`, `|`, `=` forms all resolve empty; no `env`
   config block; no `.env` auto-load; no `--env-file`; agent-file `model:`
   would beat the override; plugin hooks run after config). If the profile line
   has not been added, the loader's fail-loudly branch (exit 1 naming the var)
   surfaces the state rather than shipping empty models.
4. **Self-ci verification — RESOLVED (human: find a solution, make CI verify).**
   Two layers: (a) hermetic structural checks in `scripts/check-model-env.sh`
   (Task 5) asserting the `{env:SPEC_*_MODEL}` references **and** that the
   fallback example exists and is wired to the references — no binary needed;
   (b) the `validate` job installs the **pinned** opencode binary
   (`v1.18.18`, public GitHub release URL, unauthenticated, verified
   download + run) and executes `scripts/model-env.runtime-check.sh`, which
   runs `opencode debug agent` against a scratch project in three cases
   (defaults via loader, overrides win, loader-absent → empty), so AC-003/AC-004
   are verified in self-ci, not just in the dev environment. The dev-environment
   `opencode debug config` scenarios in AC-020-01 remain as the real-repo
   acceptance for the Coder/Verifier.
5. **Inline-default option — RESOLVED (human: OK).** "Keep `{env:...}` defaults
   inline in `opencode.json`" cannot be expressed — `{env:VAR}` has no default
   syntax, and an unset var resolves to empty (verified with the real binary).
   Defaults live only in `config/model.local.env.example`, sourced by the
   loader as the fallback. Confirmed as intended; no change.
