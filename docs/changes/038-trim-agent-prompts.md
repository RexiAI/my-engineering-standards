# 038-trim-agent-prompts

> Spec pipeline archive. Original source: `specs/038-trim-agent-prompts/` (deleted by this script).
> Archived: 2026-11-05

## Original ask

# Trim agent prompts: move procedure into scripts

Problem: agents/*.md total ~2.9k lines; largest spec-verifier (243), spec-ux (218), spec-pr-opener (171). Much is step-by-step procedure that a script could run deterministically.

Want: each spec-* agent file <=120 lines. Procedural sequences (command lists, gate runs, file-format templates) move into scripts/ or skill reference files; agent prose keeps decisions, stop conditions, and outputs. No gate is removed or weakened. check-skills.sh and check-orchestration.sh stay green; add a line-cap check for agents/spec-*.md.
Depends on 037 (agents will reference new per-stage docs).

## Tasks

# 038 — Trim agent prompts: move procedure into scripts

Baseline (measured `wc -l agents/spec-*.md` at spec time): spec-verifier 243,
spec-ux 218, spec-pr-opener 171, spec-pipeline 140, spec-deployer 139 exceed 120;
spec-coder 111, spec-refactorer 101, spec-mutation-runner 97, spec-specifier 55 are within.

Precondition: spec 037 (split `docs/SPEC_PIPELINE.md` per stage) is merged. At spec
time 037 has only `00-informal.md`; `/build` for 038 must not start until 037 lands.

## Task 1 — Agent line-cap check script
Add `scripts/check-agent-line-cap.sh` enforcing a 120-line cap on `agents/spec-*.md`.
- Scans every file matching `agents/spec-*.md` (glob, not a hard-coded list).
- A file with line count (`wc -l`) ≤ 120 passes; > 120 fails.
- On failure prints each offending path and its line count, exits 1.
- On all-pass exits 0.
- Cap value is a single named constant in the script (value 120).
- Self-test or fixture-based test exists exercising pass (=120) and fail (=121).

## Task 2 — Wire the line-cap check into CI
- `.github/workflows/self-ci.yml` has a step running `./scripts/check-agent-line-cap.sh`.
- `AGENTS.md §General Rules` mentions the script alongside check-skills/check-orchestration.

## Task 3 — Extract procedures from over-cap agents
For each of spec-verifier, spec-ux, spec-pr-opener, spec-pipeline, spec-deployer:
- Procedural sequences (ordered command lists, gate-run sequences, file-format
  templates) move to a script under `scripts/` or a reference file under
  `skills/<name>/` or the per-stage doc created by 037.
- The agent file keeps: decisions, stop conditions, outputs, and a path reference
  to each extracted artifact.
- Resulting file ≤ 120 lines.

## Task 4 — No gate removed or weakened
- Every gate script invoked (directly or by name) by an agent before the change is
  still invoked after the change, either by the agent or by an extracted script
  the agent references.
- No threshold value (complexity ≤6, mutation threshold, line caps in check-skills)
  changes in any file.

## Task 5 — Orchestration and skill checks stay green
- `scripts/check-orchestration.sh` exits 0 (every new `scripts/...`/skill path cited in agents resolves).
- `scripts/check-skills.sh` exits 0 (any new skill reference file is compliant).
- `scripts/check-agent-line-cap.sh` exits 0.

## Open questions
1. Scope: `agents/spec-pipeline.md` matches `spec-*` (140 lines) but is the
   orchestrator, not a stage agent. Assumed IN scope per the literal glob in the
   informal spec. Confirm.
2. Does a new script need a `.ps1` twin per repo convention? Assumed no unless the
   repo standard requires it — confirm.
3. Where do file-format templates go when 037's per-stage docs exist — stage doc
   or `skills/`? Assumed: Coder chooses, as long as check-orchestration resolves the reference.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- `spec-pipeline.md` is in scope for the 120-line cap.
- No `.ps1` twin.
- Coder chooses placement of extracted templates (must resolve under check-orchestration.sh).

## Acceptance scenarios

## AC-038-01-01 — All files within cap pass
## AC-038-01-02 — File at exactly 120 lines passes
## AC-038-01-03 — File at 121 lines fails with path and count
## AC-038-01-04 — Non-spec agents ignored
## AC-038-02-01 — self-ci runs the line-cap check
## AC-038-02-02 — AGENTS.md documents the check
## AC-038-03-01 — Each formerly over-cap agent within cap
## AC-038-03-02 — Extracted artifacts referenced and exist
## AC-038-04-01 — Gate invocations preserved
## AC-038-04-02 — Thresholds unchanged
## AC-038-05-01 — All three checks pass

## Verification

# 25 — Verification: 038-trim-agent-prompts

**Stage:** 4 (Verifier) · **attempt 1, phase 1** · **worktree:** `spec-038`, stacked on `spec/037`
**Branch:** detached HEAD at `f0188e6` (spec-037 tip) with spec-038 changes in the working tree (uncommitted, as the pipeline expects before stage 5b commits per task).
**Verified against:** `specs/038-trim-agent-prompts/10-tasks.md` + `specs/038-trim-agent-prompts/20-acceptance/`. `00-informal.md` was not read.

## Verdict

**PASS** — every contract gate ran and produced no FAIL-level finding.

| # | Gate | Gate ID | Verdict | Evidence |
|---|---|---|---|---|
| 1 | Scenario traceability | `traceability` | **PASS** | exit 0, `fails: []` |
| 2 | Full test suite | `test-suite` | **PASS** | exit 0, 786 `ok`, 0 `not ok`, 0 skip |
| 3 | Complexity gate | `complexity` | **PASS** | shellcheck `-S warning` exit 0 on all 6 changed/new shell files; design-principles `complexity` category 0 FAIL |
| 3.5 | Design-principles gate | `design-principles` | **PASS** | exit 0, `fails: []`, 58 WARNs — all pre-existing, none in a changed file |
| 4 | Scenario-to-behavior spot check | `spot-check` | **PASS** | 3 scenarios re-executed by hand; 2 assertion-strength notes (W-1, W-2) |
| 5 | No unaccounted behavior | `unaccounted` | **PASS with 2 findings** | W-3 (inert HTML comment) and W-4 (path-anchored citations lost) recorded below |

**Behavior vs structural — the headline the Architect needs.** The gates that prove *behavior* all pass for real: the full 786-test suite runs green, the traceability script resolves every `AC-038-*` ID against real tests, and the read-cost script measures the actual tree. What this spec's own acceptance criteria prove is mostly *structural*: AC-038-04-01 (gates intact) is a name-presence grep, AC-038-02-01 is a YAML-string grep, AC-038-03-01 is `wc -l`. I re-verified the behavioral half of each by hand and the substance holds — but two of this spec's tests would pass even if the behavior they claim to protect regressed. Details in §Findings.

## Acceptance-criteria coverage

| AC | Test(s) in the suite | Result |
|---|---|---|
| AC-038-01-01..04 | `ok 234`–`ok 237` (`scripts/tests/ac-038-line-cap.bats`) | PASS |
| AC-038-02-01..02 | `ok 224`–`ok 225` (`scripts/tests/ac-038-ci-wiring.bats`) | PASS |
| AC-038-03-01..02 | `ok 242`–`ok 243` (`scripts/tests/ac-038-trimmed-agents.bats`) | PASS |
| AC-038-04-01..02 | `ok 228`–`ok 231` (`scripts/tests/ac-038-gates-intact.bats`) | PASS (assertion-strength note W-1) |
| AC-038-05-01 | `ok 232` | PASS |

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-05T11:58:17Z

```
{
  "checks": [1, 2],
  "passes": ["AC-038-01 — traced to a test", "AC-038-02 — traced to a test", "AC-038-03 — traced to a test", "AC-038-04 — traced to a test", "AC-038-05 — traced to a test"],
  "fails": []
}
```

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-11-05T11:58:25Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 79 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..786
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
ok 228 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 229 AC-038-04-02 — the complexity threshold is still 6
ok 230 AC-038-04-02 — the skill line-limit threshold is still 500
ok 231 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 232 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 234 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 235 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 236 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 237 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 242 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 243 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
...
ok 784 unit: a cap smaller than the marker still never exceeds the cap
ok 785 unit: state exactly at the cap is not truncated and emits no reason
ok 786 unit: successful under-cap call writes no reason line at all
```

Full log: 786 `ok`, **0** `not ok`, **0** `# skip`. Excerpt above elides untouched tests only; the `AC-038` lines and the tail are verbatim.

## Evidence: complexity gate

command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash
exit: 0
at: 2026-11-05T12:05:48Z

```
(no output — shellcheck is silent when clean)
```

`bash -n scripts/check-agent-line-cap.sh` → exit 0. The project's CI linter is `shellcheck scripts/*.sh templates/*.sh` (`self-ci.yml`). Note: that CI step carries a **pre-existing** `continue-on-error: true` (`git show HEAD:.github/workflows/self-ci.yml` line 228), so CI would not fail on a shellcheck finding — unrelated to this spec, recorded as O-1. This repo's diff is shell + markdown only; `check-code-principles.sh` deliberately excludes `*.sh` from its complexity analyzer ("a .sh file never reaches the complexity analyzer", `scripts/check-code-principles.sh:450`), so the `complexity` category carries no shell findings by design. Both mechanisms were run; both are clean.

## Evidence: design-principles gate

command: scripts/check-code-principles.sh . --json
exit: 0
at: 2026-11-05T12:05:39Z

```
```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)", "file": "./scripts/check-code-principles.selftest.sh", "line": "641" }, { "message": "Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)", "file": "./scripts/check-code-principles.selftest.sh", "line": "639" }, { "message": "Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)", "file": "./scripts/tests/gate-telemetry.selftest.sh", "line": "150" }, { "message": "Comments: commented-out code (./scripts/check-bats-assertions.sh:21)", "file": "./scripts/check-bats-assertions.sh", "line": "21" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)", "file": "./scripts/gate-clean-code-lib.sh", "line": "97" }, { "message": "Comments: commented-out code (./scripts/verify-production-deploy.sh:30)", "file": "./scripts/verify-production-deploy.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:58)", "file": "./scripts/check-code-principles.sh", "line": "58" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:121)", "file": "./scripts/check-code-principles.sh", "line": "121" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)", "file": "./scripts/check-code-principles.sh", "line": "57" }, { "message": "Comments: attribution comment (./scripts/check-code-principles.sh:59)", "file": "./scripts/check-code-principles.sh", "line": "59" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)", "file": "./scripts/check-remediation-budget.sh", "line": "139" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)", "file": "./scripts/check-remediation-budget.sh", "line": "209" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)", "file": "./scripts/lint-outbox-schema.sh", "line": "13" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)", "file": "./scripts/lint-outbox-schema.sh", "line": "22" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)", "file": "./scripts/check-saga-timeouts.sh", "line": "185" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)", "file": "./scripts/ci-smoke-test.sh", "line": "51" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)", "file": "./scripts/ci-smoke-test.sh", "line": "53" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)", "file": "./scripts/ci-smoke-test.sh", "line": "90" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)", "file": "./scripts/ci-smoke-test.sh", "line": "92" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)", "file": "./scripts/ci-smoke-test.sh", "line": "132" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)", "file": "./scripts/ci-smoke-test.sh", "line": "134" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)", "file": "./scripts/ci-smoke-test.sh", "line": "149" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)", "file": "./scripts/ci-smoke-test.sh", "line": "151" }, { "message": "Comments: commented-out code (./scripts/check-loop-files.sh:10)", "file": "./scripts/check-loop-files.sh", "line": "10" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:6)", "file": "./scripts/init-ci.sh", "line": "6" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:43)", "file": "./scripts/init-ci.sh", "line": "43" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:39)", "file": "./scripts/check-loop-triage.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:49)", "file": "./scripts/check-loop-triage.sh", "line": "49" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:67)", "file": "./scripts/check-loop-triage.sh", "line": "67" }, { "message": "Comments: commented-out code (./scripts/token-stats.sh:10)", "file": "./scripts/token-stats.sh", "line": "10" }, { "message": "Comments: commented-out code (./scripts/guard-env.sh:21)", "file": "./scripts/guard-env.sh", "line": "21" }, { "message": "Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)", "file": "./scripts/check-ci-sweeper.sh", "line": "37" }, { "message": "Comments: commented-out code (./scripts/check-security-hardening.sh:39)", "file": "./scripts/check-security-hardening.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/judgment-preflight.sh:16)", "file": "./scripts/judgment-preflight.sh", "line": "16" }, { "message": "Comments: commented-out code (./scripts/check-model-env.sh:30)", "file": "./scripts/check-model-env.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/gate-stats.sh:20)", "file": "./scripts/gate-stats.sh", "line": "20" }, { "message": "Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)", "file": "./scripts/check-pr-babysitter.sh", "line": "56" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)", "file": "./scripts/check-saga-tests.sh", "line": "85" }, { "message": "Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "197" }, { "message": "Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "147" }, { "message": "Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "201" }, { "message": "Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)", "file": "./ci/templates/go-saga-lint.go", "line": "61" }, { "message": "Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "65" }]
}
```

`fails` is empty. `warns` = 58, every one pre-existing and in a file this spec did not touch — verified by filtering the WARN file list against the changed set:

```
=== warns touching files changed by this spec ===
(none)
=== top offending dirs ===
      8 ./scripts/ci-smoke-test.sh
      7 ./ci/templates/eslint-saga-rules/saga-compensation.js
      5 ./ci/templates/go-saga-lint.go
      4 ./scripts/check-code-principles.sh
      4 ./ci/templates/archunit/OutboxArchRules.java
```

No FAIL and no new WARN: the trimmed prompts, the new script, the new bats files, the stage-doc additions, `AGENTS.md`, and ADR 0020 are clean under all nine categories.

## Evidence: scenario-to-behavior spot check

command: scripts/check-agent-line-cap.sh /tmp/opencode/verify-038/fixture
exit: 1
at: 2026-11-05T12:07:02Z

Fixture tree: `agents/spec-x.md` = 121 lines, `agents/spec-exact.md` = 120 lines, `agents/other.md` = 500 lines.

```
[OK] agents/spec-exact.md 120 lines (cap 120)
[OVER] agents/spec-x.md 121 lines (cap 120)

1 agent prompt(s) exceed the 120-line cap.
```

**Scenario 1 — AC-038-01-02/03/04 (behavioral).** The test says: 121 lines → exit 1 with path and `121` in output; exactly 120 → exit 0; a 500-line non-`spec-` file is ignored. Re-executed above by hand, independent of bats: all three hold, and `other.md` never appears in the output. The assertion matches the Given/When/Then. **PASS.**

**Scenario 2 — AC-038-03-02 (behavioral).** The scenario says every `scripts/...`/`skills/...` path a trimmed agent cites must resolve. Re-resolved independently of the test helper:

```
--- agents/spec-verifier.md
  OK   scripts/check-audit-trail.sh
  OK   scripts/record-gate-run.sh
--- agents/spec-ux.md
  OK   scripts/typed-judgment.sh
--- agents/spec-pr-opener.md
  OK   scripts/archive-spec.sh
  OK   scripts/check-audit-trail.sh
  OK   scripts/check-specs-archived.sh
--- agents/spec-pipeline.md
  OK   scripts/judgment-preflight.sh
--- agents/spec-deployer.md
```

Plus each trimmed agent's stage doc resolves (`verifier.md` 85, `ux.md` 142, `pr-opener.md` 91, `deployer.md` 105 lines) and every `§heading` it names exists (`## Checks in order`, `## Telemetry record`, `## Report format`, `## Scoped re-verification`, `## Stage 5b — …`, `## Stage 5d — …`, `## Applicability fast-path (typed judgment)`, `## 15-design.md template`, `## Vercel CLI access`). Zero MISS. **PASS.**

**Scenario 3 — AC-038-04-01 (structural — assertion is weaker than its claim, W-1).** The scenario as written is a name-presence check, and the test implements exactly that (`gate_reachable` → `grep -qF "$gate" agents/spec-*.md`). Re-executed: all four baseline gate names are still present. But the assertion can be satisfied by a *permission deny rule*, not by an instruction to run the gate:

```
agents/spec-coder.md: 1 mention(s), 1 deny-rule
agents/spec-deployer.md: 1 mention(s), 1 deny-rule
agents/spec-mutation-runner.md: 1 mention(s), 1 deny-rule
agents/spec-pipeline.md: 1 mention(s), 1 deny-rule
agents/spec-pr-opener.md: 1 mention(s), 1 deny-rule
agents/spec-refactorer.md: 1 mention(s), 1 deny-rule
agents/spec-ux.md: 1 mention(s), 1 deny-rule
agents/spec-verifier.md: 4 mention(s), 0 deny-rule
```

So `check-code-principles.sh` is "reachable" seven times over through frontmatter alone. I therefore verified the behavior the test *claims* to protect by reading the trimmed prompt and its stage doc: `agents/spec-verifier.md:60` still instructs running the design-principles gate ("the design-principles gate (`check-code-principles.sh` — every FAIL stops the pipeline…)"), `:77` keeps the `--gates` scoping, and `docs/spec-pipeline/verifier.md §Checks in order` gives the full command path for both script gates (`scripts/check-scenario-traceability.sh` row 1, `scripts/check-code-principles.sh` row 3.5). Behavior preserved; the test's strength is the note.

## Supplementary gate — no gate weakened (spec-specific requirement)

command: grep -rhoP 'scripts/check-[a-z0-9-]+\.(sh|ps1)' <base: agents/spec-*.md + docs/spec-pipeline/*.md at HEAD> ; same over the working tree ; comm -23
exit: 0
at: 2026-11-05T12:09:21Z

```
=== BASE (agents + stage docs at HEAD) ===
scripts/check-agent-models.sh
scripts/check-audit-trail.sh
scripts/check-code-principles.sh
scripts/check-model-env.sh
scripts/check-scenario-traceability.sh
scripts/check-specs-archived.sh
=== AFTER ===
scripts/check-agent-models.sh
scripts/check-audit-trail.sh
scripts/check-code-principles.sh
scripts/check-model-env.sh
scripts/check-scenario-traceability.sh
scripts/check-specs-archived.sh
=== LOST (in base, not after) ===
=== ADDED ===
```

Per-agent path-anchored citations, HEAD vs now:

```
--- spec-pr-opener.md
  BASE:  scripts/check-audit-trail.sh scripts/check-specs-archived.sh
  AFTER: scripts/check-audit-trail.sh scripts/check-specs-archived.sh
--- spec-verifier.md
  BASE:  scripts/check-audit-trail.sh scripts/check-code-principles.sh scripts/check-scenario-traceability.sh
  AFTER: scripts/check-audit-trail.sh
```

No gate was removed from the reachable set; the verifier's two gate citations lost their `scripts/` prefix and are now bare names (W-4). Thresholds unchanged — the gate scripts themselves are untouched (`git status` shows no modification to `scripts/check-code-principles.sh` or `scripts/check-skills.sh`):

```
$ grep -cF '> 6' scripts/check-code-principles.sh
4
$ grep -nF 'total_lines > 500' scripts/check-skills.sh
74:if total_lines > 500:
$ grep -E '^MAX_LINES=[0-9]+$' scripts/check-agent-line-cap.sh
MAX_LINES=120
```

`self-ci.yml` wiring — step present in the single `validate` job, no `continue-on-error`:

```
      # Agent prompt line-cap gate (spec 038): a prompt that grows into a
      # procedure manual costs context on every invocation and buries the
      # decisions it exists to carry. Procedure belongs in a stage doc under
      # docs/spec-pipeline/ or a script under scripts/. A prompt over the cap
      # fails the job.
      - name: Check agent prompt line cap
        run: ./scripts/check-agent-line-cap.sh
```

`python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))"` → parsed OK, jobs: `['validate']`. `make lint` → exit 0. ADR `docs/adr/0022-agent-prompt-line-cap.md` exists, Status **Accepted**, indexed in `docs/adr/README.md` as `| 0020 | … | Accepted |`.

## Supplementary gate — repo checks green (AC-038-05-01)

command: ./scripts/check-orchestration.sh && ./scripts/check-skills.sh && ./scripts/check-agent-line-cap.sh
exit: 0
at: 2026-11-05T12:08:38Z

```
$ ./scripts/check-orchestration.sh
Checking docs/ and language-specific/ references (agents/, commands/, AGENTS.md)...
Checking agents/ for rules duplicated from docs/SPEC_PIPELINE.md...
Checking §heading references into the pipeline docs (agents/, commands/, AGENTS.md)...

All orchestration references valid.

$ ./scripts/check-skills.sh
Checking SKILL.md files...
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).

$ ./scripts/check-agent-line-cap.sh
[OK] agents/spec-coder.md 113 lines (cap 120)
[OK] agents/spec-deployer.md 118 lines (cap 120)
[OK] agents/spec-mutation-runner.md 99 lines (cap 120)
[OK] agents/spec-pipeline.md 104 lines (cap 120)
[OK] agents/spec-pr-opener.md 104 lines (cap 120)
[OK] agents/spec-refactorer.md 102 lines (cap 120)
[OK] agents/spec-specifier.md 56 lines (cap 120)
[OK] agents/spec-ux.md 120 lines (cap 120)
[OK] agents/spec-verifier.md 117 lines (cap 120)

All 9 agent prompt(s) within the 120-line cap.
```

The `skills/hallmark` WARN is pre-existing and unrelated (that skill is untouched by this spec).

## Supplementary gate — read-cost budget still holds

command: scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:08:38Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  19663   0.386  ok
coder               15379   0.302  ok
refactorer          13666   0.268  ok
verifier            25411   0.499  ok
mutation-runner     20763   0.408  ok
pr-opener           25396   0.499  ok
deployer            18744   0.368  ok

Every stage reads at most 50% of the unsplit document.
```

Budget holds, exactly. Headroom after this spec, measured in bytes against the 25418-byte limit:

| Stage | bytes | limit | headroom |
|---|---|---|---|
| verifier | 25411 | 25418 | **7 bytes** |
| pr-opener | 25396 | 25418 | 22 bytes |

For contrast, spec 037's recorded worst was `pr-opener 24439 0.480` — this spec consumed ~957 bytes of that margin (and 4,591 bytes into `verifier.md`). The win it bought is real and is on the axis that matters: the *always-read* agent prompts, not the on-demand stage docs.

```
=== agent prompt bytes (loaded every invocation): HEAD -> NOW ===
agents/spec-verifier.md           13974 ->  7236  (-6738)
agents/spec-ux.md                 10502 ->  5795  (-4707)
agents/spec-pr-opener.md           9493 ->  6643  (-2850)
agents/spec-deployer.md            7295 ->  6068  (-1227)
                                        total  -15522 bytes (-43.2% of those four)

=== stage doc bytes (read on demand): HEAD -> NOW ===
docs/spec-pipeline/verifier.md      397 ->  4988  (+4591)
docs/spec-pipeline/ux.md            402 ->  6401  (+5999)
docs/spec-pipeline/deployer.md     2570 ->  5482  (+2912)
docs/spec-pipeline/pr-opener.md    4016 ->  4973  (+957)
                                        total +14459 bytes
```

Net across both sets: −1,063 bytes. The architectural claim in ADR 0020 (prompt cheap, procedure on demand) is substantiated by the byte counts, with the caveat in W-5.

## Findings (no unaccounted behavior)

The skim covers every hunk in `git diff` plus the five untracked files. All of it traces to a task: the script and its bats file → Task 1; `self-ci.yml` + `AGENTS.md` → Task 2; the four trimmed agents + their stage-doc additions → Task 3; `ac-038-gates-intact.bats` → Task 4/5; `docs/adr/0020` + `docs/adr/README.md` → Task 3's architectural record; `test_helper.bash` (`agent_cited_paths`, `repo_path_exists`) → the helper those tests need. Four items do not trace cleanly, and are recorded rather than fixed, per the Stop-and-Ask matrix ("Design gate WARN → record and flag"; "Out-of-scope finding → record, do not fix, propose a follow-up spec").

**W-1 — AC-038-04-01's assertion is satisfiable by a permission deny rule.** `gate_reachable` greps the bare name across `agents/spec-*.md`; seven agents mention `check-code-principles.sh` only as `"**/check-code-principles.sh": deny`. Delete the verifier's run instruction tomorrow and the test still passes. The scenario is written as a name-presence check, so the test is faithful to the scenario — the scenario is just weaker than Task 4's prose ("still invoked"). Behavior is currently correct; I verified it by reading the prompt and stage doc. Recommend strengthening to `grep -E '^ *[0-9.]+ |^- ' ` on instruction lines, or asserting the stage-doc table row.

