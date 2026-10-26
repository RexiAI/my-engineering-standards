# 25-verification.md — Verifier re-check (spec 033)

Attempt 1, phase 1 (pre-PR). Base ref: `main` (6eb2c99). Branch:
`spec/033-bootstrap-capability-catalog` (dirty working tree — expected at stage 4;
the Coder/Refactorer never commit, only the PR Opener does).

Every Coder and Refactorer claim re-executed independently. Verdict below is
transcribed from the gate scripts' exit codes and output, never from the diff.

---

## Check 1 — Scenario traceability

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T00:04:48Z

{
  "checks": [1, 2],
  "passes": ["AC-033-01 — traced to a test", "AC-033-02 — traced to a test", "AC-033-03 — traced to a test", "AC-033-04 — traced to a test", "AC-033-05 — traced to a test", "AC-033-06 — traced to a test", "AC-033-07 — traced to a test", "AC-033-08 — traced to a test", "AC-033-09 — traced to a test", "AC-033-10 — traced to a test", "AC-033-11 — traced to a test", "AC-033-12 — traced to a test", "AC-033-13 — traced to a test", "AC-033-14 — traced to a test", "AC-033-15 — traced to a test", "AC-033-16 — traced to a test", "AC-033-17 — traced to a test", "AC-033-18 — traced to a test", "AC-033-19 — traced to a test", "AC-033-20 — traced to a test", "AC-033-21 — traced to a test", "AC-033-22 — traced to a test", "AC-033-23 — traced to a test", "AC-033-24 — traced to a test", "AC-033-25 — traced to a test", "AC-033-26 — traced to a test", "AC-033-27 — traced to a test", "AC-033-28 — traced to a test", "AC-033-29 — traced to a test", "AC-033-30 — traced to a test", "AC-033-31 — traced to a test", "AC-033-32 — traced to a test", "AC-033-33 — traced to a test", "AC-033-34 — traced to a test", "AC-033-35 — traced to a test", "AC-033-36 — traced to a test", "AC-033-37 — traced to a test", "AC-033-38 — traced to a test", "AC-033-39 — traced to a test", "AC-033-40 — traced to a test", "AC-033-41 — traced to a test", "AC-033-42 — traced to a test", "AC-033-43 — traced to a test", "AC-033-44 — traced to a test", "AC-033-45 — traced to a test", "AC-033-46 — traced to a test", "AC-033-47 — traced to a test", "AC-033-48 — traced to a test", "AC-033-49 — traced to a test"],
  "fails": []
}

Result: **PASS**. All 49 scenarios traced to a test; no dangling test references.

---

## Check 2 — Full test suite (run twice, per flake re-check)

`make test-scripts` runs `scripts/check-bats-assertions.sh` then `bats --tap
scripts/tests/*.bats`. The Refactorer reported two transient failures
(AC-030-01-06 and one unnamed); re-ran the suite twice. Both runs clean — the
flake did not reproduce.

### Supplementary: full test suite run 1 of 2

command: make test-scripts
exit: 0
at: 2026-10-26T00:00:03Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..535
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (535 `ok` lines total, 0 `not ok`) ...
ok 535 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 535 `ok`, 0 `not ok`.

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T00:03:46Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..535
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (535 `ok` lines total, 0 `not ok`) ...
ok 535 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 535 `ok`, 0 `not ok`.

Result: **PASS**. Exit 0 on both runs; 535 tests green; the reported transient
failures did not reproduce. No flakiness observed across two runs.

---

## Check 3 — Complexity gate

The changed files are all bash (`.sh`), one `.tsv`, `.bats`, and `.yml`. No
golangci-lint / pmd / eslint applies to bash; `shellcheck` is not installed in
this environment. The repo's authoritative cyclomatic-complexity enforcement is
`check-code-principles.sh` (its `complexity` gate), which only analyzes
Java/Go/JS-TS/Python/Rust — bash is outside its CC analyzer. Scoped to the diff
against `main`, no scanned-language file changed, so the gate finds nothing in
the change; the full-tree gate still carries the pre-existing out-of-scope
`skills/hallmark` CC=10 FAIL (see Check 3.5).

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T00:05:03Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}

