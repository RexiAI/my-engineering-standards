# Verification — 032 — Clean Code comment hygiene and naming gates

Verifier: independent re-execution of every Coder/Refactorer claim. Attempt 1,
phase 1 (no remediation cycles; `SPEC_LOOP_COUNT=1 SPEC_PHASE1_RETRIES=0
SPEC_PHASE2_RETRIES=0`).

Blame scoping: `-BaseRef main` applied to the design-principles gate (and the
complexity gate) per spec 011 / ADR 0005. The scoped run is the gate result; the
full-tree run is recorded below as separate out-of-scope evidence.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-25T12:35:14Z

```
{
  "checks": [1, 2],
  "passes": ["AC-032-01 — traced to a test", "AC-032-02 — traced to a test", "AC-032-03 — traced to a test", "AC-032-04 — traced to a test", "AC-032-05 — traced to a test", "AC-032-06 — traced to a test", "AC-032-07 — traced to a test", "AC-032-08 — traced to a test", "AC-032-09 — traced to a test", "AC-032-10 — traced to a test", "AC-032-11 — traced to a test", "AC-032-12 — traced to a test"],
  "fails": []
}
```

All 12 task files trace to at least one test; no orphaned scenarios, no dangling
references. PASS.

---

## Evidence: full test suite

command: make test
exit: 0
at: 2026-10-25T12:35:23Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..537
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (537 assertions, all `ok`, representative excerpts below) ...
ok 181 AC-032-01-01: the ADR exists with the mandated section shape
ok 182 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
ok 183 AC-032-01-03: the ADR is indexed and governance still passes
ok 184 AC-032-02-01: the three new names are accepted by --gates and --blocking
ok 185 AC-032-02-02: unknown and empty gate values still exit 2 and list all nine
ok 186 AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary
ok 187 AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch
ok 188 AC-032-02-05: each new gate has its own dispatch block
ok 189 AC-032-03-01: shell files are scanned for comments
ok 190 AC-032-03-02: excluded directories are not scanned
ok 191 AC-032-03-03: shell is not dragged into the existing gates
ok 192 AC-032-03-04: the scanned-extension message names shell, and its test is updated
ok 193 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 194 AC-032-04-02: a single code-shaped comment line is not a finding
ok 195 AC-032-04-03: two consecutive prose comment lines are not a finding
ok 196 AC-032-05-01: a token-subset comment produces a finding
ok 197 AC-032-05-02: an extra token in the comment suppresses the finding
ok 198 AC-032-05-03: short comments and non-adjacent comments do not fire
ok 199 AC-032-06-01: TODO and FIXME without an issue reference warn
ok 200 AC-032-06-02: an issue reference suppresses the TODO/FIXME finding
ok 201 AC-032-06-03: section dividers and attributions warn
ok 202 AC-032-06-04: advisory findings never become FAIL
ok 203 AC-032-07-01: the first five lines of a file are never scanned
ok 204 AC-032-07-02: tool directives are skipped per line, and do not disable the file
ok 205 AC-032-07-03: ponytail and standards markers are preserved and skipped
ok 206 AC-032-07-04: licence markers and URLs are skipped
ok 207 AC-032-07-05: doc blocks attached to public API are skipped; private code is not
ok 208 AC-032-08-01: default classification is WARN with exit 0
ok 209 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
ok 210 AC-032-08-03: --blocking comments promotes without the environment switch
ok 211 AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote
ok 212 AC-032-08-05: Python and Rust findings stay WARN under the strict switch
ok 213 AC-032-08-06: --json and -ReportPath carry the classification
ok 214 AC-032-09-01: single-character identifiers fire, loop counters do not
ok 215 AC-032-09-02: noise words fire at word boundaries only
ok 216 AC-032-09-03: encoded identifiers fire, ordinary camelCase does not
ok 217 AC-032-09-04: boolean flag parameters fire, other booleans do not
ok 218 AC-032-09-05: more than three parameters fires at four, not at three
ok 219 AC-032-09-06: naming never emits FAIL and never scans shell
ok 220 AC-032-10-01: return null is reported
ok 221 AC-032-10-02: null arguments are reported; comparisons and assignments are not
ok 222 AC-032-10-03: Python and Rust are not scanned
ok 223 AC-032-10-04: null findings never become FAIL
ok 224 AC-032-11-01: gate consistency passes with nine gates
ok 225 AC-032-11-02: the blame suite reflects that naming is now a gate
ok 226 AC-032-11-03: CODING_CONVENTIONS documents the new gates
ok 227 AC-032-11-04: the check-principles skill lists all nine gates
ok 228 AC-032-12-01: the selftest proves each new rule and each allowlist control
ok 229 AC-032-12-02: the new scenarios run as bats tests and are not vacuous
ok 230 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 231 AC-032-12-04: existing gate behavior is unchanged
... (remaining 306 assertions all `ok`) ...
ok 537 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

