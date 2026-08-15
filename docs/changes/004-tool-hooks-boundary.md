# 004-tool-hooks-boundary

> Spec pipeline archive. Original source: `specs/004-tool-hooks-boundary/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# 004 — Tool hooks: gate every bash and edit

## Why

The spec pipeline has no per-tool guards today. An agent can edit a file
outside its plan and the diff goes out. An agent can `git push` from
`main` and skip the `spec/NNN-slug` convention. An agent can skip a build
check between commits and CI only catches the failure later.

Reference: ACDC solves this with `hooks.json`
(`preToolUse`/`postToolUse` matchers wired to the harness) plus a
`pre-push` Git hook that runs the fast gate subset before push. The
harness from Phase B already exists by the time this lands.

This is **Phase C**. It depends on Phase B (the gate-runner must exist
before the hook can call it).

## What I want

A new `agents/hooks/` directory containing:

- `hooks.json` — `preToolUse` matcher `bash|powershell` → guard calls
  `scripts/gates/find-harness.sh` then `gate-runner.sh -Phase local
  -Gates G0,G6,S1` on each shell-out, BLOCK on failure. `postToolUse`
  matcher `edit|create` → format-guard (delegates to the project's own
  format command; soft WARN if absent).
- `pre-push` — Git hook that runs
  `gate-runner.sh -Phase local -Gates G0,G1,G6,S1` on the spec branch.
  Aborts the push on BLOCK. Activated via
  `git config core.hooksPath agents/hooks`.
- `commit-msg` — validates Conventional Commits prefix on `spec/*`
  branches. Bypassable via `git commit --no-verify` (logged, not
  blocked).
- `find-harness.sh` + `format-guard.sh` — local copies that delegate to
  `scripts/gates/` so the hooks resolve the same way everything else
  does.

Plus an `init-ci.sh --with-hooks` flag for child repos: copies the hooks
into the child repo's `agents/hooks/`, sets `core.hooksPath`.

Every hook is wrapped in a soft-fail pattern (`sh -c '[ -f "$0" ] ||
exit 0; sh "$0"'`) so a partial install never breaks an agent tool call.

## What I don't want

- Any change to existing `.git/hooks/*`. The new hooks live under
  `agents/hooks/` and are activated via `core.hooksPath`.
- A `[JIRA-ID]` prefix in `commit-msg` — this repo has no Jira
  convention.
- Hook enforcement on `main`/`develop`. Spec pipeline agents are the
  only intended consumers.
- Cross-tool wiring beyond `bash|powershell|edit|create`. Future tools
  (file search, network) are out of scope.

## Out of scope

- Changes to any agent spec (those are Phase D).
- New gate implementations (Phase B).

## How child repos will use this

`init-ci.sh --with-hooks` installs them. A child repo that does not run
init-ci.sh will still vendor the files (submodule bump), but no hook
fires. Activation is opt-in.

## Dependency

Phase B's `scripts/gates/` exists before this lands.

## Tasks

# 004 — Tool hooks: Tasks

Hooks at the tool boundary (`bash|powershell|edit|create`) and on Git
(`pre-push`, `commit-msg`). Soft-fail defaults: a missing harness is a
no-op, never a hard fail.

## Dependency order

1. **Task 1** (`agents/hooks/`) is the spine; implement first.
2. **Task 2** (`init-ci.sh --with-hooks`) wires activation for child
   repos.
3. **Task 3** (`gitignore` for `.civ/`, `.civ-dryrun/`) depends on
   Phase B's work (already merged or in the same change).
4. **Task 4** (verify) runs last.

---

## Task 1 — Author the hook files

Create `agents/hooks/`:

- `hooks.json` — `preToolUse` matcher `bash|powershell` → guard.
  `postToolUse` matcher `edit|create` → format guard. Both wrapped
  in `sh -c '[ -f "$0" ] || exit 0; sh "$0"'` soft-fail.
- `find-harness.sh` — delegates to
  `scripts/gates/find-harness.sh`.
- `format-guard.sh` — detects the project's format command
  (Makefile/npm/maven) and runs it. SKIP with no-op output if absent.
- `pre-push` — Git hook. On `spec/NNN-slug` branches, runs
  `gate-runner.sh -Phase local -Gates G0,G1,G6,S1`. BLOCK → exit
  `1`. Otherwise exit `0`.
- `commit-msg` — Conventional Commits regex:
  `^(feat|fix|chore|docs|test|refactor|perf|build|ci|style|version)\([^)]+\): .+`.
  Reject bad messages; bypass via `--no-verify` (logged).

Acceptance criteria:

- All five files exist under `agents/hooks/`.
- A `bash` tool call with the harness present and BLOCK result does
  not execute the tool call (test via `agents/hooks/hooks.json`
  `preToolUse` smoke test).
- A `bash` tool call with the harness absent is a no-op.

---

## Task 2 — Wire init script

`scripts/init-ci.sh --with-hooks`:

- Copies `agents/hooks/*` into the child repo's `agents/hooks/`
  (no-op if already there).
- Runs `git config core.hooksPath agents/hooks`.
- Aborts if `.git/hooks/pre-push` exists; the user must remove it
  first.
- Updates `--help` text.

Acceptance criteria:

- `init-ci.sh --help` mentions the new flag.
- On a child repo without hooks, the flag installs them; existing
  child `.git/hooks/*` are not touched.
- On a child repo with an existing pre-push, the flag aborts with
  the instructions.

---

## Task 3 — Gitignore updates

Add to root `.gitignore`:

- `.civ/` (harness state directory).
- `.civ-dryrun/` (dry-run scratch directory).

Acceptance criteria:

- Both paths are listed.
- `git status` does not show `.civ/` or `.civ-dryrun/` even after a
  runner run.

---

## Task 4 — Verify before merge

Manual tests on a test branch:

- Bad commit message (`random commit`) → `commit-msg` rejects.
- Branch with a flipped scenario → `git push` aborts.
- Clean branch → hooks run, never BLOCK.
- With `scripts/gates/` removed → hooks are silent no-ops.

Acceptance criteria:

- All four manual tests pass.

## Acceptance scenarios

## AC-001-01 — `agents/hooks/hooks.json` declares both matchers
## AC-001-02 — `find-harness.sh` and `format-guard.sh` exist
## AC-001-03 — `pre-push` invokes the gate-runner with the fast subset
## AC-001-04 — `commit-msg` enforces Conventional Commits
## AC-001-05 — Soft-fail pattern works
## AC-002-01 — `--help` documents the flag
## AC-002-02 — Flag installs hooks on a clean child repo
## AC-002-03 — Flag aborts on conflict with existing pre-push
## AC-003-01 — `.civ/` is gitignored
## AC-003-02 — `.civ-dryrun/` is gitignored
## AC-003-03 — `git status` stays clean after a runner run
## AC-004-01 — Bad commit message is rejected
## AC-004-02 — Push aborts on a flipped gate
## AC-004-03 — Clean branch hooks run but do not BLOCK
## AC-004-04 — Missing harness is silent

## Verification

# 004 — Verification

Populated by `spec-verifier` after Coder + Refactorer finish.

## Re-execution checklist

- [ ] `agents/hooks/hooks.json` validates against the expected
  schema (preToolUse bash, postToolUse edit|create)
- [ ] `agents/hooks/find-harness.sh` exists and exits `0`
- [ ] `agents/hooks/format-guard.sh` exists
- [ ] `agents/hooks/pre-push` runs `gate-runner.sh -Phase local
  -Gates G0,G1,G6,S1` on a `spec/*` branch
- [ ] `agents/hooks/commit-msg` enforces the Conventional Commits
  regex `^(feat|fix|chore|docs|test|refactor|perf|build|ci|style|version)\([^)]+\): .+`
- [ ] Soft-fail pattern works when `scripts/gates/gate-runner.sh`
  is removed
- [ ] `scripts/init-ci.sh --help` mentions `--with-hooks`
- [ ] `.gitignore` contains `.civ/` and `.civ-dryrun/`
- [ ] `git status --porcelain` stays clean after a runner run

## Manual end-to-end

- [ ] Bad commit message rejected (`commit-msg`)
- [ ] Push aborts on a flipped gate
- [ ] Push succeeds on a clean branch (hooks run, never BLOCK)
- [ ] Missing harness is silent

## Verdict

- [ ] PASS
- [ ] FAIL

## Quality gates

# 004 — Architect Report

## Manual end-to-end results

| Path | Branch | Outcome |
|---|---|---|
| PASS path | `spec/NNN-test-hooks` | Push succeeded |
| BLOCK path (flipped scenario) | `spec/NNN-test-hooks-blocked` | Push aborted with gate IDs |

## Gate results

(Populated by `spec-architect`.)

## Branch / commit summary

- Branch: `spec/004-tool-hooks-boundary`
- Commit count: _(populated by Architect)_
- Tasks touched: 4 of 4

## Verdict

(Populated by `spec-architect`.)
