# Verification Report — spec 008: Bounded remediation budget

Stage: 4 (Verifier). Attempt 1, phase 1 (first full run).
Date: 2026-08-15. Branch: `spec/008-remediation-budget`.
Scope of changes under test: `docs/SPEC_PIPELINE.md`, `agents/spec-verifier.md`,
`agents/spec-coder.md`, `agents/spec-refactorer.md`, `agents/spec-pipeline.md`,
`agents/spec-mutation-runner.md`, `commands/build.md`,
`.github/workflows/self-ci.yml`, and the new untracked
`scripts/check-remediation-budget.sh` (test carrier).

No production code was written; the only write is this file.

---

## 1. Scenario traceability — PASS (scoped AC-008 clean; full-repo exit 1, pre-existing)

Command: `scripts/check-scenario-traceability.sh`
Full-repo exit code: **1** (126 violations).

The full-repo failure is the known mid-pipeline state, not a spec-008 defect:

- Defined-but-untraced: AC-007-01..04, AC-009..AC-019 (sibling in-flight specs
  with no test carrier yet).
- Referenced-but-no-heading (stale/archived): AC-001..AC-006, AC-016, AC-020..AC-022
  (archived-spec citations in existing checks, matching `docs/changes/` history).

AC-008 scoped result (verbatim from the run):

```
PASS AC-008-01 — traced to a test
PASS AC-008-02 — traced to a test
PASS AC-008-03 — traced to a test
PASS AC-008-04 — traced to a test
PASS AC-008-05 — traced to a test
```

No FAIL line in the entire run contains `AC-008` — all five of spec 008's
scenarios are traced to real tests (the `AC-008-NN` assertion calls in
`scripts/check-remediation-budget.sh`), and no AC-008 reference dangles.
Judgment: **AC-008 scope is clean.**

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-remediation-budget.sh` | 0 | syntax valid |
| `./scripts/check-remediation-budget.sh` | 0 | every check passed (84/84 PASS, `✔ Remediation budget check: every check passed.`) |
| `./scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all 35 required files present, cross-refs valid (1 pre-existing WARN: `skills/hallmark/SKILL.md` >500 lines, unrelated) |
| `make lint` | 0 | all JSON/YAML valid, incl. `.github/workflows/self-ci.yml` |
| `python3 -c "import yaml...; yaml.safe_load(...)" .github/workflows/self-ci.yml` | 0 | `YAML_OK` — workflow still parses |

The new self-ci step is present in `.github/workflows/self-ci.yml` (verbatim
context):

```yaml
      - name: Check remediation budget
        run: ./scripts/check-remediation-budget.sh
```

(placed before "Install shellcheck"; the workflow's `validate` job also still
runs the orchestration and model-env checks — nothing displaced.)

## 3. Complexity gate — NOT APPLICABLE to this change (recorded, not invented)

No cyclomatic-complexity linter is configured for shell in this repo. The
repo's complexity tooling (`pmd`, `golangci-lint` cyclop/gocognit, ESLint
`complexity`) covers Java/Go/JS/TS only, and this spec changed **no
Java/Go/TS/JS files** — the diff is 7 `.md` + 1 `.yml` + 1 new `.sh`.
`check-code-principles.sh` (run below) confirms the same: it analyzes java/go/node
and reported zero violations outside pre-existing `ci/templates/*` state.

For the record (manual count, not a tool): the four named functions each have
cyclomatic complexity 1–2 (`collapse_whitespace` CC=1, single pipeline;
`require_file` CC=2, single `if`; `assert_contains` CC=2, single `if`;
`assert_absent` CC=2, single `if`), consistent with the Refactorer's claim. Note:
self-ci runs `shellcheck scripts/*.sh` (with `continue-on-error: true`), which is
a correctness linter, not a complexity gate; shellcheck is not installed locally,
so it was not re-run here.

## 3.5. Design-principles gate — exit 1, all FAILs/WARNs pre-existing in `ci/templates/*`, none attributable to spec 008

Command: `scripts/check-code-principles.sh` (default mode, repo root)
Exit code: **1** — "5 FAIL(s), 17 WARN(s)." Property tests: skipped
("project tier is mvp — production+ required"), which confirms the mvp tier.

Every FAIL and WARN line, verbatim:

