# 10-tasks — 035-child-project-standards-updater

## The ask (verbatim)

> New feature: script to update all child projects that uses this submodule if possible

## Grounded context (do not re-derive)

- `scripts/update-submodules.sh` already exists and does the following: accepts
  repo paths, a `repo-list.txt`, or `--auto`; checks each repo's `.gitmodules`
  for the `.standards` submodule; runs `git submodule update --remote .standards`;
  commits locally when the pointer moved. It does **not** push or open PRs, and
  `--auto` only discovers repos within the current directory tree
  (`find . -maxdepth 2`). The shell-test harness (`scripts/tests/README.md`)
  documents it as *uncharacterized* because it mutates repos and needs network.
- On this machine, 12 sibling directories under `/home/dbueno/projects/` are git
  repos whose `.gitmodules` reference `standards`. The standards repo lives at
  `/home/dbueno/projects/my-engineering-standards/`, so `--auto` run from inside
  it does **not** find those siblings.
- Repo standard: all changes reach `main` only via pull request; direct push to
  `main`/`master` is forbidden for humans and agents. A child project's own
  PR-only policy applies to changes made inside that child.

## Resolved decisions (Q1–Q6)

- **Q1 — discovery.** Add `--parent-dir <dir>`. Default is the parent directory
  of the standards repo root, derived from the script's own location (never the
  caller's cwd), so the sibling repos are discovered without being listed.
  Discovery scans **immediate** child directories of that parent (one level, not
  recursive) and selects git repos whose `.gitmodules` declares `.standards`.
  Existing inputs are preserved: explicit path args, `repo-list.txt`, and
  `--auto` (which stays cwd-relative).
- **Q2 — progression.** Default per child: create a deterministic, namespaced
  feature branch (`chore/bump-engineering-standards`), commit the pointer bump,
  push the branch, open a PR via `gh pr create`. Never push `main`/`master`. A
  re-run is idempotent: it reuses the same branch and the existing open PR
  rather than creating duplicates. `--local` retains the old behavior: local
  commit only, no push, no PR.
- **Q3 — scope.** Pointer-only. The script does **not** re-run `bootstrap.sh`
  and does not refresh copied agents / hooks / CI templates. Recorded as a
  possible follow-up spec, not in scope here.
- **Q4 — dirty/diverged.** Skip the child, continue the run, report it with a
  distinguishable status. Never stash, reset, checkout, clean, or auto-commit
  unrelated work. A diverged local branch is treated the same as dirty: skip and
  report.
- **Q5 — failure / exit code.** A child with no remote or no network is skipped,
  the run continues, and the failure is recorded in the summary. Exit code
  contract: `0` = every eligible child succeeded, or no child was eligible;
  `1` = at least one eligible child failed; `2` = usage error.
- **Q6 — testability.** Add `--dry-run` plan-only mode: discovery + eligibility
  checks, then print the planned action per child, with no network calls, no
  commits, no pushes, no PRs. Refactor decision logic so it is hermetically
  testable, and add a bats suite using local `git init` fixtures with `file://`
  submodule remotes (no real child repo, no network). Update the
  `scripts/tests/README.md` "Not characterized" entry accordingly.

## Implementation constraints

- Extend `scripts/update-submodules.sh`; do **not** add a second parallel script.
  Discovery and eligibility logic have exactly one implementation, shared by all
  input modes.
- Preserve the existing invocations as working forms: explicit path args,
  `repo-list.txt`, and `--auto`.
- Never `git init`, never create a `.gitmodules`, never create/register a
  `.standards` submodule — only update an existing one (Stop-and-Ask matrix).
- Never create git tags (CI owns versioning).

## Flags

- `--parent-dir <dir>` — scan immediate children of `<dir>`.
- `--auto` — cwd-relative `find . -maxdepth 2` (backward compatible).
- `--local` — local commit only; no branch, push, or PR.
- `--dry-run` — plan only; print, never mutate or touch the network.

## Discovery resolution order (first match wins)

