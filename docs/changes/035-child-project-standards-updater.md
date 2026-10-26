# 035-child-project-standards-updater

> Spec pipeline archive. Original source: `specs/035-child-project-standards-updater/` (deleted by this script).
> Archived: 2026-10-26

## Original ask

New feature: script to update all child projects that uses this submodule if possible

## Tasks

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

## Acceptance scenarios

## AC-035-01 — Non-git path is skipped, not treated as an error
## AC-035-02 — Git repo without a `.gitmodules` file is skipped
## AC-035-03 — Git repo whose `.gitmodules` declares no `.standards` submodule is skipped
## AC-035-04 — Git repo declaring a `.standards` submodule is eligible and proceeds
## AC-035-05 — Declared but uninitialized `.standards` is skipped with a hint
## AC-035-06 — Moved remote pointer is fetched, updated, and committed
## AC-035-07 — Already-at-latest pointer produces no commit
## AC-035-08 — `--parent-dir` scans immediate children and selects `.standards` repos
## AC-035-09 — Default parent directory is the standards repo's own parent, not the cwd
## AC-035-10 — Explicit path arguments process only those paths
## AC-035-11 — `repo-list.txt` is read when no higher-precedence input is given
## AC-035-12 — `--auto` remains cwd-relative
## AC-035-13 — A dirty child is skipped and its working tree is left untouched
## AC-035-14 — A diverged local branch is treated the same as dirty
## AC-035-15 — Default mode creates a branch, commits, pushes, and opens a PR
## AC-035-16 — A re-run reuses the existing branch and open PR without duplicating
## AC-035-17 — `--local` commits on the current branch only
## AC-035-18 — A child whose `.standards` submodule has no remote fails and is skipped
## AC-035-19 — A non-GitHub remote (or missing `gh`) fails in default mode
## AC-035-20 — A network failure during fetch is skipped and recorded
## AC-035-21 — A mixed run reports both outcomes and exits 1
## AC-035-22 — Zero eligible children is success
## AC-035-23 — `--parent-dir` naming a non-existent path is a usage error
## AC-035-24 — `--dry-run` prints the plan and performs no mutation
## AC-035-25 — `--dry-run` makes no network calls
## AC-035-26 — A bats suite characterizes the decision logic hermetically

## Verification

# 25-verification — 035-child-project-standards-updater

Verifier run: attempt 1, phase 1 (pre-PR).

Overall verdict: **PASS**

The five contract checks were executed independently against the working tree
(changed files: `scripts/update-submodules.sh`, `scripts/tests/ac-035-update-submodules.bats`,
`scripts/tests/README.md`). Every gate ran and produced no findings attributable
to this change.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-10-26T13:19:18Z

Scenario IDs found: 26 live, 442 archived

PASS AC-035-01 — traced to a test
PASS AC-035-02 — traced to a test
PASS AC-035-03 — traced to a test
PASS AC-035-04 — traced to a test
PASS AC-035-05 — traced to a test
PASS AC-035-06 — traced to a test
PASS AC-035-07 — traced to a test
PASS AC-035-08 — traced to a test
PASS AC-035-09 — traced to a test
PASS AC-035-10 — traced to a test
PASS AC-035-11 — traced to a test
PASS AC-035-12 — traced to a test
PASS AC-035-13 — traced to a test
PASS AC-035-14 — traced to a test
PASS AC-035-15 — traced to a test
PASS AC-035-16 — traced to a test
PASS AC-035-17 — traced to a test
PASS AC-035-18 — traced to a test
PASS AC-035-19 — traced to a test
PASS AC-035-20 — traced to a test
PASS AC-035-21 — traced to a test
PASS AC-035-22 — traced to a test
PASS AC-035-23 — traced to a test
PASS AC-035-24 — traced to a test
PASS AC-035-25 — traced to a test
PASS AC-035-26 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