**W-2 — The UX judgment question's criteria degraded to placeholders.** `agents/spec-ux.md:38` now sends `"criteria":{"run":"<frontend surface>","skip":"<no frontend surface>","ambiguous":"<genuinely unclear>"}` where the pre-038 prompt carried the real descriptions ("landing pages, marketing pages, portfolios, product UI in the browser, or redesigns…"). `docs/spec-pipeline/ux.md` has the same placeholders in its snippet and puts the definitions in prose 20 lines below (§Applicability check (stock path)). Nothing instructs the agent to substitute. Every `AC-028-3x` test is a `grep_file` on tokens (`"run"`, `"skip"`, `"ambiguous"`, `options:[…]`) so all stay green regardless of whether the agent ships `<frontend surface>` to the API — a false-green surface for spec 028's fast-path. Not a 038 acceptance failure and not verified as a regression (no agent was run), but it is a fidelity loss in a shipped prompt contract. One-line fix: say "substitute the definitions below" or inline them.

**W-3 — Inert HTML comment in a 120-line prompt.** `agents/spec-ux.md:46` carries `<!-- spacing keeps this outcome outside the exit-10 branch window below -->`. It is both inert and self-contradictory: the "window below" is the `awk` in `AC-028-35` that starts *at* the `**exit 10**` marker and reads forward, so lines above it cannot affect it. Verified by running that exact `awk` against a copy of the file with the line removed — byte-identical window output, and no `BLOCKED` in either:

