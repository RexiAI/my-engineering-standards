# Verification Report — Spec 009: Stop-and-Ask decision matrix

- **Stage**: 4 (Verifier)
- **Date**: 2026-08-15
- **Branch**: `spec/009-stop-and-ask-matrix` (working-tree changes; HEAD == main tip `3013d8d`)
- **Verified against**: `10-tasks.md`, `20-acceptance/AC-009-01..04.md` (not `00-informal.md`)

Changed footprint: `docs/SPEC_PIPELINE.md` (+19), `agents/spec-{pipeline,specifier,ux,coder,refactorer,verifier,mutation-runner,pr-opener}.md` (+61 total, 0 deletions), new untracked `scripts/check-stop-and-ask-matrix.sh`. No other files touched.

---

## Check 1 — Scenario traceability — PASS (AC-009 scope clean)

Command: `bash scripts/check-scenario-traceability.sh` (script is `644`, not executable — pre-existing; direct exec returns 126 Permission denied).

**Full-repo result: exit 1, "127 violation(s)"** — expected mid-pipeline condition:
- 77 scenario IDs found.
- Every FAIL is either a sibling in-flight spec with untraced scenarios (AC-007-01..04, AC-008-01..05, AC-010-01..06, AC-011-01..03, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..16, AC-017-01..05, AC-018-01..08, AC-019-01..07) or an archived-spec citation with no matching scenario (AC-001-01..06, AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04, AC-006-01..06, AC-016-01..05, AC-020-01..07, AC-021-01..08, AC-022-01..04).

**Scoped AC-009 result — clean**:
```
PASS AC-009-01 — traced to a test
PASS AC-009-02 — traced to a test
PASS AC-009-03 — traced to a test
PASS AC-009-04 — traced to a test
```
No AC-009 FAIL anywhere in the run; no dangling AC-009 reference. The 20 sub-scenario IDs cited by the Coder all appear in `scripts/check-stop-and-ask-matrix.sh` output: AC-009-01-01..05, AC-009-02-01..03, AC-009-03-01..04, AC-009-04-01..08 (verified by reading the full script output — every PASS/FAIL line carries its AC-009-NN-NN ID). Judgment: AC-009 scope is clean; the full-repo exit 1 is attributable entirely to sibling in-flight specs and archived-spec citations, not to spec 009.

## Check 2 — Full relevant suite — PASS