```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Every one is confined to `ci/templates/*` — a directory this spec did not touch.
Spec 008's changed files are `.md`/`.sh`/`.yml`, which the gate's analyzed
languages (java/go/node) do not cover. Judgment: **no FAIL or WARN is
attributable to spec 008's changes.** The pre-existing FAILs are flagged to the
Architect for awareness only (out of this spec's scope; pipeline does not stop on
pre-existing state the spec did not create — the gate's FAILs here are not
"Every FAIL is a pipeline stop" failures of *this* change).

## 4. Scenario-to-behavior spot check — PASS (3 scenarios + adversarial guard test)

**AC-008-01-04 — forbidden phrasing verbatim.** `docs/SPEC_PIPELINE.md` §Remediation
budget (line ~222) contains the exact string `re-run until green is forbidden
phrasing`. Confirmed by direct read, not only via the check script. Also verified
this is the *only* occurrence of `re-run until green` in docs/ — the five prompt
and command files (`spec-verifier.md`, `spec-coder.md`, `spec-refactorer.md`,
`spec-pipeline.md`, `commands/build.md`) contain it nowhere, satisfying the
`assert_absent` scenarios (AC-008-02-06, AC-008-03-05, AC-008-04-06).

**AC-008-04-01 — bounded loop in `commands/build.md`.** Direct read confirms the
command describes: Verifier BLOCK → re-delegate failing fix to `spec-coder`
(behavior) or `spec-refactorer` (structural/complexity) → re-invoke
`spec-verifier` for scoped re-verification → at most **3** cycles; on the 3rd
BLOCK, stop, relay failing gate IDs and last evidence from `25-verification.md`
verbatim, escalate to the human, no 4th re-delegation. Matches Given/When/Then
of AC-008-04-01 and AC-008-04-03.

**Forbidden-phrase guard actually fires (adversarial test).** Created a scratch
tree (`/tmp/opencode/rem-scratch/`) with copies of all touched files, appended
`re-run until green is the plan here` to the scratch `agents/spec-verifier.md`,
and ran `./scripts/check-remediation-budget.sh /tmp/opencode/rem-scratch`:

```
SCRATCH_RUN_EXIT=1
FAIL AC-008-02: no open-ended re-run phrasing — forbidden string 're-run until green' present in .../agents/spec-verifier.md
✘ Remediation budget check: 1 violation(s).
```

Guard verified. Scratch tree removed after the test.

**AC-008-02-05 / AC-008-03-04 — frontmatter and permissions unchanged.** Diff
review: the `agents/spec-verifier.md`, `spec-coder.md`, `spec-refactorer.md`,
`spec-mutation-runner.md` diffs show zero changes inside the YAML frontmatter
(grep for permission/edit/deny/allow lines in the diffs returns empty), and all
four still carry `"git push*": deny` / `"git commit*": deny` (asserted by the
script, which passes). The `edit: specs/*/25-verification.md` allowance is intact.

**Self-ci step present** — see check 2.

## 5. No unaccounted behavior — PASS

Full diff reviewed (8 files, +115/−15). Every hunk traces to a task:

- docs section + `30-report.md` artifact-layout line → Task 1 (artifact-layout
  change explicitly permitted by T1).
- `spec-verifier.md` additions → Task 2.
- `spec-coder.md` / `spec-refactorer.md` re-fix sections → Task 3.
- `commands/build.md` + `spec-pipeline.md` loop rewrite → Task 4 (one-sentence
  phase-2 acknowledgement only; no CI-query mechanics; no new agents/infra).
- `spec-mutation-runner.md` Remediation record bullet → Task 5.
- `self-ci.yml` step + `scripts/check-remediation-budget.sh` → open question 1,
  resolved to option (a) (grep-based content assertions, mirroring spec 006);
  the script is the test carrier that makes AC-008-01..05 traceable.

The new script is not a vacuous pass: 84 `assert_contains`/`assert_absent` calls
(not 86 — count verified by `grep -c`), each with a specific needle against a
specific file. The needles are real strings in the touched files — confirmed by
direct read of every target file during spot checks (e.g. `Phase 1 budget is
**max 3**`, `independent of **Phase 1**`, `re-run until green is forbidden
phrasing`, `failing gate IDs and the last evidence from \`25-verification.md\``),
and by the adversarial test above proving the negative assertions are not
tautological. Missing-file behavior is handled (`require_file` fails loudly, no
silent skip). Exit 0 on the clean tree.

**mvp-tier claim confirmed:** no `AGENTS_*.md` exists at the repo root
(`ls AGENTS_*.md` → no such file). `check-code-principles.sh` derives the tier
from the `AGENTS_*.md` "Conformance tier:" declaration (script lines 40, 80);
absent → mvp. The gate itself printed `(tier: mvp)` and skipped property tests
("Project tier is mvp — production+ required"), so the Architect's
property-test/mutation skips for this spec are correct per the conformance table.

## WARNs to flag to the Architect (review hints, not stops)

1. Design-principles gate: 17 WARNs — all in `ci/templates/*` (go-saga-lint.go,
   eslint-saga-rules, archunit) — pre-existing, untouched by spec 008.
2. `make validate-all`: 1 WARN — `skills/hallmark/SKILL.md` body 562 lines
   (>500 limit) — pre-existing, unrelated.
3. Full-repo traceability exits 1 on sibling/archived specs (see check 1) —
   expected mid-pipeline state; will clear as sibling specs land.

## Verdict

**PASS** — Architect may proceed (mutation run skipped at mvp tier; PR Opener
may proceed per stage-5b).

Every check re-executed independently: AC-008 traceability clean (5/5 traced, no
dangles); new check script runs green (exit 0, 84/84); orchestration, validate-all,
lint, and self-ci YAML all exit 0 with the new "Check remediation budget" step
present; complexity gate not applicable to this shell/markdown-only change (no
Java/Go/TS/JS touched); design-principles gate exit 1 with all FAILs/WARNs
confined to untouched `ci/templates/*`; scenario-to-behavior spot checks match
(file content confirmed by direct read, adversarial forbidden-phrase test fires
with exit 1); diff fully accounted for; mvp-tier claim substantiated.