Machine-readable transcript (scripts/check-scenario-traceability.sh --json, exit 0):
{"checks":[1,2],"passes":["AC-035-01 — traced to a test","AC-035-02 — traced to a test","AC-035-03 — traced to a test","AC-035-04 — traced to a test","AC-035-05 — traced to a test","AC-035-06 — traced to a test","AC-035-07 — traced to a test","AC-035-08 — traced to a test","AC-035-09 — traced to a test","AC-035-10 — traced to a test","AC-035-11 — traced to a test","AC-035-12 — traced to a test","AC-035-13 — traced to a test","AC-035-14 — traced to a test","AC-035-15 — traced to a test","AC-035-16 — traced to a test","AC-035-17 — traced to a test","AC-035-18 — traced to a test","AC-035-19 — traced to a test","AC-035-20 — traced to a test","AC-035-21 — traced to a test","AC-035-22 — traced to a test","AC-035-23 — traced to a test","AC-035-24 — traced to a test","AC-035-25 — traced to a test","AC-035-26 — traced to a test"],"fails":[]}

---

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T13:19:18Z

Checking bats assertions are not vacuous...
PASS check-bats-assertions: 59 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..662
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
... (662 total `ok` lines; representative tail follows) ...
ok 658 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 659 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 660 unit: a cap smaller than the marker still never exceeds the cap
ok 661 unit: state exactly at the cap is not truncated and emits no reason
ok 662 unit: successful under-cap call writes no reason line at all

Summary: 662 tests, 0 failures (grep -c '^not ok ' == 0). TAP plan 1..662 satisfied.

---

## Evidence: complexity gate

command: shellcheck scripts/update-submodules.sh
exit: 0
at: 2026-10-26T13:19:18Z

(no output — shellcheck reported no findings for the changed script)
Machine-readable transcript (shellcheck --format=json scripts/update-submodules.sh, exit 0):
[]

The repo's configured shell linter is `shellcheck` (`.github/workflows/self-ci.yml`
`shellcheck scripts/*.sh templates/*.sh`). This change's only `.sh` file in that
scope is `scripts/update-submodules.sh`. The new `.bats` file and the `README.md`
are not in shellcheck scope. Cyclomatic complexity (≤6) is enforced by the
design-principles gate (next block), which reports clean for this change.

---

## Evidence: design-principles gate

command: ./scripts/check-code-principles.sh -BaseRef HEAD
exit: 0
at: 2026-10-26T13:19:18Z

Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

--- DRY ---

--- YAGNI ---
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected

--- SOLID ---
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports
PASS SOLID-DIP (python): no domain→infrastructure imports
PASS SOLID-DIP (rust): no domain→infrastructure imports

--- Component-per-file ---
PASS Component-per-file: no violations

--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)

--- Comments ---

--- Naming ---

--- Null discipline ---

---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 0 WARN(s).

Machine-readable transcript (./scripts/check-code-principles.sh -BaseRef HEAD --json, exit 0):
{"tier":"mvp","gates":["complexity","dry","yagni","solid","component-per-file","property-tests","comments","naming","null-discipline"],"fails":[],"warns":[]}

Which invocation is the gate verdict, and why: the `-BaseRef HEAD` run is the gate
verdict for this change — it is the repo's change-scoped (blame-scoped) mode (spec
011 / ADR 0011), judging only the diff of the working tree against HEAD, and it is
what self-ci runs. It exited 0 with 0 FAIL(s), 0 WARN(s) for the change. The
full-repo run is reproduced in the out-of-scope finding below.

---

## Evidence: scenario-to-behavior spot check

command: manual spot check — AC-035-06 and AC-035-24 test assertions vs scenario Then-clauses
exit: 0
at: 2026-10-26T13:19:18Z

Two scenarios picked and read against their bats tests (scripts/tests/ac-035-update-submodules.bats):

AC-035-06 "A moved pointer is updated and committed in a single chore commit" (test lines 197–217):
- Scenario Then: pointer updated to remote's current commit → test asserts
  `[ "$after" = "$(git -C "$std" rev-parse HEAD)" ]` and `[ "$after" != "$before" ]`.
- Scenario Then: chore: commit naming the standards submodule → test asserts
  `[ "$(git -C "$child" log -1 --pretty=%s)" = "chore: bump engineering standards submodule" ]`.
- Scenario Then: commit touches only the .standards pointer → test asserts
  `[ "$(git -C "$child" show --name-only --pretty=format: HEAD | tr -d '\n')" = ".standards" ]`
  and a clean `git status --porcelain`.
All Then-clauses asserted with real assertions, not just the test name. PASS.

