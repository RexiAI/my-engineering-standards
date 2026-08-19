# 025-direnv-model-env

> Spec pipeline archive. Original source: `specs/025-direnv-model-env/` (deleted by this script).
> Archived: 2026-08-19

## Original ask

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

## Tasks

# Tasks — pure direnv dotenv for spec-pipeline model config and credentials (spec 025)

Formalization of `specs/025-direnv-model-env/00-informal.md`. Replace the
loader-based direnv mechanism (committed `.envrc` that evals
`scripts/load-model-env.sh --emit` / `scripts/load-env.sh --emit`) with a pure
dotenv design: `.envrc` is **per-machine and gitignored**; committed templates
(`templates/.envrc.example`, `templates/.envrc.child`) are the only committed
`.envrc` surface; direnv's `dotenv_if_exists` loads the committed example
(`config/model.local.env.example` — the sole default source), then the
gitignored per-machine override, then credentials. The two loaders and their
`--emit` mode are deleted. `scripts/check-model-env.sh` stays and is extended to
cover both real env files. No model ids, `opencode.json`, or `AGENTS.md`
model-table values change; governance constraints from spec 020 are unchanged.

## Grounded reality (verified against this repo's tree)

The current branch carries the OLD loader-based design. The Coder must reach
this state:

- Root `.envrc` exists and is **tracked by git** — must be untracked
  (`git rm --cached .envrc`, file stays on disk) and added to `.gitignore`.
- `templates/.envrc.example` does **not** exist — must be created and committed.
- `templates/.envrc.child` exists, loader-based (`eval "$(bash
  .standards/scripts/load-model-env.sh --emit)"`) — must be rewritten to pure
  `dotenv_if_exists`.
- `scripts/load-env.sh` and `scripts/load-model-env.sh` exist — must be deleted.
- Live references to the loaders exist in: `agents/spec-pipeline.md`,
  `agents/spec-pr-opener.md` (defensive `source scripts/load-env.sh`),
  `.github/workflows/ci-sweeper.yml` (`source scripts/load-model-env.sh`),
  `README.md` (§Model Configuration), `AGENTS.md` (§OpenCode Go Model
  Configuration), `docs/SPEC_PIPELINE.md` (§Model configuration),
  `config/model.local.env.example` header, `config/agent.local.env.example`
  header, `scripts/model-env.vars.sh` header note, and
  `docs/adr/0001-direnv-model-env.md` (documents the rejected `--emit`
  design, status Proposed). All must be updated or removed.
- `scripts/check-model-env.sh` exists; its untracked-file check covers only
  `config/model.local.env` — the informal spec names **both** real env files
  (`config/model.local.env`, `config/agent.local.env`).
- `scripts/model-env.selftest.sh` and `scripts/model-env.runtime-check.sh` are
  loader-based (source the loader, `--emit` cases) — must be reworked to the
  dotenv design.
- `.github/workflows/self-ci.yml` runs `check-model-env.sh`,
  `model-env.selftest.sh`, `model-env.runtime-check.sh <pinned-binary>` in the
  validate job with no `continue-on-error` — wiring stays, steps' internals change.
- `scripts/check-orchestration.sh` mechanically resolves `scripts/...` paths
  cited in `agents/` and `AGENTS.md` — deleting the loaders without updating
  those references fails the gate; the purge task must clear them.
- `docs/changes/020-model-config-env.md` is the historical archive of spec 020
  and references the loaders — treated as a historical record, **not** part of
  the purge (see Open questions 1).

## Task 1 — `.envrc` gitignored per-machine; committed dotenv templates

The repo-root `.envrc` becomes a per-machine, gitignored file copied from the
committed `templates/.envrc.example`. `templates/.envrc.child` is rewritten to
the same pure-dotenv shape for child repos. Templates are the only committed
`.envrc` surface.

Acceptance criteria:
- `git ls-files --error-unmatch -- .envrc` exits non-zero (the root `.envrc` is
  untracked); the root `.gitignore` contains a line matching `^\.envrc$`; with
  a `.envrc` present on disk, `git check-ignore -- .envrc` exits 0.
- `templates/.envrc.example` exists and is tracked; its executable lines are
  exactly three `dotenv_if_exists` lines, in this order:
  `config/model.local.env.example`, `config/model.local.env`,
  `config/agent.local.env`; the file contains no `eval`, no `bash` invocation,
  no `source`/`.` of any loader, and no `--emit`.
- `templates/.envrc.child` exists and is tracked; its executable lines are
  exactly three `dotenv_if_exists` lines, in this order:
  `.standards/config/model.local.env.example`, `config/model.local.env`,
  `config/agent.local.env`; same no-eval/no-loader/no-`--emit` constraint.
- Both templates carry a header documenting: one-time setup (`eval
  "$(direnv hook bash)"` then `direnv allow`), which file each line loads and
  why (committed defaults → per-machine override → credentials), and that the
  `.envrc` is gitignored per-machine and never committed.
- `git ls-files` returns no `.envrc` path outside `templates/` (only
  `templates/.envrc.example` and `templates/.envrc.child`).
- Regression: `git check-ignore` still exits 0 for `config/model.local.env` and
  `config/agent.local.env`, and non-zero for both `.example` files (real files
  ignored, examples committable).

Scenarios: `20-acceptance/AC-025-01-gitignore-templates.md`

## Task 2 — Parent `.envrc` dotenv semantics

The parent `.envrc` (per-machine copy of `templates/.envrc.example`) loads the
committed defaults first, then the per-machine override, then credentials.
Precedence is later-wins: a `dotenv_if_exists` line **clobbers** any
pre-existing value (pre-exported shell vars included) — accepted and
documented, the `.envrc` is the per-directory source of truth. The example
loading first guarantees the 8 `SPEC_*_MODEL` vars are non-empty when opencode
launches (`{env:VAR}` resolves empty when unset; this opencode build has no
default syntax).

