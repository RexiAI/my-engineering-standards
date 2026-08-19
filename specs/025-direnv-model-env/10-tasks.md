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