Result: **PASS** (scoped). The bash refactor cannot be CC-measured by this
gate (bash is outside the analyzer); the Refactorer's structural split of
`bootstrap.sh` into five sourced modules (`bootstrap-catalog-lib.sh`,
`bootstrap-detect-lib.sh`, `bootstrap-lib.sh`, `bootstrap-plan-lib.sh`,
`bootstrap-actions.sh`) is the complexity-reduction claim, and it is
behavior-preserving per Check 2 (full suite green) and Check 4.

---

## Check 3.5 — Design-principles gate (KISS/DRY/YAGNI/SOLID + CC + property tests)

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T00:04:51Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}

### Supplementary: design-principles gate (full tree)

command: scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T00:04:52Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }],
  "warns": [
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" },
    { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "93" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" },
    { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" },
    { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }
  ]
}

Result: **PASS** (scoped to the change). The full-tree run's single FAIL
(`skills/hallmark/site/examples/cobalt-01/script.js` CC=10) and all WARNs are
pre-existing, outside this spec's change set, and out of scope per instructions.
The scoped run against `main` carries zero FAILs and zero WARNs.

---

## Check 4 — Scenario-to-behavior spot check

Manually confirmed four scenarios' tests assert what their Given/When/Then
state (not merely that an ID exists and passes). Three match; one does not.

### PASS — AC-033-01 (`--list` prints every entry as id<TAB>label<TAB>category)

Ran `bootstrap.sh --list` from a hermetic child fixture (`.standards/` symlinked
per the bats fixture model). Output: 35 lines, every line exactly three
tab-separated fields (`id<TAB>label<TAB>category`), line count equal to the
catalog's 35 non-comment/blank rows, exit 0. First line:
`core-agents-md<TAB>AGENTS.md standards pointer<TAB>Core wiring`.
Matches the scenario.

### PASS — AC-033-44 (`--dry-run` prints the exact plan) and AC-033-45 (`--help` lists every flag)

`bootstrap.sh --dry-run --stack java --with-saga` (exit 0) prints the plan with
each selected capability id, its files, and the `init-ci.sh flags:` summary
(`--backend java --platform github --with-saga`). `bootstrap.sh --help` (exit 0)
lists every flag (`--stack`, `--frontend`, `--with-saga`, `--with-loop`,
`--with-deploy`, `--all`, `--none`, `--dry-run`, `--help`, `--list`, …).
Matches the scenarios.

### FAIL — AC-033-41 (`--with-loop` writes the loop files the gate validates)

The scenario's final requirement is: **"And `scripts/check-loop-files.sh` passes
against that repo"** (i.e. exit 0). The shipped test (`AC-033-41` in
`scripts/tests/bootstrap-capability-catalog.bats`) does **not** assert that the
gate exits 0. It runs the gate and then greps for exactly 6 `AC-016-02:
templates/` PASS lines, explicitly ignoring the gate's other checks with a
comment that they "assert standards-repo artifacts … which a child does not
carry."

Empirically, `check-loop-files.sh` does **not** pass against a child repo.
Replicating the fixture (child repo with `.standards/` symlinks, then
`bootstrap.sh --with-loop`), the gate exits 1 with 5 violations:

command: bash scripts/check-loop-files.sh <child-fixture-repo>
exit: 1
at: 2026-10-26T00:04:15Z

Checking loop-engineering foundation bundle in: /tmp/tmp.0XVokIymSm/child

FAIL AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty
PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty
PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories
FAIL AC-016-03: AGENTS.md does not reference docs/LOOP_ENGINEERING.md
FAIL AC-016-03: AGENTS.md missing the never-skip-L1 rule
FAIL AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh
FAIL AC-016-04: scripts/check-loop-files.sh is missing or not executable

✘ Loop files check: 5 violation(s). Fix before merging.

The `--with-loop` capability writes only the six `templates/*` files; the gate
additionally demands four standards-repo artifacts at the child root
(`docs/LOOP_ENGINEERING.md`, `AGENTS.md` loop references, self-ci wiring, and
`scripts/check-loop-files.sh`), which `--with-loop` does not (and per task 8 is
not required to) write. The scenario as written is therefore **not satisfied**:
the test narrows it to a subset and asserts less than the scenario requires.