```
=== BLOCKED present in either window? ===
0
0
=== diff line counts ===
  120 ux-with.md
  119 ux-without.md
```

It costs 1 of the 120 lines the spec exists to bound and tells a reading model something meaningless. No test requires it (grepped: the string appears nowhere outside the agent file). Belongs in the follow-up, or delete it.

**W-4 — The two core gate scripts lost their path-anchored citations from the agents.** At HEAD, `agents/spec-verifier.md` cited `scripts/check-code-principles.sh` and `scripts/check-scenario-traceability.sh` eight times with the path prefix. Now both appear only as bare backticked names (plus the deny rules), and `scripts/check-orchestration.sh` only path-resolves `scripts/...` citations found in `agents/`, `commands/`, and `AGENTS.md` — it does **not** scan `docs/spec-pipeline/*.md`, where the paths now live. Net effect: renaming either script would no longer be caught by the orchestration gate (nor by `ac-038-gates-intact.bats`, which resolves only path-anchored citations through `agent_cited_paths`). Both files exist today, so nothing is broken; a structural safety net narrowed. Cheapest fix: use `scripts/check-…` with the prefix in the verifier prompt (the test already handles it), or extend `check-orchestration.sh` to scan stage docs.

**W-5 — The read-cost margin is now ~zero on two stages.** `verifier` 25411 / 25418 bytes (7 bytes of headroom) and `pr-opener` 25396 / 25418 (22 bytes), both printing `0.499` against a `0.500` limit. The gate passes and I report it as PASS, but spec 037 left those stages at `0.480`/`0.409`-ish and this spec spent the difference: the next one-line addition to `docs/spec-pipeline/verifier.md`, `pr-opener.md`, or the index turns this gate red. `agents/spec-ux.md` is likewise exactly at 120/120. Not a failure — a budget observation the Architect should carry into `30-report.md`.

