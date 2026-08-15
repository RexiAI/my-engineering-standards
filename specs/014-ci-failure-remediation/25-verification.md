# Verification — spec 014 (CI-failure check-and-remediate loop)

**Verifier:** stage 4, independent re-run of Coder + Refactorer claims.
**Branch:** `spec/014-ci-failure-remediation`
**Date:** 2026-08-15
**Sources checked against:** `10-tasks.md`, `20-acceptance/AC-014-01..05` (37 sub-IDs).
`00-informal.md` was **not** read (information barrier).

---

## Check 1 — Scenario traceability — PASS (AC-014 scope clean)

**Command:** `bash scripts/check-scenario-traceability.sh`
**Full-repo exit code: 1** — 126 violations, all in sibling/archived specs. This is
the known mid-pipeline condition: in-flight specs 007–013, 015, 017–019 have
scenario headings with no test citations yet, and archived specs (001–006, 016,
020–022) have test citations whose scenario headings were removed from `specs/`
on archive. **Zero AC-014 entries appear in either FAIL group.**

Full-repo AC-014 result (representative excerpt):
```
PASS AC-014-01 — traced to a test
PASS AC-014-02 — traced to a test
PASS AC-014-03 — traced to a test
PASS AC-014-04 — traced to a test
PASS AC-014-05 — traced to a test
✘ Scenario traceability check: 126 violation(s).   (exit 1)
```

**Scoped AC-014 run** (scratch `SPECS_DIR` containing only
`014/20-acceptance/*.md` + the touched source files):
```
Scenario IDs found: 5
PASS AC-014-01 — traced to a test
PASS AC-014-02 — traced to a test
PASS AC-014-03 — traced to a test
PASS AC-014-04 — traced to a test
PASS AC-014-05 — traced to a test
✘ ... 3 violation(s).   (exit 1)
```
The scoped run's 3 check-2 violations are `AC-002-01`, `AC-002-02`, `AC-004-04`
— pre-existing citations in `docs/SPEC_PIPELINE.md` scenario-format examples
(lines 134/140/152, present on `main` before 014) and archived one-pagers. The
014 diff introduces **zero** non-014 AC citations (`git diff | grep '^+'` AC-ID
scan: empty).

**Sub-ID coverage (37 per the Coder — confirmed):**
```
sub-IDs defined in 20-acceptance: 37
sub-IDs asserted in check-post-pr-ci-loop.sh: 37
defined-but-not-asserted: (none)
asserted-but-not-defined: (none)
```
Every AC-014 sub-ID (9+7+6+9+6 = 37) is asserted by the test carrier, and every
asserted ID exists as a scenario heading. No AC-014 reference dangles.

**Judgment: AC-014 scope is clean.** The full-repo exit 1 is entirely
attributable to sibling/archived specs, not spec 014.

---

## Check 2 — Full relevant suite — PASS

Spec 014 is prompts/docs-only (no JVM/Go/Node stack); its "test suite" is the
shipped check script plus the repo gates. All executed for real:

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-post-pr-ci-loop.sh` | 0 | syntax OK |
| `bash scripts/check-post-pr-ci-loop.sh` | 0 | "Post-PR CI loop check: all assertions hold." |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | "All validations passed" (35 required files; 1 pre-existing SKILL.md WARN, skills/hallmark) |
| `make lint` | 0 | All JSON/YAML valid; `.github/workflows/self-ci.yml` `[OK]` |

`.github/workflows/self-ci.yml` parses (YAML validation `[OK]` in `make lint`)
and contains the new step, hard-gated (no `continue-on-error`):
```yaml
      - name: Check post-PR CI loop mechanics
        run: ./scripts/check-post-pr-ci-loop.sh
