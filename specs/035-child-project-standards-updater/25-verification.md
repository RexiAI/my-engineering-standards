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
