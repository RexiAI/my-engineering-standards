# 25-verification — 037-split-spec-pipeline-doc

Verifier: stage 4 (`spec-verifier`). **Attempt 1, phase 1** — first full run, no
prior BLOCK in this phase. Budget counters as exported by the orchestrator:
`SPEC_LOOP_COUNT=1`, `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`.

- Worktree: `/home/dbueno/.local/share/opencode/worktree/471827/spec-037`
- Base commit: `39fdd21` (detached HEAD; 036 merged at `75d2780`, so precondition
  P1 — "036 landed" — holds: no `specs/036-pipeline-agent-single-source/`
  remains on the base branch)
- Verified artifacts: `10-tasks.md`, `20-acceptance/AC-037-0(1, 2, 3, 4, 5)-*.md`
- Information barrier: `00-informal.md` was **not** read. Verification is against
  the tasks and acceptance scenarios only.

## Verdict

**PASS** — every gate ran and produced no findings.

Gate IDs failed: **none**. Gates run: `traceability`, `test-suite`,
`complexity`, `design-principles`, `spot-check`; supplementary `orchestration`
and `read-cost` also pass. `unaccounted` produced two recorded observations and
no blocker.

### Behavior vs structural

This spec has **no behavioral change surface**: it moves prose and rewrites
references. The only executable changes are (a) `scripts/check-orchestration.sh`
extended with a `docs/spec-pipeline/[a-z-]+\.md` path pattern and a new
`§heading` check, (b) the new `scripts/measure-stage-read-cost.sh`, and (c) three
check scripts whose *doc source path* was repointed
(`check-post-pr-ci-loop.sh`, `check-pr-review.sh`, `check-audit-trail.sh` plus
header comments elsewhere). Every one is covered by a passing test in the full
suite, and (a)/(b) additionally by their own AC-037 tests. The remaining 80-odd
files are one-line reference repoints or the new `docs/spec-pipeline/*.md`
content.

Consequently the findings below are all **structural**; none is a behavior
defect. None is a FAIL.

## Gate results

| Gate | ID | Command | Exit | Result |
|---|---|---|---|---|
| Scenario traceability | `traceability` | `scripts/check-scenario-traceability.sh --json` | 0 | PASS |
| Full test suite | `test-suite` | `make test` | 0 | PASS — 762 ok, 0 not ok, 0 skipped |
| Complexity gate | `complexity` | `make lint` + `shellcheck -S warning` + `bash -n` | 0 | PASS |
| Design-principles gate | `design-principles` | `scripts/check-code-principles.sh --json` | 0 | PASS — 0 FAIL; 58 WARN, all pre-existing and none blame-attributable to this diff |
| Scenario-to-behavior spot check | `spot-check` | manual, 3 scenarios | — | PASS |
| Orchestration wiring (supplementary) | `orchestration` | `scripts/check-orchestration.sh` | 0 | PASS |
| Read-cost (supplementary) | `read-cost` | `scripts/measure-stage-read-cost.sh` | 0 | PASS — worst stage `pr-opener` 0.480 |
| No unaccounted behavior | `unaccounted` | diff skim | — | PASS with observations |

## Stop-and-Ask conditions resolved

- **Working tree dirty** → not a stop here, and recorded so it is auditable.
  The matrix's "STOP and report" targets *foreign* dirt. Every dirty path is this
  spec's own uncommitted deliverable (stage 5b commits it), and no path outside
  the spec's surface is dirty. Nothing was stashed and nothing was committed.
- **Spec artifacts not found** → `10-tasks.md` and `20-acceptance/` both present.
- **Project type ambiguous** → not ambiguous: docs + shell repo, `mvp` tier
  (`check-code-principles.sh` reports `"tier": "mvp"`).
- **Design gate WARN (not FAIL)** → recorded below under §Findings, flagged to the
  Architect, pipeline not stopped.
- **Out-of-scope findings** → recorded below, not fixed, follow-up spec proposed.

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-01T13:34:42Z

{
  "checks": [1, 2],
  "passes": ["AC-037-01 — traced to a test", "AC-037-02 — traced to a test", "AC-037-03 — traced to a test", "AC-037-04 — traced to a test", "AC-037-05 — traced to a test"],
  "fails": []
}

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-01T13:34:17Z