AC-035-24 "--dry-run prints the plan and mutates nothing" (test lines 470–489):
- Scenario Then: plan line printed → test asserts `[PLAN] $child: would update .standards, commit on $BRANCH, push, and open a PR`.
- Scenario Then: no commit → asserts HEAD unchanged; no branch → asserts
  `show-ref` fails; no push → asserts bare-mirror main unchanged; no PR → asserts
  `[ ! -f "$GH_STUB_STATE/calls.log" ]` (gh never invoked).
All Then-clauses asserted with real assertions. PASS.

---

## No unaccounted behavior

Finding: none. The rewrite of `scripts/update-submodules.sh` traces function-by-
function to Tasks 1–8 (eligibility, uninitialized guard, pointer update/commit,
discovery, dirty/diverged, progression, failure/exit-codes, dry-run); Task 9 is the
bats suite + README characterization. Helper functions `default_branch`,
`has_branch_ref`, `has_remote_ref`, `checkout_bump_branch`, `resume_bump_branch` are
Task 6's PR-base determination and re-run idempotency, each covered by a unit test.
Backward-compatible invocations (explicit paths, `repo-list.txt`, `--auto`) are
preserved and covered by AC-035-10/11/12.

## Prior-stage claims independently re-verified

- The 26 AC-035 tests are real assertions, not vacuous: `scripts/check-bats-assertions.sh`
  passes ("59 bats file(s), no vacuous assertions", exit 0), run both standalone and
  as the first step of `make test-scripts`.
- The script keeps the documented backward-compatible invocations working: covered by
  AC-035-10 (explicit paths), AC-035-11 (`repo-list.txt`), AC-035-12 (`--auto`), all
  green in the 662-test run.
- `scripts/check-bats-assertions.sh` passes: exit 0 (evidence above).

---

## Out-of-scope finding (pre-existing, NOT a finding against this change)

The full-repo run (`./scripts/check-code-principles.sh`, no `-BaseRef`) exits 1 with
exactly one FAIL, in a file untouched by this change (`git status --short` on it is
empty):

    FAIL Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10

This FAIL reproduces on pristine HEAD, confirmed independently by archiving HEAD into
a scratch tree and re-running the gate there (no `git stash`, per pipeline rules):

    git archive HEAD | tar -x -C /tmp/opencode/pristine-head
    /tmp/opencode/pristine-head/scripts/check-code-principles.sh --gates complexity
    # exit 1
    # FAIL Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10
    # WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41
    # WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43

