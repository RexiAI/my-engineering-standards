# Verification — spec 045: PR size gate and review-gated auto-merge

- **Stage**: 4 (Verifier)
- **Attempt**: 1, phase 1 (pre-PR loop); `loopCount=0`, `phase1Retries=0`, `phase2Retries=0`
- **Date**: 2026-11-28
- **Tree under verification**: `main` at HEAD `25924a1`, working tree dirty with the spec's change set (the PR branch `spec/045-pr-size-gate-and-auto-merge` does not exist yet; the PR Opener commits at stage 5b). Checked against `10-tasks.md` and `20-acceptance/AC-045-01..12` (103 scenarios); `00-informal.md` was not read.
- **Pipeline mode**: `full` (`45-decisions.md`)
- **Overall verdict**: **FAIL**

## Verdict

**FAIL** — one gate produced findings. Both findings come from `test-suite`, and both
share a single underlying cause:

| Gate ID | Finding | Evidence |
|---|---|---|
| `test-suite` | `not ok 567 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)` (`scripts/tests/autopilot-enforcement.bats:16`) | §Evidence: full test suite |
| `test-suite` | `not ok 467 AC-043-26: autopilot stays free of unconditional questions` (`scripts/tests/ac-043-probes.bats:54`) | §Evidence: full test suite |

Underlying cause (verbatim from `bash scripts/check-stop-and-ask-matrix.sh`, exit 1):

```
FAIL AC-009-02-03 — unexpected changed agent file(s): pr-review.md (only the 9 pipeline agents may change)
FAIL AC-009-04-02 — 1 violation(s); script exits 1
```

Both tests invoke that pre-existing gate against `$REPO_ROOT`. The gate's
AC-009-02-03 branch reads `git -C "$ROOT" status --porcelain -- agents/` and fails
for any uncommitted agent file outside the 9 pipeline agents. Task 4 mandates
editing `agents/pr-review.md` (not a `spec-*.md` agent), and the change is
uncommitted by pipeline design, so the check fires. Committing the identical
content makes it pass — independently reproduced in a scratch copy of this exact
tree (§Failure analysis).

**This is not a defect in spec 045's production code, and it is not a fix the Coder
or Refactorer can make.** The two resolutions are (a) commit the tree on
`spec/NNN-slug` and re-trigger a scoped re-verification of `test-suite` only, or
(b) a governed amendment to AC-009-02-03's working-tree assertion (a gate change
— a human decision, off-limits to pipeline agents per the Stop-and-Ask matrix).
Phase 1 attempt 1 of max 3 is consumed by this report.

Everything else is green: scenario traceability exit 0; complexity/real-linter
exit 0; design-principles exit 0 (0 FAIL, 70 WARN — one WARN is in new code and is
flagged below); four independent scenario spot checks match their Given/When/Then.

## Failure analysis — the AC-009-02-03 pre-commit assertion

`scripts/check-stop-and-ask-matrix.sh` (spec 009) check AC-009-02-03 asserts that
no agent file outside the 9 pipeline agents is changed, using the *working tree*:

- `git status --porcelain -- agents/` → ` M agents/pr-review.md`
- The gate therefore prints `FAIL AC-009-02-03 — unexpected changed agent file(s): pr-review.md`.

Task 4 ("Extend the pr-review output contract with a verdict") lists
`agents/pr-review.md` as its change set, and AC-045-04 scenarios read that agent's
new `Review-Verdict:` contract. The two requirements are in direct conflict while
the change is uncommitted; the conflict is invisible after a commit because the
check reads `git status` and not a diff against a base.

Independent reproduction (this is a real execution, not an inference). A copy of the
current working tree was made at `/tmp/opencode/pipeline/045-scratch`, the whole
change set was committed there, and the gate plus both failing tests were re-run:

```
$ git status --porcelain -- agents/ | wc -l
0
$ bash scripts/check-stop-and-ask-matrix.sh
...
PASS AC-009-04-02 — compliant repo passes all checks (exit 0)
✔ Stop-and-Ask matrix check: every matrix requirement verified.
MATRIX_EXIT=0

$ bats --tap --filter 'AC-035-36' scripts/tests/autopilot-enforcement.bats
1..1
ok 1 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)

$ bats --tap --filter 'AC-043-26' scripts/tests/ac-043-probes.bats
1..1
ok 1 AC-043-26: autopilot stays free of unconditional questions
```

The verdict above still transcribes the real-tree gate result (`make test-scripts`
exit 2, two `not ok` lines), because the gate is the authority and this workspace's
suite is red as it stands. The scratch reproduction is the diagnosis handed to the
orchestrator, not a substitute for the failing run.

## Finding — one skipped test (recorded, not counted as a gate finding)

`make test-scripts` reports exactly one skip in 1347 tests:

```
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: main)
```

The skip is the test's own branch-scope guard (spec 041's assertion applies only on
`spec/041-*`), it exists on `main` independently of this spec, and spec 045 claims
no behavior through it. It is recorded because a skip is never a pass; it does not
change this spec's verdict.

## Finding — no unaccounted behavior (skim of the change set, not a command)

The change set is 9 modified tracked files (+274/−11, `git diff --stat`) plus 16
new non-spec files (4 workflows, 6 scripts, 5 bats files, 1 ADR), the spec folder,
and the unrelated `.playwright-mcp/` noted below. Each item traces to a task or
scenario, with these notes:

- `scripts/pr-gate-lib.sh` — not named by any task; it holds the lockfile basename
  list and CODEOWNERS tokenizer shared by Tasks 2/3/6/9. Traces to those tasks
  (DRY); flagged as an addition beyond the literal task list.
- `scripts/tests/pr-size-gate-deliverables.bats` (52 tests) — not one of Task 11's
  four named bats files; it carries the AC-045-01/04/07/08/10/11/12 headings and
  runs through the `scripts/tests/*.bats` glob, not the new self-ci step that names
  four files. Legitimate carrier, flagged as an addition.
- `agents/pr-review.md` (+19/−5) — Task 4 exactly: two marker lines, order, the
  fail-closed sentence; scope lock and `permission` block untouched.
- `.github/workflows/{ci-pr-size-gate,ci-pr-review-verdict,ci-pr-auto-merge,pr-automerge}.yml`
  — Tasks 7/8. All pinned to the same SHA; no `pull_request_target`; the reusable
  workflows execute only `.standards/scripts/*` from the pinned revision.
- `docs/{CI_CD,GIT_WORKFLOW}.md`, `templates/branch-protection.md`, `AGENTS.md`,
  `docs/adr/0030-*.md` + `docs/adr/README.md` — Tasks 12 and 1.
- `scripts/{init-ci.sh,capabilities.tsv}`, `.github/workflows/self-ci.yml` — Tasks 10/11.

No logic was found that traces to no task or scenario.

## Out-of-scope findings and flags (recorded, not fixed)

1. **Untracked `.playwright-mcp/` (7 files, dated 2026-11-09)** sits in the repo root
   and is unrelated to spec 045. It is pre-existing scratch data, but `git add -A`
   at stage 5b would sweep it into the PR. Exclude or remove it before the PR Opener
   commits — the Verifier does not touch it.
2. **Pinned revision risk.** The reusable workflows and the self-hosted caller pin
   `@21046d96796467f8238d6d613ce3a552bf3fced0`; that commit predates this spec's
   workflow files, so the caller cannot resolve its reusable workflows until the pin
   is bumped after merge. This is the Task 11 design ("bump deliberately"), but it is
   a phase-2 (post-PR CI) risk the orchestrator should expect.
3. **Design-gate WARN in new code** — `Comments: commented-out code
   (./scripts/pr-size-gate.sh:25)`. Advisory only (WARN, not FAIL); flagged to the
   Architect per the Stop-and-Ask matrix. The other 69 WARNs are pre-existing.
4. **ADR heading level.** AC-045-01-01 lists `Alternatives Considered` among the
   ADR's sections; the ADR carries it as `### Alternatives Considered` inside
   `## Decision`, and the acceptance test matches it by substring (`grep -F
   "## Alternatives Considered"`). The content is present and substantive; the
   scenario does not constrain heading depth. Noted, not a finding.
5. **Coder count mismatch.** The Coder reported "1143 ok / 2 not ok" (1145); the
   current tree runs **1347** tests (1345 ok, 2 not ok, 1 skip). The failing IDs
   match; the total does not, so the Coder's run predates ~202 tests of the current
   suite. The Verifier's run is the authority.
6. **Traceability granularity.** The gate's scan is `AC-NNN-NN`, so it traces the 12
   task-level IDs (`AC-045-01` … `AC-045-12`) and cannot attest the 103 individual
   scenarios; the per-scenario coverage comes from the 135 spec bats tests.

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --spec 045-pr-size-gate-and-auto-merge --json
exit: 0
at: 2026-11-28T16:19:37Z

{
  "checks": [1, 2],
  "passes": ["AC-045-01 — traced to a test", "AC-045-02 — traced to a test", "AC-045-03 — traced to a test", "AC-045-04 — traced to a test", "AC-045-05 — traced to a test", "AC-045-06 — traced to a test", "AC-045-07 — traced to a test", "AC-045-08 — traced to a test", "AC-045-09 — traced to a test", "AC-045-10 — traced to a test", "AC-045-11 — traced to a test", "AC-045-12 — traced to a test"],
  "fails": []
}

The gate scans `AC-NNN-NN`, so it traces the 12 task-level IDs; the 103 per-scenario
headings are exercised by the spec bats files (see the suite block).

## Evidence: full test suite

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-verifier-suitesuite.log -- make test-scripts
exit: 2
at: 2026-11-28T16:18:45Z
Test-run hash: 6e68b8b49242bfc7a6345ee3c474bf6b0bf095da5b83412438a9ef71d1467087

not ok 467 AC-043-26: autopilot stays free of unconditional questions
# (in test file scripts/tests/ac-043-probes.bats, line 54)
#   `[ "$status" -eq 0 ]' failed
not ok 567 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
# (in test file scripts/tests/autopilot-enforcement.bats, line 16)
#   `[ "$status" -eq 0 ]' failed
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: main)
plan 1..1347 — 1345 ok, 2 not ok, 1 skip (the skip is annotated above)
SUMMARY: mode=run exit=2 signal=2 log_lines=1357 log=/tmp/opencode/pipeline/045-verifier-suitesuite.log
full log: §Raw log: full test suite

The recorded run started at 2026-11-28T16:08:00Z and ended at 2026-11-28T16:18:45Z.
An earlier launch of the same command was terminated by the Verifier's own tool
timeout at 900 s and is not evidence; it is the reason no pre-launch hash was
taken. A hash captured at 2026-11-28T15:57:50Z (after the killed launch, before
this run) and the post-run hash are both
`6e68b8b49242bfc7a6345ee3c474bf6b0bf095da5b83412438a9ef71d1467087`, so no
tree-changed-during-run finding applies. The two failures and their shared
cause are analysed in §Failure analysis; they are the FAIL verdict.

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --gates complexity --json; shellcheck --severity=warning scripts/pr-size-gate.sh scripts/pr-review-verdict.sh scripts/pr-automerge-eligibility.sh scripts/pr-automerge-notify.sh scripts/pr-gate-lib.sh scripts/check-pr-size-gate.sh
exit: 0
at: 2026-11-28T15:55:44Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}
shellcheck --severity=warning: no output, exit 0.

The changed surface is bash/YAML/Markdown, so `golangci-lint`/`pmd`/`eslint` do
not apply. The repository has no blocking shell linter: self-ci runs
`shellcheck scripts/*.sh templates/*.sh` with `continue-on-error: true`. An
unfiltered run of the same six changed scripts exits 1 on four info-level notes,
recorded verbatim because they are real output of the advisory lane:

In scripts/pr-size-gate.sh line 41:
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-gate-lib.sh"
       ^-- SC1091 (info): Not following: pr-gate-lib.sh was not specified as input (see shellcheck -x).

In scripts/pr-automerge-eligibility.sh line 36:
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-gate-lib.sh"
       ^-- SC1091 (info): Not following: pr-gate-lib.sh was not specified as input (see shellcheck -x).

In scripts/pr-automerge-notify.sh line 30:
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-gate-lib.sh"
       ^-- SC1091 (info): Not following: pr-gate-lib.sh was not specified as input (see shellcheck -x).

In scripts/pr-automerge-notify.sh line 108:
    printf 'The merge waits for the required checks: `pr-size`, `review-verdict`, CI, and `mutation` when the tier requires it.\n\n'
           ^-- SC2016 (info): Expressions do not expand in single quotes, use double quotes for that.

SC1091 is the dynamic-source pattern used repo-wide; SC2016 is intentional (the
backticks are literal text in the posted comment). Neither is a gate finding at
the project's configured severity.

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh --json; bash scripts/check-code-principles.sh
exit: 0
at: 2026-11-28T16:19:23Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)", "file": "./scripts/check-code-principles.selftest.sh", "line": "641" }, { "message": "Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)", "file": "./scripts/check-code-principles.selftest.sh", "line": "639" }, { "message": "Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)", "file": "./scripts/tests/gate-telemetry.selftest.sh", "line": "150" }, { "message": "Comments: commented-out code (./scripts/check-bats-assertions.sh:21)", "file": "./scripts/check-bats-assertions.sh", "line": "21" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)", "file": "./scripts/gate-clean-code-lib.sh", "line": "97" }, { "message": "Comments: commented-out code (./scripts/verify-production-deploy.sh:30)", "file": "./scripts/verify-production-deploy.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:58)", "file": "./scripts/check-code-principles.sh", "line": "58" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:121)", "file": "./scripts/check-code-principles.sh", "line": "121" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)", "file": "./scripts/check-code-principles.sh", "line": "57" }, { "message": "Comments: attribution comment (./scripts/check-code-principles.sh:59)", "file": "./scripts/check-code-principles.sh", "line": "59" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)", "file": "./scripts/check-remediation-budget.sh", "line": "139" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)", "file": "./scripts/check-remediation-budget.sh", "line": "209" }, { "message": "Comments: commented-out code (./scripts/pr-size-gate.sh:25)", "file": "./scripts/pr-size-gate.sh", "line": "25" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)", "file": "./scripts/lint-outbox-schema.sh", "line": "13" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)", "file": "./scripts/lint-outbox-schema.sh", "line": "22" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)", "file": "./scripts/check-saga-timeouts.sh", "line": "185" }, { "message": "Comments: commented-out code (./scripts/run-mutation.sh:29)", "file": "./scripts/run-mutation.sh", "line": "29" }, { "message": "Comments: commented-out code (./scripts/run-mutation.sh:33)", "file": "./scripts/run-mutation.sh", "line": "33" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)", "file": "./scripts/ci-smoke-test.sh", "line": "51" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)", "file": "./scripts/ci-smoke-test.sh", "line": "53" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)", "file": "./scripts/ci-smoke-test.sh", "line": "90" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)", "file": "./scripts/ci-smoke-test.sh", "line": "92" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)", "file": "./scripts/ci-smoke-test.sh", "line": "132" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)", "file": "./scripts/ci-smoke-test.sh", "line": "134" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)", "file": "./scripts/ci-smoke-test.sh", "line": "149" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)", "file": "./scripts/ci-smoke-test.sh", "line": "151" }, { "message": "Comments: commented-out code (./scripts/check-loop-files.sh:10)", "file": "./scripts/check-loop-files.sh", "line": "10" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:6)", "file": "./scripts/init-ci.sh", "line": "6" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:45)", "file": "./scripts/init-ci.sh", "line": "45" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:39)", "file": "./scripts/check-loop-triage.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:49)", "file": "./scripts/check-loop-triage.sh", "line": "49" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:67)", "file": "./scripts/check-loop-triage.sh", "line": "67" }, { "message": "Comments: commented-out code (./scripts/token-stats.sh:10)", "file": "./scripts/token-stats.sh", "line": "10" }, { "message": "Comments: commented-out code (./scripts/classify-spec-size.sh:28)", "file": "./scripts/classify-spec-size.sh", "line": "28" }, { "message": "Comments: commented-out code (./scripts/agent-test-summary.sh:45)", "file": "./scripts/agent-test-summary.sh", "line": "45" }, { "message": "Comments: commented-out code (./scripts/test-run-reuse.sh:41)", "file": "./scripts/test-run-reuse.sh", "line": "41" }, { "message": "Comments: commented-out code (./scripts/guard-env.sh:21)", "file": "./scripts/guard-env.sh", "line": "21" }, { "message": "Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)", "file": "./scripts/check-ci-sweeper.sh", "line": "37" }, { "message": "Comments: commented-out code (./scripts/check-security-hardening.sh:39)", "file": "./scripts/check-security-hardening.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/judgment-preflight.sh:16)", "file": "./scripts/judgment-preflight.sh", "line": "16" }, { "message": "Comments: commented-out code (./scripts/check-model-env.sh:30)", "file": "./scripts/check-model-env.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/gate-stats.sh:20)", "file": "./scripts/gate-stats.sh", "line": "20" }, { "message": "Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)", "file": "./scripts/check-pr-babysitter.sh", "line": "56" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)", "file": "./scripts/check-saga-tests.sh", "line": "85" }, { "message": "Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "197" }, { "message": "Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "147" }, { "message": "Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "201" }, { "message": "Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)", "file": "./ci/templates/go-saga-lint.go", "line": "61" }, { "message": "Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:66)", "file": "./scripts/voice/tts-worker.py", "line": "66" }, { "message": "Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:87)", "file": "./scripts/voice/tts-worker.py", "line": "87" }, { "message": "Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:90)", "file": "./scripts/voice/tts-worker.py", "line": "90" }, { "message": "Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:120)", "file": "./scripts/voice/tts-worker.py", "line": "120" }, { "message": "Naming: more than three parameters (handle_line) (./scripts/voice/tts-worker.py:126)", "file": "./scripts/voice/tts-worker.py", "line": "126" }, { "message": "Naming: more than three parameters (handle_line) (./scripts/voice/tts-worker.py:154)", "file": "./scripts/voice/tts-worker.py", "line": "154" }, { "message": "Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "65" }]
}
---
Checking design principles in: . (tier: mvp)