Acceptance criteria:
- Hermetic fixture (no direnv binary required), emulating `dotenv_if_exists`
  as `[ -f <path> ] && set -a && . <path> && set +a`, run from a fixture root:
  with only `config/model.local.env.example` present, all 8 `SPEC_*_MODEL` vars
  export with the fixture example's values — non-empty and differentiated
  (plus-tier vars resolve to the fixture's plus value, fast-tier vars to the
  fixture's fast value); exit 0.
- Same emulation with a fixture `config/model.local.env` overriding one var:
  that var takes the override value, the other 7 keep the example defaults.
- Clobber semantics: with `SPEC_SPECIFIER_MODEL` pre-exported in the calling
  shell, emulating the three lines in order yields the **example/file** value,
  not the pre-exported one (a dotenv line clobbers; later lines win).
- Credentials: with a fixture `config/agent.local.env` defining `GITHUB_TOKEN`
  and `GH_TOKEN`, the third line exports both; loading order places credentials
  after the model vars.
- Missing files no-op: a fixture with only the example present — the emulation
  of the absent override/credential lines changes nothing and the shell
  continues; a fixture with no files at all exports nothing and still exits 0.
- If a root `.envrc` exists on disk, it contains no reference to
  `scripts/load-*.sh` or `--emit` (guards a stale local copy).
- Live (direnv-conditional): `direnv allow` then `direnv exec <repo-root> bash
  -c 'printf %s "${SPEC_SPECIFIER_MODEL:-EMPTY}"'` prints a non-empty model id;
  the selftest may run this but must skip cleanly (PASS-noted) when the
  `direnv` binary is absent.

Scenarios: `20-acceptance/AC-025-02-parent-envrc.md`

## Task 3 — Child `.envrc` template + bootstrap wiring

A child repo consumes this repo as a `.standards/` submodule. Its `.envrc`
(per-machine, gitignored, written by `scripts/bootstrap.sh` from
`templates/.envrc.child`) defaults to the parent's **committed** model defaults
via `.standards/config/model.local.env.example`, applies per-child overrides via
the child's own gitignored `config/model.local.env`, and loads the child's own
credentials. The submodule never carries gitignored files, so a parent's
per-machine override never propagates.

Acceptance criteria:
- Hermetic fixture emulation of the child template against a fixture
  `.standards/` (fixture scripts-less layout: just `.standards/config/` with an
  example defining all 8 vars at differentiated fast/plus values), with no
  child files: all 8 vars resolve to the fixture parent's committed defaults,
  including the per-stage differentiation (`spec-verifier` → plus value,
  `spec-coder` → fast value); exit 0.
- Same emulation with a child `config/model.local.env` overriding one var: the
  child value wins for that var, the other 7 keep the parent's committed
  defaults.
- Parent override does not propagate: a fixture `.standards/` checkout contains
  no `config/model.local.env` or `config/agent.local.env` (git ls-files of the
  standards repo lists neither), so the child's `.standards/`-relative line
  resolves against the committed example only; the child still resolves the
  defaults.
- Child credentials: with a child `config/agent.local.env` defining
  `GITHUB_TOKEN` and `GH_TOKEN`, the template's third line exports both from
  the child's own file.
- `scripts/bootstrap.sh`: copies `templates/.envrc.child` to `<child>/.envrc`
  when absent (and prints `direnv allow` guidance); skips with a message when
  one exists; ensures the child's root `.gitignore` contains a `.envrc` line
  (append when absent); writes/keeps a child `config/.gitignore` covering
  `model.local.env` and `agent.local.env`; and its "Next steps" git add list no
  longer names `.envrc`.
- Live (direnv-conditional): a scratch child built by `bootstrap.sh` resolves
  model vars to the real parent committed defaults with no local file, and to a
  child override with one; skips cleanly when direnv is absent.

Scenarios: `20-acceptance/AC-025-03-child-envrc-bootstrap.md`

## Task 4 — Remove `load-env.sh` + `load-model-env.sh` + `--emit`, purge all references

The loaders are deleted. Every live surface that cites them is updated or
cleared. "Live surface" means: `scripts/` (excluding `docs/changes/` historical
archives), `templates/`, `agents/`, `.github/`, `config/*.example`, `README.md`,
`AGENTS.md`, and `docs/SPEC_PIPELINE.md`.

Acceptance criteria:
- `scripts/load-env.sh` and `scripts/load-model-env.sh` do not exist
  (`git ls-files` lists neither; the files are absent from the worktree).
- `grep -rn --emit scripts/ templates/ agents/ .github/ config/ README.md
  AGENTS.md docs/SPEC_PIPELINE.md` returns zero matches.
- `grep -rn "load-env\|load-model-env"` over the same live surface returns zero
  matches.
- `agents/spec-pipeline.md` and `agents/spec-pr-opener.md` no longer reference
  the loaders; the PR Opener's defensive step becomes a presence check: before
  the first commit/push, verify `$GITHUB_TOKEN` and `$GH_TOKEN` are non-empty
  and report + stop when either is missing (no loader to source).
- `.github/workflows/ci-sweeper.yml` no longer sources the loader; the headless
  run loads the committed defaults itself with the dotenv-equivalent
  (`set -a; . config/model.local.env.example; set +a`) so the `{env:SPEC_*_MODEL}`
  references resolve non-empty on a bare runner.
- `config/model.local.env.example` and `config/agent.local.env.example` headers
  describe the direnv/dotenv flow and cite no loader path; the
  `scripts/model-env.vars.sh` header note about the loader's inline copy is
  removed or updated to the dotenv design.
- `bash scripts/check-orchestration.sh` exits 0 (every `scripts/...` path cited
  in `agents/`, `commands/`, and `AGENTS.md` resolves after the removals).

Scenarios: `20-acceptance/AC-025-04-remove-loaders.md`

## Task 5 — `check-model-env.sh` stays, extended to both real env files

The structural gate is the primary enforcement. It must keep its three checks
and extend the untracked-file check to both per-machine env files.

Acceptance criteria:
- On the real repo, `bash scripts/check-model-env.sh` exits 0 with a PASS line.
- Check 1 (no literal model id): a fixture `opencode.json` with a literal
  provider/model id exits 1 naming the offending agent; the real
  `opencode.json` passes — every `agent.*.model` is exactly an
  `{env:SPEC_*_MODEL}` reference and all 8 spec agents are present.
- Check 2 (real env files never tracked): a fixture git repo with
  `config/model.local.env` tracked exits 1 naming that path; **and** a fixture
  with `config/agent.local.env` tracked exits 1 naming that path (new coverage);
  a fixture with neither tracked exits 0.
- Check 3 (example wired): the committed example defines exactly the vars
  referenced by `opencode.json` — a reference with no example default exits 1
  naming the var; an example var with no reference exits 1 naming the var; the
  real repo passes.

Scenarios: `20-acceptance/AC-025-05-check-model-env.md`

## Task 6 — `model-env.selftest.sh` + `model-env.runtime-check.sh` reworked to the dotenv design

Both test scripts drop loader-specific cases (`--emit`, sourcing the loader)
and cover the dotenv design hermetically. The self-trip constraint from spec
020 is preserved: fixture model ids are built at runtime via string
concatenation, never inlined as literals.

Acceptance criteria:
- `bash scripts/model-env.selftest.sh` exits 0 on the real repo, 0 failed.
- Every `AC-025-*` scenario ID appears in the selftest, the runtime-check, or a
  CI-wiring assertion (scenario traceability).
- The selftest's dotenv fixture cases (no direnv binary required, emulating
  `dotenv_if_exists` as `[ -f <path> ] && set -a && . <path> && set +a`) assert:
  parent order and defaults (Task 2), parent override wins + clobber (Task 2),
  child inheritance and child-override-wins (Task 3), credentials loading, and
  the missing-file no-op.