`check-bats-assertions.sh` reports "no vacuous assertions" over 56 bats files
(including the new `check-code-principles-clean-code.bats`), then `bats --tap
scripts/tests/*.bats` runs 537 assertions, all `ok`. PASS. Nothing skipped,
disabled, or silently absent — the glob `scripts/tests/*.bats` picks the new
file up.

---

## Evidence: complexity gate

Primary (scoped to this change, `-BaseRef main`):

command: scripts/check-code-principles.sh --gates complexity -BaseRef main .
exit: 0
at: 2026-10-25T12:40:26Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

---------------------------------------------
✔ Design-principles check (gates: complexity): 0 FAIL(s), 0 WARN(s).
```

Full-tree (out of scope — the only FAIL is in a file untouched by this diff):

command: scripts/check-code-principles.sh --gates complexity .
exit: 1
at: 2026-10-25T12:40:15Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
FAIL Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43

---------------------------------------------
✘ Design-principles check (gates: complexity): 1 FAIL(s), 4 WARN(s).
  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md
```

The full-tree FAIL is the pre-existing `CC=10` at
`skills/hallmark/site/examples/cobalt-01/script.js`. That file is **not** in
`git diff main --name-only`, so under `-BaseRef main` it is correctly out of
scope — confirmed by the scoped run (exit 0). This spec changes only shell
scripts, markdown, and YAML; the complexity analyzer scans only
Java/Go/JS/TS/Python/Rust (`.sh` never reaches it — Task 03, verified in the
script: `SH_FILES` feeds only `COMMENT_FILES`). The changed `.sh` files are
therefore not complexity-measurable by this gate, and the Refactorer's
complexity claim (below) is about shell-function structure, not the gate.

PASS for the scoped complexity gate; the full-tree FAIL is pre-existing,
out-of-scope debt.

---

## Evidence: design-principles gate

Primary (scoped to this change, `-BaseRef main`):

command: scripts/check-code-principles.sh -BaseRef main .
exit: 0
at: 2026-10-25T12:40:30Z

```
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
```

Full-tree (out of scope — one pre-existing FAIL, plus 61 advisory WARNs):

command: scripts/check-code-principles.sh .
exit: 1
at: 2026-10-25T12:40:34Z

