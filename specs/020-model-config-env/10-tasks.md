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
loader, `config/` directory, and gitignore rule are all created fresh here.

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
  implemented here. Its loader contract (source real file, export vars, fail
  loudly when real missing + example present, no-op when both missing, do not
  clobber pre-set vars) is reused as the *shape* for this spec's loader.
- **`.github/workflows/self-ci.yml`** — one `validate` job (push/PR) with
  `permissions: contents: read` (no secrets). New `*.sh` scripts are covered by
  the existing `bash -n` step and the shellcheck step (`scripts/*.sh` glob,
  `continue-on-error`). New gates need an explicit step. No `opencode` binary
  on the `ubuntu-latest` runner — scenarios that invoke `opencode debug config`
  cannot run in self-ci; they are verified by the Coder/Verifier in the dev
  environment (where opencode exists). Self-ci coverage of the behavior is via
  `scripts/model-env.selftest.sh` (Task 6), which needs no opencode.
- **Script house style** (`scripts/check-scenario-traceability.sh`,
  `scripts/detect-saga-outbox.sh`): `#!/bin/bash`, `set -euo pipefail`, boxed
  header comment with usage + exit codes, colored `fail()`/`pass()` helpers,
  no new dependencies (bash + `grep`/`sed`/`awk`/`mktemp`, all present in the
  self-ci image).

### opencode behavior the tasks must respect (from opencode docs + verified context)

- **`{env:VAR}` has no default syntax.** opencode docs: "If the environment
  variable is not set, it will be replaced with an empty string." Verified: the
  syntax works for the `model` field when the var is exported in the process
  environment. Therefore a literal committed default cannot be kept inline in
  `opencode.json` as a fallback *value* — one JSON string cannot express "env
  var, else this literal". The fallback must live in the loader: when the local
  env file is absent, the loader exports the committed defaults (from the
  committed `.env.example`). This is the mechanism that makes AC-004
  (no empty-string breakage) true.
- **Config is read once at process start.** The loader must have exported the
  vars into the opencode process environment *before* opencode launches — a
  restart is required after any change to the local env file, and the loader
  must be sourced in the shell that launches opencode (or a shell profile). The
  subagent/`opencode run` path inherits the process environment, so sourcing at
  launch covers `/spec`, `/build`, and subagents — nothing per-agent is needed.
- **Config precedence** (opencode docs): project `opencode.json` is loaded
  *after* global config but *before* `.opencode/agents/`, so
  `agent.<name>.model` in this repo's `opencode.json` remains the effective
  source for shipped agents (which carry no `model:` key). Env interpolation
  happens during that load. No precedence change is required.

### Decision on the informal spec's open design question

The informal spec asks: keep `{env:...}` defaults inline in `opencode.json`, or
drive the whole agent block from the env file? **Resolution chosen here: env
references in `opencode.json`, defaults carried by the committed
`config/model.local.env.example`.** Rationale: `{env:}` has no default syntax
(above), so "inline literal fallback" is impossible; and `"model":
"{env:SPEC_X_MODEL}"` keeps `opencode.json` readable and self-documenting,
satisfying AC-001 + AC-006 with the example file as the single place committed
default values live. Confirm at §Open questions.

### Env file name

Chosen: **`config/model.local.env`** (+ `.env.example`), the informal spec's
dedicated-name option. `config/agent.local.env` is reserved for spec-013's
secrets and does not exist here yet. Namespaced var names
(`SPEC_*_MODEL`) already prevent collision with app-level `.env` vars.

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
- A header comment block instructs: copy the file to `config/model.local.env`,
  fill in real values, restart opencode (config is read once at startup), and
  never commit the real file.
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

### Task 4 — `scripts/load-env.sh`: exports every model var with env > local-file > example precedence