**O-1 (observation, pre-existing).** The `shellcheck scripts and templates` step in `self-ci.yml` has `continue-on-error: true` — at HEAD too (line 228), so this spec neither introduced nor fixed it. It means CI would not catch a shellcheck regression; I therefore ran shellcheck manually (see the complexity gate evidence).

**O-2 (observation).** ADR 0020 says "Four of them had grown past 120 lines" while `10-tasks.md`'s baseline lists five (including `spec-pipeline` 140). Both are accurate at their own moment: spec 037 had already trimmed `spec-pipeline.md` to 104 by the time this spec built. No action.

## Re-verification record

First full run for this spec: **attempt 1, phase 1**. No prior `25-verification.md` existed in this worktree, so no scoped re-verification was due; all six checks were run in full. Had any gate failed, the re-trigger would re-run only the failing gate(s) and append a "full run + delta" section here rather than rewriting this report.

---

# Re-verification — attempt 2, phase 1 (round 2)

**Trigger:** the W-1..W-5 remediation after the attempt-1 report (PASS with five findings).
**Scope:** scoped re-verification only (`docs/SPEC_PIPELINE.md` §Remediation budget;
`docs/spec-pipeline/verifier.md` §Scoped re-verification): full test suite, complexity,
design-principles, the W-1..W-5 spot checks, and the three supplementary structural
gates. `traceability` was not re-run — the remediation touched no scenario, gate
script, or test ID, so the attempt-1 result (`exit 0`, `fails: []`) stands unchanged.