```
... (complexity, DRY, YAGNI, SOLID, component-per-file sections identical in
scope to the complexity full-tree above) ...

--- Comments ---
WARN Comments: comment restates the following line (./skills/hallmark/site/examples/cobalt-01/script.js:186)
WARN Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)
WARN Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)
WARN Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)
WARN Comments: commented-out code (./scripts/check-bats-assertions.sh:21)
WARN Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)
WARN Comments: commented-out code (./scripts/verify-production-deploy.sh:30)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:58)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:121)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)
WARN Comments: attribution comment (./scripts/check-code-principles.sh:59)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)
WARN Comments: commented-out code (./scripts/check-loop-files.sh:10)
WARN Comments: section-divider comment (./scripts/init-ci.sh:6)
WARN Comments: section-divider comment (./scripts/init-ci.sh:32)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:39)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:49)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:67)
WARN Comments: commented-out code (./scripts/token-stats.sh:10)
WARN Comments: comment restates the following line (./scripts/bootstrap.sh:229)
WARN Comments: comment restates the following line (./scripts/bootstrap.sh:234)
WARN Comments: commented-out code (./scripts/guard-env.sh:21)
WARN Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)
WARN Comments: commented-out code (./scripts/check-security-hardening.sh:39)
WARN Comments: commented-out code (./scripts/check-model-env.sh:30)
WARN Comments: commented-out code (./scripts/gate-stats.sh:20)
WARN Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)

--- Naming ---
WARN Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)
WARN Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
WARN Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)
WARN Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)

--- Null discipline ---
WARN Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)

---------------------------------------------
✘ Design-principles check: 1 FAIL(s), 61 WARN(s).
  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md
```

The single full-tree FAIL is the pre-existing `CC=10` at
`skills/hallmark/site/examples/cobalt-01/script.js:7` — the same file that the
complexity full-tree run flags, and one that is **not** in this diff. The 61
WARNs are all advisory: 45 from the three new gates (all WARN by design — the
WARN-first rollout of Task 08 / ADR 0011 — plus the pre-existing complexity,
DRY, YAGNI, and KISS WARNs in `ci/templates/`). None of the new gates emits a
FAIL in the full-tree run, confirming Task 12 required-behaviour 4.

Under `-BaseRef main` the gate is clean (exit 0, 0 FAIL, 0 WARN). PASS.

