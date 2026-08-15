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