Result: **FAIL** — gate ID **AC-033-41**.

---

## Check 5 — No unaccounted behavior

Finding (not a command): the change set is
`scripts/bootstrap.sh` (rewrite into a thin dispatcher), five new sourced
modules (`bootstrap-catalog-lib.sh`, `bootstrap-detect-lib.sh`,
`bootstrap-lib.sh`, `bootstrap-plan-lib.sh`, `bootstrap-actions.sh`),
`scripts/capabilities.tsv` (the catalog), `scripts/init-ci.sh` (backend
python/rust + frontend ionic extension, plus a `_caller_permissions` helper
extraction), `scripts/tests/bootstrap-capability-catalog.bats`, and five
`templates/ci-wrappers/*.yml` copy-template sources. Every item traces to
tasks 1–10 or is a behavior-preserving helper (`_caller_permissions` extraction
is a DRY refactor; the ci-wrappers are the catalog's copy-template sources). No
unaccounted behavior found.

---

## Overall verdict

**FAIL** — the scenario-to-behavior spot check found a test that asserts less
than its scenario. The acceptance scenario **AC-033-41** requires
`scripts/check-loop-files.sh` to pass (exit 0) against the child repo; the
shipped test narrows this to only the six template checks and ignores the gate's
other failing checks. `check-loop-files.sh` empirically exits 1 (5 violations)
against a `--with-loop` child fixture. This is a false green, not a pass.

Every other gate ran clean: traceability (exit 0), full test suite (exit 0,
twice), complexity (exit 0 scoped), design-principles (exit 0 scoped; the
full-tree `skills/hallmark` CC=10 FAIL is pre-existing and out of scope).

Pipeline stops here. AC-033-41 is the exact gate ID to resolve — either the
scenario's "gate passes" requirement is rewritten to match what `--with-loop`
can write, or the test is made to assert the gate's actual exit code (and the
capability is extended to satisfy it). The fix belongs to the Coder
(behavior/test narrowing), not the Verifier.

---

# Remediation cycle 1 — AC-033-41 (attempt 2, phase 1)

Scoped re-verification. Base ref `main` (6eb2c99), branch
`spec/033-bootstrap-capability-catalog`. Fix under review: the Coder added a
`--scope standards|child` mode to `scripts/check-loop-files.sh` and rewrote the
AC-033-41 test to assert the gate's real exit codes in both directions (child
scope exit 0, default scope exit 1). Prior Check-4 FAIL evidence (above) is
retained; only the previously failing gate and the gates the fix could touch
are re-run: AC-033-41, `scripts/tests/check-loop-files.bats`, and
`make test-scripts` (the fix edits a shared gate script).

## Evidence: scenario-to-behavior spot check

command: bats --tap -f 'AC-033-41' scripts/tests/bootstrap-capability-catalog.bats
exit: 0
at: 2026-10-26T00:21:12Z

1..1
ok 1 AC-033-41: --with-loop writes the loop files the gate validates

Result: **PASS**. The rewritten test now asserts the scenario's two clauses
directly, not a narrowed substring:

- The six loop files are written and byte-identical to `templates/`
  (`[ -s "$CHILD/templates/$f" ]` + `cmp -s` against the repo template).
- The gate passes against the child repo — via the newly added child scope:
  `check-loop-files.sh --scope child "$CHILD"` asserts exit 0 and greps the
  documented clean line `Loop files check (child scope): every check passed`.
- The default (standards) scope still rejects the same child: exit 1 with
  `docs/LOOP_ENGINEERING.md is missing or empty` — pinning that child scope
  narrows the gate, not turns it into a blanket pass.