This repo's test framework is the `scripts/check-*.sh` + Makefile pattern (no JVM/Go/Node suite — documented in `10-tasks.md`). Ran all relevant gates:

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-stop-and-ask-matrix.sh` | 0 | syntax clean |
| `scripts/check-stop-and-ask-matrix.sh` | 0 | every check PASS; output cites all 20 AC-009-NN-NN IDs (see Check 4 for negative fixtures) |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." (agent/skill/script/doc references all resolve — confirms the 8 agent files' new references don't break orchestration) |
| `make validate-all` | 0 | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines >500 — untouched by this spec) |
| `make lint` | 0 | all JSON/YAML valid |

## Check 3 — Complexity gate — PASS

The changed code is one bash script (no PMD/golangci/eslint applies; the repo's shell-complexity gate is the ≤6 rule from `docs/CODING_CONVENTIONS.md`, mechanically enforced for this script by inspection — `check-code-principles.sh` measures Java/Go/JS only). Hand-verified decision-point counts per function (bash keywords only; excluded `if`/`&&` inside single-quoted awk strings):

- `edit_effective_action` — **5** (`&&`×3, `while`×1, `if`×1) — worst offender, ≤6 ✓
- `glob_to_regex` — 0 (single `printf | sed` pipeline) ✓
- `extract_matrix_section` — 0 (one awk command substitution) ✓
- `fail`/`pass` — 0 ✓

Refactorer claims confirmed against current state:
- **No function over 6; worst offender `edit_effective_action` = 5**: confirmed (count above).
- **`glob_to_regex` pipelines consolidated 3→1**: confirmed — exactly one sed pipeline (lines 95–102).
- **4 redundant empty-then branches inverted**: confirmed end-state — script-wide scan found zero `then` lines with empty bodies (no `then` immediately followed by `fi`/`else`); every branch has a real body. (History not diffable — file is new/untracked — but the claimed end-state holds.)

## Check 3.5 — Design-principles gate — PASS (no FAIL/WARN attributable to spec 009)

Command: `scripts/check-code-principles.sh` (default mode, repo root). **Exit code: 1** — 5 FAIL(s), 17 WARN(s). Line output is ANSI-colored; verbatim content below with escape codes stripped:

FAILs (all in `ci/templates/*`, untouched by this spec):
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARNs (17; all in `ci/templates/*`):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): } /return violations /} /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): schema: [], /}, /create(context) { /},
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): return violations /} / /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): } /} /} /violations++
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): } /} /return violations /}
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): violations++ /} /} /pos, fn.Name.Name)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

**Judgment**: the gate exits 1 with the FAILs/WARNs confined entirely to `ci/templates/*` — a pre-existing, documented state (spec 009 changed only `.md` and `.sh` files; the gate scans `.java`/`.go`/`.js`). **No FAIL or WARN is attributable to spec 009.** The new script produced zero findings on its own file. Property tests correctly skipped: "Property tests: skipped (project tier is mvp — production+ required)" ×3 — consistent with the mvp-tier claim (below).

**mvp-tier claim — confirmed**: no `AGENTS_<PROJECT>.md` exists at repo root (find returned nothing; only `AGENTS.md` and `docs/AGENTS_AND_SKILLS.md` present). Per `docs/CONFORMANCE_TIERS.md` ("A project states its tier once, in its own `AGENTS_<PROJECT>.md` or equivalent"), the absent declaration defaults the tier to mvp — so the property-test skip (Check 3.5) and the Architect mutation-testing skip (`docs/SPEC_PIPELINE.md` stage table: "Architect — mutation testing: skip" at mvp) are both correct.

## Check 4 — Scenario-to-behavior spot check — PASS

Picked AC-009-01-01 (matrix section exists) and AC-009-01-02 (authoritative declaration), plus manual confirmation of the enforcement scenarios AC-009-03-01 and AC-009-04-03..06 via live negative fixtures.

- **AC-009-01-01/02** — `docs/SPEC_PIPELINE.md` line 203: `## Stop-and-Ask decision matrix`, positioned **after** `## Compensating control` (line 190) and **before** `## Commit and push carve-out` (line 222) — exactly the placement the task proposes. Section body lines 205–206: "This matrix is authoritative for every pipeline agent: each agent resolves the listed conditions per the matrix, never by improvisation." — matches the Given/When/Then.
- **AC-009-02-02 (agent wording)** — all 8 agents carry the same sentence: "The `Stop-and-Ask decision matrix` in `docs/SPEC_PIPELINE.md` is authoritative for you: resolve every condition listed there per the matrix, never by improvisation." (verified in the diff; e.g. `agents/spec-verifier.md` lines 20–21). Exact section title `Stop-and-Ask decision matrix` present in each — grep-resolvable as the task requires.
- **AC-009-03-01 (gate-config lock)** — read all 8 frontmatters: 6 agents (pipeline, ux, coder, refactorer, mutation-runner, pr-opener) gained explicit `"**/check-code-principles.sh": deny`, `"**/pmd*.xml": deny`, `"**/*golangci*.yml": deny`, `"**/.eslintrc*": deny` (+ `"*": ask`); spec-specifier and spec-verifier rely on their existing `"*": deny` catch-all. The check script resolves each pattern via `glob_to_regex` and confirmed effective `deny` for all 8×5 (agent×gate-path) combinations (PASS AC-009-03-01).
- **Negative fixtures run for real** (scratch copy of the tree under `/tmp/opencode/fix009`, deleted after):