```

### Assertion-count reconciliation (Coder 92/92 vs Refactorer 125)

**Actual, measured from a real run** (ANSI-stripped):
```
PASS lines: 125     FAIL lines: 0
per task: task1=23  task2=19  task3=20  task4=51  task5=12   (sum 125)
```
**125 is the operative number and matches the Refactorer's report exactly.**
The Coder's "92/92 PASS" is **not reproducible from the current tree**: the
script is untracked (`?? scripts/check-post-pr-ci-loop.sh`), so no prior
revision exists to diff against. Both counts cannot describe the same script
state; the Coder's 92 is either a stale count from an earlier iteration or a
different counting convention. The Refactorer's "no assertions added or
removed" is likewise unverifiable from git history (untracked file), but its
**reported count (125) matches the live script's actual output exactly**, which
is the claim that matters for the gate. The assertion set is complete and
consistent: all 37 scenario sub-IDs are asserted, and the negative fixture
(Check 4) proves the assertions detect real violations.

---

## Check 3 — Complexity gate — PASS

Changed files are markdown prompts/docs + one bash script; no Go/Java/JS
changed, so the applicable real linters are `bash -n` (green, above) and the
design-principles gate (Check 3.5). For the check script, the Refactorer's
claims were verified directly:

- **All functions ≤2:** every function's bash-level cyclomatic complexity was
  counted: `pass`, `fail`, `section`, `contains`, `absent` = 1 (no branches);
  `frontmatter`, `str_contains`, `str_absent` = 2 (single if/else). The
  top-level agent-resolution `while` loop has one if/else (2). **Claim holds.**
- **contains/absent consolidated as thin delegates:** `contains()` and
  `absent()` are one-line wrappers delegating to `str_contains`/`str_absent`
  (lines 103–111). **Claim holds.**
- **SIGPIPE flake fix (pipes → here-strings):** `str_contains`/`str_absent`
  use `grep -q... <<< "$hay"` (here-string), not `... | grep -q`. The fix is
  technically sound: with `set -o pipefail`, `grep -q` exiting on first match
  SIGPIPEs the upstream producer, making the pipeline report failure for a
  pattern that IS present. The script documents this at lines 81–83.
- **Stress/stability:** 10 consecutive runs (plus ~15 total across this
  session) → **0 failures**, exit 0 every time. Stable, no flake reproduced.
- **Assertion semantics unchanged:** all 37 sub-IDs asserted; every asserted
  string verified present in the target files (the 125 PASS lines are real
  matches); negative fixture (Check 4) confirms wrong content is flagged.

---

## Check 3.5 — Design-principles gate — FAIL (pre-existing, NOT attributable to spec 014)

**Command:** `scripts/check-code-principles.sh` (default mode)
**Exit code: 1** — 5 FAIL(s), 17 WARN(s).

**Every FAIL/WARN is confined to `ci/templates/*`** — files untouched by spec
014. Verbatim FAIL lines:
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```
Verbatim WARN lines (17; excerpt covers all distinct sources):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): ...
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```
(Full duplication block bodies omitted here — all 17 WARNs are in
`ci/templates/go-saga-lint.go`, `eslint-saga-rules/saga-compensation.js`,
`archunit/OutboxArchRules.java`, `archunit/SagaArchRules.java`.)

**Attribution judgment:** zero FAIL/WARN references any spec-014 file
(`agents/*`, `commands/build.md`, `docs/SPEC_PIPELINE.md`,
`.github/workflows/self-ci.yml`, `scripts/check-post-pr-ci-loop.sh` — verified
by grep over the full output). This is the documented pre-existing repo state
(saga/outbox template lints). Per policy, a FAIL is a pipeline stop *if
attributable to the change*; here none is. Recorded as pre-existing; flagged
to the Architect for awareness (the `ci/templates/*` gate debt is outside 014's
scope).

**mvp-tier confirmation:** no `AGENTS_<PROJECT>.md` exists at repo root or in
`.standards/`. The gate itself printed `Property tests: skipped (project tier
is mvp — production+ required)` — tier detection works, so the property-test
skips (and the mutation-runner skip) are correct for this project.

---

## Check 4 — Scenario-to-behavior spot check — PASS

Two scenarios hand-verified against the actual files (content assertions, per
the 10-tasks.md test-carrier design):

**AC-014-05-01/02/04 (PR Opener re-push)** — `agents/spec-pr-opener.md` lines
72–85 contain the fix-round mode: commits "as one conventional commit
(`fix: ...` referencing the failing check ID(s))" on the existing
`spec/NNN-slug` branch (AC-014-05-01), "you do not open a new PR" + `gh pr view`
(AC-014-05-02), and preserves "`30-report.md` to be green", "never commit to
`main`/`master`", "never create git version tags" (AC-014-05-04). Frontmatter
line 10: `"git push*": ask` (AC-014-05-05). **Given/When/Then implemented.**

**AC-014-04-01/03/04/07 (bounded orchestrator loop)** — `commands/build.md`
lines 23–39: loop starts "After the PR Opener reports the PR URL", invokes
`spec-verifier`, routes to `spec-coder`/`spec-refactorer`, re-invokes
`spec-pr-opener`, scoped re-check, "at most 3 rounds", "independent of Phase 1
... per spec 008's remediation-budget section (do not re-declare the budget)",
"On the 3rd FAIL ... relay ... verbatim and escalate to the human — no 4th
round", "never reported as green without a fixing round". The step list does
not tell the orchestrator to run `gh` or `git commit/push` (AC-014-04-07 —
script asserts absence). **Given/When/Then implemented.**

**Also verified (from the check list):** `docs/SPEC_PIPELINE.md` lines 218–248
carry the exact `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`
query, the `bucket` parse rule, `--watch` polling, `gh api .../check-runs` +
`gh run view <RUN-ID> --log-failed`, "at most 3", "independent of Phase 1",
008 ordering dependency ("valid only once 008's section exists") — and no
"re-run until green" phrasing anywhere. `agents/spec-verifier.md` lines 90–114
have the phase-2 section with `--log-failed`, `conclusion == "failure"`,
scoped re-check on re-trigger, and unchanged frontmatter
(`edit: specs/*/25-verification.md` allow; `git commit*`/`git push*` deny).

**Negative fixture (assertion realism):** copied the touched tree to
`/tmp/opencode/014-neg`, injected two wrong strings into the copy of
`docs/SPEC_PIPELINE.md` (`gh pr checks` → `gh pr checkz`, `PASS/FAIL parse
rule` → `PASS/FAIL parse rulz`), ran
`scripts/check-post-pr-ci-loop.sh <scratch>`:
```
FAIL AC-014-01-01 — expected 'gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link' in ...
FAIL AC-014-01-01 — expected 'PASS/FAIL parse rule' in ...
5 assertion(s) failed!   (exit 1)
```
The injected wrong strings were flagged; the assertions reference real content
and detect deviations. Scratch removed afterward.

---

## Check 5 — No unaccounted behavior — PASS

Full diff skimmed (`git diff` = 8 files, +140 lines, 0 deletions; plus the new
untracked script). Every change traces to a task or a documented decision:

| Change | Traces to |
|---|---|
| `docs/SPEC_PIPELINE.md` +32 | Task 1 (AC-014-01) |
| `agents/spec-verifier.md` +26 | Task 2 (AC-014-02) |
| `agents/spec-coder.md` +14, `agents/spec-refactorer.md` +15 | Task 3 (AC-014-03) |
| `commands/build.md` +18, `agents/spec-pipeline.md` +14 | Task 4 (AC-014-04) |
| `agents/spec-pr-opener.md` +15 | Task 5 (AC-014-05) |
| `scripts/check-post-pr-ci-loop.sh` (new, untracked) | 10-tasks.md open question 1, recommendation (a) — test carrier |
| `.github/workflows/self-ci.yml` +6 (new hard-gated step) | 10-tasks.md open question 1, recommendation (a) — carrier wired into CI |

No new agents, no new CI infrastructure beyond the single check step, no
logic that lacks a task/scenario justification. The script's own negative
assertions ("banned phrase" patterns) are intentionally present in the script
itself but asserted absent from the checked files — documented at script lines
25–29, correct as written (the script is the test carrier, not an assertion
target).

---

## Overall verdict: **PASS**

Architect may proceed. All spec-014-attributable gates are green:

1. Traceability: AC-014-01..05 traced, 37/37 sub-IDs asserted bidirectionally,
   zero dangling AC-014 refs. Full-repo exit 1 is the documented sibling/archived
   condition, not 014.
2. Suite: check script exit 0 (125/125 PASS), `bash -n` OK, orchestration 0,
   `make validate-all` 0, `make lint` 0, self-ci.yml parses with the new
   hard-gated step.
3. Complexity: all functions ≤2, thin delegates, here-string SIGPIPE fix,
   stable across 10 runs, semantics proven by negative fixture.
3.5. Design-principles gate exits 1 — **all 5 FAILs / 17 WARNs confined to
   `ci/templates/*`, none attributable to spec 014** (pre-existing repo debt;
   flagged to Architect, not a stop for this spec).
4. Spot checks (AC-014-05, AC-014-04 + doc/verifier/pipeline sections) match
   Given/When/Then; negative fixture flags injected wrong content.
5. No unaccounted behavior in the diff.

**Discrepancy noted (non-blocking):** Coder's "92/92 PASS" is unreproducible
from the current tree (script untracked, no history); the Refactorer's 125
matches the live run exactly and is the authoritative count.