- The selftest asserts the structural invariants from Tasks 1/4/5:
  `templates/.envrc.example` and `.envrc.child` shape (three `dotenv_if_exists`
  lines, no loader words), `.envrc` gitignored and untracked, no committed
  `.envrc` outside `templates/`, no `load-env.sh`/`load-model-env.sh`/`--emit`
  in live surfaces, and `check-model-env.sh` exit 0 on the real repo plus its
  branch behavior on fixtures (both real env files tracked → exit 1).
- The selftest's docs assertions: `docs/SPEC_PIPELINE.md` and `AGENTS.md`
  document the dotenv flow and contain no loader reference.
- The selftest's self-ci assertion: the validate job still runs
  `check-model-env.sh`, `model-env.selftest.sh`, and
  `model-env.runtime-check.sh <pinned-binary>` with no `continue-on-error` on
  those steps.
- `bash scripts/model-env.runtime-check.sh <pinned-binary>` passes three cases
  against a scratch project, each with all 8 vars unset first:
  1. example loaded (dotenv-equivalent) → every agent resolves to the fixture
     example default, none empty;
  2. example + `config/model.local.env` overriding one var + a pre-exported env
     var for a var **absent from all files** → the file override wins, the
     pre-exported var survives, the rest stay at defaults (proves the new
     precedence: later dotenv line wins; vars no file defines are untouched);
  3. nothing loaded → every agent resolves to null/empty (proves the example
     file is what carries the defaults).
- A direnv-requiring case is conditional: absent `direnv` → PASS-noted skip,
   selftest still exits 0.

Scenarios: `20-acceptance/AC-025-06-selftest-runtime.md`

## Task 7 — Docs + ADR updated to the dotenv design

Per the informal spec's definition of done: the docs must describe the direnv
flow so a developer can reproduce it without reading scripts, and governance
requires the ADR record the decision.

Acceptance criteria:
- `docs/SPEC_PIPELINE.md §Model configuration` documents: one-time setup
  (install direnv, wire the hook once, `direnv allow`), the parent `.envrc`
  copied from `templates/.envrc.example` with its three `dotenv_if_exists`
  lines (committed example → per-machine override → credentials), the child
  flow (`bootstrap.sh` writes `.envrc` from `templates/.envrc.child`; child
  defaults to the parent's committed defaults via
  `.standards/config/model.local.env.example`; submodule never carries
  gitignored files; child override wins), precedence (later `dotenv_if_exists`
  wins; a dotenv line clobbers a pre-exported var — accepted, the `.envrc` is
  the per-directory source of truth), empty-var safety (example loaded first so
  the 8 vars are non-empty; `{env:VAR}` resolves empty when unset — no default
  syntax in this opencode build), the launch boundary (opencode must launch
  from a direnv-loaded shell; GUI/daemon launches resolve empty models, surfaced
  by empty resolution not a loader), restart-required-after-change, and the
  enforcement (check-model-env.sh primary gate; selftest + pinned-binary
  runtime-check in self-ci). It must contain no reference to
  `scripts/load-*.sh` or `--emit`.
- `AGENTS.md` (§OpenCode Go Model Configuration and the per-machine agent
  environment notes) describes the gitignored `.envrc` + `dotenv_if_exists`
  mechanism with no loader references; the model-table values are unchanged.
- `README.md` (§Model Configuration) describes the direnv flow (copy template,
  `direnv allow`, edit `config/model.local.env`, restart) with no loader
  references.
- `docs/adr/0001-direnv-model-env.md` records the **dotenv** decision: pure
  `dotenv_if_exists` (no loaders, no `--emit`), `.envrc` gitignored per-machine,
  committed templates as the default wiring, precedence/clobber accepted, the
  rejected alternatives (shell-profile status quo; the loader-`--emit` design
  this spec replaces), consequences, and compliance (check-model-env.sh,
  selftest, runtime-check). Status set to **Accepted** (see Open question 2).
- `docs/adr/README.md` lists ADR 0001 with its updated status.

Scenarios: `20-acceptance/AC-025-07-docs-adr.md`

## Open questions (need a human answer before /build)

1. **Historical archive.** `docs/changes/020-model-config-env.md` (spec 020's
   archive) references the loaders throughout. This spec treats it as a frozen
   historical record and excludes it from the purge. Confirm — or should it be
   edited to the dotenv design too (rewriting history)?
2. **ADR status.** This spec sets ADR 0001's status to Accepted on
   implementation. Per `docs/GOVERNANCE.md`, confirm that a merged spec counts
   as acceptance — or should status stay Proposed pending a separate human
   step?
3. **check-model-env.sh scope.** The informal spec's "Kept" section names both
   real env files (`config/model.local.env`, `config/agent.local.env`) as
   never-tracked checks, but the current script checks only the model file.
   Task 5 extends it to both — the `config/agent.local.env` half is also
   covered by `scripts/guard-env.sh` + self-ci; the duplication is accepted.
4. **Child `.gitignore` for `.envrc`.** The informal spec says `.envrc` is
   gitignored per-machine; Task 3 has `bootstrap.sh` append `.envrc` to the
   child's root `.gitignore`. Confirm bootstrap owns that, rather than leaving
   it to the child's manual setup.
5. **Untracking the root `.envrc`.** The current branch has `.envrc` committed
   (old design). Task 1 untracks it (`git rm --cached`); the file stays on disk
   locally. Confirm no other flow depends on the committed copy (CI does not —
   self-ci never loads `.envrc`).

## Acceptance scenarios