## Round-2 verdict

**PASS** — every re-run gate exited 0 with no FAIL-level finding, and all five
remediations hold under independent re-execution. Two residual notes recorded below
(W-2r, U-1); neither fails an acceptance criterion.

| # | Gate | Gate ID | Verdict | Evidence |
|---|---|---|---|---|
| 2 | Full test suite | `test-suite` | **PASS** | exit 0, 788 `ok`, 0 `not ok`, 0 skip |
| 3 | Complexity gate | `complexity` | **PASS** | `shellcheck -S warning` exit 0 on all 7 changed shell files; `bash -n` exit 0 |
| 3.5 | Design-principles gate | `design-principles` | **PASS** | exit 0, `fails: []`, 58 WARNs, 0 touching a changed file |
| 4 | Spot check — W-1..W-5 | `spot-check` | **PASS** | each remediation re-executed by hand; all five hold |
| — | Read-cost budget (supplementary) | — | **PASS** | verifier 24401/25418 (**1017 B**), pr-opener 24906/25418 (**512 B**) |
| — | Agent line cap (supplementary) | — | **PASS** | 9/9 within cap; max **117/117** |
| — | Orchestration + skills (supplementary) | — | **PASS** | both exit 0 (1 pre-existing `skills/hallmark` WARN) |
| 5 | No unaccounted behavior | `unaccounted` | **PASS with U-1** | one working-tree edit outside the spec's tasks, recorded below |

## Evidence: full test suite (round 2)

command: make test-scripts
exit: 0
at: 2026-11-05T12:33:22Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 79 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..788
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
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
ok 244 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 245 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
...
ok 787 unit: state exactly at the cap is not truncated and emits no reason
ok 788 unit: successful under-cap call writes no reason line at all
```

Full log: 788 `ok`, **0** `not ok`, **0** `# skip`. The two added tests
(`ok 233`–`ok 235`) are the W-1 negative fixture and its positive companion; the
count moved 786 → 788 accordingly.

## Evidence: complexity gate (round 2)

command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash tests/AC-030-01.sh
exit: 0
at: 2026-11-05T12:41:01Z

```
(no output — shellcheck is silent when clean)
```

`bash -n scripts/check-agent-line-cap.sh && bash -n scripts/tests/test_helper.bash && bash -n tests/AC-030-01.sh` → exit 0.

## Evidence: design-principles gate (round 2)