Started 2026-11-01T13:30:09Z (bats 1.11.0, `bats --tap scripts/tests/*.bats`);
finished 2026-11-01T13:34:17Z. Totals: **762 ok, 0 not ok, 0 skipped**.
`scripts/check-bats-assertions.sh` (the anti-vacuity guard) ran first inside the
same target and passed. Every AC-037 scenario test ran and passed:

```
ok 198 AC-037-01-01: index keeps the cross-cutting sections
ok 199 AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit
ok 200 AC-037-01-03: index length is at most 250 lines
ok 201 AC-037-01-04: every stage-file path in the Stage files table exists
ok 203 AC-037-04-01: the split tree passes check-orchestration
ok 204 AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1
ok 205 AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1
ok 206 AC-037-04-04: an index §anchor that exists resolves and exits 0
ok 209 AC-037-05-01: every stage reads at most 50% and the script exits 0
ok 210 AC-037-05-02: a stage over the budget exits 1 and is named
ok 211 AC-037-05-03: a stage at exactly 50% of the baseline passes
ok 214 AC-037-03-01: moved-section references are repointed to the new file
ok 215 AC-037-03-02: index-section references keep the index path
ok 216 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 219 AC-037-02-01: one file per stage agent under docs/spec-pipeline/
ok 220 AC-037-02-02: every original top-level section lands in exactly one file
ok 221 AC-037-02-03: named sections live in their owning stage file
ok 222 AC-037-02-04: every stage file points back to the index and names its index sections
ok 18 AC-030-01-06: required body sections present
```

Tail of the run (verbatim):

```
ok 757 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 758 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 759 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 760 unit: a cap smaller than the marker still never exceeds the cap
ok 761 unit: state exactly at the cap is not truncated and emits no reason
ok 762 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
EXIT=0
```

## Evidence: complexity gate

command: make lint && shellcheck -S warning scripts/check-orchestration.sh scripts/measure-stage-read-cost.sh && bash -n <every changed/new .sh>
exit: 0
at: 2026-11-01T13:34:47Z

The repo's own `make lint` target (0), then a real shell linter over the two
scripts this spec created or rewrote, then a syntax check over every changed
`.sh`. There is no golangci/PMD/ESLint surface for this repo's own code (its code
is shell + markdown), so `shellcheck` is the real linter for the changed files;
the cyclomatic/`KISS` category is covered by the design-principles script below.

`make lint` — 57 `[OK]`, 0 `[FAIL]`:

```
  [OK] ci/gitlab/frontend/ci-static.yml
  [OK] ci/gitlab/gitlab-ci.yml
Done.
```

`shellcheck -S warning` (exit 0):

```
(no output — no warnings)
```

`bash -n` over `scripts/check-orchestration.sh`, `scripts/measure-stage-read-cost.sh`
and every `.sh` in the diff (exit 0):

```
(no output — all files parse)
```

## Evidence: design-principles gate

command: scripts/check-code-principles.sh --json
exit: 0
at: 2026-11-01T13:34:43Z