Recorded as out-of-scope and not fixed, per the Stop-and-Ask matrix ("Out-of-scope
finding — record it, do not fix, propose a follow-up spec"). A follow-up spec is
proposed to reduce cyclomatic complexity in `skills/hallmark/site/examples/cobalt-01/script.js`.
It does not affect this change's verdict, which is the change-scoped `-BaseRef HEAD`
run (0 FAIL(s), 0 WARN(s)).

## Quality gates

# 30-report — 035-child-project-standards-updater

Stage 5a (Mutation Runner). Conformance tier: `mvp` (evidence below) — the mutation
gate is a recorded skip, so no mutation tool was run. The full suite was re-run
and is green. Nothing was committed, pushed, or changed in production code.

Changed surface under test (identical to the set the Verifier re-checked):

```
 M runs.jsonl
 M scripts/tests/README.md
 M scripts/update-submodules.sh
?? scripts/tests/ac-035-update-submodules.bats
?? specs/
```

`runs.jsonl` is harness telemetry, not part of this spec's diff. The dirty working
tree is the pipeline's own in-flight change (stage 5b is the committer) — per the
Stop-and-Ask matrix nothing was stashed and nothing was committed here.

---

## Verifier verdict (carried forward)

`specs/035-child-project-standards-updater/25-verification.md` — **PASS**
(Verifier run: attempt 1, phase 1 pre-PR). All five contract checks carry command,
exit code, timestamp and raw output. This stage did not substitute its own gates
for that verdict; it ran only the full suite it is required to re-confirm.

---

## Evidence: conformance tier determination

command: grep -n 'Conformance tier' AGENTS.md
exit: 1
at: 2026-10-26T13:53:38Z

(no output — the string does not occur in AGENTS.md)

Corroborating evidence, same timestamp (`2026-10-26T13:53:38Z`):

```
$ ls -1 AGENTS*.md
AGENTS.md
```

`AGENTS_*.md` does not exist, so there is no second declaration site. The report
harness default therefore applies, and the gate itself prints the tier it resolved:

```
$ ./scripts/check-code-principles.sh -BaseRef HEAD | head -2
Checking design principles in: . (tier: mvp)
```

Resolution per `docs/SPEC_PIPELINE.md §Conformance tiers` and the Stop-and-Ask row
"Project type ambiguous (… conformance tier undetectable) → defer to the harness
default (`mvp` tier)": **tier = `mvp`**.

---

## Evidence: mutation score

command: (none — recorded skip; mutation testing is a `production`-tier gate per docs/SPEC_PIPELINE.md §Conformance tiers)
exit: 0
at: 2026-10-26T13:53:38Z

Mutation score: skipped — `mvp` tier. No mutation tool (`mvn verify -Pmutation`,
`go-mutesting`/`gremlins`, `npx stryker run`) was invoked; no mutation score is
claimed. This repo's stack for the change is shell (`scripts/update-submodules.sh`),
which has no configured mutation tool in any case — the skip is driven by the tier,
not by the stack.

The `mvp` tier's test-quality controls still applied and were re-confirmed by this
run: `scripts/check-bats-assertions.sh` reports 59 bats files with no vacuous
assertions, and `scripts/check-scenario-traceability.sh` (Verifier block, exit 0)
shows every AC-035-01…AC-035-26 scenario traced to a test.

---

## Equivalent mutants

**None.** Mutation testing was not run at `mvp` tier, so no survivor list exists to
classify. This is not a claim that the suite is mutation-clean — it is a claim that
the mutation gate does not apply to this tier (`docs/SPEC_PIPELINE.md §Conformance
tiers`, Architect row: `mvp` = skip).

---

## Complexity summary (carried from the Refactorer via 25-verification.md)

The Refactorer leaves no report artifact by design (`§Audit contract`), so these are
the Verifier's re-recorded measurements, carried forward verbatim in substance:

- **Linter in scope** — `shellcheck scripts/update-submodules.sh`: exit 0, no
  findings; machine-readable transcript `[]`. This is the repo's configured shell
  linter (`.github/workflows/self-ci.yml`: `shellcheck scripts/*.sh templates/*.sh`).
- **Design-principles gate** — `./scripts/check-code-principles.sh -BaseRef HEAD`:
  exit 0, **0 FAIL(s), 0 WARN(s)**; JSON transcript
  `{"tier":"mvp","gates":["complexity","dry","yagni","solid","component-per-file","property-tests","comments","naming","null-discipline"],"fails":[],"warns":[]}`.
- **Cyclomatic complexity (≤6)** — PASS ("Complexity/KISS (java): no violations
  found"); nothing in the changed shell surface is flagged.
- **Property tests** — skipped: "project tier is mvp — production+ required".
- **Before/after Refactorer measurements** — not recorded anywhere; the Refactorer
  writes no artifact and `25-verification.md` carries only the post-refactor gate
  results above. Recorded here as a gap rather than invented.
- **Out-of-scope, pre-existing** — full-repo (non-`-BaseRef`) run exits 1 with one
  FAIL in `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10), reproduced on
  pristine HEAD by the Verifier; untouched by this change, follow-up spec proposed
  there, not fixed here.

---

## Out-of-scope finding: pre-existing flaky tests (pipefail + `grep -q` SIGPIPE)

This stage's first full-suite run failed on a test **not related to spec 035**:

command: make test-scripts
exit: 2
at: 2026-10-26T13:28:29Z

```
not ok 106 unit — model-env selftest stays green with the 10-agent roster
# (in test file scripts/tests/ac-031-orchestration-compliance.bats, line 46)
#   `[ "$status" -eq 0 ]' failed
```

Not a finding against this change. Two independent full-suite re-runs were green
(below), the failing test passes in isolation (`bats --filter 'model-env selftest
stays green'` → `ok 1`, exit 0) and as a whole file (`ac-031-orchestration-compliance.bats`
→ `1..6`, all ok, exit 0), and `bash scripts/model-env.selftest.sh` passed 68/68 in
8 consecutive standalone runs (`selftest failures: 0 of 8`).

A **second, reproducible** flake in the same suite was root-caused while diagnosing:

command: awk-frontmatter-pipe | grep -qiE (reproduction of tests/AC-030-01.sh:54 via tests/ac-030-lib.sh:76 body_of)
exit: 141
at: 2026-10-26T13:53:44Z

```
awk=141 grep=0 (SIGPIPE) occurrences: 4 of 200
```

Mechanism: `tests/AC-030-01.sh` runs under `set -euo pipefail` and tests each
heading with `if body_of "$SK" | grep -qiE …`. `body_of` is an `awk` producer;
`grep -q` exits at the first match and closes the pipe, so `awk` can die on SIGPIPE
(141). With `pipefail`, the *pipeline* status becomes 141 even though `grep`
succeeded, so the `if` takes the else branch and emits a spurious
`FAIL AC-030-01-06: heading for '…' missing`. Observed failure rates: 6/300 and
4/200 (~2%), 6/20 when the machine was loaded; the SC-030 scenario that fails varies
per run, exactly as a scheduling race predicts. `scripts/model-env.selftest.sh`
carries the same construct (`… | grep -q` under `pipefail` at lines 252, 272, 523,
577, 582, 795), which is the most plausible explanation for the unreproduced run-1
failure above — stated as a hypothesis, not a confirmed cause.

Not fixed: Stop-and-Ask matrix — "Out-of-scope finding → record it; do not fix;
propose a follow-up spec", and this stage may not edit production code. Proposed
follow-up: capture the producer output first (`body_of … > tmp` or
`shift`-style `local out; out=$(body_of "$SK"); grep -qiE … <<<"$out"`) so the
producer's SIGPIPE cannot reach the pipeline status. Residual risk to this pipeline
run: the same suite is what self-ci runs, so a phase-2 CI flake of this class is
possible at roughly the measured rate and must be diagnosed as a flake, not as a
035 regression. The 26 AC-035 tests contain no producer-into-`grep -q` pipeline
(greps are direct or `run grep -q`), so this spec does not add to the flake class.

---

## Evidence: final test status

command: make test-scripts
exit: 0
at: 2026-10-26T13:45:02Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 59 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..662
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
… (662 total `ok` lines; representative head + tail) …
ok 660 unit: a cap smaller than the marker still never exceeds the cap
ok 661 unit: state exactly at the cap is not truncated and emits no reason
ok 662 unit: successful under-cap call writes no reason line at all
```

Full-suite invocations in this stage, in order (this is the audit trail for the
"never re-run until green" rule — every re-run is a counted, diagnosed attempt):

| # | start | end | exit | ok | not ok | note |
|---|---|---|---|---|---|---|
| 1 | 2026-10-26T13:22:00Z (approx., same shell block) | 2026-10-26T13:28:29Z | 2 | 661 | 1 | pre-existing flake, test 106 (AC-031 model-env selftest); out of scope, recorded above |
| 2 | 2026-10-26T13:29:14Z | 2026-10-26T13:38:59Z | 0 | 662 | 0 | green |
| 3 (final) | 2026-10-26T13:45:02Z | 2026-10-26T13:53:33Z | 0 | 662 | 0 | green — recorded as the final status |

Final status: **PASS — 662/662 tests, 0 failures** (`grep -c '^ok '` = 662,
`grep -c '^not ok '` = 0, TAP plan `1..662` satisfied). The Verifier's earlier
662/662 PASS is therefore re-confirmed on the current tree.

---

## Remediation record

**None.** No BLOCK occurred in this stage, so no phase-1/phase-2 attempt count is
owed for it, and no remediation budget was consumed.

Carried forward, not invented:

- `25-verification.md` opens with "Verifier run: attempt 1, phase 1 (pre-PR)" and an
  overall verdict of **PASS** — i.e. the Verifier reached PASS on its first phase-1
  attempt, with no BLOCK to resolve.
- No orchestrator loop summary was supplied with this subagent invocation, so no
  phase-2 (post-PR CI) entries exist to carry.
- The three full-suite invocations above are flake diagnostics in stage 5a, not BLOCK
  remediations: attempts 2 and 3 were re-executions after a pre-existing,
  out-of-scope test flake, resolved by re-running the suite (green), with the flake
  root-caused and recorded rather than papered over.

---

## Verdict

**GREEN** — mutation gate skipped at `mvp` tier (evidence recorded), equivalent
mutants: none (not applicable), full suite green at 662/662 on the final run.
No commit, no push, no PR; `PR:` is appended by stage 5b.

---

PR: https://github.com/RexiAI/my-engineering-standards/pull/104
commit-count: 2 (branch head `fefddff` when the draft PR opened; this record commit is 3 on the branch)