command: scripts/check-code-principles.sh . --json
exit: 0
at: 2026-11-05T12:39:20Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, ...]
}
```

Parsed from the same transcript (raw filter output):

```
fails []
warn count 58
warns touching changed files: 0
```

No FAIL and no WARN in any file this spec changed; the 58 WARNs are the same
pre-existing set (saga/outbox templates, `ci-smoke-test.sh`, `hallmark` example).

## Evidence: scenario-to-behavior spot check (round 2 — W-1..W-5)

command: bats scripts/tests/ac-038-gates-intact.bats
exit: 0
at: 2026-11-05T12:39:38Z

```
1..8
ok 1 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 2 AC-038-04-02 — the complexity threshold is still 6
ok 3 AC-038-04-02 — the skill line-limit threshold is still 500
ok 4 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 5 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 6 unit — a gate named only in frontmatter is not reachable
ok 7 unit — a gate named in the agent body is reachable
ok 8 unit — no agent cites a gate script that does not exist
```

### W-1 — `gate_reachable` tightened + negative fixture: **RESOLVED**

`gate_reachable` now reads only the post-frontmatter body (`body_of`) and resolves
cited scripts from `agent_cited_paths`, filtered to `.sh`. Independent
re-execution, outside bats:

```
=== W-1: gate named in agent BODY (frontmatter excluded) ===
BODY HIT: agents/spec-verifier.md
   25:not a pass: if `scripts/check-code-principles.sh` or `scripts/check-scenario-traceability.sh` cannot
   45:real linter, the design-principles gate (`scripts/check-code-principles.sh` — every FAIL
   62:- **Scoped flags** narrow a script gate further: `scripts/check-code-principles.sh --gates <name>`, `scripts/check-scenario-traceability.sh --checks <1|2>`. ...
=== W-1: frontmatter deny rules (must NOT count) ===
agents/spec-coder.md frontmatter mentions: 1
agents/spec-deployer.md frontmatter mentions: 1
agents/spec-mutation-runner.md frontmatter mentions: 1
agents/spec-pipeline.md frontmatter mentions: 1
agents/spec-pr-opener.md frontmatter mentions: 1
agents/spec-refactorer.md frontmatter mentions: 1
agents/spec-ux.md frontmatter mentions: 1
agents/spec-verifier.md frontmatter mentions: 1
EXPECTED: gate named only in frontmatter is NOT in body -> gate_reachable would return 1
```

The negative fixture (`unit — a gate named only in frontmatter is not reachable`,
`ok 6`) fails the old assertion and passes the new one; the positive companion
(`ok 7`) protects against over-tightening. The old false-green surface is gone.

### W-2 — UX judgment criteria restored: **RESOLVED** (residual W-2r)

`agents/spec-ux.md:38` again ships the real criteria text, and the prompt now says
so explicitly ("Those criteria are fixed text, not placeholders — pass them
verbatim"):

```
$ grep -n '"criteria"' agents/spec-ux.md
38:  --questions '{"applicability":{"type":"choice","instructions":"Does this spec have a frontend surface the design-taste-frontend skill applies to? ...","criteria":{"run":"a frontend surface the skill applies to: landing pages, marketing pages, portfolios, product UI in the browser, or redesigns of any of these","skip":"no frontend surface: pure backend work, CLI tools, dashboards/admin panels/data tables, native mobile, realtime collab UI, or APIs with no visual surface","ambiguous":"genuinely unclear whether the spec has a frontend surface the skill applies to"},"options":["run","skip","ambiguous"]}}'
```

**W-2r (residual review note, not a FAIL).** `docs/spec-pipeline/ux.md:28` still
shows metavariable placeholders in its illustrative snippet
(`"<the applicability question>"`, `"<frontend surface definition>"`, …). The
loaded agent prompt is authoritative and carries the real text; the stage doc's
prose only says the criteria must be an object keyed by option names. A future
editor copying the snippet instead of the prompt would reintroduce the defect.
Cheap follow-up: mirror the real criteria into the stage-doc snippet.

### W-3 — inert HTML comment removed: **RESOLVED**

```
$ grep -rn "spacing keeps this outcome" . --exclude-dir=.git
./specs/038-trim-agent-prompts/25-verification.md:328:**W-3 — Inert HTML comment in a 120-line prompt.** ...
```

Only the historical finding quotes it; `agents/spec-ux.md` is 117 lines and no
longer carries the comment. No test referenced the string.

### W-4 — path-anchored gate citations restored: **RESOLVED**

```
$ grep -hoP '(?<!standards/)scripts/[A-Za-z0-9._-]+\.(sh|ps1)' agents/spec-verifier.md | sort -u
scripts/check-audit-trail.sh
scripts/check-code-principles.sh
scripts/check-scenario-traceability.sh
scripts/record-gate-run.sh

$ grep -n 'scripts/check-' docs/spec-pipeline/verifier.md
18:| 1 | Scenario traceability | `scripts/check-scenario-traceability.sh` ...
21:| 3.5 | Design-principles gate | `scripts/check-code-principles.sh`: ...
44:code, and an `at:` timestamp ... `scripts/check-audit-trail.sh`
63:- `scripts/check-code-principles.sh --gates <name>` ...
64:- `scripts/check-scenario-traceability.sh --checks <1|2>` ...
```

Both core gate scripts are path-anchored again in the agent prompt **and** the
stage doc, so `check-orchestration.sh` (which scans `agents/`) resolves them again
(see the orchestration evidence below). The stage doc's four anchors
(`§Checks in order`, `§Telemetry record`, `§Report format`,
`§Scoped re-verification`) all exist as `##` headings.

### W-5 — read-cost / line-cap headroom restored: **RESOLVED**

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
verifier            24401   0.479  ok
pr-opener           24906   0.489  ok
...
Every stage reads at most 50% of the unsplit document.
```

Headroom: verifier **1017 B** (25418 − 24401), pr-opener **512 B** (25418 − 24906).
Line counts (`wc -l agents/spec-*.md`): the two largest are `spec-ux.md` **117**
and `spec-verifier.md` **117** — no agent is pinned at 120/120 any more.

## Evidence: measure-stage-read-cost (round 2)

command: scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:39:31Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  19663   0.386  ok
coder               15379   0.302  ok
refactorer          13666   0.268  ok
verifier            24401   0.479  ok
mutation-runner     20763   0.408  ok
pr-opener           24906   0.489  ok
deployer            18744   0.368  ok

Every stage reads at most 50% of the unsplit document.
```

## Evidence: agent line cap (round 2)

command: ./scripts/check-agent-line-cap.sh
exit: 0
at: 2026-11-05T12:39:31Z

```
[OK] agents/spec-coder.md 113 lines (cap 120)
[OK] agents/spec-deployer.md 118 lines (cap 120)
[OK] agents/spec-mutation-runner.md 99 lines (cap 120)
[OK] agents/spec-pipeline.md 104 lines (cap 120)
[OK] agents/spec-pr-opener.md 104 lines (cap 120)
[OK] agents/spec-refactorer.md 102 lines (cap 120)
[OK] agents/spec-specifier.md 56 lines (cap 120)
[OK] agents/spec-ux.md 117 lines (cap 120)
[OK] agents/spec-verifier.md 117 lines (cap 120)

All 9 agent prompt(s) within the 120-line cap.
```

## Evidence: check-orchestration (round 2)

command: ./scripts/check-orchestration.sh && ./scripts/check-skills.sh
exit: 0
at: 2026-11-05T12:39:31Z

```
$ ./scripts/check-orchestration.sh
Checking agent references (commands/, agents/)...
Checking skill references (agents/)...
Checking scripts/ references (agents/, commands/, AGENTS.md)...
Checking docs/ and language-specific/ references (agents/, commands/, AGENTS.md)...
Checking agents/ for rules duplicated from docs/SPEC_PIPELINE.md...
Checking §heading references into the pipeline docs (agents/, commands/, AGENTS.md)...

All orchestration references valid.

$ ./scripts/check-skills.sh
Checking SKILL.md files...
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
```

The `skills/hallmark` WARN is pre-existing and unrelated (spec untouched here).

## No unaccounted behavior (round 2)

The remediation hunks all trace to W-1..W-5 plus their tests. One hunk does not:

**U-1 — working-tree edit to `tests/AC-030-01.sh` with no 038 task behind it.**
The file rewrites four `printf … | grep` pipelines to here-strings and hoists
`body_of "$SK"` out of the section loop. It is behavior-preserving: the HEAD
version and the working-tree version both run green
(`RESULT AC-030-01: passed=23 failed=0`), and `shellcheck -S warning` is silent on
both. The file's mtime (2026-11-05 13:22:12 +0100 = 12:22:12Z) is inside the
remediation window; the W-1..W-5 summary does not mention it, and it belongs to
spec 030, not 038. It is plausibly a defensive `set -euo pipefail` cleanup (the
test sets `pipefail`), but it is unaccounted.

Not a FAIL: no acceptance criterion in `20-acceptance/` covers this file, and the
PR Opener's commit-scope rule (stage only files the tasks name) leaves it
uncommitted, so it cannot leak into the PR. Recommendation: revert it or have the
Refactorer record it before the branch is finalized.

## Round-2 re-verification record

**attempt 2, phase 1.** Only the previously-flagged areas were re-run (W-1..W-5
plus the gates whose behavior could be affected by the fixes). `traceability` and
the round-1 spot-check scenarios not related to W-1..W-5 stand on their prior
evidence above; nothing in the round-1 evidence blocks was rewritten.

## Quality gates

# 30 — Mutation / Architect report: 038-trim-agent-prompts

**Stage:** 5a (Mutation Runner) · **tier:** `mvp` · **worktree:** `spec-038`
**HEAD:** detached at `f0188e6` (spec-037 tip); spec-038 changes in the working tree, uncommitted (expected pre-stage-5b state — the verifier recorded the same tree).
**Verified against:** `specs/038-trim-agent-prompts/10-tasks.md` + `20-acceptance/`, plus the Verifier's `25-verification.md`. `00-informal.md` was not read.

## Verdict

**GREEN.** Mutation testing is a `production`-tier gate (`docs/spec-pipeline/coder.md §Conformance tiers`); this project is `mvp`, so it is **skipped** with a recorded reason, not failed. Every gate that does apply is green on a fresh run: the full suite is 788/788 `ok`, `make validate-all` exits 0, the agent line cap is 9/9, and the read-cost budget holds.

| # | Row | Value | Source |
|---|---|---|---|
| 1 | Verifier verdict (carried forward) | **PASS — attempt 2, phase 1** (attempt 1 also PASS; 788 `ok`, 0 `not ok`) | `25-verification.md` §Round-2 verdict + §Round-2 record |
| 2 | Mutation score | **skipped — `mvp` tier** (`production`-tier gate; `make mutation` prints the skip and exits 0) | Evidence block below |
| 3 | Equivalent mutants | **none** — no mutation run at this tier, so none to classify | n/a |
| 4 | Complexity summary (carried from Refactorer, re-confirmed here) | PASS — `shellcheck -S warning` exit 0 on all 7 changed shell files, `bash -n` exit 0, design-principles `complexity` category 0 FAIL (3 pre-existing `KISS_LINES` WARNs, 0 in a changed file) | §Complexity summary + evidence below |
| 5 | Final full test suite | **PASS — 788 `ok`, 0 `not ok`, 0 `# skip`, plan `1..788`** | Evidence block below |
| 6 | Supplementary repo gates | PASS — `make validate-all` exit 0, `check-agent-line-cap.sh` exit 0 (9/9), `measure-stage-read-cost.sh` exit 0 | Evidence blocks below |
| 7 | Remediation record | **no BLOCK occurred**; one phase-1 remediation round (attempt 1 → attempt 2), resolved at attempt 2 | §Remediation record |
| 8 | PR Opener precondition | branch will be `spec/038-trim-agent-prompts`, this report exists and is GREEN; one staging caveat (U-1) below | §Hand-off to stage 5b |

## Evidence: mutation testing (skip at tier)

command: make mutation
exit: 0
at: 2026-11-05T12:50:11Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

The skip is the Makefile's own tier probe (`Makefile:135-141`), not an ad-hoc decision: it greps for `Conformance tier: production` in `AGENTS.md`/`AGENTS_*.md`, finds `mvp`, and prints the documented reason. Per `docs/spec-pipeline/coder.md §Conformance tiers`, the Architect role still runs at `mvp` (to carry the report to stage 5b); only the mutation *test* is omitted. No Stryker/PiTest/`gremlins` invocation exists for this repo's shell + markdown surface, and no `stryker.conf.*` / `pom.xml` / `go.mod` is present to host one.

## Evidence: final full test suite

command: make test-scripts
exit: 0
at: 2026-11-05T12:42:56Z

Started `2026-11-05T12:42:56Z`, finished `2026-11-05T12:50:02Z` (426 s, full log `/tmp/opencode/mut-038/final-suite.log`).

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 79 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..788
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
ok 228 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 229 AC-038-04-02 — the complexity threshold is still 6
ok 230 AC-038-04-02 — the skill line-limit threshold is still 500
ok 231 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 232 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 236 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 237 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 238 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 239 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 244 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 245 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
...
ok 786 unit: a cap smaller than the marker still never exceeds the cap
ok 787 unit: state exactly at the cap is not truncated and emits no reason
ok 788 unit: successful under-cap call writes no reason line at all
```

Counted from the raw TAP log: `^ok ` **788**, `^not ok` **0**, `^# skip` **0**, plan line `1..788`. Excerpt elides untouched tests only; the `AC-038-*` lines, the plan line and the tail are verbatim. This is the Verifier's 788 re-confirmed from a clean re-run — no new test code was written this stage (mutation testing is skipped), so there is no mutation-kill delta to absorb.

## Evidence: complexity gate

command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash tests/AC-030-01.sh
exit: 0
at: 2026-11-05T12:50:11Z

```
(no output — shellcheck is silent when clean)
```

command: bash -n scripts/check-agent-line-cap.sh && bash -n scripts/tests/test_helper.bash && bash -n tests/AC-030-01.sh
exit: 0
at: 2026-11-05T12:50:11Z

```
(no output — all three files parse)
```

command: scripts/check-code-principles.sh . --gates complexity --json
exit: 0
at: 2026-11-05T12:50:11Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}
```

`fails: []`. The three WARNs are pre-existing KISS line-length hints in files this spec did not touch; there is **no cyclomatic-complexity finding**, and no WARN lands in a changed file.

## Complexity summary (carried from the Refactorer)

The Refactorer writes no report artifact by design (`docs/spec-pipeline/audit-contract.md §Audit contract`); its structural claims are re-executed by the Verifier and re-recorded in `25-verification.md`, and I re-confirm them here rather than inventing numbers:

| Concern | Mechanism | Result |
|---|---|---|
| Cyclomatic complexity ≤6 | `check-code-principles.sh` complexity analyzer | **0 FAIL / 0 CC WARN**; the analyzer deliberately skips `*.sh` (`scripts/check-code-principles.sh:450`), and this diff is shell + markdown only |
| Shell correctness / lint | `shellcheck -S warning` (project linter) | **exit 0**, all 7 changed/new shell files silent |
| Shell parse | `bash -n` | **exit 0** on script + helper + `tests/AC-030-01.sh` |
| Duplication | design-principles `dry` category | **0 FAIL**; 58 WARNs repo-wide, **0 touching a changed file** (Verifier round 2) |
| Property tests | `production`+ only | **skipped — `mvp` tier** (same tier rule as mutation) |
| Agent prompt size | `check-agent-line-cap.sh` | **9/9 within 120**; max `spec-deployer.md` 118 |

## Evidence: supplementary repo gates

command: make validate-all
exit: 0
at: 2026-11-05T12:50:05Z

```
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
All validations passed.
```

command: ./scripts/check-agent-line-cap.sh
exit: 0
at: 2026-11-05T12:50:05Z

```
All 9 agent prompt(s) within the 120-line cap.
```

command: scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:50:05Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  19663   0.386  ok
coder               15379   0.302  ok
refactorer          13666   0.268  ok
verifier            24401   0.479  ok
mutation-runner     20763   0.408  ok
pr-opener           24906   0.489  ok
deployer            18744   0.368  ok

Every stage reads at most 50% of the unsplit document.
```