Full repository scan, `mvp` tier, all nine gate categories. **0 FAIL.** The 58
WARN lines are reproduced verbatim below. None of them is attributable to this
diff: the blame-scoped run (next block) reports 0 findings, and every WARN sits
in a file this spec either never touched or touched only by a comment-path
repoint.

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)", "file": "./scripts/check-code-principles.selftest.sh", "line": "641" }, { "message": "Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)", "file": "./scripts/check-code-principles.selftest.sh", "line": "639" }, { "message": "Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)", "file": "./scripts/tests/gate-telemetry.selftest.sh", "line": "150" }, { "message": "Comments: commented-out code (./scripts/check-bats-assertions.sh:21)", "file": "./scripts/check-bats-assertions.sh", "line": "21" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)", "file": "./scripts/gate-clean-code-lib.sh", "line": "97" }, { "message": "Comments: commented-out code (./scripts/verify-production-deploy.sh:30)", "file": "./scripts/verify-production-deploy.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:58)", "file": "./scripts/check-code-principles.sh", "line": "58" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:121)", "file": "./scripts/check-code-principles.sh", "line": "121" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)", "file": "./scripts/check-code-principles.sh", "line": "57" }, { "message": "Comments: attribution comment (./scripts/check-code-principles.sh:59)", "file": "./scripts/check-code-principles.sh", "line": "59" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)", "file": "./scripts/check-remediation-budget.sh", "line": "139" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)", "file": "./scripts/check-remediation-budget.sh", "line": "209" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)", "file": "./scripts/lint-outbox-schema.sh", "line": "13" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)", "file": "./scripts/lint-outbox-schema.sh", "line": "22" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)", "file": "./scripts/check-saga-timeouts.sh", "line": "185" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)", "file": "./scripts/ci-smoke-test.sh", "line": "51" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)", "file": "./scripts/ci-smoke-test.sh", "line": "53" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)", "file": "./scripts/ci-smoke-test.sh", "line": "90" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)", "file": "./scripts/ci-smoke-test.sh", "line": "92" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)", "file": "./scripts/ci-smoke-test.sh", "line": "132" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)", "file": "./scripts/ci-smoke-test.sh", "line": "134" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)", "file": "./scripts/ci-smoke-test.sh", "line": "149" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)", "file": "./scripts/ci-smoke-test.sh", "line": "151" }, { "message": "Comments: commented-out code (./scripts/check-loop-files.sh:10)", "file": "./scripts/check-loop-files.sh", "line": "10" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:6)", "file": "./scripts/init-ci.sh", "line": "6" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:43)", "file": "./scripts/init-ci.sh", "line": "43" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:39)", "file": "./scripts/check-loop-triage.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:49)", "file": "./scripts/check-loop-triage.sh", "line": "49" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:67)", "file": "./scripts/check-loop-triage.sh", "line": "67" }, { "message": "Comments: commented-out code (./scripts/token-stats.sh:10)", "file": "./scripts/token-stats.sh", "line": "10" }, { "message": "Comments: commented-out code (./scripts/guard-env.sh:21)", "file": "./scripts/guard-env.sh", "line": "21" }, { "message": "Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)", "file": "./scripts/check-ci-sweeper.sh", "line": "37" }, { "message": "Comments: commented-out code (./scripts/check-security-hardening.sh:39)", "file": "./scripts/check-security-hardening.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/judgment-preflight.sh:16)", "file": "./scripts/judgment-preflight.sh", "line": "16" }, { "message": "Comments: commented-out code (./scripts/check-model-env.sh:30)", "file": "./scripts/check-model-env.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/gate-stats.sh:20)", "file": "./scripts/gate-stats.sh", "line": "20" }, { "message": "Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)", "file": "./scripts/check-pr-babysitter.sh", "line": "56" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)", "file": "./scripts/check-saga-tests.sh", "line": "85" }, { "message": "Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "197" }, { "message": "Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "147" }, { "message": "Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "201" }, { "message": "Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)", "file": "./ci/templates/go-saga-lint.go", "line": "61" }, { "message": "Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "65" }]
}
```

### Scoped blame run (spec-attributable findings only)

command: scripts/check-code-principles.sh --json -BaseRef HEAD
exit: 0
at: 2026-11-01T13:34:45Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": []
}
```

## Evidence: scenario-to-behavior spot check

command: manual spot check — 3 scenarios read against their tests and against the artifact under test
exit: 0
at: 2026-11-01T13:32:41Z

Three scenarios picked, and each assertion compared against the scenario's
Given/When/Then, not merely the test's name.

**1. AC-037-02-02 — "Every original section lands exactly once."**
Scenario: *Given* the list of top-level `##` headings at the base commit,
*When* headings across the new index and `docs/spec-pipeline/*.md` are collected,
*Then* each original heading appears in exactly one file.
Test (`scripts/tests/ac-037-stage-files.bats`, `AC-037-02-02`): iterates a frozen
23-entry `BASE_HEADINGS` list and requires `grep -hxF "## $heading"` across index
+ all stage/shared files to count exactly 1. **Assertion matches the scenario.**
Independently re-derived (fence-aware `##` extraction from
`git show HEAD:docs/SPEC_PIPELINE.md`, compared against the current tree):