| Fixture | Manipulation | Exit | Failure line |
|---|---|---|---|
| AC-009-04-03 | removed `## Stop-and-Ask decision matrix` heading | 1 | `FAIL AC-009-01-01 — docs/SPEC_PIPELINE.md is missing the '## Stop-and-Ask decision matrix' heading` |
| AC-009-04-04 | removed all title lines from `agents/spec-coder.md` | 1 | `FAIL AC-009-02-01 — spec-coder.md missing the exact section title 'Stop-and-Ask decision matrix'` |
| AC-009-04-05 | injected `"scripts/check-code-principles.sh": allow` into `spec-pipeline.md` edit block | 1 | `FAIL AC-009-03-01 — spec-pipeline.md permission.edit does not deny scripts/check-code-principles.sh (effective: allow)` |
| AC-009-04-06 | injected `\| Confluence space / parent page unknown \| Ask for the doc space \|` row into matrix | 1 | `FAIL AC-009-01-04 — forbidden Confluence reference in the matrix section: [\| Confluence space / parent page unknown \| Ask for the doc space \|]` |

Each FAIL names the offending artifact as the scenarios require. (First fixture-B attempt was invalid — appending `X` to the title still contains the substring, grep -F semantics — rerun with full line removal; noted for completeness, not a script defect.) Base fixture (unmodified copy) exited 0, proving the negatives aren't trivially-always-fail.

## Check 5 — No unaccounted behavior — PASS

Working-tree diff skimmed in full:
- `docs/SPEC_PIPELINE.md`: +19 lines, exactly the matrix section (heading, authoritative sentence, 11-row table). Nothing else. Traces to Task 1 / AC-009-01.
- 8 agent files: every added line is either (a) the authoritative-reference sentence (Task 2 / AC-009-02-01/02) or (b) the 5-line edit-deny block on the 6 agents that lacked a deny-all (Task 3 / AC-009-03-01); spec-specifier and spec-verifier got only the sentence because their existing `"*": deny` already satisfied Task 3 (the task's option (b), minimal change). 0 deletions.
- `scripts/check-stop-and-ask-matrix.sh`: read in full (366 lines). Non-vacuous: the 11 condition/action pairs in its arrays match `10-tasks.md` verbatim; Check 2 greps the exact section title plus `authoritative` + `never by improvisation` in each agent; Check 3 parses real frontmatter `permission.edit` blocks (`edit_effective_action` + `glob_to_regex`) against 5 concrete gate paths incl. the `.standards/` twin and the three linter configs; AC-009-03-02 greps `> 6` and asserts no `--threshold`/`--complexity` flag; AC-009-03-03 uses `git diff --quiet` to assert the gate script is untouched. AC-009-04-07/08 are self-describing PASS lines, but both hold independently: all 20 sub-IDs genuinely appear in output (traceability script independently resolved AC-009-01..04 against it), and the script performs no writes (no redirects/`sed -i`/`tee`/`cp`/`mv` anywhere — read-only confirmed by inspection and by running it against a scratch copy with no side effects).
- The script takes an optional ROOT arg for scratch verification (matches AC-007's scoped-flag pattern) and is read-only by construction; no task forbids the arg, and it does not violate any acceptance criterion.

---

## Verdict: **PASS**

All five checks pass. Full-repo `check-scenario-traceability.sh` exits 1 and `check-code-principles.sh` exits 1, but both are entirely explained by pre-existing, documented repo state (sibling in-flight specs + archived-spec citations; `ci/templates/*` findings) — **zero violations attributable to spec 009**, whose own scope (matrix doc, 8 agent references, gate-config lock, check script) is clean on every gate. Gate-config lock proven to hold and to detect a violation. mvp-tier claim (no `AGENTS_<PROJECT>.md`) confirmed, making the property-test and mutation skips correct. Architect (stage 5) may proceed.

Review hints for the Architect (WARNs recorded, not stops): the 17 design-principles WARNs in `ci/templates/*` are pre-existing; a follow-up spec could address the `ci/templates` FAILs (CC 14/10/10/8/7), none of which belong to this spec.