The `skills/hallmark` WARN is pre-existing and untouched by this spec. `validate-all` = `validate validate-docs validate-refs validate-skills`, so this run also re-confirms `check-orchestration.sh` and `check-skills.sh` behind AC-038-05-01.

## Evidence: audit-trail gate (this report)

command: ./scripts/check-audit-trail.sh 038-trim-agent-prompts
exit: 0
at: 2026-11-05T12:50:50Z

```
PASS 038-trim-agent-prompts: 10-tasks.md present and non-empty
PASS 038-trim-agent-prompts: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 038-trim-agent-prompts: 25-verification.md present and non-empty
PASS 038-trim-agent-prompts: 30-report.md present and non-empty
PASS 038-trim-agent-prompts: 45-decisions.md optional without an 'Autopilot: true' marker (AC-035-35)
PASS 038-trim-agent-prompts: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-05T11:58:17Z
PASS 038-trim-agent-prompts: evidence block 'full test suite' — command: make test-scripts, exit: 0, at: 2026-11-05T11:58:25Z
PASS 038-trim-agent-prompts: evidence block 'complexity gate' — command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash, exit: 0, at: 2026-11-05T12:05:48Z
PASS 038-trim-agent-prompts: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh . --json, exit: 0, at: 2026-11-05T12:05:39Z
PASS 038-trim-agent-prompts: evidence block 'scenario-to-behavior spot check' — command: scripts/check-agent-line-cap.sh /tmp/opencode/verify-038/fixture, exit: 1, at: 2026-11-05T12:07:02Z
✔ Audit-trail check: specs/038-trim-agent-prompts complete, verifier evidence recorded.
```