```
base top-level ## headings: 23
headings not landing exactly once: 0
index-referenced stage/shared docs: 13
missing: []
```

The frozen list really is the base list (23 = 23), so the test is not
self-referential.

**2. AC-037-05-03 — "Exactly 50% passes."**
Scenario: *Given* a stage whose cost equals exactly 50% of the baseline,
*When* the script runs, *Then* that stage passes. Test builds
`index=20000` + `refactorer=5418` = 25418 = `50836/2` exactly and asserts
`status -eq 0` plus `0.500  ok`. Boundary arithmetic verified by hand against
`report_stage`'s `bytes*100 <= BASELINE*50` test: 2541800 <= 2541800 → passes.
**Genuine boundary test, not a renamed happy path.**

**3. AC-037-04-03 — "A missing section anchor is detected."**
Scenario: *Given* a scratch tree citing `docs/spec-pipeline/coder.md §No Such
Section`, *When* `check-orchestration.sh <scratch>` runs, *Then* it exits 1 and
prints the citing file:line and the missing section. Test asserts `status -eq 1`,
`agents/spec-fixture.md:5` (a real line number, not just the filename) and
`No Such Section`. **Assertion matches the scenario**, including the `:line`
clause that distinguishes this scenario from AC-037-04-02.

Spot-check conclusion: no false green found in the three sampled scenarios.

## Evidence: orchestration wiring (supplementary)

command: scripts/check-orchestration.sh
exit: 0
at: 2026-11-01T13:34:46Z

```
Checking agent references (commands/, agents/)...
Checking skill references (agents/)...
Checking scripts/ references (agents/, commands/, AGENTS.md)...
Checking docs/ and language-specific/ references (agents/, commands/, AGENTS.md)...
Checking agents/ for rules duplicated from docs/SPEC_PIPELINE.md...
Checking §heading references into the pipeline docs (agents/, commands/, AGENTS.md)...

All orchestration references valid.
```

Check 4 now matches `docs/spec-pipeline/[a-z-]+\.md` and scans `commands/` and
`AGENTS.md` in addition to `agents/` (task 4), and check 6 resolves every
`<pipeline doc> §<Section>` citation. Independently, I re-resolved **125**
`docs/SPEC_PIPELINE.md §…` / `docs/spec-pipeline/*.md §…` references across
`agents/ commands/ AGENTS.md docs/ scripts/ skills/ okf/ language-specific/ ci/`
(including two destinations check 6 does not scan, `docs/` and `scripts/`) and
found no reference to a moved section that still points at the index.

## Evidence: read cost (supplementary)

command: scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-01T13:34:47Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  13664   0.268  ok
coder               15379   0.302  ok
refactorer          13666   0.268  ok
verifier            20820   0.409  ok
mutation-runner     20763   0.408  ok
pr-opener           24439   0.480  ok
deployer            15832   0.311  ok