The prior false green (grep 6 PASS lines while ignoring the gate's exit-1) is
gone; the test asserts real exit codes in both directions.

## Evidence: check-loop-files.bats (scoped re-run, shared-gate characterization)

command: bats --tap scripts/tests/check-loop-files.bats
exit: 0
at: 2026-10-26T00:21:12Z

1..6
ok 1 check-loop-files: clean repo exits 0 and prints its documented clean line
ok 2 check-loop-files: empty tree exits 1 and names the missing artifact
ok 3 check-loop-files: child scope passes a child that has only the six loop templates
ok 4 check-loop-files: child scope still fails when a loop template is missing
ok 5 check-loop-files: default standards scope still rejects a child-shaped tree
ok 6 check-loop-files: an unknown scope is a usage error, not a pass

Result: **PASS**. Six characterization tests green. Test 3 and 4 prove child
scope is discriminating (passes a complete child, fails a missing template);
test 5 proves default scope still rejects a child-shaped tree; test 6 proves an
unknown scope is a usage error (exit 2), not a pass.

## Evidence: full test suite (scoped re-run, make test-scripts)

command: make test-scripts
exit: 0
at: 2026-10-26T00:21:12Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..539
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 207 AC-033-41: --with-loop writes the loop files the gate validates
...
ok 213 AC-033-47: orchestration references resolve
ok 214 AC-033-48: skills and gate-consistency gates stay green
ok 215 AC-033-49: no regression in default output or existing init-ci flags
...
ok 539 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 539 `ok`, 0 `not ok`.

Result: **PASS**. Suite grew from 535 → 539 tests (the four new
`check-loop-files.bats` scope tests). All 539 green, 0 failures. The fix
touches a shared gate script, so the full suite re-run confirms no other gate
regressed (AC-033-47 orchestration, AC-033-48 skills + gate-consistency, and
AC-033-49 no-regression all green).

## Evidence: two-direction claim — real --with-loop fixture

command: manual child fixture (`.standards/` symlinks + `bootstrap.sh --with-loop`), then `bash scripts/check-loop-files.sh {--scope child,} <child>`
exit: child scope 0; default scope 1
at: 2026-10-26T00:21:12Z

bootstrap exit=0
=== CHILD SCOPE ===
Checking loop-engineering foundation bundle (child scope) in: /tmp/opencode/withloop.wLejgn/child

PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty

PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories

✔ Loop files check (child scope): every check passed.
child-scope exit=0
=== DEFAULT SCOPE ===
Checking loop-engineering foundation bundle in: /tmp/opencode/withloop.wLejgn/child

FAIL AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty
PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty
PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories
FAIL AC-016-03: AGENTS.md does not reference docs/LOOP_ENGINEERING.md
FAIL AC-016-03: AGENTS.md missing the never-skip-L1 rule
FAIL AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh
FAIL AC-016-04: scripts/check-loop-files.sh is missing or not executable

✘ Loop files check: 5 violation(s). Fix before merging.
  Reference: docs/LOOP_ENGINEERING.md
default-scope exit=1

Result: **PASS**. Both directions hold on a real `--with-loop` fixture: child
scope exits 0 (the six files the bootstrap writes are validated); the default
scope still exits 1 with the same 5 violations the prior report recorded.

## Evidence: default-scope output byte-identical to main

command: `git show main:scripts/check-loop-files.sh > /tmp/…/main.sh`, then `bash {main,new} scripts/check-loop-files.sh <tree>` over the clean standards tree and an empty tree; `diff` stdout+stderr
exit: clean tree 0/0; empty tree 1/1; diffs empty in both cases
at: 2026-10-26T00:21:12Z

extracted main version, 128 lines
--- clean standards tree comparison ---
new exit=0
main exit=0
CLEAN TREE: BYTE-IDENTICAL
--- empty tree comparison (default scope) ---
new exit=1
main exit=1
EMPTY TREE: BYTE-IDENTICAL

Result: **PASS**. The default (standards) scope of the edited script produces
byte-identical stdout+stderr and the same exit codes as the `main` version over
both a clean standards tree and an empty tree — the `--scope` addition did not
alter existing default-scope behavior.

---

# Remediation cycle 1 — overall verdict

**PASS.** The AC-033-41 spot-check FAIL is resolved. The test now asserts the
scenario's clauses (files written byte-identically; the gate passes against the
child repo in child scope) with the gate's real exit codes, no longer narrowing
the assertion to a six-line substring. The two-direction claim holds on a real
`--with-loop` fixture, and the default scope is byte-identical to `main`. No
other gate regressed: `make test-scripts` is green (539 ok, 0 not ok) including
the orchestration, skills, gate-consistency, and no-regression tests.

Prior FAIL evidence for Check 4 (above) is retained for the audit trail.