1. Explicit non-flag repo path arguments.
2. `--parent-dir <dir>`.
3. `--auto`.
4. `repo-list.txt` at the repo root (script-relative).
5. Default: the parent directory of the standards repo root (the script's own
   location's parent).

## Exit-code contract

- `0` — success: every eligible child succeeded, or no child was eligible.
- `1` — at least one eligible child failed (no submodule remote, non-GitHub child
  remote in default mode, `gh` unavailable in default mode, fetch/network failure).
- `2` — usage error (unknown flag, or `--parent-dir` naming a non-existent / non-
  directory path).

---

## Task 1 — Child-project eligibility detection

Determine, per candidate path, whether it is an updatable child project. A
candidate is updatable iff it is a git repository (`.git` directory or file)
*and* its `.gitmodules` declares a `.standards` submodule.

Acceptance criteria:

- A candidate that is not a git repository is skipped, reported with a
  distinguishable status line, and does not abort the run; final exit is `0`.
- A git repository with no `.gitmodules` is skipped and reported.
- A git repository whose `.gitmodules` does not declare a submodule at path
  `.standards` is skipped and reported.
- A git repository whose `.gitmodules` declares `.standards` is eligible and
  proceeds to the update step.
- The script performs no `git init`, no `.gitmodules` creation, and no submodule
  registration on any candidate.

Scenarios: `AC-035-01` … `AC-035-04` (`20-acceptance/AC-035-eligibility.md`).

---

## Task 2 — Uninitialized-submodule guard

Handle a child that declares `.standards` but has never initialized it.

Acceptance criteria:

- When `git submodule status .standards` reports the submodule uninitialized
  (leading `-`), the child is skipped and reported with a hint naming
  `git submodule update --init .standards`.
- The script does not initialize the submodule itself.

Scenarios: `AC-035-05` (`20-acceptance/AC-035-uninitialized-guard.md`).

---

## Task 3 — Submodule pointer update and commit

Fetch the `.standards` remote and move the child's pointer, committing only when
the pointer actually changed. This is the mode-independent core shared by the
default (branch+push+PR) and `--local` paths; which branch the commit lands on is
Task 6's concern.

Acceptance criteria:

- The script runs `git submodule update --remote .standards` in the child.
- When the pointer moves, a local commit is created whose message is a
  conventional `chore:` commit naming the standards submodule (e.g.
  `chore: bump engineering standards submodule`).
- The commit touches only the `.standards` pointer; no other tracked file is
  modified.
- When the pointer is unchanged, no commit is created and the child is reported
  as already at latest.

Scenarios: `AC-035-06`, `AC-035-07` (`20-acceptance/AC-035-pointer-update.md`).

---

## Task 4 — Child-project discovery

Resolve the set of candidate paths per the discovery resolution order, and scan
a parent directory's immediate children.

Acceptance criteria:

- `--parent-dir <dir>` scans only the immediate child directories of `<dir>`
  (one level deep); a repository two levels deep is not discovered.
- The scan selects git repositories whose `.gitmodules` declares `.standards`,
  and ignores non-git directories and git repositories without `.standards`.
- With no explicit paths, no `--parent-dir`, no `--auto`, and no `repo-list.txt`,
  the default root is the parent of the standards repo root, derived from the
  script's own location — the caller's cwd does not affect discovery.
- Explicit non-flag path arguments cause only those paths to be processed (no
  additional discovery).
- `repo-list.txt` (script-relative, one path per line, `#` comments and blank
  lines ignored) remains a working input when no higher-precedence input is
  given.
- `--auto` remains cwd-relative (`find . -maxdepth 2`), unchanged.

Scenarios: `AC-035-08` … `AC-035-12` (`20-acceptance/AC-035-discovery.md`).

---

## Task 5 — Dirty / diverged child handling

Refuse to touch a child whose working tree or branch state is not clean.

Acceptance criteria:

- A child with uncommitted changes (dirty working tree or staged-but-uncommitted
  changes) is skipped, reported with a distinguishable status, and the run
  continues.
- The script never stashes, resets, checks out, cleans, or commits unrelated work;
  the child's uncommitted changes are left exactly as found.
- A child whose local branch has diverged from its upstream is treated the same
  as dirty: skipped and reported.

Scenarios: `AC-035-13`, `AC-035-14` (`20-acceptance/AC-035-dirty-diverged.md`).

---

## Task 6 — Progression: branch, push, PR, and `--local`

Carry the pointer bump through to a pull request in default mode, or stop at a
local commit under `--local`.

Acceptance criteria:

- Default mode: for an eligible, clean child whose pointer moved, the script
  creates/uses the deterministic branch `chore/bump-engineering-standards`,
  commits the pointer bump on it, pushes that branch (never `main`/`master`), and
  opens a PR from it against the child's default branch via `gh pr create`.
- Default mode: if the pointer is unchanged, no branch, commit, push, or PR is
  created and the child is reported as already at latest.
- Re-run idempotency: if the branch already exists and an open PR for it already
  exists, the re-run reuses both and creates no duplicate branch or duplicate PR.
- `--local`: the script commits the pointer bump on the current branch and
  performs no branch creation, no push, and no PR.

Scenarios: `AC-035-15` … `AC-035-17` (`20-acceptance/AC-035-progression.md`).

---

## Task 7 — Per-child failure handling and exit codes

Turn any eligible-child failure into a skip-and-continue with a recorded failure
and the agreed exit code.

Acceptance criteria:

- A child whose `.standards` submodule has no remote configured is skipped,
  reported failed with a reason, the run continues, and the summary records the
  failure; exit code `1`.
- In default mode, a child whose remote is not GitHub, or where `gh` is
  unavailable, is skipped and reported failed with a reason; exit code `1`.
  (`--local` does not require a GitHub remote or `gh`.)
- A network failure during `git submodule update --remote` is skipped, reported
  failed with a reason, the run continues; exit code `1`.
- A run where some children succeed and some fail reports both in the summary and
  exits `1`.
- A run where discovery selects zero eligible children exits `0`.
- `--parent-dir <dir>` naming a non-existent path or a non-directory is a usage
  error: message to stderr, exit `2`.
- The final summary reports success and failure counts and names each failed
  child with its reason.

Scenarios: `AC-035-18` … `AC-035-23` (`20-acceptance/AC-035-failure-exit-codes.md`).

---

## Task 8 — `--dry-run` plan-only mode

Perform discovery and eligibility checks and print the planned action per child,
without any side effects.

Acceptance criteria:

- `--dry-run` prints, for each candidate, the action that would be taken
  (update with branch/push/PR in default mode, local commit in `--local`, or a
  skip with its reason), but creates no branch, no commit, no push, and no PR.
- `--dry-run` makes no network calls: it must complete even when a child's
  `.standards` remote is unreachable, and must not fetch from it.
- `--dry-run` composes with the existing flags (`--parent-dir`, `--auto`,
  `--local`, explicit paths) and is reported by `--help`/usage text.

Scenarios: `AC-035-24`, `AC-035-25` (`20-acceptance/AC-035-dry-run.md`).

---

## Task 9 — Hermetic testability, bats suite, and README update

Make the decision logic testable without network or real child repos, and
characterize the script.

Acceptance criteria:

- Decision logic (discovery root derivation, eligibility, dirty/diverged
  detection, branch-name derivation, per-child action selection) is factored so
  it can be exercised without network or mutation of real repos.
- A bats suite under `scripts/tests/` exercises the acceptance scenarios using
  local `git init` fixtures and `file://` submodule remotes; no test touches the
  network or a real sibling repo.
- `scripts/tests/README.md`'s "Not characterized" table entry for
  `update-submodules.sh` is updated to reflect the new characterization (or
  removed, if fully characterized).

Scenarios: `AC-035-26` (`20-acceptance/AC-035-testability.md`).