## AC-025-01-01 — Root `.envrc` is untracked and gitignored
## AC-025-01-02 — `templates/.envrc.example` exists, tracked, three dotenv lines in order
## AC-025-01-03 — `templates/.envrc.child` exists, tracked, three dotenv lines in order
## AC-025-01-04 — No committed `.envrc` outside `templates/`
## AC-025-01-05 — Real env files stay ignored; examples stay committable
## AC-025-01-06 — Both templates document one-time setup and per-line roles
## AC-025-02-01 — Example alone yields all 8 non-empty, differentiated defaults
## AC-025-02-02 — Per-machine override beats the committed example
## AC-025-02-03 — A dotenv line clobbers a pre-exported shell var (later wins, accepted)
## AC-025-02-04 — Credentials load last from `config/agent.local.env`
## AC-025-02-05 — Missing files are a no-op and never fail the shell
## AC-025-02-06 — A stale local `.envrc` carries no loader references
## AC-025-02-07 — Live: direnv loads the vars after allow (direnv-conditional)
## AC-025-03-01 — No child files: all 8 vars resolve to the parent's committed defaults
## AC-025-03-02 — Child override wins; the parent's other defaults stay
## AC-025-03-03 — Parent per-machine overrides never propagate to children
## AC-025-03-04 — Child credentials load from the child's own `config/agent.local.env`
## AC-025-03-05 — bootstrap.sh writes the child `.envrc` and gitignore wiring
## AC-025-03-06 — Live: a bootstrapped child defaults to parent defaults, override wins (direnv-conditional)
## AC-025-04-01 — The loader scripts are deleted
## AC-025-04-02 — `--emit` is gone from every live surface
## AC-025-04-03 — No loader name appears in any live surface
## AC-025-04-04 — Agents no longer cite the loaders; PR Opener checks presence instead
## AC-025-04-05 — CI sweeper loads committed defaults without the loader
## AC-025-04-06 — Config example headers document direnv, cite no loader
## AC-025-04-07 — Orchestration references still resolve after the removals
## AC-025-05-01 — Real repo passes with a PASS line
## AC-025-05-02 — Literal model id in `opencode.json` fails, naming the agent
## AC-025-05-03 — Tracked `config/model.local.env` fails, naming the path
## AC-025-05-04 — Tracked `config/agent.local.env` fails, naming the path
## AC-025-05-05 — A reference with no example default fails, naming the var
## AC-025-05-06 — An example var with no reference fails, naming the var
## AC-025-05-07 — Clean fixture passes
## AC-025-06-01 — Selftest passes on the real repo
## AC-025-06-02 — Every `AC-025-*` scenario ID is cited by a test
## AC-025-06-03 — Selftest asserts parent dotenv order, override, and clobber hermetically
## AC-025-06-04 — Selftest asserts child inheritance and child-override-wins hermetically
## AC-025-06-05 — Selftest asserts the structural invariants from Tasks 1/4/5
## AC-025-06-06 — Selftest asserts docs and self-ci wiring
## AC-025-06-07 — Runtime check case 1: example loaded → defaults, none empty
## AC-025-06-08 — Runtime check case 2: file override wins; a var no file defines keeps its pre-exported value
## AC-025-06-09 — Runtime check case 3: nothing loaded → all empty
## AC-025-06-10 — Direnv-requiring cases skip cleanly when direnv is absent
## AC-025-07-01 — SPEC_PIPELINE.md §Model configuration documents the dotenv flow
## AC-025-07-02 — AGENTS.md describes the gitignored `.envrc` mechanism
## AC-025-07-03 — README.md §Model Configuration describes the direnv flow
## AC-025-07-04 — ADR 0001 records the dotenv decision with status Accepted
## AC-025-07-05 — ADR index reflects the updated status

## Verification

# Verification Report — spec 025 (direnv model env)

Branch: `spec/025-direnv-model-env` (nothing committed; working tree dirty by design — staged deletions of the loaders + modified files + untracked new files, per the Coder/Refactorer handoff).
Verifier: spec-verifier (stage 4). `00-informal.md` was not read. All evidence below was executed, not read from prior reports.

---

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 1
at: 2026-08-19T14:46:00Z

Full transcript (passes verbatim; fails summarized by class — the JSON contains 190 fail entries, all from archived-spec citations in files this spec did not touch; complete raw JSON captured at /tmp/opencode during this run and reproducible with the same command):

```json
{
  "checks": [1, 2],
  "passes": [
    "AC-025-01 — traced to a test",
    "AC-025-02 — traced to a test",
    "AC-025-03 — traced to a test",
    "AC-025-04 — traced to a test",
    "AC-025-05 — traced to a test",
    "AC-025-06 — traced to a test",
    "AC-025-07 — traced to a test"
  ],
  "fails": [
    "AC-001-01 … AC-022-04 — referenced in a test but no matching scenario heading exists in specs/*/20-acceptance/. Stale ID after a rename, or a typo.",   // 182 archived-spec IDs, one line each in the raw JSON
    "AC-888-88 — referenced in a test but no matching scenario heading exists …",
    "AC-998-01 — referenced in a test but no matching scenario heading exists …",
    "AC-999-01 — referenced in a test but no matching scenario heading exists …",
    "AC-999-02 — referenced in a test but no matching scenario heading exists …",
    "AC-999-03 — referenced in a test but no matching scenario heading exists …",
    "AC-999-99 — referenced in a test but no matching scenario heading exists …"
  ]
}
```