Run without `--require-deploy` (stage 5b's invocation, `docs/SPEC_PIPELINE.md §The gate`); this lane is non-frontend, so stage 5c records a skip rather than a deploy artifact.

## Equivalent mutants

**None.** Mutation testing was not run (`mvp` tier), so no mutant survived and none needs an un-killable classification. This spec's test surface is shell + markdown assertions, which a JS/Python mutation runner cannot meaningfully mutate anyway; the tier rule and the tooling reality agree.

## Stats

**Test surface**

| Metric | Attempt 1 (Verifier) | Final (this stage) |
|---|---|---|
| bats tests | 786 `ok` | **788 `ok`**, 0 `not ok`, 0 skip |
| bats files guarded by anti-vacuity check | 79 | 79 |
| delta vs attempt 1 | — | +2 (W-1 negative fixture + positive companion, `ok 233`–`ok 235` in round 2) |

**Agent prompts (always-loaded) vs stage docs (on-demand)** — carried from the Verifier's measurement, unchanged by this stage:

| File | HEAD → now | Δ bytes |
|---|---|---|
| `agents/spec-verifier.md` | 13974 → 7236 | −6738 |
| `agents/spec-ux.md` | 10502 → 5795 | −4707 |
| `agents/spec-pr-opener.md` | 9493 → 6643 | −2850 |
| `agents/spec-deployer.md` | 7295 → 6068 | −1227 |
| four-prompt total | — | **−15522 (−43.2%)** |
| `docs/spec-pipeline/{verifier,ux,deployer,pr-opener}.md` | — | +14459 (on demand) |
| net across both sets | — | **−1063** |

**Line counts:** 9/9 `agents/spec-*.md` ≤120; largest are `spec-deployer.md` 118, `spec-ux.md` 117, `spec-verifier.md` 117; total 930 lines across the 9 prompts.

**Read-cost headroom:** verifier 24401/25418 (**1017 B** free), pr-opener 24906/25418 (**512 B** free) — still tight, see W-5 below.

**Change set:** 14 tracked files changed (+557 / −585), 5 new in-scope files (`scripts/check-agent-line-cap.sh` + 4 `scripts/tests/ac-038-*.bats`), 1 new ADR (`docs/adr/0022-agent-prompt-line-cap.md`), plus the spec folder itself.

## Findings carried forward

- **W-2r (residual, not a FAIL).** `docs/spec-pipeline/ux.md:28` still shows metavariable placeholders in its illustrative criteria snippet (`"<the applicability question>"`, `"<frontend surface definition>"`, …). The authoritative loaded prompt (`agents/spec-ux.md:38`) carries the real criteria text and says "pass them verbatim", so behavior is correct today; the residual risk is a future editor copying the snippet instead of the prompt. Cheap follow-up: mirror the real criteria into the stage-doc snippet. Recorded per the Stop-and-Ask matrix ("Out-of-scope finding → record, do not fix").
- **U-1 (unaccounted working-tree edit, out of this spec's tasks).** `tests/AC-030-01.sh` rewrites four `printf … | grep -q` pipelines to here-strings and hoists `body_of "$SK"` out of the loop. This is exactly the latent defect **O-2 in spec 037** (`printf` takes SIGPIPE when `grep -q` exits early and `set -o pipefail` propagates it) — the fix shape 037 recommended. It is behavior-preserving (both versions green, shellcheck silent) and no 038 acceptance criterion covers it. **Recommendation: keep it, as its own commit**, e.g. `fix(tests): avoid printf|grep -q SIGPIPE flake in AC-030-01 (037 O-2)`, staged separately from the 038 task commits so it does not ride inside an unrelated `feat` commit. Do not revert — it removes a real timing-dependent flake. Contract note: 037 closed as PASS with O-2 recorded out of scope, so this commit should cite 037 O-2 in its message.
- **W-5 (budget observation).** Read-cost margin is thin again: verifier 1017 B, pr-opener 512 B free, both printing `0.479`/`0.489` against `0.500`. The gate passes; the next line added to either stage doc turns it red. Any follow-up spec touching `docs/spec-pipeline/{verifier,pr-opener}.md` must budget for it.
- **O-1 / O-2 (pre-existing, from the Verifier).** `self-ci.yml`'s shellcheck step still carries `continue-on-error: true`; ADR 0020's "four over-cap agents" vs `10-tasks.md`'s five is a timing artifact (037 had already trimmed `spec-pipeline.md`). Neither is this spec's to fix.

## Remediation record

Carried forward from `25-verification.md` §Re-verification record and the orchestrator's run ledger (`runs.jsonl`, the two `038-trim-agent-prompts` rows):

| Phase | Attempt | Trigger | Outcome |
|---|---|---|---|
| phase 1 | attempt 1 | first full verification run | **PASS with 5 findings** (W-1..W-5) — a PASS, not a BLOCK |
| phase 1 | attempt 2 | W-1..W-5 remediation | **PASS**; all five remediations independently re-executed; two residual notes (W-2r, U-1) |

**No BLOCK occurred during this run.** No gate reached the fix-the-code budget; the only re-run was the scoped phase-1 re-verification of the attempt-1 review findings. This matches the ledger's counters for loop 2 of this spec: `phase1Retries: 1`, `phase2Retries: 0`. No phase-2 (post-PR CI) round has run yet — stage 5b has not opened the PR.

## Working tree

Dirty by design at this stage: the 038 change set is uncommitted, as stage 5b commits one conventional commit per task. Dirty paths are the 14 tracked modifications, the 5 new in-scope files, the ADR, the spec folder, plus two non-038 paths — `runs.jsonl` (orchestrator telemetry, uncommitted by instruction) and `tests/AC-030-01.sh` (U-1, recommend a separate commit). Nothing was staged, committed, stashed, or reverted by stage 5a.

## Hand-off to stage 5b

Mutation gate: **skipped at `mvp`** (documented, not silently absent). Everything else GREEN. The PR Opener's precondition (`docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix`: branch `spec/NNN-slug`, `30-report.md` present and green) is satisfiable. The only staging instruction is U-1: commit `tests/AC-030-01.sh` as its own `fix(tests): …` commit referencing 037 O-2, or leave it uncommitted — do not fold it into a 038 task commit.

PR: https://github.com/RexiAI/my-engineering-standards/pull/115
Commits: 8 (task + spec commits at PR open; plus this record, the 40-deploy skip, and the archive commit)

## 40-deploy.md

# 40 — Deploy verification: 038-trim-agent-prompts

**Stage:** 5c (Deploy Verifier) · **lane:** non-frontend · **worktree:** `spec-038`
**PR:** https://github.com/RexiAI/my-engineering-standards/pull/115

## Verdict

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

## Why

This repository is a documentation and tooling standards repo, not a deployable
frontend application. Neither deterministic deploy-lane signal is present at the
repo root: there is no `vercel.json`, and there is no root `package.json`
declaring a frontend framework dependency (`next`, `react`, `@angular/core`,
`@ionic/angular`). There is therefore no Vercel preview deployment, health check,
or live E2E surface for stage 5c to verify.

The documented non-frontend behavior applies: record the skip reason and exit
cleanly (`agents/spec-deployer.md` §Non-frontend repo). Non-frontend repos never
fail the deploy gate, and phase-3 budget is not consumed (0 of 3 rounds —
not applicable).

## Deploy-lane detection

command: test -f vercel.json
exit: 1
at: 2026-11-05T13:02:20Z

```
(no output — no vercel.json at the repo root)
```

command: test -f package.json
exit: 1
at: 2026-11-05T13:02:20Z

```
(no output — no root package.json; the repo has no frontend framework manifest)
```

No deploy URL, build status, health-check result, or E2E verdict exists for this
lane. Recording fabricated deploy evidence would violate the audit contract
(`docs/spec-pipeline/audit-contract.md`), so the skip is recorded instead.