Bash-only loader, created fresh (spec-013's same-named loader does not exist in
this repo). Exports the 8 `SPEC_*_MODEL` vars so that opencode's `{env:...}`
interpolation in `opencode.json` always sees a non-empty value.

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
- Runs **non-interactively**: no prompts, no TTY requirement — works under
  `/spec`, `/build`, and subagent shells that inherit the process env.
- Bash-only, no new dependencies; resolves `config/` relative to the repo root
  (documented in the header) so it works from any cwd.
- Idempotent: running it twice yields the same exports as running it once.

Scenarios: `20-acceptance/AC-020-04-loader.md`

### Task 5 — `scripts/check-model-env.sh`: static gate proving AC-001 + AC-006

Standalone bash gate, exit 1 on a violation, enforcing that opencode.json
contains no literal model id and the real env file is never tracked.

Acceptance criteria:
- Checks `opencode.json`: every `agent.*.model` value must match the exact
  pattern `{env:SPEC_*_MODEL}` — any literal model id (e.g.
  `opencode-go/deepseek-v4-flash`) anywhere in the file exits 1 and prints the
  offending `agent` name. Exits 0 when all 8 model values are env references.
- Checks `git ls-files`: exits 1 with a message naming the offending path if
  `config/model.local.env` is tracked (a forced-add or a previously-committed
  real file). Exits 0 otherwise.
- Clean repo (all env refs, no tracked real file): exit 0, brief PASS line.
- Model-free, no new dependencies. Works against a scratch repo in `/tmp` when
  the caller points `GIT_DIR`/`--git-dir` at it (so the selftest in Task 6 can
  exercise the tracked-file branch without touching this repo).

Scenarios: `20-acceptance/AC-020-05-check-model-env.md`

### Task 6 — `scripts/model-env.selftest.sh` wired into self-ci

One model-free selftest (fixtures in `mktemp -d`, `trap` cleanup) proving the
loader and the check script actually behave as specified, run in the
`validate` job. This is the only opencode-free regression net for the behavior;
the `opencode debug config` scenarios in AC-020-01 are verified by the
Coder/Verifier in the dev environment only.

Acceptance criteria:
- Selftest covers the loader's precedence: process env wins over local file;
  local file wins over example; a partial local file leaves missing vars at
  their example defaults; a var set nowhere (fixture with no example and no
  local and no pre-set value) exits 1 with a message naming the var.
- Selftest covers the check script: an `opencode.json` fixture with a literal
  model id → exit 1; a fixture with all env references → exit 0; a scratch
  repo with `config/model.local.env` tracked → exit 1; a scratch repo without
  it tracked → exit 0.
- **Self-trip constraint**: fixture model ids must be constructed at runtime
  (string concatenation, e.g. `"opencode-go/""${RANDOM}"` or a name built in
  the fixture dir) so the fixtures do not themselves trip the check or any
  hardcoded-secret-style scan. No inline literal model-id fixture values.
- `.github/workflows/self-ci.yml` `validate` job gains a step running both
  `bash scripts/check-model-env.sh` and `bash scripts/model-env.selftest.sh`
  (single `run:` block or adjacent steps), **no `continue-on-error`** — a
  regression fails the job. Existing `bash -n` and shellcheck steps pick up the
  new scripts unchanged.

Scenarios: `20-acceptance/AC-020-06-selftest-selfci.md`

### Task 7 — Docs: `docs/SPEC_PIPELINE.md §Model configuration` and `AGENTS.md`

Update both docs to the copy-example → fill-values → restart flow, replacing
the "edit opencode.json and commit" framing.

Acceptance criteria:
- `docs/SPEC_PIPELINE.md` `§Model configuration` (current lines ~199-243)
  gains a subsection describing: `cp config/model.local.env.example
  config/model.local.env` → fill in model ids → `source scripts/load-env.sh` in
  the shell that launches opencode (or add it to the shell profile) → restart
  opencode → done, **no commit, no PR**. States that config is read once at
  startup so a restart is required after any change.