Every stage reads at most 50% of the unsplit document.
```

Baseline constant verified against the artifact it claims to measure:
`git show HEAD:docs/SPEC_PIPELINE.md | wc -c` = **50836** bytes, 893 lines —
matches `BASELINE_BYTES=50836` in the script exactly. Worst stage is `pr-opener`
at 0.480 (24439 bytes, 96.1% of the 25418-byte budget) — passing, but the margin
is thin enough to flag to the Architect: any growth in `pr-opener.md` (or of a
shared file it Must-reads) above ~979 bytes breaks the ≥50% claim.

## Findings

### Out-of-scope findings — recorded, not fixed, follow-up spec proposed

**O-1 — `check-agent-doc-duplication.sh` no longer covers where the rules live
(Refactorer flag 3, confirmed).** The script compares `agents/*.md` verbatim
against `docs/SPEC_PIPELINE.md` only (`DOC="$ROOT/docs/SPEC_PIPELINE.md"`), and
`check-orchestration.sh` check 5 delegates to it. Before this spec the index held
all 23 sections, so that was full coverage; after the split the index keeps only 6 of
them and 42,448 bytes of rules sit in `docs/spec-pipeline/*.md`, outside the scanner's
reach. Check 5 is therefore silently weaker than it was.

Is that a gap *for this spec*? Not a gate failure — Task 4 scopes the
`check-orchestration.sh` extension to check 4 plus the new anchor check, and no
AC-037 scenario covers check 5. Is the gap *real*? Empirically, not yet: I ran
the checker against a scratch tree whose `docs/SPEC_PIPELINE.md` is the index
plus every `docs/spec-pipeline/*.md` concatenated, so the scan covers the whole
split:

```
command: scripts/check-agent-doc-duplication.sh /tmp/opencode/037-dup2   (doc = index + all stage/shared files)
exit: 0
OK: agents/*.md duplicate no docs/SPEC_PIPELINE.md rule and all section references resolve
```

Zero actual duplication today. So: latent coverage regression, no live defect.
Classification: **structural, out of scope, follow-up spec** — the checker should
take a doc *list* (index + `docs/spec-pipeline/*.md`) rather than one path.
Flagged to the Architect.

**O-2 — `tests/AC-030-01.sh` `printf | grep -q` under `pipefail` (Refactorer
flag 2, confirmed as a real defect, not this spec's).** `set -euo pipefail` at
line 4 with `printf '%s\n' "$fm" | grep -qE '^name:'` at line 12 — `grep -q`
exits on first match, `printf` takes SIGPIPE, `pipefail` propagates the non-zero,
and the pipeline flakes as the payload grows or the scheduler interleaves.
Root cause confirmed by reading the file; the file's last change is `b320843`
(spec 030), it is absent from this diff (`git status --porcelain tests/` → empty).
**Under load in this run it did not reproduce**: `ok 18 AC-030-01-06: required
body sections present`. Classification: **behavior defect in a pre-existing
test, out of scope, follow-up spec** (replace `| grep -q` with a `case`/`[[ =~ ]]`
test or drop `pipefail` for that statement).

### WARNs — recorded, flagged to the Architect, pipeline not stopped

**W-1 — `measure-stage-read-cost.sh` exits 2 correctly but emits a bash
arithmetic error on the way (structural, this spec).** A missing *index* is
clean (exit 2, bats-covered). A missing *shared* file named in a `Must read:`
block also ends at exit 2 — the documented contract holds — but only after
`stage_bytes` runs `bytes=$((bytes + $(size_of "$shared")))` with an empty
substitution, printing a raw shell error and a partial results table first.
Reproduction:

```
command: bash scripts/measure-stage-read-cost.sh /tmp/opencode/037-ms   (coder.md Must-reads a missing shared.md)
exit: 2
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier             102   0.002  ok
ux                    102   0.002  ok
measure-stage-read-cost: missing /tmp/opencode/037-ms/docs/spec-pipeline/gone.md
scripts/measure-stage-read-cost.sh: line 90: bytes + : syntax error: operand expected (error token is "+ ")
```

Exit code is the contract and the contract is met, so this is a WARN, not a
FAIL. Fix worth having: have `stage_bytes` return non-zero on a failed `size_of`
instead of relying on the arithmetic error to abort.

**W-2 — "Do not read the other stages' files" collides with verifying a docs
spec (structural, introduced by this spec).** AC-037-03-03 required each stage
agent to read only its own slice, and it was implemented literally: all eight
`agents/spec-*.md` prompts now end their reading paragraph with *"Do not read
the other stages' files."* For a spec whose **deliverable is the other stage
files** (037 itself, and any future docs spec), the Verifier cannot discharge
`spot-check` or `unaccounted` without reading them. No AC covers this; no gate
fails; today it is an instruction conflict, not a blocker. This run read the
stage files as artifacts-under-test and says so explicitly. Suggested follow-up:
scope the prohibition to "when executing your stage", not "ever".

**W-3 — comma-form references escape the new anchor check.** Four repointed
references use the wrapped prose form ``(`docs/spec-pipeline/x.md`,
§Section)`` — index `§Remediation budget` (line 215), `audit-contract.md` line 91
and line 136, `pr-opener.md` line 24. Check 6's pattern requires
`<path> §<section>` adjacency, so these are not anchor-verified. All four
hand-verified to resolve, and the base had the same unverified `§`-only form, so
this is **not a regression** — but the gate's coverage of the docs it just
created is incomplete. Recorded, not fixed.

### Observations

**N-1 — two files outside Task 3's enumerated surface were edited.**
Task 3 scopes the rewrite to `agents/ commands/ AGENTS.md docs/ scripts/
skills/`. `CHANGELOG.md` (one `§Model configuration` → `docs/spec-pipeline/
model-config.md §Model configuration`) and `okf/when-to-use-typesafe.md` are
outside that list. Both are single-line reference repoints with no change to
the historical statement's meaning, and they remove a reference that would
otherwise have gone stale. Justified in effect, unaccounted by the task list's
letter — recorded so the Coder/Refactorer's scope is visible, not assumed.

**N-2 — the index keeps the whole `Autopilot mode` section.** Task 1 lists
"Autopilot never-list (incl. hard stops)" among the sections the index keeps;
the index keeps `## Autopilot mode` in full (trigger, no-questions,
recording-decisions, hard stops, never-list). That is a superset of the required
content and all of it is cross-cutting, so it satisfies the intent and the
"moved verbatim" rule (my section-level diff shows zero semantic change). Noted,
not a finding.

**N-3 — moved content is verbatim.** Independent check beyond AC-037-02-02: I
diffed each of the 23 base sections against its new location, normalizing only
doc paths. Nine sections differ, and every difference is either the new
index-intro paragraph or a bare `§Section` intra-doc reference that would have
dangled after the split and was given an explicit path. **Zero semantic
rewrites.** The Stop-and-Ask table is stronger than "visually unchanged": the 14
table lines extracted from base and current index have identical SHA-256
(`8aa9a287483453118299b6e86c8fc0fe86443772a8fe197a1ab2333be55e242c`), which
independently confirms AC-037-01-02. Index length 228 ≤ 250 (AC-037-01-03).

### No unaccounted behavior

- Every changed path traces to Task 1–5: 13 new `docs/spec-pipeline/*.md`
  (Task 2), the shrunken index (Task 1), reference repoints across 87 files
  (Task 3), `check-orchestration.sh` checks 4+6 (Task 4), and
  `measure-stage-read-cost.sh` + its 5 bats files (Task 5). Two files fall
  outside Task 3's literal file list — recorded as N-1, benign, no other
  logic was added that no task or scenario accounts for.
- No production behavior was added: the only new executable code is the read-cost
  measurement script and the two orchestration checks, each covered by AC-037
  tests that ran and passed in the full suite.

## Telemetry

Recorded once via `scripts/record-gate-run.sh` (spec 012), appended to
`runs.jsonl`. The record as written:

```
{"specSlug": "037-split-spec-pipeline-doc", "gatesFailed": [], "warnings": [...6 warnings...], "durationSec": 327, "outcome": "pass","runId":"dc0c6b00-f0ea-4bd5-89f7-44dc26370a6b","loopCount":0,"phase1Retries":0,"phase2Retries":0}
```

`gatesFailed: []`, `outcome: pass` — consistent with the PASS verdict above, and
the six warnings carry W-1..W-3, O-1..O-2 and the thin read-cost margin.

Correction inside that record: its first warning string says "62 WARN"; the
actual count is **58** (`grep -o '"message"'` over the captured JSON = 58, and
`jq`-equivalent parse gives `warns: 58`). The number in §Evidence above is the
corrected one. I did not rewrite the appended line — the append-only contract
wins, and the report is the auditable artifact.

**Telemetry warning (tooling, not a gate):** the record carries `loopCount: 0`
because `SPEC_LOOP_COUNT` / `SPEC_PHASE1_RETRIES` / `SPEC_PHASE2_RETRIES` were
**not exported into this shell** — `echo "${SPEC_LOOP_COUNT:-UNSET}"` returns
`UNSET`, so `record-gate-run.sh` applied its documented default of 0. The
authoritative counters for this run, as passed to this stage, are
**loop 1, phase-1 retries 0, phase-2 retries 0**; this document's header and
`30-report.md` carry those. I did not rewrite `runs.jsonl` (append-only
contract) and did not append a duplicate correction record, because a second
record would double-count the run in `scripts/gate-stats.sh`. Orchestrator: export
the three `SPEC_*` counters before invoking the Verifier.