Design-principles WARNs to flag to the Architect (review hints, not blockers —
Stop-and-Ask matrix "Design gate WARN → record, do not stop"): the new
`comments` gate reports pre-existing commented-out code, section-divider
comments, TODO/FIXME-without-reference, and attribution comments across
`scripts/` (e.g. `check-code-principles.selftest.sh:639/641`,
`check-code-principles.sh:57/58/59/121`, `gate-clean-code-lib.sh:97`). These are
the day-one WARNs the spec explicitly chose not to clean up (Task 12 / "Out of
scope — rewriting existing comments").

---

## Evidence: scenario-to-behavior spot check

command: bats --tap --filter 'AC-032-04-01|AC-032-08-02' scripts/tests/check-code-principles-clean-code.bats
exit: 0
at: 2026-10-25T12:43:33Z

```
1..2
ok 1 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 2 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
```

Two scenarios chosen at random, each confirmed to assert real behavior rather
than self-reference:

- **AC-032-04-01** (`20-acceptance/AC-032-04-commented-out-code.md`). Scenario:
  two consecutive code-shaped comment lines inside a method → exactly one
  `Comments: commented-out code` finding, anchored at the first comment's line,
  exit 0. Test (`check-code-principles-clean-code.bats:358-375`) builds a
  `Ledger.java` fixture in `mktemp`, runs `--gates comments`, and asserts
  `count_sho 'Comments: commented-out code' == 1` **and** the exact anchor
  `sho 'Ledger\.java:9'` (line 9 = the first comment). This is a concrete
  count + line-anchor assertion, not a name-only check.

- **AC-032-08-02** (`20-acceptance/AC-032-08-comment-severity-rollout.md`).
  Scenario: `STRICT_CLEAN_CODE=1` promotes the blocking-class rule → `FAIL`
  prefix, exit 1. Test (`check-code-principles-clean-code.bats:728-743`) runs
  `cc_env STRICT_CLEAN_CODE=1 --gates comments`, asserts `[ "$RC" -eq 1 ]` and
  `sho 'FAIL.*Comments: commented-out code'`. A severity + exit-code assertion,
  with the WARN/default and only-literal-`1` controls asserted in the sibling
  tests (AC-032-08-01, -03, -04).

Both tests use `mktemp` fixtures (never committed, per Task 12), assert both the
positive finding and the negative/control direction, and were confirmed green in
the full suite. Neither is vacuous or self-referential.

---

## Refactorer structural claims — independently re-verified

- **Checker is ~1098 lines**: `wc -l scripts/check-code-principles.sh` → `1098`.
  Confirmed (main's version was 1520 lines).
- **New libraries exist**: `scripts/gate-analysis-lib.sh` (590 lines — the
  DRY/YAGNI/SOLID/component-per-file/property-tests analyzers) and
  `scripts/gate-clean-code-lib.sh` (488 lines — the comments/naming/
  null-discipline analyzers). Confirmed present and sourced by the dispatcher.
- **Extracted analysis is byte-identical behaviorally**: ran main's
  `check-code-principles.sh` (with `gate-report-lib.sh` / `check-common.sh`
  copied alongside) and the current script over the repo with the six original
  gates, then diffed the JSON transcripts:

  command: bash /tmp/opencode/032/check-code-principles.main.sh --gates complexity,dry,yagni,solid,component-per-file,property-tests --json .
  exit: 1   (both scripts exit 1 — same single pre-existing CC=10 FAIL)
  at: 2026-10-25T12:41:00Z

  `diff main.json cur.json` → **JSON IDENTICAL** (1 fail, 16 warns, identical
  `gates` array and identical finding triples). The six original gates produce
  byte-identical output before and after the extraction.
- **The nine analyzer functions moved unmodified**: `check_dry`, `check_yagni`,
  `check_solid_srp`, `check_solid_ocp`, `check_solid_lsp`, `check_solid_isp`,
  `check_solid_dip`, `check_component_per_file`, `check_property_tests` — each
  extracted from main's `check-code-principles.sh` and diffed against
  `gate-analysis-lib.sh`; all nine are byte-identical (8 via a brace-matching
  extractor, `check_yagni` via a direct line-range `diff` — both report
  `identical`).

### Judgment: the 9 pre-existing CC>6 shell functions in gate-analysis-lib.sh

The Refactorer's note reports "9 pre-existing CC>6 functions in
`scripts/gate-analysis-lib.sh` (moved unmodified)". Two facts frame this:

1. **The complexity gate never measures shell.** The analyzer's file set is
   Java/Go/JS/TS/Python/Rust only; `SH_FILES` is discovered separately and fed
   *only* to `COMMENT_FILES` (Task 03 — "a `.sh` file never reaches the
   complexity analyzer", confirmed in the script at lines 446-456). So "CC>6"
   for these shell functions is a self-assessment, not a gate finding — the gate
   can never flag them, scoped or full-tree. (An independent brace-depth+keyword
   count over `gate-analysis-lib.sh` using the repo's own heuristic puts 7 of the
   9 functions above CC 6 — `check_dry` 21, `check_solid_srp` 22, `check_yagni`
   68, `check_solid_isp` 11, `check_solid_ocp` 10, `check_solid_lsp` 8,
   `check_solid_dip` 7 — while `check_component_per_file` and
   `check_property_tests` sit at/below the threshold because their logic lives in
   embedded awk strings. The precise count is immaterial: the gate does not scan
   shell.)
2. **The debt is relocated, not created.** All nine functions are byte-identical
   to their `main` counterparts (verified above). Under `-BaseRef main` the
   gate reports clean (exit 0), and `gate-analysis-lib.sh` is a new file that the
   complexity gate does not scan.

**Judgment: acceptable.** No new complexity was introduced; the extraction moved
pre-existing shell-function complexity (invisible to the gate) out of the
dispatcher into a lib, shrinking the dispatcher from 1520 → 1098 lines. This is a
structural improvement, not a regression, and it is fully covered by blame
scoping. If shell complexity is ever to be gated, that is a follow-up spec
(recorded here as an out-of-scope finding, not implemented).

---

## Task 01 / Task 11 confirmations

- **ADR 0011 listed in `docs/adr/README.md`**: row
  `| 0011 | [Clean Code comment hygiene and naming gates](0011-clean-code-comment-gates.md) | Proposed |`
  present; link target `docs/adr/0011-clean-code-comment-gates.md` exists. ADR
  heading order confirmed: `# ADR 0011: …`, then `## Status` (`Proposed`),
  `## Context`, `## Decision` (with `### Alternatives Considered` inside),
  `## Consequences`, `## Compliance`.
- **`.github/workflows/self-ci.yml` NOT modified**: `git diff main --
  .github/workflows/self-ci.yml` is empty.
- **`docs/GOVERNANCE.md` NOT modified**: `git diff main -- docs/GOVERNANCE.md`
  is empty; `bash scripts/check-governance.sh` exits 0 (also asserted by
  AC-032-01-03).
- **Catalog consumers re-synced (Task 11)**:
  - `bash scripts/check-gate-consistency.sh` → exit 0, `Check 4: gate count = 9
    (expected 9)`, `PASS — 9 gates`.
  - `bash scripts/check-code-principles.selftest.sh` → exit 0,
    `60 assertions passed`.
  - `bash scripts/tests/check-code-principles-blame.sh` → exit 0,
    `25 passed, 0 failed`.
- **Task 12 required behaviour 4**:
  `bash scripts/check-code-principles.sh --gates comments,naming,null-discipline .`
  → exit 0, `0 FAIL(s), 45 WARN(s)` — the three new gates do not turn the repo
  red on day one (verified directly, and by AC-032-12-03).

---

## No unaccounted behavior

Finding line: the diff (`git diff main --name-only` plus untracked files)
contains exactly the files the twelve tasks name — the ADR and its README row
(Task 01), the three-gate registration and header/help text (Task 02), comment
discovery + the three `comments` rules + allowlist + rollout (Tasks 03-08), the
`naming` and `null-discipline` gates (Tasks 09-10), the consumer re-sync —
`check-gate-consistency.sh`, `check-code-principles-blame.sh`,
`check-code-principles.bats`, `CODING_CONVENTIONS.md`, `check-principles/SKILL.md`
(Task 11) — and the fixture/wiring/regression proof (Task 12). The two new lib
files (`gate-analysis-lib.sh`, `gate-clean-code-lib.sh`) are the Refactorer's
extraction of existing analyzers, not new behavior. No logic found that does not
trace to a task or scenario.

---

## Verdict

**PASS.**

Every gate ran and produced no findings for the change under review:

| Check | Scoped result | Full-tree (out of scope) |
|---|---|---|
| scenario traceability | PASS (exit 0) | — |
| full test suite | PASS (exit 0, 537/537) | — |
| complexity gate | PASS (exit 0) | 1 pre-existing FAIL (CC=10 script.js, untouched) |
| design-principles gate | PASS (exit 0, 0 FAIL / 0 WARN) | 1 pre-existing FAIL + 61 advisory WARN |
| scenario-to-behavior spot check | PASS (2/2 non-vacuous) | — |

The one full-tree FAIL — `Cyclomatic complexity >6` at
`skills/hallmark/site/examples/cobalt-01/script.js:7` — is pre-existing and in a
file absent from `git diff main`; under `-BaseRef main` blame scoping it is
correctly excluded and the scoped gate is clean. The 61 full-tree WARNs are all
advisory (WARN-first rollout of the three new gates, plus pre-existing `ci/`
template WARNs). No FAIL is attributable to this spec's change. The Refactorer's
structural claims — ~1098-line dispatcher, two new lib files, byte-identical
six-gate output, nine analyzer functions moved unmodified — are all confirmed.
The 9 pre-existing CC>6 shell functions are acceptable: the complexity gate does
not scan shell, and the debt is relocated (byte-identical) rather than created.

The Architect may proceed.