- The subsection states the precedence: committed defaults (example) when a var
  is unset; the gitignored file wins when present; a pre-existing exported var
  wins over the file. States that sourcing the loader is what prevents the
  empty-string failure (`{env:VAR}` with an unset var resolves to empty).
- `AGENTS.md` (the "OpenCode Go Model Configuration" section, current lines
  ~49-70) model table gains a note that the per-machine values come from
  `config/model.local.env` via the loader, and that switching a model means
  editing the local file + restart, not committing.
- Both docs mention `scripts/check-model-env.sh` as the structural enforcement
  of "no literal model id in opencode.json" and "real file never tracked".

Scenarios: `20-acceptance/AC-020-07-docs.md`

## Acceptance criteria mapping

| Informal AC | Task(s) | Scenario file |
|---|---|---|
| AC-001 every spec-* agent model resolves from an env var, falls back to committed value when unset | 1 + 4 (fallback) + 5 (gate) | `AC-020-01-opencode-env.md`, `AC-020-04-loader.md`, `AC-020-05-check-model-env.md` |
| AC-002 committed `.env.example` one var per agent with comments; real file gitignored | 2 + 3 | `AC-020-02-example-template.md`, `AC-020-03-gitignore.md` |
| AC-003 loader exports values; loader + `opencode debug config` shows overridden model with no commit | 4 + 1 | `AC-020-04-loader.md`, `AC-020-01-opencode-env.md` |
| AC-004 no env file → `opencode debug config` still resolves to committed defaults (no empty-string breakage) | 4 (exports defaults) + 1 | `AC-020-04-loader.md`, `AC-020-01-opencode-env.md` |
| AC-005 docs updated with copy → fill → restart flow | 7 | `AC-020-07-docs.md` |
| AC-006 no hardcoded model value a dev is meant to change outside `.env.example` / `opencode.json` | 5 + 6 | `AC-020-05-check-model-env.md`, `AC-020-06-selftest-selfci.md` |

## Open questions (need a human answer before /build)

1. **`config/model.local.env` chosen over plain `.env` and over reusing
   `config/agent.local.env`.** `.env` is already gitignored but would clash with
   app-level env files; `config/agent.local.env` is spec-013's secrets file,
   which does not exist here. The dedicated `config/model.local.env` keeps model
   preferences separate from secrets. Confirm this name.
2. **`scripts/load-env.sh` name collides with spec-013's spec'd loader.** Spec
   013 names a `scripts/load-env.sh` that is not implemented in this repo. If
   013 is ever implemented here, two loaders with the same name would conflict
   (013 sources `config/agent.local.env` for secrets; this one sources
   `config/model.local.env` for models). Options: (a) keep the shared name and
   later merge both source files into one loader, (b) name this one
   `scripts/load-model-env.sh`. Confirm which.
3. **Empty-string boundary is real and unavoidable at the `{env:}` layer.**
   `opencode debug config` run **without** the loader sourced shows empty model
   strings (unset var → empty, per opencode docs). "No empty-string breakage"
   holds only when the loader ran in the opencode process env. The docs task
   instructs sourcing the loader in the launch shell/profile; there is no
   mechanism that makes the default apply without the loader. Accept this
   documented boundary?
4. **`opencode debug config` scenarios can't run in self-ci.** Self-ci
   (`ubuntu-latest`, `permissions: contents: read`) has no opencode binary, so
   AC-003/AC-004 are verified by the Coder/Verifier in the dev environment via
   the `opencode debug config` scenarios; self-ci runs only the opencode-free
   selftest (Task 6). Acceptable?
5. **Informal spec's inline-default option is impossible.** "Keep `{env:...}`
   defaults inline in `opencode.json`" cannot be expressed — `{env:VAR}` has no
   default syntax, and an unset var resolves to empty (see §Grounded reality).
   Defaults therefore live only in `config/model.local.env.example`, sourced by
   the loader as the fallback. Confirm this resolves the informal spec's design
   question as intended.