Attribution analysis (this is why exit 1 is not a spec-025 defect):
- Check 1 (scenario→test): **exit 0 in isolation** — `bash scripts/check-scenario-traceability.sh --checks 1 --json` → exit 0, every AC-025-01…07 heading traced.
- Check 2 (reference→scenario) fails contain **zero AC-025-* entries**. Every failing ID (AC-001…022, AC-888/998/999) is referenced only in **unmodified files**: `docs/changes/*.md` historical archives (verified by grep: the referrers of AC-001-01, AC-999-01, etc. are all under `docs/changes/`), plus the pre-existing worked-example headings `## AC-002-01/02` in `docs/SPEC_PIPELINE.md` §Scenario format (present on HEAD; this spec's diff adds **zero** AC-* lines to that file — `git diff HEAD -- docs/SPEC_PIPELINE.md | grep -cE '^\+.*AC-'` = 0).
- This fail pattern is the repo's documented baseline: `docs/changes/009-stop-and-ask-matrix.md` ("archived-spec citation with no matching scenario (AC-001-01..06, …)"), `docs/changes/019-daily-triage-loop.md` ("FAIL AC-001-01..06 …"), `docs/changes/015-auditable-agent-steps.md` ("archived-spec citations (AC-001-01 .. AC-006-06 …)") all record the identical state from prior pipeline runs.

Sub-scenario coverage (independent of the script): 48 scenario IDs (`grep -rhoE '^## AC-025-[0-9]{2}-[0-9]{2}' specs/025-direnv-model-env/20-acceptance/*.md`, count = 48) — **all 48 cited** by `scripts/model-env.selftest.sh` (48 unique), with `scripts/model-env.runtime-check.sh` adding AC-025-06-07/08/09 and `scripts/agent-env.selftest.sh` citing AC-025-02-04/03-04. **Zero dangling**: 48 unique IDs cited in tests, all 48 resolve to scenario headings (comm = ∅).

---

## Evidence: full test suite

All commands executed with real exit codes; no tests skipped, no `--emit`/loader cases remain (grep of the three scripts for `--emit` and `load-` = zero matches).

command: bash scripts/model-env.selftest.sh; bash scripts/agent-env.selftest.sh; bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode
exit: 0
at: 2026-08-19T14:47:00Z

--- run 1/3: bash scripts/model-env.selftest.sh ---

```
== AC-025-01 .envrc gitignored + dotenv templates ==
PASS AC-025-01-01 root .gitignore contains a line matching ^.envrc$
PASS AC-025-01-01 .envrc on disk: git ls-files non-zero, git check-ignore exit 0
PASS AC-025-01-02 AC-025-01-03 .envrc.example tracked (or committable pre-commit)
PASS AC-025-01-02 AC-025-01-03 .envrc.child tracked (or committable pre-commit)
PASS AC-025-01-02 templates/.envrc.example has exactly three dotenv_if_exists lines
PASS AC-025-01-02 example line order: committed example -> per-machine override -> credentials
PASS AC-025-01-02 no eval / bash invocation / source / . / emit flag in executable lines
PASS AC-025-01-03 templates/.envrc.child has exactly three dotenv_if_exists lines
PASS AC-025-01-03 child line order: .standards committed example -> child override -> child credentials
PASS AC-025-01-03 no eval / bash invocation / source / . / emit flag in executable lines
PASS AC-025-01-04 no .envrc path outside templates/ (tracked or committable)
PASS AC-025-01-05 git check-ignore exits 0 for both real env files
PASS AC-025-01-05 examples are not ignored (templates stay trackable)
PASS AC-025-01-06 .envrc.example header documents direnv allow, the three file roles, never-commit
PASS AC-025-01-06 .envrc.child header documents direnv allow, the three file roles, never-commit
== AC-025-02 parent .envrc semantics ==
PASS AC-025-02-01 AC-025-06-03 example alone: all 8 vars non-empty, plus-tier -> plus, fast-tier -> fast, exit 0
PASS AC-025-02-02 AC-025-06-03 override file: SPEC_SPECIFIER_MODEL wins, other 7 keep defaults, exit 0
PASS AC-025-02-03 AC-025-06-03 clobber: example value wins over the pre-exported var (dotenv line clobbers)
PASS AC-025-02-04 AC-025-06-03 credentials: GITHUB_TOKEN + GH_TOKEN load from the third line, model vars intact
PASS AC-025-02-04 credentials line executes after the model-var lines
PASS AC-025-02-05 missing override/credential files: no-op, no error, exit 0
PASS AC-025-02-05 no files at all: exit 0, nothing exported
PASS AC-025-02-06 no root .envrc on disk — stale-copy guard trivially satisfied
PASS AC-025-02-07 live direnv: SPEC_SPECIFIER_MODEL resolves non-empty after allow
== AC-025-03 child template + bootstrap ==
PASS AC-025-03-01 AC-025-06-04 no child files: all 8 vars resolve to the parent's committed defaults, exit 0
PASS AC-025-03-02 AC-025-06-04 child override: SPEC_CODER_MODEL wins, other 7 keep parent defaults, exit 0
PASS AC-025-03-03 standards git index lists neither real env file
PASS AC-025-03-03 .standards-relative line resolves against the committed example only; defaults still resolve
PASS AC-025-03-04 AC-025-06-04 child credentials: GITHUB_TOKEN + GH_TOKEN from the child's own file
PASS AC-025-03-05 bootstrap writes .envrc as a copy of templates/.envrc.child
PASS AC-025-03-05 bootstrap appends .envrc to the child root .gitignore
PASS AC-025-03-05 child config/.gitignore covers model.local.env and agent.local.env
PASS AC-025-03-05 next-steps git add list does not name .envrc
PASS AC-025-03-05 re-run: bootstrap prints a skip message and does not overwrite .envrc
PASS AC-025-03-06 live direnv: bootstrapped child resolves the parent's committed default (spec-verifier)
PASS AC-025-03-06 live direnv: child override wins after adding config/model.local.env
== AC-025-04 loaders removed + purge ==
PASS AC-025-04-01 the loader scripts are deleted (index + worktree)
PASS AC-025-04-02 no emit-flag string in any live surface
PASS AC-025-04-03 no loader-name string in any live surface
PASS AC-025-04-04 agents/spec-pipeline.md and spec-pr-opener.md cite no loader
PASS AC-025-04-04 PR Opener verifies GITHUB_TOKEN + GH_TOKEN non-empty, reports + stops when missing, sources nothing
PASS AC-025-04-05 ci-sweeper.yml cites no loader
PASS AC-025-04-05 ci-sweeper headless run loads committed defaults via the dotenv-equivalent
PASS AC-025-04-06 model.local.env.example header documents the direnv dotenv_if_exists flow
PASS AC-025-04-06 agent.local.env.example header documents the direnv dotenv_if_exists flow
PASS AC-025-04-07 check-orchestration.sh exits 0 (scripts/ paths in agents/, commands/, AGENTS.md resolve)
== AC-025-05 check-model-env branches ==
PASS AC-025-05-01 check-model-env exits 0 on the real repo with a PASS line
PASS AC-025-05-02 literal model id: exit 1, output names the offending agent (spec-coder)
PASS AC-025-05-03 AC-025-06-05 tracked config/model.local.env: exit 1, output names the path
PASS AC-025-05-04 AC-025-06-05 tracked config/agent.local.env: exit 1, output names the path
PASS AC-025-05-05 reference with no example default: exit 1, output names SPEC_CODER_MODEL
PASS AC-025-05-06 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL
PASS AC-025-05-07 clean fixture: exit 0 with a PASS line
== AC-025-06 selftest + runtime self-assertions ==
PASS AC-025-06-02 every AC-025-* scenario ID cited by the selftest or the runtime check
PASS AC-025-06-05 structural invariants held: templates shape, .envrc gitignored/untracked, purge clean, gate branches proven
PASS AC-025-06-06 AC-025-07-01 SPEC_PIPELINE.md documents the dotenv flow with no loader reference
PASS AC-025-06-06 AC-025-07-02 AGENTS.md documents the dotenv flow with no loader reference
PASS AC-025-06-06 self-ci validate job runs check-model-env, the selftest, and the runtime check
PASS AC-025-06-06 AC-025-06-10 no continue-on-error on the model-env steps — a regression must fail the job
PASS AC-025-06-07 cited by the runtime check
PASS AC-025-06-08 cited by the runtime check
PASS AC-025-06-09 cited by the runtime check
== AC-025-07 docs + ADR ==
PASS AC-025-07-01 SPEC_PIPELINE.md §Model configuration documents setup, parent/child flow, precedence, safety, boundary, enforcement
PASS AC-025-07-02 AGENTS.md describes the gitignored .envrc mechanism; model-table values unchanged
PASS AC-025-07-03 README.md §Model Configuration describes copy template, direnv allow, edit, restart
PASS AC-025-07-04 ADR 0001: status Accepted, dotenv decision, rejected alternatives (shell-profile, loader design), compliance
PASS AC-025-07-05 docs/adr/README.md lists ADR 0001 with status Accepted

selftest: 67 passed, 0 failed
✔ model-env.selftest: all cases pass.
```


--- run 2/3: bash scripts/agent-env.selftest.sh ---

```
== agent env template + gitignore ==
PASS config/agent.local.env.example exists
PASS example is tracked (or committable pre-commit: not ignored, git add stages it)
PASS every credential has a <...> placeholder with a comment directly above
PASS template enumerates exactly GITHUB_TOKEN and GH_TOKEN
PASS header documents the direnv dotenv_if_exists flow and never-commit
PASS git check-ignore config/agent.local.env exits 0 (file absent on disk)
PASS example is NOT ignored (template stays trackable)
== guard-env ==
PASS staged real file: guard --staged exits 1 and names config/agent.local.env
PASS tracked real file: guard (CI mode) exits 1 and names config/agent.local.env
PASS clean scratch repo: guard exits 0 with a PASS line in both modes
== check-no-hardcoded-secrets ==
PASS literal token prefix: exit 1, output prints the matching file
PASS secret-style assignment: exit 1, output prints the matching file
PASS placeholders and variable references are not flagged
PASS real scanned dirs (agents/ commands/ scripts/ docs/) are clean — the selftest itself trips nothing
== self-ci wiring ==
PASS self-ci validate job runs the guard, the secrets check, and the selftest
PASS no continue-on-error on the agent-env step — a regression must fail the job
== docs + agent cross-references (spec 025 dotenv flow) ==
PASS AGENTS.md documents copy -> fill -> never commit and the direnv .envrc flow
PASS AGENTS.md names the credentials and the enforcement scripts
PASS PR Opener verifies credential presence via the direnv flow and uses env vars, never literals
PASS orchestrator documents that the direnv-loaded shell already has the env loaded
PASS no literal credential value in agents/ or commands/

selftest: 21 passed, 0 failed
✔ agent-env.selftest: all cases pass.
```


--- run 3/3: bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode (pinned binary v1.18.18, per self-ci wiring) ---

```
pinned opencode binary: /tmp/opencode-bin/opencode
PASS AC-025-06-07 opencode binary runs (--version)
PASS AC-025-06-07 case 1: example loaded — all 8 agents resolve to the fixture example defaults, none empty
PASS AC-025-06-08 case 2: later dotenv line wins for spec-specifier; spec-ux keeps its pre-exported value; rest stay at defaults
PASS AC-025-06-09 case 3: nothing loaded — every agent resolves to null/empty, proving the example carries the defaults

runtime-check: 4 passed, 0 failed
✔ model-env.runtime-check: all cases pass.
```

---

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --json   (this repo's complexity gate at `mvp` tier — KISS/CC heuristics; real linters per language)
exit: 1
at: 2026-08-19T14:48:00Z

The gate ran and produced findings (see next block, Check 3.5, for the full FAIL/WARN transcription). All findings — every one — are in `ci/templates/*` files untouched by this spec (`git status` shows no changes under `ci/`; last commit touching `ci/templates/go-saga-lint.go` is c81b75d "v1.3.0 - saga/outbox CI quality gates", predating this branch).

Proof of pre-existing baseline (same method the archived spec-007 Verifier used, docs/changes/007-verifier-discipline.md §Check 3.5):
- `git diff HEAD -- scripts/check-code-principles.sh` = 0 lines (the gate script itself is unmodified by this spec).
- HEAD-script run vs working-tree-script run: **byte-identical JSON output, both exit 1** (`diff -q /tmp/opencode/ccp-old2.json /tmp/opencode/ccp-new2.json` → identical).
- The gate's own blame-scoped mode: `bash scripts/check-code-principles.sh --json -BaseRef HEAD` → **exit 0, `"fails": [], "warns": []`** — the diff of this spec introduces zero FAILs/WARNs.

---

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh --json
exit: 1
at: 2026-08-19T14:48:00Z

Full transcript (verbatim — every FAIL and WARN line as emitted):

```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "property-tests"],
  "fails": [
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:CC=14", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:CC=10", "file": "./ci/templates/go-saga-lint.go", "line": "163" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:CC=10", "file": "./ci/templates/go-saga-lint.go", "line": "207" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:CC=8", "file": "./ci/templates/go-saga-lint.go", "line": "275" },
    { "message": "Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:69:getSagaStepOptions:CC=7", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "56" }
  ],
  "warns": [
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:KISS_LINES=59", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:KISS_LINES=42", "file": "./ci/templates/go-saga-lint.go", "line": "163" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:KISS_LINES=38", "file": "./ci/templates/go-saga-lint.go", "line": "207" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:KISS_LINES=31", "file": "./ci/templates/go-saga-lint.go", "line": "275" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)", "file": "./ci/templates/go-saga-lint.go", "line": "155" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "112" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "129" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)", "file": "./ci/templates/go-saga-lint.go", "line": "156" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)", "file": "./ci/templates/go-saga-lint.go", "line": "104" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "130" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)", "file": "./ci/templates/go-saga-lint.go", "line": "198" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)", "file": "./ci/templates/go-saga-lint.go", "line": "199" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)", "file": "./ci/templates/go-saga-lint.go", "line": "197" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" },
    { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" },
    { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }
  ]
}
```

Attribution (following the documented repo precedent in docs/changes/007-verifier-discipline.md §Check 3.5, which recorded the identical 5 FAILs + 17 WARNs, proved them byte-identical to HEAD, and concluded: "Per the gate contract, these FAILs would normally stop the pipeline — but they are pre-existing … and in files this spec does not touch. They are flagged to the Architect as a separate remediation item, not a failure of spec 007."):
- All 5 FAILs and all 17 WARNs reference `ci/templates/` files. `git status --short ci/` is empty — this spec touches none of them.
- HEAD-gate-script run is byte-identical to the working-tree run (same exit 1, same JSON).
- The gate's own blame-scoped mode (`-BaseRef HEAD`) exits 0 with `"fails": [], "warns": []` — nothing this spec's diff introduces.
- **Not a verdict blocker for spec 025**; flagged to the Architect as a pre-existing remediation item (same class as the traceability baseline).

---

## Evidence: scenario-to-behavior spot check

command: bash scripts/model-env.selftest.sh (grep of AC-025-02-03 block) + bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode (AC-025-06-08 block) + read of agents/spec-pr-opener.md and .github/workflows/ci-sweeper.yml
exit: 0
at: 2026-08-19T14:49:00Z

Spot-checked 4 scenarios against the actual test code (not just test-name presence):

1. **AC-025-02-03 (clobber)** — `scripts/model-env.selftest.sh:322-331`. Scenario: pre-exported `SPEC_SPECIFIER_MODEL` → emulated lines → example's value wins. Test: writes fixture example, runs `snap_envrc "$PARENT_TPL" "$f0203" "SPEC_SPECIFIER_MODEL=$provider/pre-exported$RANDOM"` (pre-export passes in), asserts `snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST"` + rc 0. Assertion matches Given/When/Then exactly. ✓
2. **AC-025-06-08 (runtime precedence)** — `scripts/model-env.runtime-check.sh:152-185`. Scenario: file override wins for spec-specifier; a var absent from all files (SPEC_UX_MODEL) keeps its pre-exported value; rest stay at defaults. Test: strips `SPEC_UX_MODEL` from the fixture example (`grep -v '^SPEC_UX_MODEL='`), writes local override, unsets all 8, pre-exports SPEC_UX_MODEL, sources example then local, resolves every agent with the **real pinned opencode binary**, wants spec-specifier=file override / spec-ux=pre-exported / others=defaults. The subtle case is faithfully asserted, including proving later-line-wins against the actual binary. ✓
3. **AC-025-03-03 (parent override never propagates)** — `scripts/model-env.selftest.sh:444-459`. Scenario: standards git index lists neither real env file; `.standards`-relative line resolves against committed example only. Test: asserts the actual standards repo index (`git ls-files` lists neither `config/model.local.env` nor `config/agent.local.env`) and that the child emulation resolves all 8 defaults with rc 0. ✓
4. **AC-025-04-04 / AC-025-04-05 (PR Opener presence check; CI sweeper dotenv-equivalent)** — `agents/spec-pr-opener.md:46-52`: "verify `$GITHUB_TOKEN` and `$GH_TOKEN` are both non-empty before the first commit or push … If either is missing, report and stop … There is no env script to source." `.github/workflows/ci-sweeper.yml:65`: `set -a; . config/model.local.env.example; set +a` replaces `source scripts/load-model-env.sh`. Both match their scenarios' Then-clauses. ✓

Result: all spot-checked tests assert what their scenarios say. No false-green found.

---

## Evidence: no unaccounted behavior (diff skim — finding lines, not a command)

Skimmed the full diff (`git diff HEAD`, 18 files, +1013/−735). Every change traces to a task:
- `.gitignore` (+.envrc line, Task 1) · `templates/.envrc.example` + `.envrc.child` (new, Tasks 1/3) · `scripts/check-model-env.sh` (Check 2 loop over both real env files, Task 5) · `scripts/model-env.vars.sh` (header note, Task 4) · `scripts/bootstrap.sh` (child .envrc + child .gitignore + child config/.gitignore + next-steps list, Task 3) · `scripts/model-env.selftest.sh` / `model-env.runtime-check.sh` / `agent-env.selftest.sh` (Tasks 2/3/5/6) · `scripts/load-env.sh` / `scripts/load-model-env.sh` (deleted, Task 4) · `agents/spec-pipeline.md` / `agents/spec-pr-opener.md` (loader purge + presence check, Task 4) · `.github/workflows/ci-sweeper.yml` (dotenv-equivalent, Task 4) · `config/*.env.example` (headers, Task 4) · `AGENTS.md` / `README.md` / `docs/SPEC_PIPELINE.md` / `docs/adr/README.md` (Task 7) · `docs/adr/0001-direnv-model-env.md` (new, Task 7).
- No logic exists that lacks a task/scenario anchor. The AGENTS.md model table is unchanged (`git diff HEAD -- AGENTS.md` adds zero lines containing a model id — grep exit 1).
- No unaccounted behavior found.

---

## User-requested supplementary checks

### Loaders truly gone / purge (check 3)
- `git ls-files --error-unmatch -- scripts/load-env.sh scripts/load-model-env.sh` → exit 1 (neither in the index); neither file exists on disk. ✓
- `grep -rn -- '--emit' scripts/ templates/ agents/ .github/ config/ README.md AGENTS.md docs/SPEC_PIPELINE.md` → zero matches. ✓
- `grep -rn -- 'load-env\|load-model-env'` over the same live surface → zero matches. ✓
- Repo-wide enumeration of every remaining loader/`--emit` reference (excluding `.git/`, `specs/`): only `docs/changes/013-agent-local-env.md`, `docs/changes/020-model-config-env.md` (historical archives — the spec's Task 4 live-surface definition excludes `docs/changes/` entirely; 020 additionally exempted by name), and `docs/adr/0001-direnv-model-env.md` (describes the replaced loader design in its Context/Alternatives — required by AC-025-07-04). ✓

### .envrc / real env files git state (check 4)
- `.envrc` on disk: absent here (was removed with the old design; the acceptance criteria hold vacuously and the selftest notes "stale-copy guard trivially satisfied").
- `git ls-files --error-unmatch -- .envrc` → exit 1 (untracked). `git check-ignore -- .envrc` → exit 0 (ignored). `.gitignore` line 32: `.envrc` (matches `^\.envrc$`). `git ls-files` filtered for `.envrc` → only `templates/.envrc.example` + `templates/.envrc.child` (both new/untracked, committable). ✓
- `config/model.local.env`, `config/agent.local.env`: `git ls-files --error-unmatch` → exit 1 for both (not tracked); `git check-ignore` → exit 0 for both (ignored); neither on disk. Examples: `git check-ignore` → exit 1 for both (committable). ✓

### ADR (check 5)
- `docs/adr/0001-direnv-model-env.md` Status: **Accepted** (line 9). Content: pure `dotenv_if_exists` (no loaders, no `--emit` — deleted), `.envrc` gitignored per-machine, committed templates as the only committed `.envrc` surface, later-lines-win precedence with accepted clobber, parent/child inheritance, rejected alternatives (shell-profile status quo; the loader-`--emit` design), consequences, compliance (check-model-env.sh, selftest, runtime-check). Matches AC-025-07-04 and the 10-tasks.md Task 7 criteria. ✓
- `docs/adr/README.md` index now lists ADR 0001 with status Accepted (AC-025-07-05). ✓

### Other gates (all executed, real exit codes)
- `bash scripts/check-model-env.sh` → exit 0, "PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired." ✓
- `bash scripts/check-orchestration.sh` → exit 0, "All orchestration references valid." ✓
- `bash scripts/check-no-hardcoded-secrets.sh` → exit 0, "PASS check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/." ✓
- `bash scripts/guard-env.sh` → exit 0, "PASS guard-env: no config/agent.local.env in the scanned set (tracked mode)." ✓

### Claim check: 67 / 21 / 4 assertions
Confirmed by actual runs: model-env.selftest "67 passed, 0 failed"; agent-env.selftest "21 passed, 0 failed"; model-env.runtime-check "4 passed, 0 failed". All 48 AC-025-* scenario IDs carried (48 unique cited in model-env.selftest.sh; runtime-check 3; agent-env 2; union 48, zero dangling).

---

## Review hints (WARN-level, non-blocking — flagged to the Architect)

1. `templates/.envrc.child` line 15: comment typo "the PARENT.s committed defaults" → "the PARENT's committed defaults". Comment-only, zero functional impact.
2. Pre-existing baseline findings that this gate is not responsible for but the Architect should schedule remediation on: (a) the 5 cyclomatic-complexity FAILs + 17 WARNs in `ci/templates/go-saga-lint.go` / `eslint-saga-rules/saga-compensation.js` / `archunit/*.java`; (b) the archived-spec citation FAILs of `check-scenario-traceability.sh` (AC-001…022, AC-888/998/999) — both classes predate this spec (byte-identical to HEAD, files untouched by spec 025) and are documented in docs/changes/007/008/009/015/019.

---

## Verdict

**PASS**

Every gate ran with real execution. This spec's implementation is green under every gate's own scoped judgment:

| Gate | Full-tree exit | Spec-attributable findings | Verdict for spec 025 |
|---|---|---|---|
| Scenario traceability | 1 (pre-existing baseline: archived-spec citations in `docs/changes/` + worked-example IDs, all in unmodified files; `--checks 1` alone exits 0; zero AC-025 issues in either direction; 48/48 sub-IDs cited, zero dangling) | none | PASS |
| Full test suite (selftest 67, agent-env 21, runtime-check 4 w/ pinned binary) | 0 | — | PASS |
| check-model-env.sh | 0 | — | PASS |
| check-orchestration.sh | 0 | — | PASS |
| check-no-hardcoded-secrets.sh | 0 | — | PASS |
| guard-env.sh | 0 | — | PASS |
| check-code-principles.sh (complexity + KISS/DRY/YAGNI/SOLID) | 1 (5 FAILs + 17 WARNs, all in untouched `ci/templates/*`, byte-identical to HEAD; `-BaseRef HEAD` scoped run exits 0 with `fails: [], warns: []`) | none | PASS (pre-existing baseline flagged to Architect per docs/changes/007 precedent) |

Notes for the human/Architect: both script gates' full-tree exit codes are non-zero purely from pre-existing baseline findings in files this spec does not touch — proven by the gates' own scoped modes and byte-identical HEAD comparison, and consistent with the repo's documented handling of the identical state in prior archived pipelines (spec 007/008/009/015/019). If the repo policy instead demands a globally green gate before any pipeline proceeds, that is a pre-existing condition on main, not a spec-025 defect; remediation targets `ci/templates/*` and the archived-spec citation policy.

Architect may proceed (stage 5a — Mutation Runner; at `mvp` tier it is skipped per CONFORMANCE_TIERS.md, so stage 5b — PR Opener — may proceed directly).

## Quality gates

# Mutation Runner Report — spec 025 (direnv model env)

Stage: 5a (Mutation Runner). Branch: `spec/025-direnv-model-env` (nothing committed). `00-informal.md` was not read.

## Verifier's verdict

PASS (carried forward from `specs/025-direnv-model-env/25-verification.md`, verdict at 2026-08-19, all five checks recorded with real execution: scenario traceability, full test suite, complexity gate, design-principles gate, scenario-to-behavior spot check).

## Conformance tier

`mvp`.

Determination: mutation testing is a `production`-tier rule (`docs/CONFORMANCE_TIERS.md` §Tier assignments — "Mutation testing (PiTest / Gremlins / Stryker): production"). This repo is the engineering-standards project — bash/shell scripts + docs, no deployed service, no staging/prod split, no service boundaries — so it does not meet the `production` profile (deployed to a real environment with users). The Verifier's own design-principles gate run records `"tier": "mvp"` in its JSON output. The repo's test surface is the shell selftests; there is no Java/Go/JS-TS production code and no configured mutation toolchain (no `mvn`/PiTest, no `go-mutesting`/`gremlins`, no Stryker config).

## Mutation testing

mutation: skipped — `mvp` tier
command: (none — mutation testing is a `production`-tier gate per docs/SPEC_PIPELINE.md §Conformance tiers; this project declares `mvp`, so the mutation test is skipped by policy, not run)
at: 2026-08-19T14:57:36Z

## Equivalent mutants

None. No mutation run was performed at `mvp` tier, so no mutants were generated and none survived; there are no equivalent mutants to name.

## Complexity summary (carried from the Refactorer, re-recorded by the Verifier in `25-verification.md` §Evidence: complexity gate)

- Gate: `bash scripts/check-code-principles.sh --json` → exit 1.
- 5 FAILs + 17 WARNs, all in `ci/templates/*` files untouched by this spec (`git status` shows no changes under `ci/`).
- Spec-attributable findings: zero — the gate's blame-scoped mode `bash scripts/check-code-principles.sh --json -BaseRef HEAD` → exit 0, `"fails": [], "warns": []`.
- Pre-existing baseline (documented repo precedent: docs/changes/007-verifier-discipline.md §Check 3.5): byte-identical to HEAD, in files this spec does not touch. Flagged to the Architect as a pre-existing remediation item, not a spec-025 defect.

## Final test status (full suite, re-run one final time by the Mutation Runner)

command: bash scripts/model-env.selftest.sh; bash scripts/agent-env.selftest.sh; bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode
exit: 0
at: 2026-08-19T14:57:36Z

```
scripts/model-env.selftest.sh:      selftest: 67 passed, 0 failed  → exit 0
scripts/agent-env.selftest.sh:      selftest: 21 passed, 0 failed  → exit 0
scripts/model-env.runtime-check.sh: runtime-check: 4 passed, 0 failed → exit 0 (pinned opencode binary v1.18.18)
Total: 92 assertions green, all three scripts exit 0.
```

Every acceptance scenario (48/48 AC-025-* sub-IDs, zero dangling) is cited and green; no tests skipped.

## Remediation record

None. No BLOCK occurred during this Mutation Runner run. `25-verification.md` contains no re-verification attempt entries (no phase/attempt counts to carry forward), so per the agent contract the record is `none` rather than a fabricated phase and attempt count. The pre-existing baseline findings (ci/templates complexity FAILs, archived-spec traceability citations) were flagged to the Architect by the Verifier as remediation items, not BLOCKs of this run.

PR: https://github.com/RexiAI/my-engineering-standards/pull/41
Commits: 7