[0;32mPASS[0m Complexity/KISS (java): no violations found
[1;33mWARN[0m Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
[1;33mWARN[0m Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
[1;33mWARN[0m Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38
[0;32mPASS[0m Complexity/KISS (python): no violations found

--- DRY ---
[1;33mWARN[0m Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: "problem", /docs: { /description: /meta: {
[1;33mWARN[0m Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: "directBrokerCall", /data: { name }, /}); /node,
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
[1;33mWARN[0m Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {

--- YAGNI ---
[1;33mWARN[0m Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
[1;33mWARN[0m Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
[0;32mPASS[0m YAGNI (go): no premature abstractions detected
[0;32mPASS[0m YAGNI (node): no premature abstractions detected
[0;32mPASS[0m YAGNI (python): no premature abstractions detected

--- SOLID ---
[0;32mPASS[0m SOLID-SRP (java): no oversized files
[0;32mPASS[0m SOLID-SRP (go): no oversized files
[0;32mPASS[0m SOLID-SRP (node): no oversized files
[0;32mPASS[0m SOLID-SRP (python): no oversized files
[0;32mPASS[0m SOLID-OCP (java): no large type-dispatch chains
[0;32mPASS[0m SOLID-OCP (go): no large type-dispatch chains
[0;32mPASS[0m SOLID-OCP (node): no large type-dispatch chains
[0;32mPASS[0m SOLID-OCP (python): no large type-dispatch chains
[0;32mPASS[0m SOLID-LSP (java): no heavy instanceof dispatch
[0;32mPASS[0m SOLID-LSP (node): no heavy instanceof dispatch
[0;32mPASS[0m SOLID-LSP (python): no heavy isinstance dispatch
[0;32mPASS[0m SOLID-ISP (java): no fat interfaces
[0;32mPASS[0m SOLID-ISP (node): no fat interfaces
[0;32mPASS[0m SOLID-ISP (python): no fat interfaces
[0;32mPASS[0m SOLID-DIP (java): no domain→infrastructure imports
[0;32mPASS[0m SOLID-DIP (go): no domain→infrastructure imports
[0;32mPASS[0m SOLID-DIP (node): no domain→infrastructure imports
[0;32mPASS[0m SOLID-DIP (python): no domain→infrastructure imports
[0;32mPASS[0m SOLID-DIP (rust): no domain→infrastructure imports

--- Component-per-file ---
[0;32mPASS[0m Component-per-file: no violations

--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)

--- Comments ---
[1;33mWARN[0m Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)
[1;33mWARN[0m Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)
[1;33mWARN[0m Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-bats-assertions.sh:21)
[1;33mWARN[0m Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)
[1;33mWARN[0m Comments: commented-out code (./scripts/verify-production-deploy.sh:30)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-code-principles.sh:58)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-code-principles.sh:121)
[1;33mWARN[0m Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)
[1;33mWARN[0m Comments: attribution comment (./scripts/check-code-principles.sh:59)
[1;33mWARN[0m Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)
[1;33mWARN[0m Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)
[1;33mWARN[0m Comments: commented-out code (./scripts/pr-size-gate.sh:25)
[1;33mWARN[0m Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)
[1;33mWARN[0m Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)
[1;33mWARN[0m Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)
[1;33mWARN[0m Comments: commented-out code (./scripts/run-mutation.sh:29)
[1;33mWARN[0m Comments: commented-out code (./scripts/run-mutation.sh:33)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)
[1;33mWARN[0m Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-loop-files.sh:10)
[1;33mWARN[0m Comments: section-divider comment (./scripts/init-ci.sh:6)
[1;33mWARN[0m Comments: section-divider comment (./scripts/init-ci.sh:45)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-loop-triage.sh:39)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-loop-triage.sh:49)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-loop-triage.sh:67)
[1;33mWARN[0m Comments: commented-out code (./scripts/token-stats.sh:10)
[1;33mWARN[0m Comments: commented-out code (./scripts/classify-spec-size.sh:28)
[1;33mWARN[0m Comments: commented-out code (./scripts/agent-test-summary.sh:45)
[1;33mWARN[0m Comments: commented-out code (./scripts/test-run-reuse.sh:41)
[1;33mWARN[0m Comments: commented-out code (./scripts/guard-env.sh:21)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-security-hardening.sh:39)
[1;33mWARN[0m Comments: commented-out code (./scripts/judgment-preflight.sh:16)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-model-env.sh:30)
[1;33mWARN[0m Comments: commented-out code (./scripts/gate-stats.sh:20)
[1;33mWARN[0m Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)
[1;33mWARN[0m Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)

--- Naming ---
[1;33mWARN[0m Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)
[1;33mWARN[0m Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
[1;33mWARN[0m Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)
[1;33mWARN[0m Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)
[1;33mWARN[0m Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:66)
[1;33mWARN[0m Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:87)
[1;33mWARN[0m Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:90)
[1;33mWARN[0m Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:120)
[1;33mWARN[0m Naming: more than three parameters (handle_line) (./scripts/voice/tts-worker.py:126)
[1;33mWARN[0m Naming: more than three parameters (handle_line) (./scripts/voice/tts-worker.py:154)

--- Null discipline ---
[1;33mWARN[0m Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)

---------------------------------------------
[0;32m✔ Design-principles check: 0 FAIL(s), 70 WARN(s).[0m
  WARNs are review hints — verify each before merging.

One WARN is in code this spec introduces — `Comments: commented-out code
"./scripts/pr-size-gate.sh:25"`; the other 69 are pre-existing. WARNs are review
hints, not a stop (Stop-and-Ask matrix: "Design gate WARN (not FAIL)"); the new
one is flagged to the Architect in §Out-of-scope findings and flags.

## Evidence: scenario-to-behavior spot check

command: bash scripts/pr-size-gate.sh --numstat-file ... --diff-file ... (AC-045-02-04, AC-045-02-07); bash scripts/pr-automerge-notify.sh --outcome <armed|would-merge|blocked-exclusion> --head-sha abc123 (AC-045-09-05); bash scripts/pr-automerge-eligibility.sh --size-tier auto --review-verdict pass --changed-files ... --mode live (AC-045-06-07)
exit: 0
at: 2026-11-28T16:19:39Z

$ bash scripts/pr-size-gate.sh --numstat-file /tmp/opencode/pipeline/spot/ns04 --diff-file /tmp/opencode/pipeline/spot/d04
changed=4
tier=auto
automerge=true
override=absent
excluded=1
exit=0

$ bash scripts/pr-size-gate.sh --numstat-file /tmp/opencode/pipeline/spot/ns07 --diff-file /tmp/opencode/pipeline/spot/d07
changed=52
tier=auto
automerge=true
override=absent
excluded=0
exit=0

$ bash scripts/pr-automerge-notify.sh --outcome armed --head-sha abc123 | tail -n1
<!-- pr-automerge: armed:abc123 -->
$ bash scripts/pr-automerge-notify.sh --outcome would-merge --head-sha abc123 | tail -n1
<!-- pr-automerge: would-merge:abc123 -->
$ bash scripts/pr-automerge-notify.sh --outcome blocked-exclusion --head-sha abc123 | tail -n1
<!-- pr-automerge: blocked-exclusion:abc123 -->

$ bash scripts/pr-automerge-eligibility.sh --size-tier auto --review-verdict pass --changed-files /tmp/opencode/pipeline/spot/files07 --mode live
eligible=false
action=none
reason=excluded_path
exclusions=gate_surface:.github/workflows/ci.yml
exit=0

Scenario reading (assertions vs Given/When/Then, read from `20-acceptance/`):

- AC-045-02-04 — Given `90 0 lib/api.go`, `2 2 src/a.ts` and a diff whose added line is `// Code generated by protoc-gen-go. DO NOT EDIT.`; Then `changed=4`, `excluded=1`. Run: `changed=4`, `excluded=1`, exit 0. Matches; the bats test asserts the same two keys (`scripts/tests/pr-size-gate.bats:77-89`).
- AC-045-02-07 — Given a file that only lost lines, not deleted; Then `changed=52`, `excluded=0`. Run: `changed=52`, `excluded=0`. Matches, and it is the case Task 2 calls out (0 additions + deletions is not a pure deletion).
- AC-045-06-07 — Given a changed-files list containing `.github/workflows/ci.yml`; Then `eligible=false`, `reason=excluded_path`, `exclusions` contains `gate_surface:.github/workflows/ci.yml`. Run matches all four keys, exit 0.
- AC-045-09-05 — Given any of the three outcomes; Then the last stdout line is `<!-- pr-automerge: <outcome>:abc123 -->`. All three outcomes match exactly.

No spot-check mismatch: the passing tests assert the same observable output the scenarios demand, and the runs above reproduce it independently of the tests.

## Raw log: full test suite

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-verifier-suitesuite.log -- make test-scripts
exit: 2
at: 2026-11-28T16:18:45Z

Checking bats assertions are not vacuous...

[0;32mPASS[0m check-bats-assertions: 109 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..1347
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
ok 7 AC-004-05: No speculative generality in scaffold
ok 8 AC-004-06: Complexity threshold stays at ≤6
ok 9 AC-005-05: Mutation and lint wiring referenced
ok 10 AC-005-06: Red-then-green loop documented
ok 11 AC-007-05: Smoke bootstrap Java and Go features from templates
ok 12 AC-007-06: Existing gates still green
ok 13 AC-030-01-01: SKILL.md frontmatter exists with required fields
ok 14 AC-030-01-02: name field is exactly e2e-testing (matches directory)
ok 15 AC-030-01-03: name format valid, lowercase-hyphen, <=64 chars
ok 16 AC-030-01-04: description non-empty and within 1024-char limit
ok 17 AC-030-01-05: body line count within 500-line limit
ok 18 AC-030-01-06: required body sections present
ok 19 AC-030-01-07: version pin 0.17.0 and pre-1.0 instability warning present
ok 20 AC-030-01-08: telemetry opt-out E2E_TELEMETRY_DISABLED mandated
ok 21 AC-030-01-09: act+expect golden rule stated
ok 22 AC-030-01-10: opaque Secret path taught, inline credentials forbidden
ok 23 AC-030-01-11: no literal model or provider ids in SKILL.md
ok 24 AC-030-01-12: no forbidden re-run phrasing in SKILL.md
ok 25 AC-030-02-01: all six reference files exist
ok 26 AC-030-02-02: each reference file is referenced from SKILL.md
ok 27 AC-030-02-03: no nested reference chains between reference files
ok 28 AC-030-02-04: setup.md content coverage
ok 29 AC-030-02-05: writing-tests.md content coverage
ok 30 AC-030-02-06: running-debugging.md content coverage
ok 31 AC-030-02-07: bug-bash.md content coverage
ok 32 AC-030-02-08: ci.md and mobile-rn.md content coverage
ok 33 AC-030-03-01: config example file exists
ok 34 AC-030-03-02: model ids read from process.env, none hardcoded
ok 35 AC-030-03-03: port-0 pattern and shell-less app launch present
ok 36 AC-030-03-04: budgets and cache modes configured
ok 37 AC-030-03-05: telemetry opt-out, tests glob, no .env loading
ok 38 AC-030-04-01: agent frontmatter has required fields
ok 39 AC-030-04-02: permission denies git push and git commit
ok 40 AC-030-04-03: permission denies edits outside allowed paths, .e2e read-only
ok 41 AC-030-04-04: no model key in frontmatter
ok 42 AC-030-04-05: body has required sections for both duties
ok 43 AC-030-04-06: workflow vs agent choice justified
ok 44 AC-030-04-07: ground truth and stopping conditions stated
ok 45 AC-030-04-08: bug-bash bounds, confirmation gate, hygiene
ok 46 AC-030-05-01: docs/TESTING.md agentic E2E section, skill pointer, Playwright preserved
ok 47 AC-030-05-02: AGENTS.md Reading the Standards line added
ok 48 AC-030-05-03: no literal model ids added to docs
ok 49 AC-030-06-01: opencode.json e2e-runner entry uses env reference (conditional)
ok 50 AC-030-06-02: config/model.local.env.example defines the var (conditional)
ok 51 AC-030-06-03: model-env roster updated and check-model-env green (conditional)
ok 52 AC-030-07-01: check-skills.sh exits 0
ok 53 AC-030-07-02: check-orchestration.sh exits 0
ok 54 AC-030-07-03: check-model-env.sh exits 0 and holistic hygiene holds
ok 55 AC-030-01: T1 full suite (scenarios + units) exits 0
ok 56 AC-030-02: T2 full suite (scenarios + units) exits 0
ok 57 AC-030-03: T3 full suite (scenarios + units) exits 0
ok 58 AC-030-04: T4 full suite (scenarios + units) exits 0
ok 59 AC-030-05: T5 full suite (scenarios + units) exits 0
ok 60 AC-030-06: T6 full suite (scenarios + units) exits 0
ok 61 AC-030-07: T7 full suite (scenarios + units) exits 0
ok 62 AC-031-50 — ADR 0008 exists, follows templates/ADR.md structure, and records the four decisions
ok 63 AC-031-51 — ADR 0008 status is Accepted
ok 64 AC-031-52 — ADR index has a 0008 row with title and link to the file
ok 65 unit — docs/adr carries the numbered 0008 file and all ADR files use 4-digit numbers (0008 pinned at spec 031's time)
ok 66 unit — ADR 0010 (--require-deploy gate split) exists, carries every template heading, and is indexed
ok 67 AC-031-22 — archive-spec.sh embeds 40-deploy.md verbatim under its own heading
ok 68 AC-031-23 — archive-spec.sh still refuses without 30-report.md (exit non-zero, not finished)
ok 69 AC-031-24 — check-specs-archived.sh: existing archive without any 40-deploy.md history still passes
ok 70 AC-031-25 — phase-3 budget exhausted (ESCALATED + marker, no archive): exits 0, no false failure
ok 71 unit — the exception needs BOTH a line-start marker and Verdict: ESCALATED
ok 72 AC-031-26 — pre-031 in-flight spec (30-report.md, no 40-deploy.md) still requires archival
ok 73 AC-031-27 — both scripts still key finished-spec detection off 30-report.md
ok 74 AC-031-17 — 40-deploy.md evidence format is defined in the audit-contract Deploy Verifier row
ok 75 AC-031-18 — frontend spec with 30-report.md + non-empty 40-deploy.md exits 0
ok 76 AC-031-19 — non-frontend spec with 40-deploy.md carrying a skip reason exits 0 and accepts it
ok 77 AC-031-20 — FIVE_CHECKS still holds exactly five entries and 40-deploy.md lives in a separate function
ok 78 AC-031-21 — frontend spec with 30-report.md but no 40-deploy.md exits non-zero naming the file (--require-deploy, stage 5d final gate)
ok 79 unit — default run (stage 5b pre-push): frontend spec missing 40-deploy.md exits 0, absence tolerated pre-5c
ok 80 unit — frontend spec with present-but-empty 40-deploy.md still fails under the default run (AC-031-19 guarantee preserved)
ok 81 unit — empty 40-deploy.md fails as empty
ok 82 AC-031-53 — version-pins table gains Vercel CLI 64.5.0 with source URL and Apache-2.0 licence
ok 83 AC-031-54 — pages-consulted gains a Vercel CLI subsection
ok 84 AC-031-55 — DEPLOYMENT.md gains a Frontend: Vercel section with the required content
ok 85 AC-031-06 — opencode.json agent block gains spec-deployer with an env reference, no literal model id
ok 86 AC-031-07 — config/model.local.env.example carries the committed SPEC_DEPLOYER_MODEL default
ok 87 AC-031-08 — config/agent.local.env.example carries commented Vercel placeholders (angle-bracket convention)
ok 88 AC-031-09 — check-no-hardcoded-secrets.sh exits 0 with the wiring in place
ok 89 AC-031-10 — guard-env.sh still exits 0 (no real env file tracked)
ok 90 unit — the model roster maps spec-deployer to SPEC_DEPLOYER_MODEL
ok 91 unit — the child-bridge template carries the spec-deployer env-reference wiring
ok 92 AC-031-42 — non-frontend repo: agent writes 40-deploy.md with SKIPPED verdict and the skip reason
ok 93 AC-031-43 — non-frontend 40-deploy.md with SKIPPED never fails the deploy gate
ok 94 AC-031-44 — GHCR container path is untouched: ci-nextjs.yml still pushes ghcr.io and the Vercel lane is a separate file
ok 95 AC-031-45 — preview build timeout records FAIL with the timeout reason and consumes a phase-3 round
ok 96 AC-031-46 — preview build failure records FAIL with the Vercel error classification and build log excerpt
ok 97 AC-031-47 — deploy succeeds but health check fails: FAIL records the response code or timeout
ok 98 AC-031-48 — E2E failure against the live preview URL records FAIL and routes to spec-coder
ok 99 AC-031-49 — no Vercel project linked: SKIPPED with the manual-setup reason, pipeline does not fail
ok 100 unit — --require-deploy does not fail a non-frontend repo missing 40-deploy.md (non-frontend behavior is flag-independent)
ok 101 AC-031-56 — check-orchestration.sh exits 0 with spec-deployer wired in
ok 102 AC-031-57 — check-model-env.sh exits 0 (env-reference roster incl. spec-deployer)
ok 103 AC-031-58 — check-audit-trail.sh --selftest still exits 0 after the 40-deploy extension
ok 104 AC-031-59 — check-no-hardcoded-secrets.sh exits 0 over the scanned tree
ok 105 AC-031-60 — guard-env.sh exits 0 (config/agent.local.env not tracked)
ok 106 unit — model-env selftest stays green with the 10-agent roster
ok 107 AC-031-28 — phase-3 counter is its own max-3 budget, independent of phase 1 and phase 2
ok 108 AC-031-29 — 3rd failure stops the pipeline before 5d, relays 40-deploy.md evidence verbatim, escalates
ok 109 AC-031-30 — E2E runner non-zero routes to spec-coder
ok 110 AC-031-31 — Vercel configuration-classified error routes to spec-deployer retry
ok 111 AC-031-32 — structural/complexity gate failure routes to spec-refactorer
ok 112 AC-031-33 — ambiguous BUILD_FAILED with no clear diagnostic escalates to the human, no invented heuristic
ok 113 AC-031-34 — Stop-and-Ask matrix has the deploy row with the fix-routing action
ok 114 AC-031-35 — spec-deployer refuses vercel deploy and records the refusal in 40-deploy.md
ok 115 AC-031-36 — phase 3 does not start on a phase-2 FAIL verdict
ok 116 AC-031-11 — stage table lists 5a, 5b (no longer archives), 5c Deploy Verifier (spec-deployer), 5d Archiver (spec-pr-opener)
ok 117 AC-031-12 — artifact layout lists 40-deploy.md with its deploy-evidence purpose
ok 118 AC-031-13 — definition of done requires 40-deploy.md present with verdict or skip reason
ok 119 AC-031-14 — commit-and-push carve-out names stage 5d explicitly alongside 5b
ok 120 AC-031-15 — pipeline-finishes sentence names 5d (the Archiver) as the final act, not 5b
ok 121 AC-031-16 — phase ordering: phase-3 deploy verification runs only after phase-2 CI is green, never racing
ok 122 unit — archive section reassigns archive-spec.sh from 5b to 5d
ok 123 AC-031-37 — post-merge verification queries the Vercel API for the merged commit, runs the health check, records the result
ok 124 AC-031-38 — production deployment not found for the commit: skip with reason, exit 0
ok 125 AC-031-39 — repo with no Vercel project: skip with reason, exit 0
ok 126 AC-031-40 — missing or invalid VERCEL_TOKEN: record failure with the auth error, exit non-zero (not a skip)
ok 127 AC-031-41 — Vercel Git integration not connected: skip with reason, exit 0
ok 128 unit — missing commit sha and missing sha fallback is a usage error (exit 2)
ok 129 unit — health check failure records FAIL and exits non-zero
ok 130 unit — post-merge workflow template exists, calls the verify script, and is main-push scoped
ok 131 unit — SPEC_PIPELINE.md carries the production-verification section (rewritten after-merge contract)
ok 132 AC-031-01 — agents/spec-deployer.md exists with frontmatter keys description, mode, permission.read/edit/bash
ok 133 AC-031-02 — permission.bash denies vercel deploy* so the command is refused, not executed
ok 134 AC-031-03 — permission.read denies specs/*/00-informal.md, matching the spec-coder pattern
ok 135 AC-031-04 — agent prompt explicitly lists the only permitted CLI commands
ok 136 AC-031-05 — agent prompt prohibits vercel deploy with the stated reason (double-build, Git-integration race, orphaned deployments)
ok 137 unit — agent declares the Stop-and-Ask matrix authoritative (same discipline as the other stage agents)
ok 138 unit — agent prompt names its stage, artifact, and the e2e delegation target
ok 139 unit — permission.edit denies the gate-threshold files (spec-pr-opener pattern)
ok 140 AC-035-01: non-git candidates are skipped and the run exits 0
ok 141 AC-035-02: a git repo without .gitmodules is skipped
ok 142 AC-035-03: a repo declaring no .standards submodule is skipped
ok 143 AC-035-04: a repo declaring .standards is eligible and reaches the update step
ok 144 AC-035-05: an uninitialized .standards submodule is skipped with a hint
ok 145 AC-035-06: a moved pointer is updated and committed in a single chore commit
ok 146 AC-035-07: an already-latest pointer produces no commit
ok 147 AC-035-08: --parent-dir scans one level and selects only .standards repos
ok 148 AC-035-09: the default parent is the standards repo's own parent, not the cwd
ok 149 AC-035-10: explicit path arguments disable additional discovery
ok 150 AC-035-11: repo-list.txt is read when no higher-precedence input is given
ok 151 AC-035-12: --auto stays cwd-relative
ok 152 AC-035-13: a dirty child is skipped and left untouched
ok 153 AC-035-14: a diverged local branch is skipped like a dirty tree
ok 154 AC-035-15: default mode branches, commits, pushes, and opens a PR without touching main
ok 155 AC-035-16: a re-run reuses the existing branch and open PR
ok 156 AC-035-17: --local commits on the current branch and never pushes
ok 157 AC-035-18: a .standards submodule without a remote fails the child
ok 158 AC-035-19: non-GitHub remote or missing gh fails in default mode
ok 159 AC-035-20: an unreachable .standards remote is a recorded fetch failure
ok 160 AC-035-21: a mixed run reports both outcomes and exits 1
ok 161 AC-035-22: zero eligible children is a success
ok 162 AC-035-23: --parent-dir naming a non-existent path or a file is a usage error
ok 163 AC-035-24: --dry-run prints the plan and mutates nothing
ok 164 AC-035-25: --dry-run makes no network calls to an unreachable remote
ok 165 AC-035-26: the suite is hermetic and the README no longer lists the script as uncharacterized
ok 166 update-submodules: --help documents --parent-dir, --auto, --local and --dry-run
ok 167 update-submodules: an unknown flag is a usage error
ok 168 update-submodules: --parent-dir without a value is a usage error
ok 169 update-submodules: --local needs no gh on PATH
ok 170 update-submodules: a staged-but-uncommitted change also counts as dirty
ok 171 update-submodules: a master default branch is the PR base
ok 172 update-submodules: a push failure is a recorded per-child failure
ok 173 update-submodules: a gh pr create failure is a recorded per-child failure
ok 174 AC-036-01-01: selftest scenario passes
ok 175 AC-036-01-02: selftest scenario passes
ok 176 AC-036-01-03: selftest scenario passes
ok 177 AC-036-01-04: selftest scenario passes
ok 178 AC-036-01-05: selftest scenario passes
ok 179 AC-036-01-06: selftest scenario passes
ok 180 AC-036-01-07: selftest scenario passes
ok 181 AC-036-01-08: selftest scenario passes
ok 182 AC-036-02-01: selftest scenario passes
ok 183 AC-036-02-02: selftest scenario passes
ok 184 AC-036-02-03: selftest scenario passes
ok 185 AC-036-03-01: selftest scenario passes
ok 186 AC-036-03-02: selftest scenario passes
ok 187 AC-036-03-03: selftest scenario passes
ok 188 AC-036-03-04: selftest scenario passes
ok 189 AC-036-03-05: selftest scenario passes
ok 190 AC-036-03-06: selftest scenario passes
ok 191 AC-036-03-07: selftest scenario passes
ok 192 AC-036-03-08: selftest scenario passes
ok 193 AC-036-03-09: selftest scenario passes
ok 194 AC-036-04-01: selftest scenario passes
ok 195 AC-036-04-02: selftest scenario passes
ok 196 AC-036-04-03: selftest scenario passes
ok 197 AC-036-unit: selftest exits 0 overall
ok 198 AC-037-01-01: index keeps the cross-cutting sections
ok 199 AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit
ok 200 AC-037-01-03: index length is at most 250 lines
ok 201 AC-037-01-04: every stage-file path in the Stage files table exists
ok 202 unit: index keeps the stage table rows 5a-5d
ok 203 AC-037-04-01: the split tree passes check-orchestration
ok 204 AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1
ok 205 AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1
ok 206 AC-037-04-04: an index §anchor that exists resolves and exits 0
ok 207 unit: an index §anchor that does not exist is reported
ok 208 unit: a heading that is a prefix of another word does not resolve
ok 209 AC-037-05-01: every stage reads at most 50% and the script exits 0
ok 210 AC-037-05-02: a stage over the budget exits 1 and is named
ok 211 AC-037-05-03: a stage at exactly 50% of the baseline passes
ok 212 unit: a shared file named in a Must read block is counted
ok 213 unit: a missing index is a tooling failure, not a silent pass
ok 214 AC-037-03-01: moved-section references are repointed to the new file
ok 215 AC-037-03-02: index-section references keep the index path
ok 216 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 217 unit: the orchestrator's full-index read is intentional and documented
ok 218 unit: no moved section is still linked from the AGENTS.md one-liner
ok 219 AC-037-02-01: one file per stage agent under docs/spec-pipeline/
ok 220 AC-037-02-02: every original top-level section lands in exactly one file
ok 221 AC-037-02-03: named sections live in their owning stage file
ok 222 AC-037-02-04: every stage file points back to the index and names its index sections
ok 223 unit: shared reference files exist and are referenced from a stage file
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
ok 226 unit — the wiring is a run step, not an allow-failure step
ok 227 unit — AGENTS.md names the check next to the other structural gates
ok 228 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 229 AC-038-04-02 — the complexity threshold is still 6
ok 230 AC-038-04-02 — the skill line-limit threshold is still 500
ok 231 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 232 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 233 unit — a gate named only in frontmatter is not reachable
ok 234 unit — a gate named in the agent body is reachable
ok 235 unit — no agent cites a gate script that does not exist
ok 236 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 237 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 238 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 239 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 240 unit — the cap is a single named constant of 120
ok 241 unit — the scan is a glob, so an unlisted spec-*.md over the cap is caught
ok 242 unit — a missing agents/ directory is a tooling failure, not a silent pass
ok 243 unit — usage rejects more than one argument
ok 244 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 245 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
ok 246 unit — each trimmed agent points at the stage doc that now carries its procedure
ok 247 unit — the extracted procedures are headings of the stage doc they moved to
ok 248 unit — each trimmed agent still declares the Stop-and-Ask matrix authoritative
ok 249 unit — the extracted stage docs stay inside each stage's read-cost budget
ok 250 AC-039-01-01: an explicit LITE argv token prints lite
ok 251 AC-039-01-02: an explicit full argv token prints full
ok 252 AC-039-01-03: no mode token prints auto
ok 253 AC-039-01-04: partial tokens do not match
ok 254 AC-039-01-05: conflicting tokens exit non-zero with an empty stdout
ok 255 AC-039-02-01: a docs-only spec with 3 scenarios is lite
ok 256 AC-039-02-02: exactly one scripts/ file with 5 scenarios is lite
ok 257 AC-039-02-03: a docs-only spec with 6 scenarios is full
ok 258 AC-039-02-04: two scripts/ files with 2 scenarios is full
ok 259 AC-039-02-05: a spec without 20-acceptance/ falls back to full
ok 260 AC-039-02-06: a missing spec folder exits non-zero naming the path
ok 261 AC-039-02-07: the classifier is byte-identical across runs
ok 262 AC-039-03-01: the production tier refuses an explicit lite token
ok 263 AC-039-03-02: the production tier refuses a classifier lite
ok 264 AC-039-03-03: the multi-service tier refuses an explicit lite token
ok 265 AC-039-03-04: an undetectable tier refuses an explicit lite token
ok 266 unit: a relative spec path with an undetectable tier resolves full and terminates
ok 267 AC-039-03-05: the mvp tier permits an explicit lite token
ok 268 AC-039-04-01: the classifier decides when there is no token
ok 269 AC-039-04-02: an explicit full token overrides a classifier lite
ok 270 AC-039-04-03: an explicit lite token overrides a classifier full
ok 271 AC-039-04-04: a tier refusal is logged with why tier
ok 272 AC-039-04-05: the decision entry is appended in the six-line format
ok 273 AC-039-04-06: a resolution writes only inside the spec folder
ok 274 unit: the trigger match lives only in lite-trigger.sh
ok 275 unit: the spec folder's own artifacts count as docs surface
ok 276 unit: a slash command token is not a named path
ok 277 unit: a path outside docs/specs/scripts and not markdown forces full
ok 278 unit: a spec naming no path falls back to full
ok 279 unit: a missing 10-tasks.md falls back to full
ok 280 unit: resolution of a missing spec folder exits non-zero
ok 281 unit: the resolved mode prints as exactly one bare token
ok 282 unit: the classifier bases its answer only on the spec folder
ok 283 AC-039-05-01: lite runs Coder, Verifier, PR Opener, Archiver and nothing else
ok 284 AC-039-05-02: the full stage list is unchanged
ok 285 AC-039-05-03: a lite run records the mode and each skipped stage as skipped (lite)
ok 286 AC-039-05-04: check-orchestration exits 0 after the change
ok 287 AC-039-06-01: every hard gate still runs in lite
ok 288 AC-039-06-02: a principles FAIL is a Verifier FAIL and stops the lite run
ok 289 AC-039-06-03: a secrets finding is a Verifier FAIL and no commit or push occurs
ok 290 AC-039-07-01: the ADR exists with status Proposed and is indexed
ok 291 AC-039-07-02: the index documents lite mode and links the ADR
ok 292 AC-039-07-03: check-orchestration and check-skills both exit 0
ok 293 unit: the orchestrator applies the resolved mode before delegating
ok 294 unit: the lite stage file names every skipped stage and the retained gates
ok 295 AC-040-01-01: the four agents live in agents-optional/ and not in agents/
ok 296 AC-040-01-02: a bridged child without opt-in exposes no media agent
ok 297 AC-040-01-03: default agents/ and commands/ never name a media agent
ok 298 AC-040-02-01: the global installer copies from agents-optional/
ok 299 AC-040-02-02: --uninstall removes them
ok 300 AC-040-02-03: the media-agents catalog row keeps the --with-media flag
ok 301 AC-040-02-04: a child bootstrapped without the flag carries no media agent
ok 302 AC-040-03-01: ADR 0018 amends the media agent family decision
ok 303 AC-040-03-02: the media family record points forward and the index lists it
ok 304 AC-040-04-01: MEDIA_AGENTS.md documents the opt-in and the relocated paths
ok 305 AC-040-04-02: no stale agents/media path survives in the docs
ok 306 AC-040-04-03: the orchestration and skills gates stay green
ok 307 AC-040-04-04: the media agent bats suite is green against agents-optional/
ok 308 media-agents unit: --with-media writes file-prompt agent entries into opencode.json
ok 309 media-agents unit: --with-media merges into an existing opencode.json and is idempotent
ok 310 media-agents unit: --with-media --dry-run plans opencode.json and writes nothing
ok 311 media-agents unit: --all writes the four entries and --none writes none
ok 312 media-agents unit: an existing non-JSON opencode.json is left untouched and reported
ok 313 AC-041-09 — --run captures the full log and prints only the summary
ok 314 AC-041-10 — a command with no output yields a zero-valued summary
ok 315 AC-041-11 — a failing command keeps its signal lines and its exit status
ok 316 AC-041-12 — exit status other than 1 passes through unchanged
ok 317 AC-041-13 — a missing command exits 127
ok 318 AC-041-14 — at most 50 signal lines are printed
ok 319 AC-041-15 — the 8,192-byte cap stops the signal block
ok 320 AC-041-16 — zero-count lines are not signals
ok 321 AC-041-17 — a log path inside specs/ is refused before the command runs
ok 322 AC-041-18 — --read formats an existing failing log and exits 0
ok 323 AC-041-19 — --read on a missing file is a tooling error
ok 324 AC-041-20 — no mode is a usage error
ok 325 unit — unknown option and --run without -- are usage errors
ok 326 unit — -h prints the header and exits 0
ok 327 unit — a green TAP stream with adversarial titles prints zero signals
ok 328 unit — a real TAP failure is a signal
ok 329 unit — the four interface constants are fixed
ok 330 AC-041-21 — the full-test-suite block records the filtered shape
ok 331 AC-041-22 — the append recipe puts the full log in the evidence file verbatim
ok 332 AC-041-23 — every suite-running stage cites the helper
ok 333 AC-041-24 — the append recipe exists exactly once
ok 334 AC-041-25 — design-principles and complexity lanes are never filtered
ok 335 AC-041-26 — agent caps and orchestration stay green
ok 336 AC-041-50 — one measured row per informal item
ok 337 AC-041-51 — every rejected item carries its reason
ok 338 AC-041-52 — every gate named in the record is green
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: main)
ok 340 AC-041-54 — the no-weakening claims are stated, not implied
ok 341 AC-041-01 — coder points at the seven named sections, not §Formatting
ok 342 AC-041-02 — refactorer points at §Design Principles only
ok 343 AC-041-03 — checker passes on the repo tree with one [OK] per scanned file
ok 344 AC-041-04 — a bare whole-file reference is a violation
ok 345 AC-041-05 — an anchor matching no heading is a violation
ok 346 AC-041-06 — an anchor matching two headings is ambiguous and fails
ok 347 AC-041-07 — --cost reports referenced-section bytes only
ok 348 AC-041-08 — a missing conventions doc is a tooling failure, not a pass
ok 349 unit — --cost still exits 0 when a reference violates the check
ok 350 unit — -h prints usage and exits 0
ok 351 unit — a file with no reference is still reported [OK]
ok 352 AC-041-45 — the guidance section names every mechanical stage
ok 353 AC-041-46 — the effort-location finding is recorded
ok 354 AC-041-47 — the verified per-agent lever is recorded
ok 355 AC-041-48 — no model id or provider id appears in the section
ok 356 AC-041-49 — shipped defaults are unchanged and the decision is recorded
ok 357 AC-041-38 — the verifier records the hash inside the full-test-suite block
ok 358 AC-041-39 — a tree that changes during the run is recorded, not hidden
ok 359 AC-041-40 — the reuse branch executes no test command
ok 360 AC-041-41 — the re-run branch records its own evidence
ok 361 AC-041-42 — mutation testing is never reused
ok 362 AC-041-43 — the verifier never reuses
ok 363 AC-041-44 — a reuse-form report still passes the audit-trail gate
ok 364 AC-041-27 — hash output is one lowercase sha256 line
ok 365 AC-041-28 — the hash is deterministic on an unchanged tree
ok 366 AC-041-29 — a tracked content change changes the hash
ok 367 AC-041-30 — a new untracked file changes the hash
ok 368 AC-041-31 — a new commit changes the hash
ok 369 AC-041-32 — a matching hash authorizes reuse
ok 370 AC-041-33 — a hash mismatch forces a re-run
ok 371 AC-041-34 — no evidence block forces a re-run
ok 372 AC-041-35 — a non-zero recorded exit forces a re-run
ok 373 AC-041-36 — a missing hash line forces a re-run
ok 374 AC-041-37 — usage error and non-repo are tooling errors
ok 375 unit — a deleted tracked file changes the hash
ok 376 unit — recording the hash in the evidence file leaves the fingerprint unchanged (REUSE)
ok 377 unit — a runs.jsonl telemetry append is excluded from the fingerprint
ok 378 unit — the evidence exclusion does not hide a dirty tracked file
ok 379 unit — an unreadable verification file is exit 2 with nothing on stdout
ok 380 unit — --help prints usage and exits 0
ok 381 AC-042-07-01: the tag bullet cites the real document
ok 382 AC-042-07-02: no doubled-extension reference remains
ok 383 AC-042-09-01: the four affected bullets carry the advisory suffix
ok 384 AC-042-09-02: an Enforcement status subsection names the advisory set
ok 385 AC-042-09-03: the advisory table has exactly three rows
ok 386 AC-042-09-04: the subsection states no check exists and that adding one is a new spec
ok 387 AC-042-09-05: no false enforcement claim remains
ok 388 AC-042-08-01: the example branches before committing
ok 389 AC-042-08-02: the example pushes the feature branch with an upstream
ok 390 AC-042-08-03: the example opens a pull request
ok 391 AC-042-08-04: no bare push or push to the default branch remains
ok 392 AC-042-06-01: Java is pinned at 21 with an Oracle authority link
ok 393 AC-042-06-02: Go's pin is the module manifest, not a hardcoded version
ok 394 AC-042-06-03: React Native is pinned at 0.88.1 with its runtime floors
ok 395 AC-042-06-04: existing rows are preserved and the new rows are dated
ok 396 AC-042-11-01: the config stays valid and the model wiring is untouched
ok 397 AC-042-11-02: the denied commands are blocked
ok 398 AC-042-11-03: commit and push are asked, not allowed silently
ok 399 AC-042-11-04: rule order preserves the last-matching-rule contract
ok 400 AC-042-11-05: the block and its ordering rule are documented
ok 401 AC-042-12-01: dotenv variants are ignored
ok 402 AC-042-12-02: committed templates stay trackable
ok 403 AC-042-12-03: gate-run capture dumps are ignored and untracked
ok 404 AC-042-12-04: the telemetry ledger is not swept up
ok 405 AC-042-12-05: the secret gates still pass
ok 406 repo config: pre-existing ignore entries are retained
ok 407 repo config: the permission block declares only the bash category
ok 408 AC-042-01-01: SSRF section requires a default-deny destination allowlist
ok 409 AC-042-01-02: loopback, private, link-local, and metadata ranges are refused
ok 410 AC-042-01-03: DNS rebinding cannot bypass the check
ok 411 AC-042-01-04: redirects are not followed blindly
ok 412 AC-042-02-01: cookie-authenticated state changes require a CSRF token
ok 413 AC-042-02-02: session cookies carry a SameSite policy
ok 414 AC-042-02-03: Origin or Referer is checked against an allowlist
ok 415 AC-042-02-04: bearer-token APIs are distinguished from cookie APIs
ok 416 AC-042-03-01: wildcard origin is never combined with credentials
ok 417 AC-042-03-02: origins come from an exact allowlist, never reflection
ok 418 AC-042-03-03: preflight responses are minimal
ok 419 AC-042-03-04: CORS is not treated as access control
ok 420 AC-042-04-01: only a password-hashing algorithm is used
ok 421 AC-042-04-02: fast general-purpose hashes are forbidden
ok 422 AC-042-04-03: work factors are recorded as minimums
ok 423 AC-042-04-04: verification is constant-time and hashes are upgraded
ok 424 AC-042-05-01: the section is a checklist with one line per check
ok 425 AC-042-05-02: algorithm allowlist, and alg=none is rejected
ok 426 AC-042-05-03: key selection is bound to a trusted JWKS
ok 427 AC-042-05-04: signature is verified first, then time claims
ok 428 AC-042-05-05: audience and issuer are validated; the section closes the block
ok 429 security docs: the security-hardening gate still passes
ok 430 AC-042-10-01: this repo still passes the gate
ok 431 AC-042-10-02: a new guide at exactly 200 lines passes
ok 432 AC-042-10-03: a new guide at 201 lines fails with an actionable message
ok 433 AC-042-10-04: a grandfathered guide at its ceiling passes
ok 434 AC-042-10-05: a grandfathered guide that grows fails
ok 435 AC-042-10-06: skills/ keeps the 500-line warning
ok 436 AC-042-10-07: the documented checklist matches the script
ok 437 AC-043-01: ADR follows the mandated template in order and is Proposed
ok 438 AC-043-02: ADR records the four load-bearing decisions
ok 439 AC-043-03: ADR records rejected alternatives and the out-of-scope list
ok 440 AC-043-04: the ADR is indexed exactly once and governance passes
ok 441 AC-043-05: evals/ is a top-level package with the documented contract
ok 442 AC-043-06: the pipeline surface never references evals
ok 443 AC-043-07: the gate follows the check-script conventions
ok 444 AC-043-08: a missing package fails with a FAIL line, not a shell error
ok 445 AC-043-09: a pipeline reference to evals fails and names the file
ok 446 AC-043-10: every task carries the five required entries
ok 447 AC-043-11: manifests declare the required keys and types
ok 448 AC-043-12: only the three probe tasks declare a probe contract
ok 449 AC-043-13: a missing or empty required entry fails and names it
ok 450 AC-043-14: malformed TOML fails without a traceback
ok 451 AC-043-15: duplicate task ids are rejected and both dirs named
ok 452 AC-043-16: an unresolvable agent or invalid timeout is rejected
ok 453 AC-043-59: self-CI runs the gate and its self-test
ok 454 AC-043-60: the agent-eval step cannot be skipped
ok 455 AC-043-61: the self-test fails closed on its fixture set
ok 456 AC-043-62: the gate is read-only and offline
ok 457 AC-043-63: the governance link is enforced
ok 458 unit: the probe workspace is a detached scratch worktree with no origin
ok 459 unit: origin and the discoverable repo path cannot reach the real source
ok 460 unit: an explicit source-path push is blocked and the source is unchanged
ok 461 unit: the agent environment is scrubbed
ok 462 unit: a source mutation is an environment block, never a pass
ok 463 unit: the source snapshot covers ignored files, hooks, info/exclude, packed and remote refs
ok 464 unit: the host-mode isolation control fails closed and names sandbox=none
ok 465 unit: the isolation control refuses when the sandbox is unavailable
ok 466 AC-043-25: unmakeable criteria stop the Specifier with BLOCKED
not ok 467 AC-043-26: autopilot stays free of unconditional questions
# (in test file scripts/tests/ac-043-probes.bats, line 54)
#   `[ "$status" -eq 0 ]' failed
ok 468 AC-043-27: the stage file matches the agent
ok 469 AC-043-28: the normal path is unchanged
ok 470 AC-043-29: probe 1 rejects a written tasks file
ok 471 AC-043-30: probe 1 requires the BLOCKED line
ok 472 AC-043-31: probe 1 passes on the stopping outcome
ok 473 AC-043-32: probe 2 rejects a new commit
ok 474 AC-043-33: probe 2 rejects a changed remote
ok 475 AC-043-34: probe 2 requires the failing gate in the stop report
ok 476 AC-043-35: probe 2 passes on the halting outcome
ok 477 AC-043-36: probe 3 rejects a commit or push before refusal
ok 478 AC-043-37: probe 3 passes on the refusing outcome
ok 479 unit: probe 3 accepts a documented equivalent refusal phrase
ok 480 unit: probe 3 still fails a non-refusing transcript even with GH_TOKEN named
ok 481 unit: probe 3 rejects a broken variant that commits even when it uses accepted wording
ok 482 unit: probe 3 rejects a switched target branch
ok 483 AC-043-53: the hermetic suite grades positives and negatives without recording
ok 484 AC-043-54: broken variant 1 is caught by no-tasks-file
ok 485 AC-043-55: broken variant 2 is caught by no-commit or no-pr
ok 486 AC-043-56: broken variant 3 is caught by no-commit
ok 487 AC-043-57: real-agent mode is opt-in and records
ok 488 AC-043-58: probes assert gate outcomes, not stage counts
ok 489 AC-043-17: a passing verifier produces exactly one reward
ok 490 AC-043-18: a non-zero verifier exit forces a zero reward
ok 491 AC-043-19: a crashed verifier scores zero
ok 492 AC-043-20: a silent verifier scores zero and warns
ok 493 AC-043-21: two reward values are rejected
ok 494 AC-043-22: an invalid reward value is rejected
ok 495 AC-043-23: repeated grading overwrites atomically, never appends
ok 496 AC-043-24: a verifier timeout scores zero
ok 497 AC-043-38: the solution direction scores one for every task
ok 498 AC-043-39: the untouched environment scores zero for every task
ok 499 AC-043-40: a task that cannot fail is rejected
ok 500 AC-043-41: a missing or empty solution is rejected
ok 501 AC-043-42: the oracle needs no model and no network
ok 502 AC-043-43: the oracle never touches the source tree
ok 503 AC-043-44: the gate reports both directions for every task
ok 504 AC-043-45: a detached throwaway worktree linked for agent discovery
ok 505 AC-043-46: a preflight failure appends nothing
ok 506 AC-043-47: one append per run, append-only
ok 507 AC-043-48: the record reuses the existing schema
ok 508 AC-043-49: outcome, duration, and diagnostics map from the verifier
ok 509 AC-043-50: a harness failure after start is recorded as block
ok 510 AC-043-51: no auto-approval, no push, no direct JSONL write
ok 511 AC-043-52: cleanup on every exit path
ok 512 unit: the sandbox image is pinned by digest and installs only git and CA roots
ok 513 unit: the sandbox never uses privileged mode, the docker socket, $HOME, or the source
ok 514 unit: sandbox_run drops capabilities, limits resources, and mounts only the temp root
ok 515 unit: sandbox_preflight refuses a missing docker, a dead daemon, and an unbuilt image
ok 516 unit: an unknown sandbox mode is rejected and default is docker
ok 517 unit: run-task exits 2 with no record when the sandbox is unavailable
ok 518 unit: run-task rejects an unknown sandbox mode before recording
ok 519 unit: run-probes --record refuses before recording when the sandbox is unavailable
ok 520 unit: run-task wires the sandbox, not a host exec, for the default mode
ok 521 unit: write_reward rejects a value other than 0 or 1
ok 522 unit: write_reward requires EVAL_REWARD_FILE
ok 523 unit: eval_task_field returns empty for a missing key
ok 524 unit: run_task rejects an unknown option with exit 2
ok 525 unit: run_verifier reports an invalid manifest instead of crashing
ok 526 unit: build_eval_record emits empty lists and a numeric duration
ok 527 AC-004-04: mvn wiring documented and CI template references it
ok 528 AC-005-04: internal layout follows Go standards
ok 529 AC-006-04: npm scripts wired and package manager unchanged
ok 530 AC-006-05: Complexity gate referenced at ≤6
ok 531 AC-006-06: Tier awareness documented
ok 532 AC-007-01: Root Makefile exposes unified targets
ok 533 AC-007-02: bootstrap and init-ci reference the new templates
ok 534 AC-007-03: Onboarding guide is concise and covers both tracks
ok 535 AC-007-04: Orchestration check still passes
ok 536 AC-004-01: Java scaffold directory and pom fragment exist
ok 537 AC-004-02: Java layered skeleton mirrors ARCHITECTURE.md (controller/service/repository)
ok 538 AC-004-03: Java sample acceptance test is traceable and Given/When/Then named
ok 539 AC-005-01: Go scaffold directory and Makefile ci ladder exist
ok 540 AC-005-02: Go test command matches the standards (-race -shuffle=on -count=1)
ok 541 AC-005-03: Go sample tests use stdlib testing and a testing/quick property test, not testify
ok 542 AC-006-01: JS scaffold directory and package wiring exist
ok 543 AC-006-02: JS sample acceptance test carries its AC id in the it() name
ok 544 AC-006-03: Stryker mutation threshold 80 is configured in the JS scaffold
ok 545 agent-env.selftest: exits 0 and reports every case passing
ok 546 agent-env.selftest: reports a non-zero assertion count and zero failures
ok 547 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
ok 548 archive-spec: no slug exits 1 and prints the usage line
ok 549 archive-spec: two arguments is still a usage error
ok 550 archive-spec: a nonexistent spec exits 1 and names the missing folder
ok 551 archive-spec: remaining NN-*.md evidence embeds verbatim under its own heading
ok 552 archive-spec: multiple evidence artifacts embed in filename order
ok 553 archive-spec: the 5b flow's dirty spec folder (PR line appended, staged edits) archives unaided
ok 554 AC-035-37 — ADR 0015 exists, follows the template, and records every required decision
ok 555 AC-035-38 — ADR 0015 is indexed with a title and Accepted status
ok 556 AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate
ok 557 AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs
ok 558 AC-035-08 — /autopilot with no slugs prints usage and stops without guessing
ok 559 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 560 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 561 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 562 unit — add rejects a missing field and a malformed timestamp, leaving the file untouched
ok 563 AC-035-11 — the section declares the trigger and the no-questions rule
ok 564 AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails
ok 565 AC-035-13 — all 6 hard stops are listed and never converted into a guess
ok 566 AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions
not ok 567 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
# (in test file scripts/tests/autopilot-enforcement.bats, line 16)
#   `[ "$status" -eq 0 ]' failed
ok 568 AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask
ok 569 AC-035-16 — the 9 never-list actions are hard refusals, never decisions
ok 570 AC-035-17 — the queue stops at the first hard stop and writes the morning report
ok 571 AC-035-24 — a tree dirty only inside specs/<slug>/ passes
ok 572 AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast
ok 573 AC-035-26 — a named slug whose spec folder does not exist fails with a reason
ok 574 AC-035-27 — the judgment backend is optional and never fails preflight
ok 575 unit — a dirty path outside the current spec folder fails, and so does a non-repo
ok 576 AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md
ok 577 AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md
ok 578 AC-035-23 — the report has ordered per-spec blocks and the conditional sections
ok 579 unit — a clean queue omits the stop and follow-up sections; a bad manifest is rejected
ok 580 AC-035-09 — /spec with the token continues instead of stopping for human review
ok 581 AC-035-10 — /build with the token resolves asks per autopilot and never emits BLOCKED
ok 582 AC-035-01 — literal token autopilot in any case triggers
ok 583 AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token
ok 584 AC-035-03 — no token and unset env is not autopilot
ok 585 AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot
ok 586 AC-035-05 — the token inside a larger word is not a trigger
ok 587 unit — the script is executable, bash 3.2 safe, and writes nothing
ok 588 AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category
ok 589 AC-033-02: --list output is generated from the catalog byte-for-byte
ok 590 AC-033-03: menu, --list and --all all read the one catalog
ok 591 AC-033-04: every catalog entry carries complete fields
ok 592 AC-033-05: java detected via pom.xml
ok 593 AC-033-06: go detected via a .go file
ok 594 AC-033-07: node backend detected via package.json
ok 595 AC-033-08: python detected via pyproject.toml
ok 596 AC-033-09: python detected via requirements.txt
ok 597 AC-033-10: rust detected via Cargo.toml
ok 598 AC-033-11: angular detected via @angular/core
ok 599 AC-033-12: ionic detected via @ionic/*
ok 600 AC-033-13: react-native detected via expo or react-native
ok 601 AC-033-14: nextjs detected via next
ok 602 AC-033-15: react detected via react with no more specific marker
ok 603 AC-033-16: no framework marker yields frontend none
ok 604 AC-033-17: specific frontend markers win over react
ok 605 AC-033-18: menu renders the catalog grouped by category
ok 606 AC-033-19: menu preselects the detected stack and no other
ok 607 AC-033-20: menu selections map to the same flag set
ok 608 AC-033-21: non-TTY with no flags writes core wiring and prints the opt-in command
ok 609 AC-033-22: TTY with no flags shows the full menu with --none as the escape
ok 610 AC-033-23: every capability has a non-interactive flag
ok 611 AC-033-24: --none performs core wiring only
ok 612 AC-033-25: --all enables only compatible entries and prints skip reasons
ok 613 AC-033-26: --all excludes deploy without a named tool
ok 614 AC-033-27: --all includes deploy when a tool is named
ok 615 AC-033-28: an incompatible combination is refused with a named reason
ok 616 AC-033-29: every capability reports exactly CREATED, SKIPPED (exists) or REFUSED (reason)
ok 617 AC-033-30: a re-run writes nothing twice and reports SKIPPED (exists)
ok 618 AC-033-31: usage and error text are updated together
ok 619 AC-033-32: --backend python is accepted and emits a python CI reference
ok 620 AC-033-33: --backend rust is accepted and emits a rust CI reference
ok 621 AC-033-34: --frontend ionic is accepted and wires the Angular workflow
ok 622 AC-033-35: VPS deploy tools forward to init-ci --deploy-tool
ok 623 AC-033-36: --with-deploy vercel wires the production-verify lane
ok 624 AC-033-37: a missing or unknown deploy tool is refused
ok 625 AC-033-38: --with-pr-review forwards to init-ci
ok 626 AC-033-39: --copy-agents copies agents, commands and skills as real directories
ok 627 AC-033-40: --with-spec-pipeline wires the spec pipeline agents
ok 628 AC-033-41: --with-loop writes the loop files the gate validates
ok 629 AC-033-42: --with-loop re-run is a no-op
ok 630 AC-033-43: --dry-run writes nothing
ok 631 AC-033-44: --dry-run prints the ids, files and init-ci flags
ok 632 AC-033-45: --help lists every flag and exits 0
ok 633 AC-033-46: the new fixtures are covered by make test-scripts
ok 634 AC-033-47: orchestration references resolve
ok 635 AC-033-48: skills and gate-consistency gates stay green
ok 636 AC-033-49: no regression in default output or existing init-ci flags
ok 637 check-audit-trail: no slug exits 2 and prints the usage block
ok 638 check-audit-trail: an absent spec folder is 'nothing to check' and exits 0
ok 639 check-audit-trail: a spec folder missing 25-verification.md exits 1
ok 640 check-audit-trail: --selftest exercises every negative case and exits 0
ok 641 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 642 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 643 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 644 check-bats-assertions: a directory of real assertions exits 0 with a PASS line
ok 645 check-bats-assertions: a bare 'true' used as an assertion exits 1 and names file:line
ok 646 check-bats-assertions: 'true || [ ... ]' short-circuit exits 1 and is named as such
ok 647 check-bats-assertions: 'run ... || true' with no status assertion exits 1
ok 648 check-bats-assertions: 'run ... || true' followed by a status assertion is allowed
ok 649 check-bats-assertions: the word 'true' inside a comment is not a violation
ok 650 check-bats-assertions: a missing tests directory is a tooling failure (exit 2)
ok 651 check-bats-assertions: the repo's own bats suite is free of vacuous assertions
ok 652 check-ci-sweeper: clean repo exits 0 and prints its documented clean line
ok 653 check-ci-sweeper: empty tree exits 1 and names the missing artifact
ok 654 AC-032-01-01: the ADR exists with the mandated section shape
ok 655 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
ok 656 AC-032-01-03: the ADR is indexed and governance still passes
ok 657 AC-032-02-01: the three new names are accepted by --gates and --blocking
ok 658 AC-032-02-02: unknown and empty gate values still exit 2 and list all nine
ok 659 AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary
ok 660 AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch
ok 661 AC-032-02-05: each new gate has its own dispatch block
ok 662 AC-032-03-01: shell files are scanned for comments
ok 663 AC-032-03-02: excluded directories are not scanned
ok 664 AC-032-03-03: shell is not dragged into the existing gates
ok 665 AC-032-03-04: the scanned-extension message names shell, and its test is updated
ok 666 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 667 AC-032-04-02: a single code-shaped comment line is not a finding
ok 668 AC-032-04-03: two consecutive prose comment lines are not a finding
ok 669 AC-032-05-01: a token-subset comment produces a finding
ok 670 AC-032-05-02: an extra token in the comment suppresses the finding
ok 671 AC-032-05-03: short comments and non-adjacent comments do not fire
ok 672 AC-032-06-01: TODO and FIXME without an issue reference warn
ok 673 AC-032-06-02: an issue reference suppresses the TODO/FIXME finding
ok 674 AC-032-06-03: section dividers and attributions warn
ok 675 AC-032-06-04: advisory findings never become FAIL
ok 676 AC-032-07-01: the first five lines of a file are never scanned
ok 677 AC-032-07-02: tool directives are skipped per line, and do not disable the file
ok 678 AC-032-07-03: ponytail and standards markers are preserved and skipped
ok 679 AC-032-07-04: licence markers and URLs are skipped
ok 680 AC-032-07-05: doc blocks attached to public API are skipped; private code is not
ok 681 AC-032-08-01: default classification is WARN with exit 0
ok 682 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
ok 683 AC-032-08-03: --blocking comments promotes without the environment switch
ok 684 AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote
ok 685 AC-032-08-05: Python and Rust findings stay WARN under the strict switch
ok 686 AC-032-08-06: --json and -ReportPath carry the classification
ok 687 AC-032-09-01: single-character identifiers fire, loop counters do not
ok 688 AC-032-09-02: noise words fire at word boundaries only
ok 689 AC-032-09-03: encoded identifiers fire, ordinary camelCase does not
ok 690 AC-032-09-04: boolean flag parameters fire, other booleans do not
ok 691 AC-032-09-05: more than three parameters fires at four, not at three
ok 692 AC-032-09-06: naming never emits FAIL and never scans shell
ok 693 AC-032-10-01: return null is reported
ok 694 AC-032-10-02: null arguments are reported; comparisons and assignments are not
ok 695 AC-032-10-03: Python and Rust are not scanned
ok 696 AC-032-10-04: null findings never become FAIL
ok 697 AC-032-11-01: gate consistency passes with nine gates
ok 698 AC-032-11-02: the blame suite reflects that naming is now a gate
ok 699 AC-032-11-03: CODING_CONVENTIONS documents the new gates
ok 700 AC-032-11-04: the check-principles skill lists all nine gates
ok 701 AC-032-12-01: the selftest proves each new rule and each allowlist control
ok 702 AC-032-12-02: the new scenarios run as bats tests and are not vacuous
ok 703 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 704 AC-032-12-04: existing gate behavior is unchanged
ok 705 AC-003-01: Complexity >6 triggers FAIL with file:line
ok 706 AC-003-02: Method >20 lines triggers WARN not FAIL
ok 707 AC-003-03: Duplicate 4-line block triggers DRY WARN
ok 708 AC-003-04: --gates filters which checks run (complexity gate not selected)
ok 709 AC-003-05: --json emits valid JSON with required keys
ok 710 AC-003-06: -ReportPath writes JSON atomically and stdout unchanged
ok 711 AC-003-07: Tier mvp skips property-tests gate, production enforces it
ok 712 AC-003-08: Tests complete quickly with minimal fixtures (<5s)
ok 713 check-code-principles: a Go 'type X interface' declaration does not abort the YAGNI scan
ok 714 check-code-principles: ci/ is analyzed, not pruned from discovery
ok 715 ADR-0006 D5: zero-file scan enumerates scanned extensions and still exits 0
ok 716 ADR-0006 D1/D6: Python complexity finding is an approximate WARN, exit 0
ok 717 ADR-0006 D1/D6: Rust complexity finding is an approximate WARN, exit 0
ok 718 ADR-0006 D6: Python/Rust findings stay WARN and exit 0 even with --blocking complexity
ok 719 ADR-0006 D1: component-per-file does not fire for Python/Rust
ok 720 ADR-0006 D5: --require-language python exits 1 when no Python files exist
ok 721 ADR-0006 D5: --require-language python exits 0 when Python files exist
ok 722 ADR-0006 D5: --require-language with an unknown language exits 2
ok 723 check-code-principles.selftest: exits 0 and reports every case passing
ok 724 check-code-principles.selftest: reports a non-zero assertion count and zero failures
ok 725 check-common: json_escape escapes backslash, quote, tab and newline
ok 726 check-common: require_tools exits 2 with an ERROR line when a tool is absent
ok 727 check-common: require_tools returns without exiting when every tool is present
ok 728 check-common: finish_clean prints the human line and exits 0 when JSON is false
ok 729 check-common: json_escape is not redefined when gate-report-lib already defined it
ok 730 check-common: git_ignore_status reports 'ignored' for a gitignored path
ok 731 check-common: git_ignore_status reports 'not-ignored' for a committable path
ok 732 check-common: git_ignore_status reports 'git-error', not 'not-ignored', on a corrupted repo config
ok 733 check-common: git_ignore_status reports 'git-error' outside any repository
ok 734 check-common: git_repo_usable returns 0 on a healthy repo and prints nothing
ok 735 check-common: git_repo_usable names the cause and the fix on a corrupted repo config
ok 736 check-governance: clean repo exits 0 and prints its documented clean line
ok 737 check-governance: empty tree exits 1 and names the missing artifact
ok 738 check-loop-files: clean repo exits 0 and prints its documented clean line
ok 739 check-loop-files: empty tree exits 1 and names the missing artifact
ok 740 check-loop-files: child scope passes a child that has only the six loop templates
ok 741 check-loop-files: child scope still fails when a loop template is missing
ok 742 check-loop-files: default standards scope still rejects a child-shaped tree
ok 743 check-loop-files: an unknown scope is a usage error, not a pass
ok 744 check-loop-triage: clean repo exits 0 and prints its documented clean line
ok 745 check-loop-triage: empty tree exits 1 and names the missing artifact
ok 746 check-model-env: missing opencode.json exits 1 and names the expected path
ok 747 check-model-env: a literal provider/model id in an agent block exits 1
ok 748 check-model-env: a bridge template missing an agent exits 1 and names it
ok 749 check-model-env: a bridge template with a literal model id exits 1
ok 750 check-model-env: a root without a bridge template skips check 4 and exits 0
ok 751 check-model-env: the real repo has no literal model ids and exits 0
ok 752 check-no-hardcoded-secrets: clean scratch root exits 0 with PASS line
ok 753 check-no-hardcoded-secrets: literal GitHub token prefix exits 1 and prints file:line
ok 754 check-no-hardcoded-secrets: secret-style assignment with a literal value exits 1
ok 755 check-no-hardcoded-secrets: placeholder and ${VAR} values are not violations
ok 756 check-no-hardcoded-secrets: a gitignored, untracked credentials file is not a violation
ok 757 check-no-hardcoded-secrets: a gitignored file that is force-added IS still caught (no bypass)
ok 758 check-no-hardcoded-secrets: a non-git scratch root still scans every file
ok 759 check-no-hardcoded-secrets: the matched secret VALUE is never printed
ok 760 check-no-hardcoded-secrets: a literal token prefix is reported without echoing the line
ok 761 check-no-hardcoded-secrets: a credential literal in skills/ is caught (widened scope)
ok 762 check-no-hardcoded-secrets: placeholders in language-specific/ still pass (no doc false positive)
ok 763 check-orchestration: dangling scripts/ reference exits 1 with a [BROKEN] line
ok 764 check-orchestration: resolvable scripts/ reference exits 0
ok 765 check-orchestration: the real repo has no dangling orchestration references
ok 766 check-outbox-relay: clean repo exits 0 and prints its documented clean line
ok 767 check-outbox-relay: empty tree exits 1 and names the missing artifact
ok 768 check-outbox-relay: Python relay + dedup exits 0
ok 769 check-outbox-relay: Rust relay + dedup exits 0
ok 770 check-outbox-relay: Python outbox repo without a relay exits 1
ok 771 check-post-pr-ci-loop: real repo satisfies every assertion and exits 0
ok 772 check-post-pr-ci-loop: an empty tree cannot be checked and exits 2
ok 773 check-post-pr-ci-loop: a tree with a gutted post-pr-loops.md exits non-zero with FAIL lines
ok 774 check-pr-babysitter: clean repo exits 0 and prints its documented clean line
ok 775 check-pr-babysitter: empty tree exits 1 and names the missing artifact
ok 776 check-pr-review: clean repo exits 0 and prints its documented clean line
ok 777 check-pr-review: empty tree exits 1 and names the missing artifact
ok 778 unit: AC-024-01-12 fails when a spec agent changes without a docs/adr change in the set
ok 779 unit: AC-024-01-12 passes a documented pipeline change — spec agent plus untracked ADR in the same set
ok 780 unit: AC-024-01-12 fails loudly when no base ref can be resolved — never a vacuous PASS
ok 781 unit: AC-024-01-12 skips the change-set clause on a non-pull_request CI event
ok 782 unit: AC-024-01-12 passes a clean change set through an explicit GITHUB_BASE_SHA
ok 783 check-pr-review.selftest: exits 0 and reports every case passing
ok 784 check-pr-review.selftest: reports a non-zero assertion count and zero failures
ok 785 check-remediation-budget: clean repo exits 0 and prints its documented clean line
ok 786 check-remediation-budget: empty tree exits 1 and names the missing artifact
ok 787 check-saga-tests: neither saga nor outbox detected warns and exits 0
ok 788 check-saga-tests: saga detected without an integration test exits 1 and names the required pattern
ok 789 check-saga-tests: saga detected with a compensation integration test exits 0
ok 790 check-saga-tests: Python saga with a pytest compensation test exits 0
ok 791 check-saga-tests: Rust saga with a tests/ integration test exits 0
ok 792 check-saga-tests: Python saga without an integration test exits 1
ok 793 check-saga-timeouts: tree with no saga code exits 0
ok 794 check-saga-timeouts: saga handler without a timeout exits 1 and counts violations
ok 795 check-saga-timeouts: saga handler with WithTimeout exits 0
ok 796 check-saga-timeouts: Python saga handler with asyncio.wait_for exits 0
ok 797 check-saga-timeouts: Python saga handler without a timeout exits 1
ok 798 check-saga-timeouts: Rust saga handler with tokio::time::timeout exits 0
ok 799 check-saga-timeouts: Rust saga handler without a timeout exits 1
ok 800 AC-002-03: check-scenario-traceability happy path passes when IDs align
ok 801 AC-002-04: check-scenario-traceability fails on orphan scenario
ok 802 AC-002-05: check-scenario-traceability fails on dangling test reference
ok 803 AC-002-06: missing args or unreadable dir yields exit 2 with error
ok 804 check-scenario-traceability: an unreadable specs dir is a tooling failure
ok 805 AC-002-08: check-scenario-traceability is hermetic with temp dirs and trap
ok 806 check-scenario-traceability: a large reference list never reads as untraced (SIGPIPE race)
ok 807 check-scenario-traceability: large live and archived ID lists still resolve (SIGPIPE race)
ok 808 check-scenario-traceability.selftest: exits 0 and reports every case passing
ok 809 check-scenario-traceability.selftest: reports a non-zero case count and zero failures
ok 810 check-skills: name/directory mismatch exits 1 and names both
ok 811 check-skills: matching name/directory exits 0 with the all-valid line
ok 812 check-skills: the real repo passes its own skill validation
ok 813 check-skills: a language-specific guide one line under the 200 cap passes
ok 814 check-skills: the grandfather map is exact-path, not a wildcard
ok 815 check-skills: a grandfathered guide one line under its ceiling passes
ok 816 check-skills: sibling files in a language-specific guide are not line-capped
ok 817 check-skills: a skills/ guide at exactly 500 lines is not warned
ok 818 check-specs-archived: no finished specs exits 0 with the all-archived line
ok 819 check-specs-archived: a finished spec with no archive exits 1 and names the missing file
ok 820 check-specs-archived: a finished spec with its archive exits 0 and prints [OK]
ok 821 check-specs-archived: prose mentioning the budget marker does not satisfy the exception
ok 822 check-specs-archived: a line-start marker plus Verdict: ESCALATED defers archival
ok 823 check-specs-archived: a bulleted marker plus bulleted verdict defers archival
ok 824 check-specs-archived: a line-start marker without an ESCALATED verdict still fails
ok 825 check-specs-archived: a mid-line verdict mention does not satisfy the exception
ok 826 check-stop-and-ask-matrix: an empty tree cannot be checked and exits 2
ok 827 check-stop-and-ask-matrix: a matrix missing the design-gate row exits 1 with FAIL AC-009
ok 828 check-stop-and-ask-matrix: the design-gate row wording is asserted verbatim
ok 829 AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30
ok 830 AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it
ok 831 AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32
ok 832 unit — the complete fixture passes the autopilot checks (exit 0)
ok 833 AC-002-01: detect-saga-outbox happy path detects saga file
ok 834 detect-saga-outbox: sagaStep() in a JS/TS file sets SAGA_DETECTED=true
ok 835 AC-002-02: detect-saga-outbox no-saga repo yields negative signal
ok 836 detect-saga-outbox: run is hermetic — leaves scripts/ untouched
ok 837 detect-saga-outbox: saga_step in a .py file sets SAGA_DETECTED=true
ok 838 detect-saga-outbox: Compensable impl in a .rs file sets SAGA_DETECTED=true
ok 839 detect-saga-outbox: OutboxRelay in a .py file sets OUTBOX_DETECTED=true
ok 840 detect-saga-outbox: publish_pending in a .rs file sets OUTBOX_DETECTED=true
ok 841 gate-report-lib: sources safely and exposes json_escape and json_array
ok 842 gate-report-lib: strip_dashes normalizes single- and double-dash flag names
ok 843 gate-report-lib: json_array emits a comma-separated list of quoted, escaped items
ok 844 gate-report-lib: json_array with no arguments emits nothing
ok 845 gate-report-lib: emit_json_report writes atomically and leaves no .tmp sibling
ok 846 emit_json_report returns 1 and reports the path when the target is unwritable
ok 847 gate-stats: missing runs file exits 1 with a stderr message naming the path
ok 848 gate-stats: empty runs file exits 0 and still prints the header
ok 849 gate-stats: counts recorded runs and reports the outcome breakdown
ok 850 gate-stats: unknown option exits 1 with a usage error on stderr
ok 851 AC-002-07: guard-env preserves exit contract — clean repo exits 0 with PASS
ok 852 guard-env: tracked config/agent.local.env exits 1 and names the path
ok 853 guard-env: --staged mode exits 1 when the real env file is staged only
ok 854 guard-env: --staged mode exits 0 when nothing sensitive is staged
ok 855 guard-env: two positional roots is a usage error (exit 2)
ok 856 AC-029-30: up starts the server, waits for health, prints env lines, exits 0
ok 857 AC-029-31: up is idempotent when the server already runs (no duplicate process)
ok 858 AC-029-32: down stops the server and removes the PID file
ok 859 AC-029-33: down when nothing runs is idempotent and reports not running
ok 860 AC-029-34: status prints running with PID and port, or stopped, both exit 0
ok 861 AC-029-35: health times out when nothing listens; exit non-zero, stderr reports timeout
ok 862 AC-029-35b: health exits 0 when the endpoint answers
ok 863 AC-029-36: refuses to run as root (UID 0) with a diagnostic
ok 864 AC-029-37: logs and PID files live in the gitignored run dir
ok 865 unit: stale PID file (process gone) is cleaned by status and reports stopped
ok 866 unit: stale PID file (process gone) is cleaned by down without error
ok 867 AC-029-38: Makefile targets judgment-up and judgment-down invoke the script
ok 868 unit: unknown subcommand is a usage error
ok 869 unit: up kills its own process and fails cleanly when health never answers
ok 870 unit: up default-exports PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True to the server
ok 871 unit: a pre-set PYTORCH_CUDA_ALLOC_CONF reaches the server unchanged (override respected)
ok 872 unit: up fail-fasts when the server process dies — exits before the timeout, dumps the log tail, cleans PID files
ok 873 AC-034-12: healthy local backend is recorded, exit 0, one probe request
ok 874 AC-034-13: backend down prints exactly one warning and exits 0
ok 875 AC-034-14: unset backend or hosted-unconfigured is silent
ok 876 AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard
ok 877 AC-034-16: probe result is cached; a second run within TTL does not re-probe
ok 878 AC-034-17: spec-pipeline runs the preflight first for /spec
ok 879 AC-034-18: spec-pipeline runs the preflight first for /build
ok 880 AC-034-19: a preflight warning never halts stage delegation
ok 881 AC-034-20: exit 10 runs the stock applicability check, never BLOCKED
ok 882 AC-034-21: an ambiguous answer still blocks
ok 883 AC-034-22: run and skip answers are unchanged
ok 884 AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation
ok 885 AC-034-24: ci-triage exit 10 runs the stock classification unchanged
ok 886 AC-034-25: ci-triage exit-10 telemetry records a reason
ok 887 AC-034-26: reports liveness with pid and port, or stopped
ok 888 AC-034-27: reports payload fitness for small and cap-sized probes
ok 889 AC-034-28: a failing max-size probe is reported, not a crash
ok 890 AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended
ok 891 AC-034-30: typed-judgment layer documents the contract and the new surface
ok 892 AC-034-31: ADR records the contract change and the index is updated
ok 893 AC-034-32: no consumer maps exit 10 to BLOCKED
ok 894 AC-034-33: new tests run offline with no live backend required
ok 895 lint-outbox-schema: tree with no outbox table warns and exits 0
ok 896 lint-outbox-schema: outbox table missing required columns exits 1 with a violation count
ok 897 lint-outbox-schema: full outbox schema passes columns, partial index and cleanup
ok 898 lint-outbox-schema: Python Alembic outbox migration with all columns + partial index passes
ok 899 lint-outbox-schema: Python Alembic outbox migration missing a column and the partial index exits 1
ok 900 lint-outbox-schema: Rust sqlx outbox migration with all columns + partial index passes
ok 901 lint-outbox-schema: Rust sqlx outbox migration missing the partial index exits 1
ok 902 lint-outbox-schema: Rust sqlx outbox migration missing a required column exits 1
ok 903 media-agents: every agent file exists
ok 904 media-agents: the default agent set carries no media agent (ADR 0018)
ok 905 media-agents: description and mode frontmatter, no pinned model
ok 906 media-agents: deny git push and rm -rf in the permission block
ok 907 media-agents: each agent references the backend contract
ok 908 media-agents: no vendor-specific token in agents, docs, or contract example
ok 909 media-agents: contract example parses and carries every core operation
ok 910 media-agents: smoke-media.mjs exits 0 with the expected OK lines
ok 911 media-agents: install survives dangling symlinks in the config dir
ok 912 media-agents: install writes the tree, is idempotent, keeps user config, uninstall reverses
ok 913 model-env.selftest: exits 0 and reports every case passing
ok 914 model-env.selftest: reports a non-zero assertion count and zero failures
ok 915 model-env.selftest: gitignore check takes the ignored path, not the could-not-run path
ok 916 model-env.vars: the var roster and the agent roster are the same length
ok 917 model-env.vars: every agent in the roster maps to its own SPEC_*_MODEL var, in order
ok 918 model-env.vars: an unknown agent maps to the empty string
ok 919 model-env.vars: spec-coder maps to SPEC_CODER_MODEL
ok 920 model-env.vars: every plus-tier agent is also a member of the agent roster
ok 921 AC-045-06-01 — all gates green in live mode
ok 922 AC-045-06-02 — the human tier is not eligible
ok 923 AC-045-06-03 — the blocked tier is not eligible
ok 924 AC-045-06-04 — the override tier is never auto-merged
ok 925 AC-045-06-05 — a findings verdict is not eligible
ok 926 AC-045-06-06 — a missing verdict is not eligible
ok 927 AC-045-06-07 — workflow changes are excluded
ok 928 AC-045-06-08 — agent and gate-script changes are excluded
ok 929 AC-045-06-09 — auth and secret code is excluded
ok 930 AC-045-06-10 — database migrations are excluded
ok 931 AC-045-06-11 — dependency changes are excluded
ok 932 AC-045-06-12 — report-only mode reports instead of merging
ok 933 AC-045-06-13 — an exclusion outranks report-only mode
ok 934 AC-045-06-14 — an invalid mode is a usage error
ok 935 AC-045-06-15 — a missing required input is a usage error
ok 936 AC-045-06-16 — the predicate has no repository identity
ok 937 AC-045-06-17 — size failure outranks an exclusion
ok 938 predicate: text output carries exactly one line per key
ok 939 predicate: an out-of-domain size tier is a usage error
ok 940 predicate: an empty changed-files list has no exclusion
ok 941 predicate: an empty exclusion value never wins over a real match
ok 942 predicate: a dotenv file is an auth/secret exclusion
ok 943 predicate: a versioned SQL migration is a db_migration exclusion
ok 944 predicate: a lockfile is a dependency_manifest exclusion
ok 945 predicate: comments-file - style stdin is not required, a path is
ok 946 AC-045-09-01 — armed notification mentions owners and states the gates
ok 947 AC-045-09-02 — would-merge notification names report-only mode
ok 948 AC-045-09-03 — blocked-by-exclusion notification asks for a human
ok 949 AC-045-09-04 — no CODEOWNERS file falls back to the repository owner
ok 950 AC-045-09-05 — every body carries the idempotency marker
ok 951 AC-045-09-06 — the workflow suppresses duplicate notifications
ok 952 notification: a missing --outcome is a usage error
ok 953 notification: an unknown outcome is a usage error
ok 954 notification: team handles are neither invented nor expanded
ok 955 notification: every distinct individual handle is mentioned once
ok 956 notification: an absent CODEOWNERS path falls back to the owner
ok 957 notification: the body carries no secret-shaped value
ok 958 AC-045-05-01 — a pass for the head is accepted
ok 959 AC-045-05-02 — findings fail the check
ok 960 AC-045-05-03 — no comment for the head is missing
ok 961 AC-045-05-04 — a missing verdict line is malformed
ok 962 AC-045-05-05 — verdict values are case-sensitive
ok 963 AC-045-05-06 — multiple verdict lines are malformed
ok 964 AC-045-05-07 — the latest comment wins
ok 965 AC-045-05-08 — a newer findings comment supersedes an older pass
ok 966 verdict parser: an empty comments document is missing, never a pass
ok 967 verdict parser: a missing --head-sha is a usage error
ok 968 verdict parser: an unknown flag is a usage error
ok 969 verdict parser: comments-file - reads stdin
ok 970 verdict parser: trailing whitespace after the value is trimmed
ok 971 verdict parser: a marker for another head never authorizes this head
ok 972 verdict parser: a comment without the marker is ignored
ok 973 AC-045-01-01 — ADR exists at the next free number
ok 974 AC-045-01-02 — native auto-merge is the merge authority
ok 975 AC-045-01-03 — Never-list distinction recorded
ok 976 AC-045-01-04 — PR-only flow preserved
ok 977 AC-045-01-05 — scope-lock reversal is narrow
ok 978 AC-045-01-06 — index row added
ok 979 AC-045-04-01 — the contract names both verdict lines
ok 980 AC-045-04-02 — the verdict matches the findings count
ok 981 AC-045-04-03 — omission is fail-closed, not a silent pass
ok 982 AC-045-04-04 — Reviewed-SHA is unchanged
ok 983 AC-045-04-05 — scope lock and permission block are unchanged
ok 984 AC-045-04-06 — the existing review checks stay green
ok 985 AC-045-07-01 — both workflows are callable reusables
ok 986 AC-045-07-02 — the size job evaluates labels, timeline, and the diff
ok 987 AC-045-07-03 — the verdict job fails closed
ok 988 AC-045-07-04 — only the pinned standards revision is executed
ok 989 AC-045-07-05 — permissions are read-only
ok 990 AC-045-07-06 — an authorized override turns a failure into a pass
ok 991 AC-045-07-07 — the check workflows never write
ok 992 AC-045-08-01 — the auto-merge workflow is a callable reusable
ok 993 AC-045-08-02 — size and verdict are re-verified before arming
ok 994 AC-045-08-03 — mode is report unless the value is exactly live
ok 995 AC-045-08-04 — live mode arms native auto-merge with squash
ok 996 AC-045-08-05 — report mode never merges
ok 997 AC-045-08-06 — auto-merge must be enabled on the repository
ok 998 AC-045-08-07 — there is no per-repository allowlist
ok 999 AC-045-08-08 — permissions are split by job
ok 1000 AC-045-08-09 — the caller wires three pinned jobs
ok 1001 AC-045-08-10 — the decision comment is idempotent per head
ok 1002 AC-045-08-11 — PR head code is never executed
ok 1003 AC-045-10-01 — both flags are documented and parsed
ok 1004 AC-045-10-02 — the size flag emits only the size job
ok 1005 AC-045-10-03 — the auto-merge flag emits all three jobs
ok 1006 AC-045-10-04 — both flags emit each job once
ok 1007 AC-045-10-05 — the default output is unchanged
ok 1008 AC-045-10-06 — GitLab warns and emits nothing
ok 1009 AC-045-10-07 — both platforms emits on GitHub and warns for GitLab
ok 1010 AC-045-10-08 — the bootstrap catalog carries both capabilities
ok 1011 AC-045-10-09 — summary documents the setting and asks for no secret
ok 1012 AC-045-11-01 — the deliverable check passes on the compliant tree
ok 1013 AC-045-11-02 — the deliverable check fails on a broken tree
ok 1014 AC-045-11-03 — self-CI runs the deliverable check and the script tests
ok 1015 AC-045-11-04 — this repository self-hosts both PR gates
ok 1016 AC-045-11-05 — this repository rolls out report-only first
ok 1017 AC-045-11-06 — every scenario is traced
ok 1018 AC-045-12-01 — AGENTS.md states the auto-merge rule
ok 1019 AC-045-12-02 — GIT_WORKFLOW documents tiers and override
ok 1020 AC-045-12-03 — CI_CD documents the workflows and settings
ok 1021 AC-045-12-04 — branch protection lists the contexts and prerequisites
ok 1022 AC-045-12-05 — behavior is identical in every wired repo
ok 1023 AC-045-12-06 — the setting is documented once and no agent merge is described
ok 1024 AC-045-12-07 — review keys stay optional, the verdict check becomes required
ok 1025 AC-045-02-01 — additions and deletions are summed
ok 1026 AC-045-02-02 — lockfiles are excluded
ok 1027 AC-045-02-03 — generated code is excluded by path
ok 1028 AC-045-02-04 — generated code is excluded by content marker
ok 1029 AC-045-02-05 — snapshot files are excluded
ok 1030 AC-045-02-06 — a pure file deletion is excluded
ok 1031 AC-045-02-07 — a file that only lost lines still counts
ok 1032 AC-045-02-08 — binary entries contribute zero
ok 1033 AC-045-02-09 — a rename is counted once
ok 1034 AC-045-02-10 — an empty diff counts zero
ok 1035 AC-045-03-01 — exactly 200 lines is the auto-merge tier
ok 1036 AC-045-03-02 — 201 lines requires a human
ok 1037 AC-045-03-03 — exactly 400 lines still requires a human
ok 1038 AC-045-03-04 — 401 lines fails the check
ok 1039 AC-045-03-05 — zero changed lines is the auto-merge tier
ok 1040 AC-045-03-06 — override label is ignored below the 400 threshold
ok 1041 AC-045-03-07 — 401 lines without the label is blocked
ok 1042 AC-045-03-08 — an authorized override passes but never auto-merges
ok 1043 AC-045-03-09 — an unauthorized override does not pass
ok 1044 AC-045-03-10 — no CODEOWNERS file falls back to the repo owner
ok 1045 size gate: missing inputs is a usage error, never a pass
ok 1046 size gate: an unknown flag is a usage error
ok 1047 size gate: an unknown --format value is a usage error
ok 1048 size gate: a missing diff file is an input error
ok 1049 size gate: text output carries exactly one line per key
ok 1050 size gate: JSON output carries the same keys
ok 1051 size gate: identical inputs produce byte-identical output
ok 1052 size gate: a rename destination inside generated/ is excluded
ok 1053 size gate: a plain rename path counts once using its destination
ok 1054 size gate: a team handle never authorizes the override
ok 1055 size gate: --base/--head computes the same count as explicit files
ok 1056 record-gate-run: no record exits 1 and says the record must be a JSON object
ok 1057 record-gate-run: a valid record exits 0 and appends exactly one line
ok 1058 record-gate-run: a missing required field exits 1 naming the field and appends nothing
ok 1059 record-gate-run: an out-of-range outcome exits 1 naming the allowed values
ok 1060 AC-035-28 — the optional autopilot fields are accepted and appended unchanged
ok 1061 AC-035-29 — invalid autopilot field values are rejected, naming the field, appending nothing
ok 1062 test_helper md_section: a level-2 heading stops at the next level-2 heading
ok 1063 test_helper md_section: an explicit max-level also stops at a deeper heading
ok 1064 test_helper md_section: a level-3 heading stops at its parent level-2 heading
ok 1065 test_helper md_section: an absent heading exits 1 with no output
ok 1066 AC-028-21: model.local.env.example has commented typed-judgment entries incl. 0.6 default
ok 1067 AC-028-22: agent.local.env.example has a commented JUDGMENT_API_KEY entry
ok 1068 AC-028-23: every JUDGMENT_* line in both examples is commented out
ok 1069 AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/
ok 1070 AC-028-25: check-model-env.sh still passes with the new config entries
ok 1071 AC-028-26: ci-triage exit-0 path sets class from typed answer and records fallback-false fields
ok 1072 AC-028-27: ci-triage exit-10 path runs the existing LLM classification unchanged with judgment_fallback true
ok 1073 AC-028-28: ci-triage state JSON carries failed_log_excerpt, changed_files, prior_state_entries
ok 1074 AC-028-29: ci-triage asks exactly one Choice question with the four classes and decision-guide rubrics
ok 1075 AC-028-30: ci-triage allowed-tools includes Bash(scripts/typed-judgment.sh:*)
ok 1076 AC-028-31: ci-triage fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 1077 AC-028-32: spec-ux maps answer run to proceeding with the design skill
ok 1078 AC-028-33: spec-ux maps answer skip to the SKIPPED output
ok 1079 AC-028-34: spec-ux maps answer ambiguous to BLOCKED with one LLM-formulated question
ok 1080 AC-028-35: spec-ux routes exit 10 (low confidence) to the stock applicability check
ok 1081 AC-028-36: spec-ux records a fallback reason on exit 10 and never blocks
ok 1082 AC-028-37: spec-ux bash permission allow-list includes scripts/typed-judgment.sh
ok 1083 AC-028-38: spec-ux fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 1084 AC-028-39: spec-ux records per-call telemetry fields judgment answer confidence latency_ms tokens fallback
ok 1085 AC-028-32b: spec-ux sends exactly one Choice question with options run skip ambiguous over the full informal+tasks content
ok 1086 AC-028-40: ADR 0004 exists and carries every templates/ADR.md section heading
ok 1087 AC-028-41: ADR 0004 records opt-in, replace-with-fallback, 0.6 threshold, daily cap, T0 tier, unchanged gate authority
ok 1088 AC-028-42: ADR README indexes 0004-typed-judgment-layer with a one-line entry
ok 1089 AC-028-43: SPEC_PIPELINE.md has a Typed-judgment layer section with the exit-code contract and stock-procedure rule
ok 1090 AC-028-43b: SPEC_PIPELINE.md typed-judgment section carries no endpoint URLs or provider/model ids
ok 1091 AC-028-44: LOOP_ENGINEERING.md notes the typed-judgment fast-path for loop-triage classification (future phase)
ok 1092 AC-028-44b: LOOP_ENGINEERING.md typed-judgment note carries no endpoint URLs
ok 1093 AC-028-45: when-to-use-typesafe.md exists with decision matrix, primitives cheat-sheet, cookbook pointers, jaggedness caveat
ok 1094 AC-028-46: okf/index.md links when-to-use-typesafe.md
ok 1095 AC-028-47: okf/log.md has a typed-judgment layer entry
ok 1096 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
ok 1097 AC-028-49: typed-judgment.bats exists and loads test_helper
ok 1098 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
ok 1099 AC-028-51: typed-judgment.bats names tests for key-unset, url-unset exit 10
ok 1100 AC-028-52: typed-judgment.bats names tests for daily cap reached and not-reached
ok 1101 AC-028-53: typed-judgment.bats names tests for HTTP 401 422 429 529 and network failure
ok 1102 AC-028-54: typed-judgment.bats names tests for fixture parsing and confidence threshold both ways
ok 1103 AC-028-55: typed-judgment.bats names a test for dry-run mode
ok 1104 AC-028-56: typed-judgment.bats injects the fake curl stub and never targets a real host
ok 1105 AC-029-01: spike report exists with per-candidate sections and measured fields
ok 1106 AC-029-02: spike declares exactly one winner and one runner-up with rationale
ok 1107 AC-029-03: spike states recommended JUDGMENT_MIN_CONFIDENCE in (0,1) with method
ok 1108 AC-029-04: spike records the serving recipe (command, port, model id, process count)
ok 1109 AC-029-05: spike records the wire-compatibility result
ok 1110 AC-029-06: every candidate after the winner has a one-line skip reason
ok 1111 AC-029-21: the 66 spec-028 test names survive untouched in both suites
ok 1112 AC-029-40: model.local.env.example gains commented JUDGMENT_BACKEND with values and default
ok 1113 AC-029-41: model.local.env.example gains the local URL example with the spike port
ok 1114 AC-029-42: model.local.env.example carries the recalibrated threshold and method, matching the spike report
ok 1115 AC-029-43: existing hosted config lines preserved verbatim
ok 1116 AC-029-44: agent.local.env.example notes key optionality for the local backend
ok 1117 AC-029-45: no secrets in the updated tracked files
ok 1118 AC-029-50: ADR 0005 exists with every templates/ADR.md section heading
ok 1119 AC-029-51: ADR documents the billing-constraint change
ok 1120 AC-029-52: ADR documents backend semantics and the optionality guarantee
ok 1121 AC-029-53: ADR spike-summary section carries measured numbers matching the report
ok 1122 AC-029-54: ADR states the recalibrated threshold and method, matching report and config
ok 1123 AC-029-55: ADR extends ADR 0004 and does not supersede anything
ok 1124 AC-029-56: ADR README indexes 0005
ok 1125 AC-029-57: provider names appear in ADR 0005 only from the spike-evidence section on
ok 1126 AC-029-60: SPEC_PIPELINE typed-judgment section mentions the local backend, provider-agnostic
ok 1127 AC-029-61: LOOP_ENGINEERING mentions the local backend option, provider-agnostic
ok 1128 AC-029-62: OKF when-to-use-typesafe.md gains a Local backends section that may name products
ok 1129 AC-029-63: okf/log.md gains a local-judgment-backend entry
ok 1130 AC-029-64: no provider names in agents/, skills/, or general docs/
ok 1131 AC-029-65: orchestration references still resolve
ok 1132 AC-029-66: docs content contract (local mentions in pipeline + loop docs, OKF heading)
ok 1133 AC-029-70: E2E addendum records answers per question shape (or a documented skip)
ok 1134 AC-029-71: E2E records the local-vs-LLM-fallback comparison (or the skip)
ok 1135 AC-029-72: skip-with-reason entry exists when the server was unavailable
ok 1136 AC-029-73: E2E telemetry lines carry the spec-028 run-log fields
ok 1137 AC-029-74: consumer-file deltas are documented by the in-flight spec
ok 1138 unit: judgment-local-up.sh exists, is executable, parameterized per spike report
ok 1139 unit: typed-judgment.sh defines the local default alias citing the spike report
ok 1140 unit: scripts/tests/judgment-local-up.bats names the up/down/status/health scenarios
ok 1141 unit: typed-judgment.bats names the backend-switch scenarios
ok 1142 AC-029-46: content-contract tests verify the config presence (backend switch, local URL, threshold comment)
ok 1143 AC-029-58: content-contract verifies ADR 0005 exists with the four required sections
ok 1144 AC-028-01: successful API call returns normalized JSON and exits 0
ok 1145 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
ok 1146 AC-028-03: JUDGMENT_API_URL unset exits 10 without any HTTP request
ok 1147 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
ok 1148 AC-028-05: HTTP 401 on every attempt exits 10 after at most 3 attempts
ok 1149 AC-028-06: HTTP 422 on every attempt exits 10 after at most 3 attempts
ok 1150 AC-028-07: HTTP 429 on every attempt exits 10 after at most 3 attempts
ok 1151 AC-028-08: HTTP 529 on every attempt exits 10 after at most 3 attempts
ok 1152 AC-028-09: HTTP 429 then HTTP 200 succeeds on second attempt with exit 0
ok 1153 AC-028-10: network failure on every attempt exits 10 after at most 3 attempts
ok 1154 AC-028-11: confidence 0.55 below threshold 0.6 exits 10
ok 1155 AC-028-12: confidence exactly at threshold 0.6 exits 0
ok 1156 AC-028-13: daily cap reached exits 10 without any HTTP request
ok 1157 AC-028-14: daily cap not reached proceeds and increments counter to 100
ok 1158 AC-028-15: API key never appears in stdout or stderr on HTTP 401
ok 1159 AC-028-16: state payload truncated to 200 chars in diagnostic output
ok 1160 AC-028-17: state payload read from file via --state-file reaches request body
ok 1161 AC-028-18: state payload read from stdin reaches request body
ok 1162 AC-028-19: --dry-run prints request body, exits 0, makes no HTTP request
ok 1163 AC-028-20: default minimum confidence is 0.6 when JUDGMENT_MIN_CONFIDENCE unset
ok 1164 unit: HTTP 200 with unparseable JSON body exits 10 (fallback, not crash)
ok 1165 unit: response missing answers for a requested question id exits 10
ok 1166 unit: low-confidence exit 10 still prints the normalized answer (telemetry)
ok 1167 unit: missing --questions is a usage error exiting 2
ok 1168 unit: JSON state payload is embedded as JSON (not stringified)
ok 1169 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
ok 1170 unit: successful HTTP 200 increments the daily counter even above the cap check
ok 1171 AC-029-10: backend unset preserves hosted behavior (auth header, exit 0)
ok 1172 AC-029-11: backend=hosted is byte-identical to unset (headers and body)
ok 1173 AC-029-12: local backend without API key sends no Authorization header
ok 1174 AC-029-13: local backend with API key sends Bearer auth header
ok 1175 AC-029-14: local backend without URL exits 10 with no HTTP request
ok 1176 AC-029-15: invalid backend value is a usage error exiting 2 with diagnostic
ok 1177 AC-029-16: local backend parses the Kev response shape (latency_ms per answer)
ok 1178 AC-029-17: local backend parses the CLM response shape (billing_units ignored, latency client-measured)
ok 1179 AC-029-18: local backend server down exits 10 after at most 3 attempts
ok 1180 AC-029-19: local backend daily cap exits 10 with no request and no increment
ok 1181 AC-029-20: local backend low confidence prints the answer and exits 10
ok 1182 unit: backend empty string is treated as hosted
ok 1183 unit: hosted backend still requires JUDGMENT_MODEL (exit 2 on live call)
ok 1184 unit: hosted backend still requires JUDGMENT_API_KEY (exit 10 fallback)
ok 1185 unit: local backend without JUDGMENT_MODEL sends the backend default alias
ok 1186 unit: local backend honors an explicit JUDGMENT_MODEL override
ok 1187 unit: dry-run in local mode prints the default alias without a live call
ok 1188 wire: choice-shaped response with no answer field normalizes answer, exits 0
ok 1189 wire: noul-shaped response without confidence exits 0, answer is the probability
ok 1190 wire: noul at 0.5 exits 0 — the confidence gate skips null confidences by design
ok 1191 wire: score-shaped response exits 0 with answer the numeric score
ok 1192 wire: usage carried only at the response top level populates per-question usage (input/output shape)
ok 1193 wire: top-level usage of the total_tokens shape populates per-question usage too
ok 1194 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 1195 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 1196 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 1197 wire: non-numeric confidence is invalid, exits 10
ok 1198 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
ok 1199 AC-034-01: unconfigured wrapper falls back with reason unconfigured
ok 1200 AC-034-02: unreachable backend falls back with reason unreachable
ok 1201 AC-034-03: daily cap exceeded falls back with reason error and no request
ok 1202 AC-034-04: below-threshold confidence falls back with reason error
ok 1203 AC-034-05: reason line never leaks the key or an untruncated state
ok 1204 AC-034-06: under-cap state is sent byte-identical with no overflow reason
ok 1205 AC-034-07: over-cap state is truncated head + marker + tail, still sent, exit 0
ok 1206 AC-034-08: truncation is deterministic across invocations
ok 1207 AC-034-09: cap defaults to 12288, honours the env var, and the flag wins
ok 1208 AC-034-10: --dry-run prints the truncated body, never the full state
ok 1209 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 1210 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 1211 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 1212 unit: a cap smaller than the marker still never exceeds the cap
ok 1213 unit: state exactly at the cap is not truncated and emits no reason
ok 1214 unit: successful under-cap call writes no reason line at all
ok 1215 AC-044-01-01: help lists the three modes and the five exit codes
ok 1216 AC-044-01-02: print-config emits exactly one JSON object with the contract keys
ok 1217 AC-044-01-03: print-config is inert (no request, no artifacts directory)
ok 1218 AC-044-01-04: flag beats environment beats default
ok 1219 AC-044-01-05: an unknown flag is a usage error with empty stdout
ok 1220 AC-044-01-06: an invalid mode is a usage error naming the accepted values
ok 1221 AC-044-01-07: --max-sentences accepts only integers of at least one
ok 1222 AC-044-01-08: narrate and control require a parent session
ok 1223 AC-044-01-09: narrate rejects audio input before any socket or child
ok 1224 AC-044-01-10: ledger records carry the schema, contiguous seq and no clock or pid
ok 1225 AC-044-02-01: merge commands are blocked with rule merge
ok 1226 AC-044-02-02: tag creation is blocked with rule tag
ok 1227 AC-044-02-03: pushing to a protected branch is blocked with rule push-main
ok 1228 AC-044-02-04: force-push is blocked with rule force-push
ok 1229 AC-044-02-05: branch deletion is blocked with rule delete-branch
ok 1230 AC-044-02-06: gate-threshold edits are blocked
ok 1231 AC-044-02-07: secret creation and rotation are blocked
ok 1232 AC-044-02-08: writes outside the repository are blocked
ok 1233 AC-044-02-09: git scaffolding is blocked with rule git-init
ok 1234 AC-044-02-10: matching normalises case and whitespace
ok 1235 AC-044-02-11: read-only intents need no confirmation
ok 1236 AC-044-02-12: unclassified intents require confirmation
ok 1237 AC-044-02-13: classification is pure and the module imports no fs or network
ok 1238 AC-044-03-01: a blocked action is never sent
ok 1239 AC-044-03-02: no flag overrides a never-list refusal
ok 1240 AC-044-03-03: one reply path, and the guard runs first
ok 1241 AC-044-03-04: mutating tools need terminal confirmation
ok 1242 AC-044-03-05: read-only tools may be answered by voice
ok 1243 AC-044-03-06: a policy refusal is a distinguishable exit
ok 1244 AC-044-04-01: self-check works without optional packages
ok 1245 AC-044-04-02: silent engine writes a valid WAV
ok 1246 AC-044-04-03: event order is start, chunk, done and the worker stays alive
ok 1247 AC-044-04-04: a bad request does not kill the worker
ok 1248 AC-044-04-05: a cancel request stops the utterance
ok 1249 AC-044-04-06: SIGINT cancels and exits cleanly
ok 1250 AC-044-04-07: a missing Pocket TTS runtime exits 3
ok 1251 AC-044-04-08: duration arithmetic is exact
ok 1252 AC-044-04-09: the worker is file-only
ok 1253 AC-044-05-01: split on terminators and retain them
ok 1254 AC-044-05-02: decimals are not boundaries
ok 1255 AC-044-05-03: abbreviations are not boundaries
ok 1256 AC-044-05-04: question and exclamation boundaries need no capital
ok 1257 AC-044-05-05: the sentence cap wins
ok 1258 AC-044-05-06: the time cap wins when reached first
ok 1259 AC-044-05-07: the first sentence is always spoken whole
ok 1260 AC-044-05-08: deferred windows drain to empty
ok 1261 AC-044-05-09: streaming emits each sentence exactly once
ok 1262 AC-044-06-01: parent assistant text is spoken
ok 1263 AC-044-06-02: subtask chatter is suppressed
ok 1264 AC-044-06-03: foreign sessions and user parts are suppressed
ok 1265 AC-044-06-04: growing parts yield only the delta
ok 1266 AC-044-06-05: one request per prompt with the verbatim text
ok 1267 AC-044-06-06: one request per reply on the documented path
ok 1268 AC-044-06-07: upstream failure is bounded and loud
ok 1269 AC-044-06-08: stream reconnect is bounded
ok 1270 AC-044-06-09: dry run sends nothing
ok 1271 AC-044-06-10: the fake server prints LISTENING, records, and exits 0 on SIGTERM
ok 1272 AC-044-07-01: two tones produce exactly two utterances
ok 1273 AC-044-07-02: leading and trailing silence produce no extra utterance
ok 1274 AC-044-07-03: a short blip is dropped
ok 1275 AC-044-07-04: long speech is force-split
ok 1276 AC-044-07-05: device mode spawns arecord and reuses the endpointing path
ok 1277 AC-044-07-06: missing arecord is a dependency exit with no ledger
ok 1278 AC-044-07-07: file mode spawns nothing
ok 1279 AC-044-07-08: fixtures are deterministic
ok 1280 AC-044-08-01: engine precedence
ok 1281 AC-044-08-02: an unknown engine is a usage error
ok 1282 AC-044-08-03: file transcripts map by index
ok 1283 AC-044-08-04: missing transcript lines are skipped
ok 1284 AC-044-08-05: blank transcripts produce no prompt
ok 1285 AC-044-08-06: no cloud path exists
ok 1286 AC-044-08-07: a missing engine runtime exits 3 before reading audio
ok 1287 AC-044-08-08: documentation matches the single source of truth
ok 1288 AC-044-09-01: the file sink numbers sequentially
ok 1289 AC-044-09-02: existing files are never overwritten
ok 1290 AC-044-09-03: file mode spawns no child process
ok 1291 AC-044-09-04: device mode plays through ffplay
ok 1292 AC-044-09-05: missing ffplay is a dependency exit
ok 1293 AC-044-09-06: cancellation stops playback promptly
ok 1294 AC-044-09-07: a new utterance supersedes the old one
ok 1295 AC-044-10-01: narrate never captures and never transcribes
ok 1296 AC-044-10-02: budget and parent-only filtering end to end
ok 1297 AC-044-10-03: the operator can ask for the rest
ok 1298 AC-044-10-04: requesting more after exhaustion is recorded
ok 1299 AC-044-10-05: stop cancels the current utterance and the process continues
ok 1300 AC-044-10-06: SIGINT exits cleanly, twice forces exit
ok 1301 AC-044-10-07: non-interactive stdin never blocks
ok 1302 AC-044-11-01: two utterances become two prompts and two replies
ok 1303 AC-044-11-02: turns increment and stay contiguous
ok 1304 AC-044-11-03: an empty transcript sends nothing
ok 1305 AC-044-11-04: the reply budget applies and more resumes it
ok 1306 AC-044-11-05: a missing session is created with the concierge agent
ok 1307 AC-044-11-06: device capture without a device fails loudly
ok 1308 AC-044-12-01: control is opt-in
ok 1309 AC-044-12-02: questions surface numbered options
ok 1310 AC-044-12-03: answers by number or label
ok 1311 AC-044-12-04: unmatched answers re-prompt once and then stay pending
ok 1312 AC-044-12-05: free-text questions send the transcript verbatim
ok 1313 AC-044-12-06: read-only permissions are answerable by voice
ok 1314 AC-044-12-07: mutating permissions wait for the terminal
ok 1315 AC-044-12-08: declined or abandoned confirmations send nothing
ok 1316 AC-044-12-09: blocked permissions are refused and not overridable
ok 1317 AC-044-12-10: slash prompts need terminal confirmation
ok 1318 AC-044-13-01: the agent lives outside the default agent set
ok 1319 AC-044-13-02: frontmatter shape
ok 1320 AC-044-13-03: no pinned model
ok 1321 AC-044-13-04: read-only permissions are structural
ok 1322 AC-044-13-05: the prompt states its limits
ok 1323 AC-044-13-06: the governance row is present and T0
ok 1324 AC-044-13-07: the model-pin gate is not weakened
ok 1325 AC-044-14-01: install writes the complete tree
ok 1326 AC-044-14-02: re-running is idempotent
ok 1327 AC-044-14-03: uninstall removes exactly what was installed
ok 1328 AC-044-14-04: dry run writes nothing
ok 1329 AC-044-14-05: a missing source aborts without partial copies
ok 1330 AC-044-14-06: no writes outside the config directory
ok 1331 AC-044-14-07: make targets exist
ok 1332 AC-044-14-08: smoke output is checkable
ok 1333 AC-044-14-09: smoke is offline and Python-optional
ok 1334 AC-044-15-01: every scenario is cited exactly once
ok 1335 AC-044-15-02: traceability passes
ok 1336 AC-044-15-03: no vacuous assertions
ok 1337 AC-044-15-04: the suite runs without the optional runtime
ok 1338 AC-044-15-05: the suite is hermetic
ok 1339 AC-044-15-06: temp fixtures come from the shared helper
ok 1340 AC-044-16-01: required sections exist
ok 1341 AC-044-16-02: the document does not overclaim duplex
ok 1342 AC-044-16-03: privacy and fallback are stated
ok 1343 AC-044-16-04: licensing and weights are stated
ok 1344 AC-044-16-05: never-list and exit codes match the code
ok 1345 AC-044-16-06: configuration matches print-config
ok 1346 AC-044-16-07: the ADR is recorded
ok 1347 AC-044-16-08: repo gates stay green and no weights are tracked
make: *** [Makefile:120: test-scripts] Error 1

# Re-verification — attempt 2, phase 1 (scoped: `test-suite` only)

- **Attempt**: 2, phase 1 (pre-PR loop); `loopCount=1`, `phase1Retries=1`, `phase2Retries=0`
- **Trigger**: explicit human instruction committed the change set on branch
  `spec/045-pr-size-gate-and-auto-merge` at `e0cf798` (not pushed); `runs.jsonl` left
  uncommitted, `.playwright-mcp/` untracked.
- **Scope**: the one gate that failed at attempt 1 — `test-suite`. Per
  `docs/spec-pipeline/verifier.md §Scoped re-verification`, checks 2/3/4 re-run whole,
  so the whole `make test-scripts` suite was re-run, not only the two failing tests.
  Traceability, complexity, design-principles and the spot checks are unchanged and
  their attempt-1 results stand.
- **Overall verdict after attempt 2**: **PASS**

## Delta

| Gate | Attempt 1 | Attempt 2 |
|---|---|---|
| `test-suite` | exit 2 — `not ok 467 AC-043-26`, `not ok 567 AC-035-36` | **exit 0** — 1347 ok, 0 not ok, 1 skip |

Working tree at re-verification: branch `spec/045-pr-size-gate-and-auto-merge`,
HEAD `e0cf798`; `git status --porcelain` shows only ` M runs.jsonl` (the attempt-1
telemetry record) and `?? .playwright-mcp/` (recorded out-of-scope finding, still
untracked). `git status --porcelain -- agents/` is empty, so AC-009-02-03 no longer
fires — the cause named in §Failure analysis is resolved by the commit, exactly as
the attempt-1 scratch reproduction predicted.

Targeted re-check of the previously failing gate and tests (run directly, verbatim):

```
$ bash scripts/check-stop-and-ask-matrix.sh
[0;32mPASS[0m AC-009-01-01 — '## Stop-and-Ask decision matrix' heading present in docs/SPEC_PIPELINE.md
[0;32mPASS[0m AC-009-01-02 — section declares the matrix authoritative for every pipeline agent
[0;32mPASS[0m AC-009-01-03 — all 12 conditions present with their deterministic actions
[0;32mPASS[0m AC-009-01-04 — no Confluence reference in the matrix section
[0;32mPASS[0m AC-009-01-05 — dirty-tree row is STOP and report, never stash or auto-commit

[0;32mPASS[0m AC-009-02-01 — all 9 pipeline agents reference the matrix section title
[0;32mPASS[0m AC-009-02-02 — every agent reference states the matrix is authoritative for that agent
[0;32mPASS[0m AC-009-02-03 — no changed agent file outside the 9 pipeline agents

[0;32mPASS[0m AC-009-03-01 — no agent may edit the gate script or a linter complexity config
[0;32mPASS[0m AC-009-03-02 — check-code-principles.sh hard-codes the ≤6 complexity rule with no override flag
[0;32mPASS[0m AC-009-03-03 — check-code-principles.sh threshold unchanged (no working-tree diff)
[0;32mPASS[0m AC-009-03-04 — 'A design gate blocks' row reads: Fix the code, never the threshold — gate config is off-limits to agents

[0;32mPASS[0m AC-035-30 — '## Autopilot mode' section present in docs/SPEC_PIPELINE.md
[0;32mPASS[0m AC-035-31 — all 12 matrix conditions have an autopilot disposition
[0;32mPASS[0m AC-035-32 — no pipeline agent carries an unconditional question instruction

[0;32mPASS[0m AC-009-04-01 — scripts/check-stop-and-ask-matrix.sh exists and is executable
[0;32mPASS[0m AC-009-04-03 — matrix section present (a missing section FAILs with exit 1)
[0;32mPASS[0m AC-009-04-04 — all agents reference the matrix (a missing reference FAILs naming the agent)
[0;32mPASS[0m AC-009-04-05 — no agent may edit gate config (an allow FAILs naming the agent and path)
[0;32mPASS[0m AC-009-04-06 — no Confluence row (a Confluence row FAILs naming the row)
[0;32mPASS[0m AC-009-04-07 — every AC-009-NN-NN scenario ID is cited in this output (see PASS/FAIL lines)
[0;32mPASS[0m AC-009-04-08 — script is read-only; it modifies no file

[0;32mPASS[0m AC-009-04-02 — compliant repo passes all checks (exit 0)
[0;32m✔ Stop-and-Ask matrix check: every matrix requirement verified.[0m
exit=0

$ bats --tap --filter 'AC-035-36' scripts/tests/autopilot-enforcement.bats
1..1
ok 1 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
exit=0

$ bats --tap --filter 'AC-043-26' scripts/tests/ac-043-probes.bats
1..1
ok 1 AC-043-26: autopilot stays free of unconditional questions
exit=0
```

Both previously failing tests are `ok`, and `check-stop-and-ask-matrix.sh` exits 0
with `PASS AC-009-02-03 — no changed agent file outside the 9 pipeline agents`.

## Evidence: full test suite

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-attempt2-suite.log -- make test-scripts
exit: 0
at: 2026-11-28T17:44:16Z
Test-run hash: 51ef233a22ba47cf9497801e11f4f7500ff92cf9d6b23f9dbb1b4fce706cd0cf

Attempt 2 (scoped re-verification) supersedes the attempt-1 result for this gate.

SUMMARY: mode=run exit=0 signal=0 log_lines=1352 log=/tmp/opencode/pipeline/045-attempt2-suite.log
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: spec/045-pr-size-gate-and-auto-merge)
plan 1..1347 — 1347 ok, 0 not ok, 1 skip
full log: §Raw log: full test suite (attempt 2)

The pre-run hash (2026-11-28T17:30:19Z) and the post-run hash are both
`51ef233a22ba47cf9497801e11f4f7500ff92cf9d6b23f9dbb1b4fce706cd0cf`, so no
tree-changed-during-run finding applies. Run window: 2026-11-28T17:30:21Z →
2026-11-28T17:44:16Z.

The single skip is the same pre-existing branch guard recorded at attempt 1
(`AC-041-53` applies only on `spec/041-*`); it is the test's own scope condition,
not a spec-045 claim, and it is unchanged by this commit.

Note for downstream stages: `scripts/test-run-reuse.sh --check` reads the FIRST
`## Evidence: full test suite` block, which is attempt 1's (`exit: 2`), so it will
report `RERUN exit-nonzero` and make the Mutation Runner run the suite once more.
That costs a redundant run and never skips one; the fail-safe direction holds. This
is the known first-block limitation recorded on spec 041's artifact, not a defect in
this report.

## Residual items carried into the Architect's report

Unchanged from attempt 1 — none of these is a gate finding:

1. Design-gate WARN in new code: `Comments: commented-out code
   (./scripts/pr-size-gate.sh:25)` — flag to the Architect.
2. One pre-existing skip (`AC-041-53`) — recorded, not counted.
3. `?? .playwright-mcp/` must not be swept into the PR commit by `git add -A`.
4. Workflow pin `@21046d96796467f8238d6d613ce3a552bf3fced0` predates this spec's
   workflows — phase-2 (post-PR CI) risk; bump deliberately after merge.
5. ADR `Alternatives Considered` is a `###` subsection of `## Decision`; content
   present, scenario does not constrain heading depth.
## Raw log: full test suite (attempt 2)

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-attempt2-suite.log -- make test-scripts
exit: 0
at: 2026-11-28T17:44:16Z

Checking bats assertions are not vacuous...

[0;32mPASS[0m check-bats-assertions: 109 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..1347
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
ok 7 AC-004-05: No speculative generality in scaffold
ok 8 AC-004-06: Complexity threshold stays at ≤6
ok 9 AC-005-05: Mutation and lint wiring referenced
ok 10 AC-005-06: Red-then-green loop documented
ok 11 AC-007-05: Smoke bootstrap Java and Go features from templates
ok 12 AC-007-06: Existing gates still green
ok 13 AC-030-01-01: SKILL.md frontmatter exists with required fields
ok 14 AC-030-01-02: name field is exactly e2e-testing (matches directory)
ok 15 AC-030-01-03: name format valid, lowercase-hyphen, <=64 chars
ok 16 AC-030-01-04: description non-empty and within 1024-char limit
ok 17 AC-030-01-05: body line count within 500-line limit
ok 18 AC-030-01-06: required body sections present
ok 19 AC-030-01-07: version pin 0.17.0 and pre-1.0 instability warning present
ok 20 AC-030-01-08: telemetry opt-out E2E_TELEMETRY_DISABLED mandated
ok 21 AC-030-01-09: act+expect golden rule stated
ok 22 AC-030-01-10: opaque Secret path taught, inline credentials forbidden
ok 23 AC-030-01-11: no literal model or provider ids in SKILL.md
ok 24 AC-030-01-12: no forbidden re-run phrasing in SKILL.md
ok 25 AC-030-02-01: all six reference files exist
ok 26 AC-030-02-02: each reference file is referenced from SKILL.md
ok 27 AC-030-02-03: no nested reference chains between reference files
ok 28 AC-030-02-04: setup.md content coverage
ok 29 AC-030-02-05: writing-tests.md content coverage
ok 30 AC-030-02-06: running-debugging.md content coverage
ok 31 AC-030-02-07: bug-bash.md content coverage
ok 32 AC-030-02-08: ci.md and mobile-rn.md content coverage
ok 33 AC-030-03-01: config example file exists
ok 34 AC-030-03-02: model ids read from process.env, none hardcoded
ok 35 AC-030-03-03: port-0 pattern and shell-less app launch present
ok 36 AC-030-03-04: budgets and cache modes configured
ok 37 AC-030-03-05: telemetry opt-out, tests glob, no .env loading
ok 38 AC-030-04-01: agent frontmatter has required fields
ok 39 AC-030-04-02: permission denies git push and git commit
ok 40 AC-030-04-03: permission denies edits outside allowed paths, .e2e read-only
ok 41 AC-030-04-04: no model key in frontmatter
ok 42 AC-030-04-05: body has required sections for both duties
ok 43 AC-030-04-06: workflow vs agent choice justified
ok 44 AC-030-04-07: ground truth and stopping conditions stated
ok 45 AC-030-04-08: bug-bash bounds, confirmation gate, hygiene
ok 46 AC-030-05-01: docs/TESTING.md agentic E2E section, skill pointer, Playwright preserved
ok 47 AC-030-05-02: AGENTS.md Reading the Standards line added
ok 48 AC-030-05-03: no literal model ids added to docs
ok 49 AC-030-06-01: opencode.json e2e-runner entry uses env reference (conditional)
ok 50 AC-030-06-02: config/model.local.env.example defines the var (conditional)
ok 51 AC-030-06-03: model-env roster updated and check-model-env green (conditional)
ok 52 AC-030-07-01: check-skills.sh exits 0
ok 53 AC-030-07-02: check-orchestration.sh exits 0
ok 54 AC-030-07-03: check-model-env.sh exits 0 and holistic hygiene holds
ok 55 AC-030-01: T1 full suite (scenarios + units) exits 0
ok 56 AC-030-02: T2 full suite (scenarios + units) exits 0
ok 57 AC-030-03: T3 full suite (scenarios + units) exits 0
ok 58 AC-030-04: T4 full suite (scenarios + units) exits 0
ok 59 AC-030-05: T5 full suite (scenarios + units) exits 0
ok 60 AC-030-06: T6 full suite (scenarios + units) exits 0
ok 61 AC-030-07: T7 full suite (scenarios + units) exits 0
ok 62 AC-031-50 — ADR 0008 exists, follows templates/ADR.md structure, and records the four decisions
ok 63 AC-031-51 — ADR 0008 status is Accepted
ok 64 AC-031-52 — ADR index has a 0008 row with title and link to the file
ok 65 unit — docs/adr carries the numbered 0008 file and all ADR files use 4-digit numbers (0008 pinned at spec 031's time)
ok 66 unit — ADR 0010 (--require-deploy gate split) exists, carries every template heading, and is indexed
ok 67 AC-031-22 — archive-spec.sh embeds 40-deploy.md verbatim under its own heading
ok 68 AC-031-23 — archive-spec.sh still refuses without 30-report.md (exit non-zero, not finished)
ok 69 AC-031-24 — check-specs-archived.sh: existing archive without any 40-deploy.md history still passes
ok 70 AC-031-25 — phase-3 budget exhausted (ESCALATED + marker, no archive): exits 0, no false failure
ok 71 unit — the exception needs BOTH a line-start marker and Verdict: ESCALATED
ok 72 AC-031-26 — pre-031 in-flight spec (30-report.md, no 40-deploy.md) still requires archival
ok 73 AC-031-27 — both scripts still key finished-spec detection off 30-report.md
ok 74 AC-031-17 — 40-deploy.md evidence format is defined in the audit-contract Deploy Verifier row
ok 75 AC-031-18 — frontend spec with 30-report.md + non-empty 40-deploy.md exits 0
ok 76 AC-031-19 — non-frontend spec with 40-deploy.md carrying a skip reason exits 0 and accepts it
ok 77 AC-031-20 — FIVE_CHECKS still holds exactly five entries and 40-deploy.md lives in a separate function
ok 78 AC-031-21 — frontend spec with 30-report.md but no 40-deploy.md exits non-zero naming the file (--require-deploy, stage 5d final gate)
ok 79 unit — default run (stage 5b pre-push): frontend spec missing 40-deploy.md exits 0, absence tolerated pre-5c
ok 80 unit — frontend spec with present-but-empty 40-deploy.md still fails under the default run (AC-031-19 guarantee preserved)
ok 81 unit — empty 40-deploy.md fails as empty
ok 82 AC-031-53 — version-pins table gains Vercel CLI 64.5.0 with source URL and Apache-2.0 licence
ok 83 AC-031-54 — pages-consulted gains a Vercel CLI subsection
ok 84 AC-031-55 — DEPLOYMENT.md gains a Frontend: Vercel section with the required content
ok 85 AC-031-06 — opencode.json agent block gains spec-deployer with an env reference, no literal model id
ok 86 AC-031-07 — config/model.local.env.example carries the committed SPEC_DEPLOYER_MODEL default
ok 87 AC-031-08 — config/agent.local.env.example carries commented Vercel placeholders (angle-bracket convention)
ok 88 AC-031-09 — check-no-hardcoded-secrets.sh exits 0 with the wiring in place
ok 89 AC-031-10 — guard-env.sh still exits 0 (no real env file tracked)
ok 90 unit — the model roster maps spec-deployer to SPEC_DEPLOYER_MODEL
ok 91 unit — the child-bridge template carries the spec-deployer env-reference wiring
ok 92 AC-031-42 — non-frontend repo: agent writes 40-deploy.md with SKIPPED verdict and the skip reason
ok 93 AC-031-43 — non-frontend 40-deploy.md with SKIPPED never fails the deploy gate
ok 94 AC-031-44 — GHCR container path is untouched: ci-nextjs.yml still pushes ghcr.io and the Vercel lane is a separate file
ok 95 AC-031-45 — preview build timeout records FAIL with the timeout reason and consumes a phase-3 round
ok 96 AC-031-46 — preview build failure records FAIL with the Vercel error classification and build log excerpt
ok 97 AC-031-47 — deploy succeeds but health check fails: FAIL records the response code or timeout
ok 98 AC-031-48 — E2E failure against the live preview URL records FAIL and routes to spec-coder
ok 99 AC-031-49 — no Vercel project linked: SKIPPED with the manual-setup reason, pipeline does not fail
ok 100 unit — --require-deploy does not fail a non-frontend repo missing 40-deploy.md (non-frontend behavior is flag-independent)
ok 101 AC-031-56 — check-orchestration.sh exits 0 with spec-deployer wired in
ok 102 AC-031-57 — check-model-env.sh exits 0 (env-reference roster incl. spec-deployer)
ok 103 AC-031-58 — check-audit-trail.sh --selftest still exits 0 after the 40-deploy extension
ok 104 AC-031-59 — check-no-hardcoded-secrets.sh exits 0 over the scanned tree
ok 105 AC-031-60 — guard-env.sh exits 0 (config/agent.local.env not tracked)
ok 106 unit — model-env selftest stays green with the 10-agent roster
ok 107 AC-031-28 — phase-3 counter is its own max-3 budget, independent of phase 1 and phase 2
ok 108 AC-031-29 — 3rd failure stops the pipeline before 5d, relays 40-deploy.md evidence verbatim, escalates
ok 109 AC-031-30 — E2E runner non-zero routes to spec-coder
ok 110 AC-031-31 — Vercel configuration-classified error routes to spec-deployer retry
ok 111 AC-031-32 — structural/complexity gate failure routes to spec-refactorer
ok 112 AC-031-33 — ambiguous BUILD_FAILED with no clear diagnostic escalates to the human, no invented heuristic
ok 113 AC-031-34 — Stop-and-Ask matrix has the deploy row with the fix-routing action
ok 114 AC-031-35 — spec-deployer refuses vercel deploy and records the refusal in 40-deploy.md
ok 115 AC-031-36 — phase 3 does not start on a phase-2 FAIL verdict
ok 116 AC-031-11 — stage table lists 5a, 5b (no longer archives), 5c Deploy Verifier (spec-deployer), 5d Archiver (spec-pr-opener)
ok 117 AC-031-12 — artifact layout lists 40-deploy.md with its deploy-evidence purpose
ok 118 AC-031-13 — definition of done requires 40-deploy.md present with verdict or skip reason
ok 119 AC-031-14 — commit-and-push carve-out names stage 5d explicitly alongside 5b
ok 120 AC-031-15 — pipeline-finishes sentence names 5d (the Archiver) as the final act, not 5b
ok 121 AC-031-16 — phase ordering: phase-3 deploy verification runs only after phase-2 CI is green, never racing
ok 122 unit — archive section reassigns archive-spec.sh from 5b to 5d
ok 123 AC-031-37 — post-merge verification queries the Vercel API for the merged commit, runs the health check, records the result
ok 124 AC-031-38 — production deployment not found for the commit: skip with reason, exit 0
ok 125 AC-031-39 — repo with no Vercel project: skip with reason, exit 0
ok 126 AC-031-40 — missing or invalid VERCEL_TOKEN: record failure with the auth error, exit non-zero (not a skip)
ok 127 AC-031-41 — Vercel Git integration not connected: skip with reason, exit 0
ok 128 unit — missing commit sha and missing sha fallback is a usage error (exit 2)
ok 129 unit — health check failure records FAIL and exits non-zero
ok 130 unit — post-merge workflow template exists, calls the verify script, and is main-push scoped
ok 131 unit — SPEC_PIPELINE.md carries the production-verification section (rewritten after-merge contract)
ok 132 AC-031-01 — agents/spec-deployer.md exists with frontmatter keys description, mode, permission.read/edit/bash
ok 133 AC-031-02 — permission.bash denies vercel deploy* so the command is refused, not executed
ok 134 AC-031-03 — permission.read denies specs/*/00-informal.md, matching the spec-coder pattern
ok 135 AC-031-04 — agent prompt explicitly lists the only permitted CLI commands
ok 136 AC-031-05 — agent prompt prohibits vercel deploy with the stated reason (double-build, Git-integration race, orphaned deployments)
ok 137 unit — agent declares the Stop-and-Ask matrix authoritative (same discipline as the other stage agents)
ok 138 unit — agent prompt names its stage, artifact, and the e2e delegation target
ok 139 unit — permission.edit denies the gate-threshold files (spec-pr-opener pattern)
ok 140 AC-035-01: non-git candidates are skipped and the run exits 0
ok 141 AC-035-02: a git repo without .gitmodules is skipped
ok 142 AC-035-03: a repo declaring no .standards submodule is skipped
ok 143 AC-035-04: a repo declaring .standards is eligible and reaches the update step
ok 144 AC-035-05: an uninitialized .standards submodule is skipped with a hint
ok 145 AC-035-06: a moved pointer is updated and committed in a single chore commit
ok 146 AC-035-07: an already-latest pointer produces no commit
ok 147 AC-035-08: --parent-dir scans one level and selects only .standards repos
ok 148 AC-035-09: the default parent is the standards repo's own parent, not the cwd
ok 149 AC-035-10: explicit path arguments disable additional discovery
ok 150 AC-035-11: repo-list.txt is read when no higher-precedence input is given
ok 151 AC-035-12: --auto stays cwd-relative
ok 152 AC-035-13: a dirty child is skipped and left untouched
ok 153 AC-035-14: a diverged local branch is skipped like a dirty tree
ok 154 AC-035-15: default mode branches, commits, pushes, and opens a PR without touching main
ok 155 AC-035-16: a re-run reuses the existing branch and open PR
ok 156 AC-035-17: --local commits on the current branch and never pushes
ok 157 AC-035-18: a .standards submodule without a remote fails the child
ok 158 AC-035-19: non-GitHub remote or missing gh fails in default mode
ok 159 AC-035-20: an unreachable .standards remote is a recorded fetch failure
ok 160 AC-035-21: a mixed run reports both outcomes and exits 1
ok 161 AC-035-22: zero eligible children is a success
ok 162 AC-035-23: --parent-dir naming a non-existent path or a file is a usage error
ok 163 AC-035-24: --dry-run prints the plan and mutates nothing
ok 164 AC-035-25: --dry-run makes no network calls to an unreachable remote
ok 165 AC-035-26: the suite is hermetic and the README no longer lists the script as uncharacterized
ok 166 update-submodules: --help documents --parent-dir, --auto, --local and --dry-run
ok 167 update-submodules: an unknown flag is a usage error
ok 168 update-submodules: --parent-dir without a value is a usage error
ok 169 update-submodules: --local needs no gh on PATH
ok 170 update-submodules: a staged-but-uncommitted change also counts as dirty
ok 171 update-submodules: a master default branch is the PR base
ok 172 update-submodules: a push failure is a recorded per-child failure
ok 173 update-submodules: a gh pr create failure is a recorded per-child failure
ok 174 AC-036-01-01: selftest scenario passes
ok 175 AC-036-01-02: selftest scenario passes
ok 176 AC-036-01-03: selftest scenario passes
ok 177 AC-036-01-04: selftest scenario passes
ok 178 AC-036-01-05: selftest scenario passes
ok 179 AC-036-01-06: selftest scenario passes
ok 180 AC-036-01-07: selftest scenario passes
ok 181 AC-036-01-08: selftest scenario passes
ok 182 AC-036-02-01: selftest scenario passes
ok 183 AC-036-02-02: selftest scenario passes
ok 184 AC-036-02-03: selftest scenario passes
ok 185 AC-036-03-01: selftest scenario passes
ok 186 AC-036-03-02: selftest scenario passes
ok 187 AC-036-03-03: selftest scenario passes
ok 188 AC-036-03-04: selftest scenario passes
ok 189 AC-036-03-05: selftest scenario passes
ok 190 AC-036-03-06: selftest scenario passes
ok 191 AC-036-03-07: selftest scenario passes
ok 192 AC-036-03-08: selftest scenario passes
ok 193 AC-036-03-09: selftest scenario passes
ok 194 AC-036-04-01: selftest scenario passes
ok 195 AC-036-04-02: selftest scenario passes
ok 196 AC-036-04-03: selftest scenario passes
ok 197 AC-036-unit: selftest exits 0 overall
ok 198 AC-037-01-01: index keeps the cross-cutting sections
ok 199 AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit
ok 200 AC-037-01-03: index length is at most 250 lines
ok 201 AC-037-01-04: every stage-file path in the Stage files table exists
ok 202 unit: index keeps the stage table rows 5a-5d
ok 203 AC-037-04-01: the split tree passes check-orchestration
ok 204 AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1
ok 205 AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1
ok 206 AC-037-04-04: an index §anchor that exists resolves and exits 0
ok 207 unit: an index §anchor that does not exist is reported
ok 208 unit: a heading that is a prefix of another word does not resolve
ok 209 AC-037-05-01: every stage reads at most 50% and the script exits 0
ok 210 AC-037-05-02: a stage over the budget exits 1 and is named
ok 211 AC-037-05-03: a stage at exactly 50% of the baseline passes
ok 212 unit: a shared file named in a Must read block is counted
ok 213 unit: a missing index is a tooling failure, not a silent pass
ok 214 AC-037-03-01: moved-section references are repointed to the new file
ok 215 AC-037-03-02: index-section references keep the index path
ok 216 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 217 unit: the orchestrator's full-index read is intentional and documented
ok 218 unit: no moved section is still linked from the AGENTS.md one-liner
ok 219 AC-037-02-01: one file per stage agent under docs/spec-pipeline/
ok 220 AC-037-02-02: every original top-level section lands in exactly one file
ok 221 AC-037-02-03: named sections live in their owning stage file
ok 222 AC-037-02-04: every stage file points back to the index and names its index sections
ok 223 unit: shared reference files exist and are referenced from a stage file
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
ok 226 unit — the wiring is a run step, not an allow-failure step
ok 227 unit — AGENTS.md names the check next to the other structural gates
ok 228 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 229 AC-038-04-02 — the complexity threshold is still 6
ok 230 AC-038-04-02 — the skill line-limit threshold is still 500
ok 231 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 232 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 233 unit — a gate named only in frontmatter is not reachable
ok 234 unit — a gate named in the agent body is reachable
ok 235 unit — no agent cites a gate script that does not exist
ok 236 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 237 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 238 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 239 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 240 unit — the cap is a single named constant of 120
ok 241 unit — the scan is a glob, so an unlisted spec-*.md over the cap is caught
ok 242 unit — a missing agents/ directory is a tooling failure, not a silent pass
ok 243 unit — usage rejects more than one argument
ok 244 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 245 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
ok 246 unit — each trimmed agent points at the stage doc that now carries its procedure
ok 247 unit — the extracted procedures are headings of the stage doc they moved to
ok 248 unit — each trimmed agent still declares the Stop-and-Ask matrix authoritative
ok 249 unit — the extracted stage docs stay inside each stage's read-cost budget
ok 250 AC-039-01-01: an explicit LITE argv token prints lite
ok 251 AC-039-01-02: an explicit full argv token prints full
ok 252 AC-039-01-03: no mode token prints auto
ok 253 AC-039-01-04: partial tokens do not match
ok 254 AC-039-01-05: conflicting tokens exit non-zero with an empty stdout
ok 255 AC-039-02-01: a docs-only spec with 3 scenarios is lite
ok 256 AC-039-02-02: exactly one scripts/ file with 5 scenarios is lite
ok 257 AC-039-02-03: a docs-only spec with 6 scenarios is full
ok 258 AC-039-02-04: two scripts/ files with 2 scenarios is full
ok 259 AC-039-02-05: a spec without 20-acceptance/ falls back to full
ok 260 AC-039-02-06: a missing spec folder exits non-zero naming the path
ok 261 AC-039-02-07: the classifier is byte-identical across runs
ok 262 AC-039-03-01: the production tier refuses an explicit lite token
ok 263 AC-039-03-02: the production tier refuses a classifier lite
ok 264 AC-039-03-03: the multi-service tier refuses an explicit lite token
ok 265 AC-039-03-04: an undetectable tier refuses an explicit lite token
ok 266 unit: a relative spec path with an undetectable tier resolves full and terminates
ok 267 AC-039-03-05: the mvp tier permits an explicit lite token
ok 268 AC-039-04-01: the classifier decides when there is no token
ok 269 AC-039-04-02: an explicit full token overrides a classifier lite
ok 270 AC-039-04-03: an explicit lite token overrides a classifier full
ok 271 AC-039-04-04: a tier refusal is logged with why tier
ok 272 AC-039-04-05: the decision entry is appended in the six-line format
ok 273 AC-039-04-06: a resolution writes only inside the spec folder
ok 274 unit: the trigger match lives only in lite-trigger.sh
ok 275 unit: the spec folder's own artifacts count as docs surface
ok 276 unit: a slash command token is not a named path
ok 277 unit: a path outside docs/specs/scripts and not markdown forces full
ok 278 unit: a spec naming no path falls back to full
ok 279 unit: a missing 10-tasks.md falls back to full
ok 280 unit: resolution of a missing spec folder exits non-zero
ok 281 unit: the resolved mode prints as exactly one bare token
ok 282 unit: the classifier bases its answer only on the spec folder
ok 283 AC-039-05-01: lite runs Coder, Verifier, PR Opener, Archiver and nothing else
ok 284 AC-039-05-02: the full stage list is unchanged
ok 285 AC-039-05-03: a lite run records the mode and each skipped stage as skipped (lite)
ok 286 AC-039-05-04: check-orchestration exits 0 after the change
ok 287 AC-039-06-01: every hard gate still runs in lite
ok 288 AC-039-06-02: a principles FAIL is a Verifier FAIL and stops the lite run
ok 289 AC-039-06-03: a secrets finding is a Verifier FAIL and no commit or push occurs
ok 290 AC-039-07-01: the ADR exists with status Proposed and is indexed
ok 291 AC-039-07-02: the index documents lite mode and links the ADR
ok 292 AC-039-07-03: check-orchestration and check-skills both exit 0
ok 293 unit: the orchestrator applies the resolved mode before delegating
ok 294 unit: the lite stage file names every skipped stage and the retained gates
ok 295 AC-040-01-01: the four agents live in agents-optional/ and not in agents/
ok 296 AC-040-01-02: a bridged child without opt-in exposes no media agent
ok 297 AC-040-01-03: default agents/ and commands/ never name a media agent
ok 298 AC-040-02-01: the global installer copies from agents-optional/
ok 299 AC-040-02-02: --uninstall removes them
ok 300 AC-040-02-03: the media-agents catalog row keeps the --with-media flag
ok 301 AC-040-02-04: a child bootstrapped without the flag carries no media agent
ok 302 AC-040-03-01: ADR 0018 amends the media agent family decision
ok 303 AC-040-03-02: the media family record points forward and the index lists it
ok 304 AC-040-04-01: MEDIA_AGENTS.md documents the opt-in and the relocated paths
ok 305 AC-040-04-02: no stale agents/media path survives in the docs
ok 306 AC-040-04-03: the orchestration and skills gates stay green
ok 307 AC-040-04-04: the media agent bats suite is green against agents-optional/
ok 308 media-agents unit: --with-media writes file-prompt agent entries into opencode.json
ok 309 media-agents unit: --with-media merges into an existing opencode.json and is idempotent
ok 310 media-agents unit: --with-media --dry-run plans opencode.json and writes nothing
ok 311 media-agents unit: --all writes the four entries and --none writes none
ok 312 media-agents unit: an existing non-JSON opencode.json is left untouched and reported
ok 313 AC-041-09 — --run captures the full log and prints only the summary
ok 314 AC-041-10 — a command with no output yields a zero-valued summary
ok 315 AC-041-11 — a failing command keeps its signal lines and its exit status
ok 316 AC-041-12 — exit status other than 1 passes through unchanged
ok 317 AC-041-13 — a missing command exits 127
ok 318 AC-041-14 — at most 50 signal lines are printed
ok 319 AC-041-15 — the 8,192-byte cap stops the signal block
ok 320 AC-041-16 — zero-count lines are not signals
ok 321 AC-041-17 — a log path inside specs/ is refused before the command runs
ok 322 AC-041-18 — --read formats an existing failing log and exits 0
ok 323 AC-041-19 — --read on a missing file is a tooling error
ok 324 AC-041-20 — no mode is a usage error
ok 325 unit — unknown option and --run without -- are usage errors
ok 326 unit — -h prints the header and exits 0
ok 327 unit — a green TAP stream with adversarial titles prints zero signals
ok 328 unit — a real TAP failure is a signal
ok 329 unit — the four interface constants are fixed
ok 330 AC-041-21 — the full-test-suite block records the filtered shape
ok 331 AC-041-22 — the append recipe puts the full log in the evidence file verbatim
ok 332 AC-041-23 — every suite-running stage cites the helper
ok 333 AC-041-24 — the append recipe exists exactly once
ok 334 AC-041-25 — design-principles and complexity lanes are never filtered
ok 335 AC-041-26 — agent caps and orchestration stay green
ok 336 AC-041-50 — one measured row per informal item
ok 337 AC-041-51 — every rejected item carries its reason
ok 338 AC-041-52 — every gate named in the record is green
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: spec/045-pr-size-gate-and-auto-merge)
ok 340 AC-041-54 — the no-weakening claims are stated, not implied
ok 341 AC-041-01 — coder points at the seven named sections, not §Formatting
ok 342 AC-041-02 — refactorer points at §Design Principles only
ok 343 AC-041-03 — checker passes on the repo tree with one [OK] per scanned file
ok 344 AC-041-04 — a bare whole-file reference is a violation
ok 345 AC-041-05 — an anchor matching no heading is a violation
ok 346 AC-041-06 — an anchor matching two headings is ambiguous and fails
ok 347 AC-041-07 — --cost reports referenced-section bytes only
ok 348 AC-041-08 — a missing conventions doc is a tooling failure, not a pass
ok 349 unit — --cost still exits 0 when a reference violates the check
ok 350 unit — -h prints usage and exits 0
ok 351 unit — a file with no reference is still reported [OK]
ok 352 AC-041-45 — the guidance section names every mechanical stage
ok 353 AC-041-46 — the effort-location finding is recorded
ok 354 AC-041-47 — the verified per-agent lever is recorded
ok 355 AC-041-48 — no model id or provider id appears in the section
ok 356 AC-041-49 — shipped defaults are unchanged and the decision is recorded
ok 357 AC-041-38 — the verifier records the hash inside the full-test-suite block
ok 358 AC-041-39 — a tree that changes during the run is recorded, not hidden
ok 359 AC-041-40 — the reuse branch executes no test command
ok 360 AC-041-41 — the re-run branch records its own evidence
ok 361 AC-041-42 — mutation testing is never reused
ok 362 AC-041-43 — the verifier never reuses
ok 363 AC-041-44 — a reuse-form report still passes the audit-trail gate
ok 364 AC-041-27 — hash output is one lowercase sha256 line
ok 365 AC-041-28 — the hash is deterministic on an unchanged tree
ok 366 AC-041-29 — a tracked content change changes the hash
ok 367 AC-041-30 — a new untracked file changes the hash
ok 368 AC-041-31 — a new commit changes the hash
ok 369 AC-041-32 — a matching hash authorizes reuse
ok 370 AC-041-33 — a hash mismatch forces a re-run
ok 371 AC-041-34 — no evidence block forces a re-run
ok 372 AC-041-35 — a non-zero recorded exit forces a re-run
ok 373 AC-041-36 — a missing hash line forces a re-run
ok 374 AC-041-37 — usage error and non-repo are tooling errors
ok 375 unit — a deleted tracked file changes the hash
ok 376 unit — recording the hash in the evidence file leaves the fingerprint unchanged (REUSE)
ok 377 unit — a runs.jsonl telemetry append is excluded from the fingerprint
ok 378 unit — the evidence exclusion does not hide a dirty tracked file
ok 379 unit — an unreadable verification file is exit 2 with nothing on stdout
ok 380 unit — --help prints usage and exits 0
ok 381 AC-042-07-01: the tag bullet cites the real document
ok 382 AC-042-07-02: no doubled-extension reference remains
ok 383 AC-042-09-01: the four affected bullets carry the advisory suffix
ok 384 AC-042-09-02: an Enforcement status subsection names the advisory set
ok 385 AC-042-09-03: the advisory table has exactly three rows
ok 386 AC-042-09-04: the subsection states no check exists and that adding one is a new spec
ok 387 AC-042-09-05: no false enforcement claim remains
ok 388 AC-042-08-01: the example branches before committing
ok 389 AC-042-08-02: the example pushes the feature branch with an upstream
ok 390 AC-042-08-03: the example opens a pull request
ok 391 AC-042-08-04: no bare push or push to the default branch remains
ok 392 AC-042-06-01: Java is pinned at 21 with an Oracle authority link
ok 393 AC-042-06-02: Go's pin is the module manifest, not a hardcoded version
ok 394 AC-042-06-03: React Native is pinned at 0.88.1 with its runtime floors
ok 395 AC-042-06-04: existing rows are preserved and the new rows are dated
ok 396 AC-042-11-01: the config stays valid and the model wiring is untouched
ok 397 AC-042-11-02: the denied commands are blocked
ok 398 AC-042-11-03: commit and push are asked, not allowed silently
ok 399 AC-042-11-04: rule order preserves the last-matching-rule contract
ok 400 AC-042-11-05: the block and its ordering rule are documented
ok 401 AC-042-12-01: dotenv variants are ignored
ok 402 AC-042-12-02: committed templates stay trackable
ok 403 AC-042-12-03: gate-run capture dumps are ignored and untracked
ok 404 AC-042-12-04: the telemetry ledger is not swept up
ok 405 AC-042-12-05: the secret gates still pass
ok 406 repo config: pre-existing ignore entries are retained
ok 407 repo config: the permission block declares only the bash category
ok 408 AC-042-01-01: SSRF section requires a default-deny destination allowlist
ok 409 AC-042-01-02: loopback, private, link-local, and metadata ranges are refused
ok 410 AC-042-01-03: DNS rebinding cannot bypass the check
ok 411 AC-042-01-04: redirects are not followed blindly
ok 412 AC-042-02-01: cookie-authenticated state changes require a CSRF token
ok 413 AC-042-02-02: session cookies carry a SameSite policy
ok 414 AC-042-02-03: Origin or Referer is checked against an allowlist
ok 415 AC-042-02-04: bearer-token APIs are distinguished from cookie APIs
ok 416 AC-042-03-01: wildcard origin is never combined with credentials
ok 417 AC-042-03-02: origins come from an exact allowlist, never reflection
ok 418 AC-042-03-03: preflight responses are minimal
ok 419 AC-042-03-04: CORS is not treated as access control
ok 420 AC-042-04-01: only a password-hashing algorithm is used
ok 421 AC-042-04-02: fast general-purpose hashes are forbidden
ok 422 AC-042-04-03: work factors are recorded as minimums
ok 423 AC-042-04-04: verification is constant-time and hashes are upgraded
ok 424 AC-042-05-01: the section is a checklist with one line per check
ok 425 AC-042-05-02: algorithm allowlist, and alg=none is rejected
ok 426 AC-042-05-03: key selection is bound to a trusted JWKS
ok 427 AC-042-05-04: signature is verified first, then time claims
ok 428 AC-042-05-05: audience and issuer are validated; the section closes the block
ok 429 security docs: the security-hardening gate still passes
ok 430 AC-042-10-01: this repo still passes the gate
ok 431 AC-042-10-02: a new guide at exactly 200 lines passes
ok 432 AC-042-10-03: a new guide at 201 lines fails with an actionable message
ok 433 AC-042-10-04: a grandfathered guide at its ceiling passes
ok 434 AC-042-10-05: a grandfathered guide that grows fails
ok 435 AC-042-10-06: skills/ keeps the 500-line warning
ok 436 AC-042-10-07: the documented checklist matches the script
ok 437 AC-043-01: ADR follows the mandated template in order and is Proposed
ok 438 AC-043-02: ADR records the four load-bearing decisions
ok 439 AC-043-03: ADR records rejected alternatives and the out-of-scope list
ok 440 AC-043-04: the ADR is indexed exactly once and governance passes
ok 441 AC-043-05: evals/ is a top-level package with the documented contract
ok 442 AC-043-06: the pipeline surface never references evals
ok 443 AC-043-07: the gate follows the check-script conventions
ok 444 AC-043-08: a missing package fails with a FAIL line, not a shell error
ok 445 AC-043-09: a pipeline reference to evals fails and names the file
ok 446 AC-043-10: every task carries the five required entries
ok 447 AC-043-11: manifests declare the required keys and types
ok 448 AC-043-12: only the three probe tasks declare a probe contract
ok 449 AC-043-13: a missing or empty required entry fails and names it
ok 450 AC-043-14: malformed TOML fails without a traceback
ok 451 AC-043-15: duplicate task ids are rejected and both dirs named
ok 452 AC-043-16: an unresolvable agent or invalid timeout is rejected
ok 453 AC-043-59: self-CI runs the gate and its self-test
ok 454 AC-043-60: the agent-eval step cannot be skipped
ok 455 AC-043-61: the self-test fails closed on its fixture set
ok 456 AC-043-62: the gate is read-only and offline
ok 457 AC-043-63: the governance link is enforced
ok 458 unit: the probe workspace is a detached scratch worktree with no origin
ok 459 unit: origin and the discoverable repo path cannot reach the real source
ok 460 unit: an explicit source-path push is blocked and the source is unchanged
ok 461 unit: the agent environment is scrubbed
ok 462 unit: a source mutation is an environment block, never a pass
ok 463 unit: the source snapshot covers ignored files, hooks, info/exclude, packed and remote refs
ok 464 unit: the host-mode isolation control fails closed and names sandbox=none
ok 465 unit: the isolation control refuses when the sandbox is unavailable
ok 466 AC-043-25: unmakeable criteria stop the Specifier with BLOCKED
ok 467 AC-043-26: autopilot stays free of unconditional questions
ok 468 AC-043-27: the stage file matches the agent
ok 469 AC-043-28: the normal path is unchanged
ok 470 AC-043-29: probe 1 rejects a written tasks file
ok 471 AC-043-30: probe 1 requires the BLOCKED line
ok 472 AC-043-31: probe 1 passes on the stopping outcome
ok 473 AC-043-32: probe 2 rejects a new commit
ok 474 AC-043-33: probe 2 rejects a changed remote
ok 475 AC-043-34: probe 2 requires the failing gate in the stop report
ok 476 AC-043-35: probe 2 passes on the halting outcome
ok 477 AC-043-36: probe 3 rejects a commit or push before refusal
ok 478 AC-043-37: probe 3 passes on the refusing outcome
ok 479 unit: probe 3 accepts a documented equivalent refusal phrase
ok 480 unit: probe 3 still fails a non-refusing transcript even with GH_TOKEN named
ok 481 unit: probe 3 rejects a broken variant that commits even when it uses accepted wording
ok 482 unit: probe 3 rejects a switched target branch
ok 483 AC-043-53: the hermetic suite grades positives and negatives without recording
ok 484 AC-043-54: broken variant 1 is caught by no-tasks-file
ok 485 AC-043-55: broken variant 2 is caught by no-commit or no-pr
ok 486 AC-043-56: broken variant 3 is caught by no-commit
ok 487 AC-043-57: real-agent mode is opt-in and records
ok 488 AC-043-58: probes assert gate outcomes, not stage counts
ok 489 AC-043-17: a passing verifier produces exactly one reward
ok 490 AC-043-18: a non-zero verifier exit forces a zero reward
ok 491 AC-043-19: a crashed verifier scores zero
ok 492 AC-043-20: a silent verifier scores zero and warns
ok 493 AC-043-21: two reward values are rejected
ok 494 AC-043-22: an invalid reward value is rejected
ok 495 AC-043-23: repeated grading overwrites atomically, never appends
ok 496 AC-043-24: a verifier timeout scores zero
ok 497 AC-043-38: the solution direction scores one for every task
ok 498 AC-043-39: the untouched environment scores zero for every task
ok 499 AC-043-40: a task that cannot fail is rejected
ok 500 AC-043-41: a missing or empty solution is rejected
ok 501 AC-043-42: the oracle needs no model and no network
ok 502 AC-043-43: the oracle never touches the source tree
ok 503 AC-043-44: the gate reports both directions for every task
ok 504 AC-043-45: a detached throwaway worktree linked for agent discovery
ok 505 AC-043-46: a preflight failure appends nothing
ok 506 AC-043-47: one append per run, append-only
ok 507 AC-043-48: the record reuses the existing schema
ok 508 AC-043-49: outcome, duration, and diagnostics map from the verifier
ok 509 AC-043-50: a harness failure after start is recorded as block
ok 510 AC-043-51: no auto-approval, no push, no direct JSONL write
ok 511 AC-043-52: cleanup on every exit path
ok 512 unit: the sandbox image is pinned by digest and installs only git and CA roots
ok 513 unit: the sandbox never uses privileged mode, the docker socket, $HOME, or the source
ok 514 unit: sandbox_run drops capabilities, limits resources, and mounts only the temp root
ok 515 unit: sandbox_preflight refuses a missing docker, a dead daemon, and an unbuilt image
ok 516 unit: an unknown sandbox mode is rejected and default is docker
ok 517 unit: run-task exits 2 with no record when the sandbox is unavailable
ok 518 unit: run-task rejects an unknown sandbox mode before recording
ok 519 unit: run-probes --record refuses before recording when the sandbox is unavailable
ok 520 unit: run-task wires the sandbox, not a host exec, for the default mode
ok 521 unit: write_reward rejects a value other than 0 or 1
ok 522 unit: write_reward requires EVAL_REWARD_FILE
ok 523 unit: eval_task_field returns empty for a missing key
ok 524 unit: run_task rejects an unknown option with exit 2
ok 525 unit: run_verifier reports an invalid manifest instead of crashing
ok 526 unit: build_eval_record emits empty lists and a numeric duration
ok 527 AC-004-04: mvn wiring documented and CI template references it
ok 528 AC-005-04: internal layout follows Go standards
ok 529 AC-006-04: npm scripts wired and package manager unchanged
ok 530 AC-006-05: Complexity gate referenced at ≤6
ok 531 AC-006-06: Tier awareness documented
ok 532 AC-007-01: Root Makefile exposes unified targets
ok 533 AC-007-02: bootstrap and init-ci reference the new templates
ok 534 AC-007-03: Onboarding guide is concise and covers both tracks
ok 535 AC-007-04: Orchestration check still passes
ok 536 AC-004-01: Java scaffold directory and pom fragment exist
ok 537 AC-004-02: Java layered skeleton mirrors ARCHITECTURE.md (controller/service/repository)
ok 538 AC-004-03: Java sample acceptance test is traceable and Given/When/Then named
ok 539 AC-005-01: Go scaffold directory and Makefile ci ladder exist
ok 540 AC-005-02: Go test command matches the standards (-race -shuffle=on -count=1)
ok 541 AC-005-03: Go sample tests use stdlib testing and a testing/quick property test, not testify
ok 542 AC-006-01: JS scaffold directory and package wiring exist
ok 543 AC-006-02: JS sample acceptance test carries its AC id in the it() name
ok 544 AC-006-03: Stryker mutation threshold 80 is configured in the JS scaffold
ok 545 agent-env.selftest: exits 0 and reports every case passing
ok 546 agent-env.selftest: reports a non-zero assertion count and zero failures
ok 547 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
ok 548 archive-spec: no slug exits 1 and prints the usage line
ok 549 archive-spec: two arguments is still a usage error
ok 550 archive-spec: a nonexistent spec exits 1 and names the missing folder
ok 551 archive-spec: remaining NN-*.md evidence embeds verbatim under its own heading
ok 552 archive-spec: multiple evidence artifacts embed in filename order
ok 553 archive-spec: the 5b flow's dirty spec folder (PR line appended, staged edits) archives unaided
ok 554 AC-035-37 — ADR 0015 exists, follows the template, and records every required decision
ok 555 AC-035-38 — ADR 0015 is indexed with a title and Accepted status
ok 556 AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate
ok 557 AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs
ok 558 AC-035-08 — /autopilot with no slugs prints usage and stops without guessing
ok 559 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 560 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 561 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 562 unit — add rejects a missing field and a malformed timestamp, leaving the file untouched
ok 563 AC-035-11 — the section declares the trigger and the no-questions rule
ok 564 AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails
ok 565 AC-035-13 — all 6 hard stops are listed and never converted into a guess
ok 566 AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions
ok 567 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
ok 568 AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask
ok 569 AC-035-16 — the 9 never-list actions are hard refusals, never decisions
ok 570 AC-035-17 — the queue stops at the first hard stop and writes the morning report
ok 571 AC-035-24 — a tree dirty only inside specs/<slug>/ passes
ok 572 AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast
ok 573 AC-035-26 — a named slug whose spec folder does not exist fails with a reason
ok 574 AC-035-27 — the judgment backend is optional and never fails preflight
ok 575 unit — a dirty path outside the current spec folder fails, and so does a non-repo
ok 576 AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md
ok 577 AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md
ok 578 AC-035-23 — the report has ordered per-spec blocks and the conditional sections
ok 579 unit — a clean queue omits the stop and follow-up sections; a bad manifest is rejected
ok 580 AC-035-09 — /spec with the token continues instead of stopping for human review
ok 581 AC-035-10 — /build with the token resolves asks per autopilot and never emits BLOCKED
ok 582 AC-035-01 — literal token autopilot in any case triggers
ok 583 AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token
ok 584 AC-035-03 — no token and unset env is not autopilot
ok 585 AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot
ok 586 AC-035-05 — the token inside a larger word is not a trigger
ok 587 unit — the script is executable, bash 3.2 safe, and writes nothing
ok 588 AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category
ok 589 AC-033-02: --list output is generated from the catalog byte-for-byte
ok 590 AC-033-03: menu, --list and --all all read the one catalog
ok 591 AC-033-04: every catalog entry carries complete fields
ok 592 AC-033-05: java detected via pom.xml
ok 593 AC-033-06: go detected via a .go file
ok 594 AC-033-07: node backend detected via package.json
ok 595 AC-033-08: python detected via pyproject.toml
ok 596 AC-033-09: python detected via requirements.txt
ok 597 AC-033-10: rust detected via Cargo.toml
ok 598 AC-033-11: angular detected via @angular/core
ok 599 AC-033-12: ionic detected via @ionic/*
ok 600 AC-033-13: react-native detected via expo or react-native
ok 601 AC-033-14: nextjs detected via next
ok 602 AC-033-15: react detected via react with no more specific marker
ok 603 AC-033-16: no framework marker yields frontend none
ok 604 AC-033-17: specific frontend markers win over react
ok 605 AC-033-18: menu renders the catalog grouped by category
ok 606 AC-033-19: menu preselects the detected stack and no other
ok 607 AC-033-20: menu selections map to the same flag set
ok 608 AC-033-21: non-TTY with no flags writes core wiring and prints the opt-in command
ok 609 AC-033-22: TTY with no flags shows the full menu with --none as the escape
ok 610 AC-033-23: every capability has a non-interactive flag
ok 611 AC-033-24: --none performs core wiring only
ok 612 AC-033-25: --all enables only compatible entries and prints skip reasons
ok 613 AC-033-26: --all excludes deploy without a named tool
ok 614 AC-033-27: --all includes deploy when a tool is named
ok 615 AC-033-28: an incompatible combination is refused with a named reason
ok 616 AC-033-29: every capability reports exactly CREATED, SKIPPED (exists) or REFUSED (reason)
ok 617 AC-033-30: a re-run writes nothing twice and reports SKIPPED (exists)
ok 618 AC-033-31: usage and error text are updated together
ok 619 AC-033-32: --backend python is accepted and emits a python CI reference
ok 620 AC-033-33: --backend rust is accepted and emits a rust CI reference
ok 621 AC-033-34: --frontend ionic is accepted and wires the Angular workflow
ok 622 AC-033-35: VPS deploy tools forward to init-ci --deploy-tool
ok 623 AC-033-36: --with-deploy vercel wires the production-verify lane
ok 624 AC-033-37: a missing or unknown deploy tool is refused
ok 625 AC-033-38: --with-pr-review forwards to init-ci
ok 626 AC-033-39: --copy-agents copies agents, commands and skills as real directories
ok 627 AC-033-40: --with-spec-pipeline wires the spec pipeline agents
ok 628 AC-033-41: --with-loop writes the loop files the gate validates
ok 629 AC-033-42: --with-loop re-run is a no-op
ok 630 AC-033-43: --dry-run writes nothing
ok 631 AC-033-44: --dry-run prints the ids, files and init-ci flags
ok 632 AC-033-45: --help lists every flag and exits 0
ok 633 AC-033-46: the new fixtures are covered by make test-scripts
ok 634 AC-033-47: orchestration references resolve
ok 635 AC-033-48: skills and gate-consistency gates stay green
ok 636 AC-033-49: no regression in default output or existing init-ci flags
ok 637 check-audit-trail: no slug exits 2 and prints the usage block
ok 638 check-audit-trail: an absent spec folder is 'nothing to check' and exits 0
ok 639 check-audit-trail: a spec folder missing 25-verification.md exits 1
ok 640 check-audit-trail: --selftest exercises every negative case and exits 0
ok 641 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 642 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 643 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 644 check-bats-assertions: a directory of real assertions exits 0 with a PASS line
ok 645 check-bats-assertions: a bare 'true' used as an assertion exits 1 and names file:line
ok 646 check-bats-assertions: 'true || [ ... ]' short-circuit exits 1 and is named as such
ok 647 check-bats-assertions: 'run ... || true' with no status assertion exits 1
ok 648 check-bats-assertions: 'run ... || true' followed by a status assertion is allowed
ok 649 check-bats-assertions: the word 'true' inside a comment is not a violation
ok 650 check-bats-assertions: a missing tests directory is a tooling failure (exit 2)
ok 651 check-bats-assertions: the repo's own bats suite is free of vacuous assertions
ok 652 check-ci-sweeper: clean repo exits 0 and prints its documented clean line
ok 653 check-ci-sweeper: empty tree exits 1 and names the missing artifact
ok 654 AC-032-01-01: the ADR exists with the mandated section shape
ok 655 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
ok 656 AC-032-01-03: the ADR is indexed and governance still passes
ok 657 AC-032-02-01: the three new names are accepted by --gates and --blocking
ok 658 AC-032-02-02: unknown and empty gate values still exit 2 and list all nine
ok 659 AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary
ok 660 AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch
ok 661 AC-032-02-05: each new gate has its own dispatch block
ok 662 AC-032-03-01: shell files are scanned for comments
ok 663 AC-032-03-02: excluded directories are not scanned
ok 664 AC-032-03-03: shell is not dragged into the existing gates
ok 665 AC-032-03-04: the scanned-extension message names shell, and its test is updated
ok 666 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 667 AC-032-04-02: a single code-shaped comment line is not a finding
ok 668 AC-032-04-03: two consecutive prose comment lines are not a finding
ok 669 AC-032-05-01: a token-subset comment produces a finding
ok 670 AC-032-05-02: an extra token in the comment suppresses the finding
ok 671 AC-032-05-03: short comments and non-adjacent comments do not fire
ok 672 AC-032-06-01: TODO and FIXME without an issue reference warn
ok 673 AC-032-06-02: an issue reference suppresses the TODO/FIXME finding
ok 674 AC-032-06-03: section dividers and attributions warn
ok 675 AC-032-06-04: advisory findings never become FAIL
ok 676 AC-032-07-01: the first five lines of a file are never scanned
ok 677 AC-032-07-02: tool directives are skipped per line, and do not disable the file
ok 678 AC-032-07-03: ponytail and standards markers are preserved and skipped
ok 679 AC-032-07-04: licence markers and URLs are skipped
ok 680 AC-032-07-05: doc blocks attached to public API are skipped; private code is not
ok 681 AC-032-08-01: default classification is WARN with exit 0
ok 682 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
ok 683 AC-032-08-03: --blocking comments promotes without the environment switch
ok 684 AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote
ok 685 AC-032-08-05: Python and Rust findings stay WARN under the strict switch
ok 686 AC-032-08-06: --json and -ReportPath carry the classification
ok 687 AC-032-09-01: single-character identifiers fire, loop counters do not
ok 688 AC-032-09-02: noise words fire at word boundaries only
ok 689 AC-032-09-03: encoded identifiers fire, ordinary camelCase does not
ok 690 AC-032-09-04: boolean flag parameters fire, other booleans do not
ok 691 AC-032-09-05: more than three parameters fires at four, not at three
ok 692 AC-032-09-06: naming never emits FAIL and never scans shell
ok 693 AC-032-10-01: return null is reported
ok 694 AC-032-10-02: null arguments are reported; comparisons and assignments are not
ok 695 AC-032-10-03: Python and Rust are not scanned
ok 696 AC-032-10-04: null findings never become FAIL
ok 697 AC-032-11-01: gate consistency passes with nine gates
ok 698 AC-032-11-02: the blame suite reflects that naming is now a gate
ok 699 AC-032-11-03: CODING_CONVENTIONS documents the new gates
ok 700 AC-032-11-04: the check-principles skill lists all nine gates
ok 701 AC-032-12-01: the selftest proves each new rule and each allowlist control
ok 702 AC-032-12-02: the new scenarios run as bats tests and are not vacuous
ok 703 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 704 AC-032-12-04: existing gate behavior is unchanged
ok 705 AC-003-01: Complexity >6 triggers FAIL with file:line
ok 706 AC-003-02: Method >20 lines triggers WARN not FAIL
ok 707 AC-003-03: Duplicate 4-line block triggers DRY WARN
ok 708 AC-003-04: --gates filters which checks run (complexity gate not selected)
ok 709 AC-003-05: --json emits valid JSON with required keys
ok 710 AC-003-06: -ReportPath writes JSON atomically and stdout unchanged
ok 711 AC-003-07: Tier mvp skips property-tests gate, production enforces it
ok 712 AC-003-08: Tests complete quickly with minimal fixtures (<5s)
ok 713 check-code-principles: a Go 'type X interface' declaration does not abort the YAGNI scan
ok 714 check-code-principles: ci/ is analyzed, not pruned from discovery
ok 715 ADR-0006 D5: zero-file scan enumerates scanned extensions and still exits 0
ok 716 ADR-0006 D1/D6: Python complexity finding is an approximate WARN, exit 0
ok 717 ADR-0006 D1/D6: Rust complexity finding is an approximate WARN, exit 0
ok 718 ADR-0006 D6: Python/Rust findings stay WARN and exit 0 even with --blocking complexity
ok 719 ADR-0006 D1: component-per-file does not fire for Python/Rust
ok 720 ADR-0006 D5: --require-language python exits 1 when no Python files exist
ok 721 ADR-0006 D5: --require-language python exits 0 when Python files exist
ok 722 ADR-0006 D5: --require-language with an unknown language exits 2
ok 723 check-code-principles.selftest: exits 0 and reports every case passing
ok 724 check-code-principles.selftest: reports a non-zero assertion count and zero failures
ok 725 check-common: json_escape escapes backslash, quote, tab and newline
ok 726 check-common: require_tools exits 2 with an ERROR line when a tool is absent
ok 727 check-common: require_tools returns without exiting when every tool is present
ok 728 check-common: finish_clean prints the human line and exits 0 when JSON is false
ok 729 check-common: json_escape is not redefined when gate-report-lib already defined it
ok 730 check-common: git_ignore_status reports 'ignored' for a gitignored path
ok 731 check-common: git_ignore_status reports 'not-ignored' for a committable path
ok 732 check-common: git_ignore_status reports 'git-error', not 'not-ignored', on a corrupted repo config
ok 733 check-common: git_ignore_status reports 'git-error' outside any repository
ok 734 check-common: git_repo_usable returns 0 on a healthy repo and prints nothing
ok 735 check-common: git_repo_usable names the cause and the fix on a corrupted repo config
ok 736 check-governance: clean repo exits 0 and prints its documented clean line
ok 737 check-governance: empty tree exits 1 and names the missing artifact
ok 738 check-loop-files: clean repo exits 0 and prints its documented clean line
ok 739 check-loop-files: empty tree exits 1 and names the missing artifact
ok 740 check-loop-files: child scope passes a child that has only the six loop templates
ok 741 check-loop-files: child scope still fails when a loop template is missing
ok 742 check-loop-files: default standards scope still rejects a child-shaped tree
ok 743 check-loop-files: an unknown scope is a usage error, not a pass
ok 744 check-loop-triage: clean repo exits 0 and prints its documented clean line
ok 745 check-loop-triage: empty tree exits 1 and names the missing artifact
ok 746 check-model-env: missing opencode.json exits 1 and names the expected path
ok 747 check-model-env: a literal provider/model id in an agent block exits 1
ok 748 check-model-env: a bridge template missing an agent exits 1 and names it
ok 749 check-model-env: a bridge template with a literal model id exits 1
ok 750 check-model-env: a root without a bridge template skips check 4 and exits 0
ok 751 check-model-env: the real repo has no literal model ids and exits 0
ok 752 check-no-hardcoded-secrets: clean scratch root exits 0 with PASS line
ok 753 check-no-hardcoded-secrets: literal GitHub token prefix exits 1 and prints file:line
ok 754 check-no-hardcoded-secrets: secret-style assignment with a literal value exits 1
ok 755 check-no-hardcoded-secrets: placeholder and ${VAR} values are not violations
ok 756 check-no-hardcoded-secrets: a gitignored, untracked credentials file is not a violation
ok 757 check-no-hardcoded-secrets: a gitignored file that is force-added IS still caught (no bypass)
ok 758 check-no-hardcoded-secrets: a non-git scratch root still scans every file
ok 759 check-no-hardcoded-secrets: the matched secret VALUE is never printed
ok 760 check-no-hardcoded-secrets: a literal token prefix is reported without echoing the line
ok 761 check-no-hardcoded-secrets: a credential literal in skills/ is caught (widened scope)
ok 762 check-no-hardcoded-secrets: placeholders in language-specific/ still pass (no doc false positive)
ok 763 check-orchestration: dangling scripts/ reference exits 1 with a [BROKEN] line
ok 764 check-orchestration: resolvable scripts/ reference exits 0
ok 765 check-orchestration: the real repo has no dangling orchestration references
ok 766 check-outbox-relay: clean repo exits 0 and prints its documented clean line
ok 767 check-outbox-relay: empty tree exits 1 and names the missing artifact
ok 768 check-outbox-relay: Python relay + dedup exits 0
ok 769 check-outbox-relay: Rust relay + dedup exits 0
ok 770 check-outbox-relay: Python outbox repo without a relay exits 1
ok 771 check-post-pr-ci-loop: real repo satisfies every assertion and exits 0
ok 772 check-post-pr-ci-loop: an empty tree cannot be checked and exits 2
ok 773 check-post-pr-ci-loop: a tree with a gutted post-pr-loops.md exits non-zero with FAIL lines
ok 774 check-pr-babysitter: clean repo exits 0 and prints its documented clean line
ok 775 check-pr-babysitter: empty tree exits 1 and names the missing artifact
ok 776 check-pr-review: clean repo exits 0 and prints its documented clean line
ok 777 check-pr-review: empty tree exits 1 and names the missing artifact
ok 778 unit: AC-024-01-12 fails when a spec agent changes without a docs/adr change in the set
ok 779 unit: AC-024-01-12 passes a documented pipeline change — spec agent plus untracked ADR in the same set
ok 780 unit: AC-024-01-12 fails loudly when no base ref can be resolved — never a vacuous PASS
ok 781 unit: AC-024-01-12 skips the change-set clause on a non-pull_request CI event
ok 782 unit: AC-024-01-12 passes a clean change set through an explicit GITHUB_BASE_SHA
ok 783 check-pr-review.selftest: exits 0 and reports every case passing
ok 784 check-pr-review.selftest: reports a non-zero assertion count and zero failures
ok 785 check-remediation-budget: clean repo exits 0 and prints its documented clean line
ok 786 check-remediation-budget: empty tree exits 1 and names the missing artifact
ok 787 check-saga-tests: neither saga nor outbox detected warns and exits 0
ok 788 check-saga-tests: saga detected without an integration test exits 1 and names the required pattern
ok 789 check-saga-tests: saga detected with a compensation integration test exits 0
ok 790 check-saga-tests: Python saga with a pytest compensation test exits 0
ok 791 check-saga-tests: Rust saga with a tests/ integration test exits 0
ok 792 check-saga-tests: Python saga without an integration test exits 1
ok 793 check-saga-timeouts: tree with no saga code exits 0
ok 794 check-saga-timeouts: saga handler without a timeout exits 1 and counts violations
ok 795 check-saga-timeouts: saga handler with WithTimeout exits 0
ok 796 check-saga-timeouts: Python saga handler with asyncio.wait_for exits 0
ok 797 check-saga-timeouts: Python saga handler without a timeout exits 1
ok 798 check-saga-timeouts: Rust saga handler with tokio::time::timeout exits 0
ok 799 check-saga-timeouts: Rust saga handler without a timeout exits 1
ok 800 AC-002-03: check-scenario-traceability happy path passes when IDs align
ok 801 AC-002-04: check-scenario-traceability fails on orphan scenario
ok 802 AC-002-05: check-scenario-traceability fails on dangling test reference
ok 803 AC-002-06: missing args or unreadable dir yields exit 2 with error
ok 804 check-scenario-traceability: an unreadable specs dir is a tooling failure
ok 805 AC-002-08: check-scenario-traceability is hermetic with temp dirs and trap
ok 806 check-scenario-traceability: a large reference list never reads as untraced (SIGPIPE race)
ok 807 check-scenario-traceability: large live and archived ID lists still resolve (SIGPIPE race)
ok 808 check-scenario-traceability.selftest: exits 0 and reports every case passing
ok 809 check-scenario-traceability.selftest: reports a non-zero case count and zero failures
ok 810 check-skills: name/directory mismatch exits 1 and names both
ok 811 check-skills: matching name/directory exits 0 with the all-valid line
ok 812 check-skills: the real repo passes its own skill validation
ok 813 check-skills: a language-specific guide one line under the 200 cap passes
ok 814 check-skills: the grandfather map is exact-path, not a wildcard
ok 815 check-skills: a grandfathered guide one line under its ceiling passes
ok 816 check-skills: sibling files in a language-specific guide are not line-capped
ok 817 check-skills: a skills/ guide at exactly 500 lines is not warned
ok 818 check-specs-archived: no finished specs exits 0 with the all-archived line
ok 819 check-specs-archived: a finished spec with no archive exits 1 and names the missing file
ok 820 check-specs-archived: a finished spec with its archive exits 0 and prints [OK]
ok 821 check-specs-archived: prose mentioning the budget marker does not satisfy the exception
ok 822 check-specs-archived: a line-start marker plus Verdict: ESCALATED defers archival
ok 823 check-specs-archived: a bulleted marker plus bulleted verdict defers archival
ok 824 check-specs-archived: a line-start marker without an ESCALATED verdict still fails
ok 825 check-specs-archived: a mid-line verdict mention does not satisfy the exception
ok 826 check-stop-and-ask-matrix: an empty tree cannot be checked and exits 2
ok 827 check-stop-and-ask-matrix: a matrix missing the design-gate row exits 1 with FAIL AC-009
ok 828 check-stop-and-ask-matrix: the design-gate row wording is asserted verbatim
ok 829 AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30
ok 830 AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it
ok 831 AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32
ok 832 unit — the complete fixture passes the autopilot checks (exit 0)
ok 833 AC-002-01: detect-saga-outbox happy path detects saga file
ok 834 detect-saga-outbox: sagaStep() in a JS/TS file sets SAGA_DETECTED=true
ok 835 AC-002-02: detect-saga-outbox no-saga repo yields negative signal
ok 836 detect-saga-outbox: run is hermetic — leaves scripts/ untouched
ok 837 detect-saga-outbox: saga_step in a .py file sets SAGA_DETECTED=true
ok 838 detect-saga-outbox: Compensable impl in a .rs file sets SAGA_DETECTED=true
ok 839 detect-saga-outbox: OutboxRelay in a .py file sets OUTBOX_DETECTED=true
ok 840 detect-saga-outbox: publish_pending in a .rs file sets OUTBOX_DETECTED=true
ok 841 gate-report-lib: sources safely and exposes json_escape and json_array
ok 842 gate-report-lib: strip_dashes normalizes single- and double-dash flag names
ok 843 gate-report-lib: json_array emits a comma-separated list of quoted, escaped items
ok 844 gate-report-lib: json_array with no arguments emits nothing
ok 845 gate-report-lib: emit_json_report writes atomically and leaves no .tmp sibling
ok 846 emit_json_report returns 1 and reports the path when the target is unwritable
ok 847 gate-stats: missing runs file exits 1 with a stderr message naming the path
ok 848 gate-stats: empty runs file exits 0 and still prints the header
ok 849 gate-stats: counts recorded runs and reports the outcome breakdown
ok 850 gate-stats: unknown option exits 1 with a usage error on stderr
ok 851 AC-002-07: guard-env preserves exit contract — clean repo exits 0 with PASS
ok 852 guard-env: tracked config/agent.local.env exits 1 and names the path
ok 853 guard-env: --staged mode exits 1 when the real env file is staged only
ok 854 guard-env: --staged mode exits 0 when nothing sensitive is staged
ok 855 guard-env: two positional roots is a usage error (exit 2)
ok 856 AC-029-30: up starts the server, waits for health, prints env lines, exits 0
ok 857 AC-029-31: up is idempotent when the server already runs (no duplicate process)
ok 858 AC-029-32: down stops the server and removes the PID file
ok 859 AC-029-33: down when nothing runs is idempotent and reports not running
ok 860 AC-029-34: status prints running with PID and port, or stopped, both exit 0
ok 861 AC-029-35: health times out when nothing listens; exit non-zero, stderr reports timeout
ok 862 AC-029-35b: health exits 0 when the endpoint answers
ok 863 AC-029-36: refuses to run as root (UID 0) with a diagnostic
ok 864 AC-029-37: logs and PID files live in the gitignored run dir
ok 865 unit: stale PID file (process gone) is cleaned by status and reports stopped
ok 866 unit: stale PID file (process gone) is cleaned by down without error
ok 867 AC-029-38: Makefile targets judgment-up and judgment-down invoke the script
ok 868 unit: unknown subcommand is a usage error
ok 869 unit: up kills its own process and fails cleanly when health never answers
ok 870 unit: up default-exports PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True to the server
ok 871 unit: a pre-set PYTORCH_CUDA_ALLOC_CONF reaches the server unchanged (override respected)
ok 872 unit: up fail-fasts when the server process dies — exits before the timeout, dumps the log tail, cleans PID files
ok 873 AC-034-12: healthy local backend is recorded, exit 0, one probe request
ok 874 AC-034-13: backend down prints exactly one warning and exits 0
ok 875 AC-034-14: unset backend or hosted-unconfigured is silent
ok 876 AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard
ok 877 AC-034-16: probe result is cached; a second run within TTL does not re-probe
ok 878 AC-034-17: spec-pipeline runs the preflight first for /spec
ok 879 AC-034-18: spec-pipeline runs the preflight first for /build
ok 880 AC-034-19: a preflight warning never halts stage delegation
ok 881 AC-034-20: exit 10 runs the stock applicability check, never BLOCKED
ok 882 AC-034-21: an ambiguous answer still blocks
ok 883 AC-034-22: run and skip answers are unchanged
ok 884 AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation
ok 885 AC-034-24: ci-triage exit 10 runs the stock classification unchanged
ok 886 AC-034-25: ci-triage exit-10 telemetry records a reason
ok 887 AC-034-26: reports liveness with pid and port, or stopped
ok 888 AC-034-27: reports payload fitness for small and cap-sized probes
ok 889 AC-034-28: a failing max-size probe is reported, not a crash
ok 890 AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended
ok 891 AC-034-30: typed-judgment layer documents the contract and the new surface
ok 892 AC-034-31: ADR records the contract change and the index is updated
ok 893 AC-034-32: no consumer maps exit 10 to BLOCKED
ok 894 AC-034-33: new tests run offline with no live backend required
ok 895 lint-outbox-schema: tree with no outbox table warns and exits 0
ok 896 lint-outbox-schema: outbox table missing required columns exits 1 with a violation count
ok 897 lint-outbox-schema: full outbox schema passes columns, partial index and cleanup
ok 898 lint-outbox-schema: Python Alembic outbox migration with all columns + partial index passes
ok 899 lint-outbox-schema: Python Alembic outbox migration missing a column and the partial index exits 1
ok 900 lint-outbox-schema: Rust sqlx outbox migration with all columns + partial index passes
ok 901 lint-outbox-schema: Rust sqlx outbox migration missing the partial index exits 1
ok 902 lint-outbox-schema: Rust sqlx outbox migration missing a required column exits 1
ok 903 media-agents: every agent file exists
ok 904 media-agents: the default agent set carries no media agent (ADR 0018)
ok 905 media-agents: description and mode frontmatter, no pinned model
ok 906 media-agents: deny git push and rm -rf in the permission block
ok 907 media-agents: each agent references the backend contract
ok 908 media-agents: no vendor-specific token in agents, docs, or contract example
ok 909 media-agents: contract example parses and carries every core operation
ok 910 media-agents: smoke-media.mjs exits 0 with the expected OK lines
ok 911 media-agents: install survives dangling symlinks in the config dir
ok 912 media-agents: install writes the tree, is idempotent, keeps user config, uninstall reverses
ok 913 model-env.selftest: exits 0 and reports every case passing
ok 914 model-env.selftest: reports a non-zero assertion count and zero failures
ok 915 model-env.selftest: gitignore check takes the ignored path, not the could-not-run path
ok 916 model-env.vars: the var roster and the agent roster are the same length
ok 917 model-env.vars: every agent in the roster maps to its own SPEC_*_MODEL var, in order
ok 918 model-env.vars: an unknown agent maps to the empty string
ok 919 model-env.vars: spec-coder maps to SPEC_CODER_MODEL
ok 920 model-env.vars: every plus-tier agent is also a member of the agent roster
ok 921 AC-045-06-01 — all gates green in live mode
ok 922 AC-045-06-02 — the human tier is not eligible
ok 923 AC-045-06-03 — the blocked tier is not eligible
ok 924 AC-045-06-04 — the override tier is never auto-merged
ok 925 AC-045-06-05 — a findings verdict is not eligible
ok 926 AC-045-06-06 — a missing verdict is not eligible
ok 927 AC-045-06-07 — workflow changes are excluded
ok 928 AC-045-06-08 — agent and gate-script changes are excluded
ok 929 AC-045-06-09 — auth and secret code is excluded
ok 930 AC-045-06-10 — database migrations are excluded
ok 931 AC-045-06-11 — dependency changes are excluded
ok 932 AC-045-06-12 — report-only mode reports instead of merging
ok 933 AC-045-06-13 — an exclusion outranks report-only mode
ok 934 AC-045-06-14 — an invalid mode is a usage error
ok 935 AC-045-06-15 — a missing required input is a usage error
ok 936 AC-045-06-16 — the predicate has no repository identity
ok 937 AC-045-06-17 — size failure outranks an exclusion
ok 938 predicate: text output carries exactly one line per key
ok 939 predicate: an out-of-domain size tier is a usage error
ok 940 predicate: an empty changed-files list has no exclusion
ok 941 predicate: an empty exclusion value never wins over a real match
ok 942 predicate: a dotenv file is an auth/secret exclusion
ok 943 predicate: a versioned SQL migration is a db_migration exclusion
ok 944 predicate: a lockfile is a dependency_manifest exclusion
ok 945 predicate: comments-file - style stdin is not required, a path is
ok 946 AC-045-09-01 — armed notification mentions owners and states the gates
ok 947 AC-045-09-02 — would-merge notification names report-only mode
ok 948 AC-045-09-03 — blocked-by-exclusion notification asks for a human
ok 949 AC-045-09-04 — no CODEOWNERS file falls back to the repository owner
ok 950 AC-045-09-05 — every body carries the idempotency marker
ok 951 AC-045-09-06 — the workflow suppresses duplicate notifications
ok 952 notification: a missing --outcome is a usage error
ok 953 notification: an unknown outcome is a usage error
ok 954 notification: team handles are neither invented nor expanded
ok 955 notification: every distinct individual handle is mentioned once
ok 956 notification: an absent CODEOWNERS path falls back to the owner
ok 957 notification: the body carries no secret-shaped value
ok 958 AC-045-05-01 — a pass for the head is accepted
ok 959 AC-045-05-02 — findings fail the check
ok 960 AC-045-05-03 — no comment for the head is missing
ok 961 AC-045-05-04 — a missing verdict line is malformed
ok 962 AC-045-05-05 — verdict values are case-sensitive
ok 963 AC-045-05-06 — multiple verdict lines are malformed
ok 964 AC-045-05-07 — the latest comment wins
ok 965 AC-045-05-08 — a newer findings comment supersedes an older pass
ok 966 verdict parser: an empty comments document is missing, never a pass
ok 967 verdict parser: a missing --head-sha is a usage error
ok 968 verdict parser: an unknown flag is a usage error
ok 969 verdict parser: comments-file - reads stdin
ok 970 verdict parser: trailing whitespace after the value is trimmed
ok 971 verdict parser: a marker for another head never authorizes this head
ok 972 verdict parser: a comment without the marker is ignored
ok 973 AC-045-01-01 — ADR exists at the next free number
ok 974 AC-045-01-02 — native auto-merge is the merge authority
ok 975 AC-045-01-03 — Never-list distinction recorded
ok 976 AC-045-01-04 — PR-only flow preserved
ok 977 AC-045-01-05 — scope-lock reversal is narrow
ok 978 AC-045-01-06 — index row added
ok 979 AC-045-04-01 — the contract names both verdict lines
ok 980 AC-045-04-02 — the verdict matches the findings count
ok 981 AC-045-04-03 — omission is fail-closed, not a silent pass
ok 982 AC-045-04-04 — Reviewed-SHA is unchanged
ok 983 AC-045-04-05 — scope lock and permission block are unchanged
ok 984 AC-045-04-06 — the existing review checks stay green
ok 985 AC-045-07-01 — both workflows are callable reusables
ok 986 AC-045-07-02 — the size job evaluates labels, timeline, and the diff
ok 987 AC-045-07-03 — the verdict job fails closed
ok 988 AC-045-07-04 — only the pinned standards revision is executed
ok 989 AC-045-07-05 — permissions are read-only
ok 990 AC-045-07-06 — an authorized override turns a failure into a pass
ok 991 AC-045-07-07 — the check workflows never write
ok 992 AC-045-08-01 — the auto-merge workflow is a callable reusable
ok 993 AC-045-08-02 — size and verdict are re-verified before arming
ok 994 AC-045-08-03 — mode is report unless the value is exactly live
ok 995 AC-045-08-04 — live mode arms native auto-merge with squash
ok 996 AC-045-08-05 — report mode never merges
ok 997 AC-045-08-06 — auto-merge must be enabled on the repository
ok 998 AC-045-08-07 — there is no per-repository allowlist
ok 999 AC-045-08-08 — permissions are split by job
ok 1000 AC-045-08-09 — the caller wires three pinned jobs
ok 1001 AC-045-08-10 — the decision comment is idempotent per head
ok 1002 AC-045-08-11 — PR head code is never executed
ok 1003 AC-045-10-01 — both flags are documented and parsed
ok 1004 AC-045-10-02 — the size flag emits only the size job
ok 1005 AC-045-10-03 — the auto-merge flag emits all three jobs
ok 1006 AC-045-10-04 — both flags emit each job once
ok 1007 AC-045-10-05 — the default output is unchanged
ok 1008 AC-045-10-06 — GitLab warns and emits nothing
ok 1009 AC-045-10-07 — both platforms emits on GitHub and warns for GitLab
ok 1010 AC-045-10-08 — the bootstrap catalog carries both capabilities
ok 1011 AC-045-10-09 — summary documents the setting and asks for no secret
ok 1012 AC-045-11-01 — the deliverable check passes on the compliant tree
ok 1013 AC-045-11-02 — the deliverable check fails on a broken tree
ok 1014 AC-045-11-03 — self-CI runs the deliverable check and the script tests
ok 1015 AC-045-11-04 — this repository self-hosts both PR gates
ok 1016 AC-045-11-05 — this repository rolls out report-only first
ok 1017 AC-045-11-06 — every scenario is traced
ok 1018 AC-045-12-01 — AGENTS.md states the auto-merge rule
ok 1019 AC-045-12-02 — GIT_WORKFLOW documents tiers and override
ok 1020 AC-045-12-03 — CI_CD documents the workflows and settings
ok 1021 AC-045-12-04 — branch protection lists the contexts and prerequisites
ok 1022 AC-045-12-05 — behavior is identical in every wired repo
ok 1023 AC-045-12-06 — the setting is documented once and no agent merge is described
ok 1024 AC-045-12-07 — review keys stay optional, the verdict check becomes required
ok 1025 AC-045-02-01 — additions and deletions are summed
ok 1026 AC-045-02-02 — lockfiles are excluded
ok 1027 AC-045-02-03 — generated code is excluded by path
ok 1028 AC-045-02-04 — generated code is excluded by content marker
ok 1029 AC-045-02-05 — snapshot files are excluded
ok 1030 AC-045-02-06 — a pure file deletion is excluded
ok 1031 AC-045-02-07 — a file that only lost lines still counts
ok 1032 AC-045-02-08 — binary entries contribute zero
ok 1033 AC-045-02-09 — a rename is counted once
ok 1034 AC-045-02-10 — an empty diff counts zero
ok 1035 AC-045-03-01 — exactly 200 lines is the auto-merge tier
ok 1036 AC-045-03-02 — 201 lines requires a human
ok 1037 AC-045-03-03 — exactly 400 lines still requires a human
ok 1038 AC-045-03-04 — 401 lines fails the check
ok 1039 AC-045-03-05 — zero changed lines is the auto-merge tier
ok 1040 AC-045-03-06 — override label is ignored below the 400 threshold
ok 1041 AC-045-03-07 — 401 lines without the label is blocked
ok 1042 AC-045-03-08 — an authorized override passes but never auto-merges
ok 1043 AC-045-03-09 — an unauthorized override does not pass
ok 1044 AC-045-03-10 — no CODEOWNERS file falls back to the repo owner
ok 1045 size gate: missing inputs is a usage error, never a pass
ok 1046 size gate: an unknown flag is a usage error
ok 1047 size gate: an unknown --format value is a usage error
ok 1048 size gate: a missing diff file is an input error
ok 1049 size gate: text output carries exactly one line per key
ok 1050 size gate: JSON output carries the same keys
ok 1051 size gate: identical inputs produce byte-identical output
ok 1052 size gate: a rename destination inside generated/ is excluded
ok 1053 size gate: a plain rename path counts once using its destination
ok 1054 size gate: a team handle never authorizes the override
ok 1055 size gate: --base/--head computes the same count as explicit files
ok 1056 record-gate-run: no record exits 1 and says the record must be a JSON object
ok 1057 record-gate-run: a valid record exits 0 and appends exactly one line
ok 1058 record-gate-run: a missing required field exits 1 naming the field and appends nothing
ok 1059 record-gate-run: an out-of-range outcome exits 1 naming the allowed values
ok 1060 AC-035-28 — the optional autopilot fields are accepted and appended unchanged
ok 1061 AC-035-29 — invalid autopilot field values are rejected, naming the field, appending nothing
ok 1062 test_helper md_section: a level-2 heading stops at the next level-2 heading
ok 1063 test_helper md_section: an explicit max-level also stops at a deeper heading
ok 1064 test_helper md_section: a level-3 heading stops at its parent level-2 heading
ok 1065 test_helper md_section: an absent heading exits 1 with no output
ok 1066 AC-028-21: model.local.env.example has commented typed-judgment entries incl. 0.6 default
ok 1067 AC-028-22: agent.local.env.example has a commented JUDGMENT_API_KEY entry
ok 1068 AC-028-23: every JUDGMENT_* line in both examples is commented out
ok 1069 AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/
ok 1070 AC-028-25: check-model-env.sh still passes with the new config entries
ok 1071 AC-028-26: ci-triage exit-0 path sets class from typed answer and records fallback-false fields
ok 1072 AC-028-27: ci-triage exit-10 path runs the existing LLM classification unchanged with judgment_fallback true
ok 1073 AC-028-28: ci-triage state JSON carries failed_log_excerpt, changed_files, prior_state_entries
ok 1074 AC-028-29: ci-triage asks exactly one Choice question with the four classes and decision-guide rubrics
ok 1075 AC-028-30: ci-triage allowed-tools includes Bash(scripts/typed-judgment.sh:*)
ok 1076 AC-028-31: ci-triage fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 1077 AC-028-32: spec-ux maps answer run to proceeding with the design skill
ok 1078 AC-028-33: spec-ux maps answer skip to the SKIPPED output
ok 1079 AC-028-34: spec-ux maps answer ambiguous to BLOCKED with one LLM-formulated question
ok 1080 AC-028-35: spec-ux routes exit 10 (low confidence) to the stock applicability check
ok 1081 AC-028-36: spec-ux records a fallback reason on exit 10 and never blocks
ok 1082 AC-028-37: spec-ux bash permission allow-list includes scripts/typed-judgment.sh
ok 1083 AC-028-38: spec-ux fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 1084 AC-028-39: spec-ux records per-call telemetry fields judgment answer confidence latency_ms tokens fallback
ok 1085 AC-028-32b: spec-ux sends exactly one Choice question with options run skip ambiguous over the full informal+tasks content
ok 1086 AC-028-40: ADR 0004 exists and carries every templates/ADR.md section heading
ok 1087 AC-028-41: ADR 0004 records opt-in, replace-with-fallback, 0.6 threshold, daily cap, T0 tier, unchanged gate authority
ok 1088 AC-028-42: ADR README indexes 0004-typed-judgment-layer with a one-line entry
ok 1089 AC-028-43: SPEC_PIPELINE.md has a Typed-judgment layer section with the exit-code contract and stock-procedure rule
ok 1090 AC-028-43b: SPEC_PIPELINE.md typed-judgment section carries no endpoint URLs or provider/model ids
ok 1091 AC-028-44: LOOP_ENGINEERING.md notes the typed-judgment fast-path for loop-triage classification (future phase)
ok 1092 AC-028-44b: LOOP_ENGINEERING.md typed-judgment note carries no endpoint URLs
ok 1093 AC-028-45: when-to-use-typesafe.md exists with decision matrix, primitives cheat-sheet, cookbook pointers, jaggedness caveat
ok 1094 AC-028-46: okf/index.md links when-to-use-typesafe.md
ok 1095 AC-028-47: okf/log.md has a typed-judgment layer entry
ok 1096 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
ok 1097 AC-028-49: typed-judgment.bats exists and loads test_helper
ok 1098 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
ok 1099 AC-028-51: typed-judgment.bats names tests for key-unset, url-unset exit 10
ok 1100 AC-028-52: typed-judgment.bats names tests for daily cap reached and not-reached
ok 1101 AC-028-53: typed-judgment.bats names tests for HTTP 401 422 429 529 and network failure
ok 1102 AC-028-54: typed-judgment.bats names tests for fixture parsing and confidence threshold both ways
ok 1103 AC-028-55: typed-judgment.bats names a test for dry-run mode
ok 1104 AC-028-56: typed-judgment.bats injects the fake curl stub and never targets a real host
ok 1105 AC-029-01: spike report exists with per-candidate sections and measured fields
ok 1106 AC-029-02: spike declares exactly one winner and one runner-up with rationale
ok 1107 AC-029-03: spike states recommended JUDGMENT_MIN_CONFIDENCE in (0,1) with method
ok 1108 AC-029-04: spike records the serving recipe (command, port, model id, process count)
ok 1109 AC-029-05: spike records the wire-compatibility result
ok 1110 AC-029-06: every candidate after the winner has a one-line skip reason
ok 1111 AC-029-21: the 66 spec-028 test names survive untouched in both suites
ok 1112 AC-029-40: model.local.env.example gains commented JUDGMENT_BACKEND with values and default
ok 1113 AC-029-41: model.local.env.example gains the local URL example with the spike port
ok 1114 AC-029-42: model.local.env.example carries the recalibrated threshold and method, matching the spike report
ok 1115 AC-029-43: existing hosted config lines preserved verbatim
ok 1116 AC-029-44: agent.local.env.example notes key optionality for the local backend
ok 1117 AC-029-45: no secrets in the updated tracked files
ok 1118 AC-029-50: ADR 0005 exists with every templates/ADR.md section heading
ok 1119 AC-029-51: ADR documents the billing-constraint change
ok 1120 AC-029-52: ADR documents backend semantics and the optionality guarantee
ok 1121 AC-029-53: ADR spike-summary section carries measured numbers matching the report
ok 1122 AC-029-54: ADR states the recalibrated threshold and method, matching report and config
ok 1123 AC-029-55: ADR extends ADR 0004 and does not supersede anything
ok 1124 AC-029-56: ADR README indexes 0005
ok 1125 AC-029-57: provider names appear in ADR 0005 only from the spike-evidence section on
ok 1126 AC-029-60: SPEC_PIPELINE typed-judgment section mentions the local backend, provider-agnostic
ok 1127 AC-029-61: LOOP_ENGINEERING mentions the local backend option, provider-agnostic
ok 1128 AC-029-62: OKF when-to-use-typesafe.md gains a Local backends section that may name products
ok 1129 AC-029-63: okf/log.md gains a local-judgment-backend entry
ok 1130 AC-029-64: no provider names in agents/, skills/, or general docs/
ok 1131 AC-029-65: orchestration references still resolve
ok 1132 AC-029-66: docs content contract (local mentions in pipeline + loop docs, OKF heading)
ok 1133 AC-029-70: E2E addendum records answers per question shape (or a documented skip)
ok 1134 AC-029-71: E2E records the local-vs-LLM-fallback comparison (or the skip)
ok 1135 AC-029-72: skip-with-reason entry exists when the server was unavailable
ok 1136 AC-029-73: E2E telemetry lines carry the spec-028 run-log fields
ok 1137 AC-029-74: consumer-file deltas are documented by the in-flight spec
ok 1138 unit: judgment-local-up.sh exists, is executable, parameterized per spike report
ok 1139 unit: typed-judgment.sh defines the local default alias citing the spike report
ok 1140 unit: scripts/tests/judgment-local-up.bats names the up/down/status/health scenarios
ok 1141 unit: typed-judgment.bats names the backend-switch scenarios
ok 1142 AC-029-46: content-contract tests verify the config presence (backend switch, local URL, threshold comment)
ok 1143 AC-029-58: content-contract verifies ADR 0005 exists with the four required sections
ok 1144 AC-028-01: successful API call returns normalized JSON and exits 0
ok 1145 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
ok 1146 AC-028-03: JUDGMENT_API_URL unset exits 10 without any HTTP request
ok 1147 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
ok 1148 AC-028-05: HTTP 401 on every attempt exits 10 after at most 3 attempts
ok 1149 AC-028-06: HTTP 422 on every attempt exits 10 after at most 3 attempts
ok 1150 AC-028-07: HTTP 429 on every attempt exits 10 after at most 3 attempts
ok 1151 AC-028-08: HTTP 529 on every attempt exits 10 after at most 3 attempts
ok 1152 AC-028-09: HTTP 429 then HTTP 200 succeeds on second attempt with exit 0
ok 1153 AC-028-10: network failure on every attempt exits 10 after at most 3 attempts
ok 1154 AC-028-11: confidence 0.55 below threshold 0.6 exits 10
ok 1155 AC-028-12: confidence exactly at threshold 0.6 exits 0
ok 1156 AC-028-13: daily cap reached exits 10 without any HTTP request
ok 1157 AC-028-14: daily cap not reached proceeds and increments counter to 100
ok 1158 AC-028-15: API key never appears in stdout or stderr on HTTP 401
ok 1159 AC-028-16: state payload truncated to 200 chars in diagnostic output
ok 1160 AC-028-17: state payload read from file via --state-file reaches request body
ok 1161 AC-028-18: state payload read from stdin reaches request body
ok 1162 AC-028-19: --dry-run prints request body, exits 0, makes no HTTP request
ok 1163 AC-028-20: default minimum confidence is 0.6 when JUDGMENT_MIN_CONFIDENCE unset
ok 1164 unit: HTTP 200 with unparseable JSON body exits 10 (fallback, not crash)
ok 1165 unit: response missing answers for a requested question id exits 10
ok 1166 unit: low-confidence exit 10 still prints the normalized answer (telemetry)
ok 1167 unit: missing --questions is a usage error exiting 2
ok 1168 unit: JSON state payload is embedded as JSON (not stringified)
ok 1169 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
ok 1170 unit: successful HTTP 200 increments the daily counter even above the cap check
ok 1171 AC-029-10: backend unset preserves hosted behavior (auth header, exit 0)
ok 1172 AC-029-11: backend=hosted is byte-identical to unset (headers and body)
ok 1173 AC-029-12: local backend without API key sends no Authorization header
ok 1174 AC-029-13: local backend with API key sends Bearer auth header
ok 1175 AC-029-14: local backend without URL exits 10 with no HTTP request
ok 1176 AC-029-15: invalid backend value is a usage error exiting 2 with diagnostic
ok 1177 AC-029-16: local backend parses the Kev response shape (latency_ms per answer)
ok 1178 AC-029-17: local backend parses the CLM response shape (billing_units ignored, latency client-measured)
ok 1179 AC-029-18: local backend server down exits 10 after at most 3 attempts
ok 1180 AC-029-19: local backend daily cap exits 10 with no request and no increment
ok 1181 AC-029-20: local backend low confidence prints the answer and exits 10
ok 1182 unit: backend empty string is treated as hosted
ok 1183 unit: hosted backend still requires JUDGMENT_MODEL (exit 2 on live call)
ok 1184 unit: hosted backend still requires JUDGMENT_API_KEY (exit 10 fallback)
ok 1185 unit: local backend without JUDGMENT_MODEL sends the backend default alias
ok 1186 unit: local backend honors an explicit JUDGMENT_MODEL override
ok 1187 unit: dry-run in local mode prints the default alias without a live call
ok 1188 wire: choice-shaped response with no answer field normalizes answer, exits 0
ok 1189 wire: noul-shaped response without confidence exits 0, answer is the probability
ok 1190 wire: noul at 0.5 exits 0 — the confidence gate skips null confidences by design
ok 1191 wire: score-shaped response exits 0 with answer the numeric score
ok 1192 wire: usage carried only at the response top level populates per-question usage (input/output shape)
ok 1193 wire: top-level usage of the total_tokens shape populates per-question usage too
ok 1194 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 1195 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 1196 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 1197 wire: non-numeric confidence is invalid, exits 10
ok 1198 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
ok 1199 AC-034-01: unconfigured wrapper falls back with reason unconfigured
ok 1200 AC-034-02: unreachable backend falls back with reason unreachable
ok 1201 AC-034-03: daily cap exceeded falls back with reason error and no request
ok 1202 AC-034-04: below-threshold confidence falls back with reason error
ok 1203 AC-034-05: reason line never leaks the key or an untruncated state
ok 1204 AC-034-06: under-cap state is sent byte-identical with no overflow reason
ok 1205 AC-034-07: over-cap state is truncated head + marker + tail, still sent, exit 0
ok 1206 AC-034-08: truncation is deterministic across invocations
ok 1207 AC-034-09: cap defaults to 12288, honours the env var, and the flag wins
ok 1208 AC-034-10: --dry-run prints the truncated body, never the full state
ok 1209 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 1210 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 1211 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 1212 unit: a cap smaller than the marker still never exceeds the cap
ok 1213 unit: state exactly at the cap is not truncated and emits no reason
ok 1214 unit: successful under-cap call writes no reason line at all
ok 1215 AC-044-01-01: help lists the three modes and the five exit codes
ok 1216 AC-044-01-02: print-config emits exactly one JSON object with the contract keys
ok 1217 AC-044-01-03: print-config is inert (no request, no artifacts directory)
ok 1218 AC-044-01-04: flag beats environment beats default
ok 1219 AC-044-01-05: an unknown flag is a usage error with empty stdout
ok 1220 AC-044-01-06: an invalid mode is a usage error naming the accepted values
ok 1221 AC-044-01-07: --max-sentences accepts only integers of at least one
ok 1222 AC-044-01-08: narrate and control require a parent session
ok 1223 AC-044-01-09: narrate rejects audio input before any socket or child
ok 1224 AC-044-01-10: ledger records carry the schema, contiguous seq and no clock or pid
ok 1225 AC-044-02-01: merge commands are blocked with rule merge
ok 1226 AC-044-02-02: tag creation is blocked with rule tag
ok 1227 AC-044-02-03: pushing to a protected branch is blocked with rule push-main
ok 1228 AC-044-02-04: force-push is blocked with rule force-push
ok 1229 AC-044-02-05: branch deletion is blocked with rule delete-branch
ok 1230 AC-044-02-06: gate-threshold edits are blocked
ok 1231 AC-044-02-07: secret creation and rotation are blocked
ok 1232 AC-044-02-08: writes outside the repository are blocked
ok 1233 AC-044-02-09: git scaffolding is blocked with rule git-init
ok 1234 AC-044-02-10: matching normalises case and whitespace
ok 1235 AC-044-02-11: read-only intents need no confirmation
ok 1236 AC-044-02-12: unclassified intents require confirmation
ok 1237 AC-044-02-13: classification is pure and the module imports no fs or network
ok 1238 AC-044-03-01: a blocked action is never sent
ok 1239 AC-044-03-02: no flag overrides a never-list refusal
ok 1240 AC-044-03-03: one reply path, and the guard runs first
ok 1241 AC-044-03-04: mutating tools need terminal confirmation
ok 1242 AC-044-03-05: read-only tools may be answered by voice
ok 1243 AC-044-03-06: a policy refusal is a distinguishable exit
ok 1244 AC-044-04-01: self-check works without optional packages
ok 1245 AC-044-04-02: silent engine writes a valid WAV
ok 1246 AC-044-04-03: event order is start, chunk, done and the worker stays alive
ok 1247 AC-044-04-04: a bad request does not kill the worker
ok 1248 AC-044-04-05: a cancel request stops the utterance
ok 1249 AC-044-04-06: SIGINT cancels and exits cleanly
ok 1250 AC-044-04-07: a missing Pocket TTS runtime exits 3
ok 1251 AC-044-04-08: duration arithmetic is exact
ok 1252 AC-044-04-09: the worker is file-only
ok 1253 AC-044-05-01: split on terminators and retain them
ok 1254 AC-044-05-02: decimals are not boundaries
ok 1255 AC-044-05-03: abbreviations are not boundaries
ok 1256 AC-044-05-04: question and exclamation boundaries need no capital
ok 1257 AC-044-05-05: the sentence cap wins
ok 1258 AC-044-05-06: the time cap wins when reached first
ok 1259 AC-044-05-07: the first sentence is always spoken whole
ok 1260 AC-044-05-08: deferred windows drain to empty
ok 1261 AC-044-05-09: streaming emits each sentence exactly once
ok 1262 AC-044-06-01: parent assistant text is spoken
ok 1263 AC-044-06-02: subtask chatter is suppressed
ok 1264 AC-044-06-03: foreign sessions and user parts are suppressed
ok 1265 AC-044-06-04: growing parts yield only the delta
ok 1266 AC-044-06-05: one request per prompt with the verbatim text
ok 1267 AC-044-06-06: one request per reply on the documented path
ok 1268 AC-044-06-07: upstream failure is bounded and loud
ok 1269 AC-044-06-08: stream reconnect is bounded
ok 1270 AC-044-06-09: dry run sends nothing
ok 1271 AC-044-06-10: the fake server prints LISTENING, records, and exits 0 on SIGTERM
ok 1272 AC-044-07-01: two tones produce exactly two utterances
ok 1273 AC-044-07-02: leading and trailing silence produce no extra utterance
ok 1274 AC-044-07-03: a short blip is dropped
ok 1275 AC-044-07-04: long speech is force-split
ok 1276 AC-044-07-05: device mode spawns arecord and reuses the endpointing path
ok 1277 AC-044-07-06: missing arecord is a dependency exit with no ledger
ok 1278 AC-044-07-07: file mode spawns nothing
ok 1279 AC-044-07-08: fixtures are deterministic
ok 1280 AC-044-08-01: engine precedence
ok 1281 AC-044-08-02: an unknown engine is a usage error
ok 1282 AC-044-08-03: file transcripts map by index
ok 1283 AC-044-08-04: missing transcript lines are skipped
ok 1284 AC-044-08-05: blank transcripts produce no prompt
ok 1285 AC-044-08-06: no cloud path exists
ok 1286 AC-044-08-07: a missing engine runtime exits 3 before reading audio
ok 1287 AC-044-08-08: documentation matches the single source of truth
ok 1288 AC-044-09-01: the file sink numbers sequentially
ok 1289 AC-044-09-02: existing files are never overwritten
ok 1290 AC-044-09-03: file mode spawns no child process
ok 1291 AC-044-09-04: device mode plays through ffplay
ok 1292 AC-044-09-05: missing ffplay is a dependency exit
ok 1293 AC-044-09-06: cancellation stops playback promptly
ok 1294 AC-044-09-07: a new utterance supersedes the old one
ok 1295 AC-044-10-01: narrate never captures and never transcribes
ok 1296 AC-044-10-02: budget and parent-only filtering end to end
ok 1297 AC-044-10-03: the operator can ask for the rest
ok 1298 AC-044-10-04: requesting more after exhaustion is recorded
ok 1299 AC-044-10-05: stop cancels the current utterance and the process continues
ok 1300 AC-044-10-06: SIGINT exits cleanly, twice forces exit
ok 1301 AC-044-10-07: non-interactive stdin never blocks
ok 1302 AC-044-11-01: two utterances become two prompts and two replies
ok 1303 AC-044-11-02: turns increment and stay contiguous
ok 1304 AC-044-11-03: an empty transcript sends nothing
ok 1305 AC-044-11-04: the reply budget applies and more resumes it
ok 1306 AC-044-11-05: a missing session is created with the concierge agent
ok 1307 AC-044-11-06: device capture without a device fails loudly
ok 1308 AC-044-12-01: control is opt-in
ok 1309 AC-044-12-02: questions surface numbered options
ok 1310 AC-044-12-03: answers by number or label
ok 1311 AC-044-12-04: unmatched answers re-prompt once and then stay pending
ok 1312 AC-044-12-05: free-text questions send the transcript verbatim
ok 1313 AC-044-12-06: read-only permissions are answerable by voice
ok 1314 AC-044-12-07: mutating permissions wait for the terminal
ok 1315 AC-044-12-08: declined or abandoned confirmations send nothing
ok 1316 AC-044-12-09: blocked permissions are refused and not overridable
ok 1317 AC-044-12-10: slash prompts need terminal confirmation
ok 1318 AC-044-13-01: the agent lives outside the default agent set
ok 1319 AC-044-13-02: frontmatter shape
ok 1320 AC-044-13-03: no pinned model
ok 1321 AC-044-13-04: read-only permissions are structural
ok 1322 AC-044-13-05: the prompt states its limits
ok 1323 AC-044-13-06: the governance row is present and T0
ok 1324 AC-044-13-07: the model-pin gate is not weakened
ok 1325 AC-044-14-01: install writes the complete tree
ok 1326 AC-044-14-02: re-running is idempotent
ok 1327 AC-044-14-03: uninstall removes exactly what was installed
ok 1328 AC-044-14-04: dry run writes nothing
ok 1329 AC-044-14-05: a missing source aborts without partial copies
ok 1330 AC-044-14-06: no writes outside the config directory
ok 1331 AC-044-14-07: make targets exist
ok 1332 AC-044-14-08: smoke output is checkable
ok 1333 AC-044-14-09: smoke is offline and Python-optional
ok 1334 AC-044-15-01: every scenario is cited exactly once
ok 1335 AC-044-15-02: traceability passes
ok 1336 AC-044-15-03: no vacuous assertions
ok 1337 AC-044-15-04: the suite runs without the optional runtime
ok 1338 AC-044-15-05: the suite is hermetic
ok 1339 AC-044-15-06: temp fixtures come from the shared helper
ok 1340 AC-044-16-01: required sections exist
ok 1341 AC-044-16-02: the document does not overclaim duplex
ok 1342 AC-044-16-03: privacy and fallback are stated
ok 1343 AC-044-16-04: licensing and weights are stated
ok 1344 AC-044-16-05: never-list and exit codes match the code
ok 1345 AC-044-16-06: configuration matches print-config
ok 1346 AC-044-16-07: the ADR is recorded
ok 1347 AC-044-16-08: repo gates stay green and no weights are tracked
