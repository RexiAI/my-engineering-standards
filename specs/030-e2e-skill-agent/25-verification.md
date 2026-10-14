# 25-verification.md — spec 030 (e2e-skill-agent)

- **Verdict: PASS**
- Attempt index: 1 (first full run), phase 1 (pre-PR)
- Verified by: spec-verifier (stage 4), 2026-10-14
- Information barrier honored: `specs/030-e2e-skill-agent/00-informal.md` was **not**
  read. Verification is against `10-tasks.md` and `20-acceptance/AC-030-01..07.md` only.
- Working-tree state: all spec-030 deliverables are uncommitted changes on `main`'s
  working tree at HEAD `8af331a` (per orchestrator instruction; nothing was stashed,
  committed, or fixed by the Verifier).

## Summary

| # | Check | Result | Exit |
|---|---|---|---|
| 1 | Scenario traceability | PASS | 0 |
| 2 | Full test suite | PASS (green in CI-equivalent env; 8 machine-local environmental failures proven unrelated — see judgment) | 0 (CI-equivalent) |
| 3 | Complexity gate | PASS (0 violations; worst function CC=6 ≤6) | 0 |
| 3.5 | Design-principles gate | PASS (0 FAIL; 14 WARN all pre-existing in ci/templates) | 0 |
| 4 | Scenario-to-behavior spot check (a–d) | PASS | 0 |
| 5 | No unaccounted behavior | PASS (finding line; no untraced behavior) | — |
| extra | check-skills / check-orchestration / check-model-env / check-bats-assertions | PASS | 0/0/0/0 |
| extra | no-literal-model-id + no-secrets over new deliverables | PASS (zero hits) | 0 |

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-10-14T14:41:14Z

```
PASS AC-030-01 — traced to a test
PASS AC-030-02 — traced to a test
PASS AC-030-03 — traced to a test
PASS AC-030-04 — traced to a test
PASS AC-030-05 — traced to a test
PASS AC-030-06 — traced to a test
PASS AC-030-07 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.
```

Machine-readable transcript (`--json`):

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-14T14:41:34Z

```json
{
  "checks": [1, 2],
  "passes": ["AC-030-01 — traced to a test", "AC-030-02 — traced to a test", "AC-030-03 — traced to a test", "AC-030-04 — traced to a test", "AC-030-05 — traced to a test", "AC-030-06 — traced to a test", "AC-030-07 — traced to a test"],
  "fails": []
}
```

Independent 42-ID verification (the script's ERE truncates IDs to task level
`AC-030-NN` on both sides — heading scan and reference scan — so it verifies at
task granularity; the full scenario-level citation was checked mechanically):

command: grep -hoE '^## AC-030-[0-9]{2}-[0-9]{2}' specs/030-e2e-skill-agent/20-acceptance/*.md | sort -u → per-ID grep in scripts/tests/ac-030-e2e-skill-agent.bats and tests/
exit: 0
at: 2026-10-14T14:41:34Z

```
42
all-42-cited-in-bats: YES
all-42-cited-in-bash-tests: YES
scripts/tests/ac-004-005-007-trace.bats 2547bytes
```

Coder's scan-pattern claim — **verified from the script source**
(`scripts/check-scenario-traceability.sh` lines 204–207): the reference scan is
`grep --include="*.bats" --include="*_test.go" --include="*Test.java"
--include="*PropertyTest.java" --include="*.test.ts" --include="*.test.js"
--include="*.spec.ts" --include="*.spec.js"`. Plain `tests/AC-030-NN.sh` matches
none of these patterns, so the prescribed bash tests alone would leave all 42
IDs uncited and check 1 would fail. The ID-citing bats wrapper
`scripts/tests/ac-030-e2e-skill-agent.bats` is therefore load-bearing, and the
precedent file `scripts/tests/ac-004-005-007-trace.bats` exists (2547 bytes).
The wrapper cites all 42 full `AC-030-NN-MM` IDs — strictly more granular than
the script's task-level truncation.

## Evidence: full test suite

command: make test (repo suite, this machine's dirty env) → then the CI-equivalent run: pristine-HEAD git worktree + deliverables copied in + sanitized env (JUDGMENT_* unset, no gitignored credential files)
exit: 0
at: 2026-10-14T14:50:35Z

**Spec-030 bash suites (prescribed by 10-tasks.md), current tree:**

command: for n in 01..07; do bash tests/AC-030-$n.sh; done
exit: 0
at: 2026-10-14T14:42:04Z

```
tests/AC-030-01.sh exit=0 :: RESULT AC-030-01: passed=23 failed=0
tests/AC-030-02.sh exit=0 :: RESULT AC-030-02: passed=97 failed=0
tests/AC-030-03.sh exit=0 :: RESULT AC-030-03: passed=21 failed=0
tests/AC-030-04.sh exit=0 :: RESULT AC-030-04: passed=40 failed=0
tests/AC-030-05.sh exit=0 :: RESULT AC-030-05: passed=13 failed=0
tests/AC-030-06.sh exit=0 :: RESULT AC-030-06: passed=4 failed=0
tests/AC-030-07.sh exit=0 :: RESULT AC-030-07: passed=8 failed=0
SPEC030_BASH_OVERALL=0
```

**Spec-030 bats wrapper (49 tests: 42 scenario + 7 full-suite):**

command: bats --tap scripts/tests/ac-030-e2e-skill-agent.bats
exit: 0
at: 2026-10-14T14:42:17Z

```
ok 45 AC-030-03: T3 full suite (scenarios + units) exits 0
ok 46 AC-030-04: T4 full suite (scenarios + units) exits 0
ok 47 AC-030-05: T5 full suite (scenarios + units) exits 0
ok 48 AC-030-06: T6 full suite (scenarios + units) exits 0
ok 49 AC-030-07: T7 full suite (scenarios + units) exits 0
49 ok, 0 not ok
```

**Repo suite, this machine's live (dirty) env — reproduces the claimed 8 failures:**

command: make test
exit: 2
at: 2026-10-14T14:42:42Z

```
not ok 5 AC-001-05: No secrets in harness or fixtures
not ok 80 agent-env.selftest: exits 0 and reports every case passing
not ok 81 agent-env.selftest: reports a non-zero assertion count and zero failures
not ok 82 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
not ok 263 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
not ok 310 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
not ok 312 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
not ok 334 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
352 ok / 8 not ok (360 tests)
```

**Environmental proof A — same tree, sanitized env, typed-judgment files only:**

command: env -u JUDGMENT_API_URL -u JUDGMENT_BACKEND -u JUDGMENT_MIN_CONFIDENCE -u JUDGMENT_API_KEY -u JUDGMENT_MODEL bats --tap scripts/tests/typed-judgment.bats scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-10-14T14:46:36Z

```
130 ok / 0 not ok  (all 4 AC-028 failures vanish when this machine's
JUDGMENT_* vars — JUDGMENT_BACKEND=local et al., loaded by direnv from the
gitignored config/model.local.env — are unset; deliverables still present)
```

**Environmental proof B — pristine HEAD worktree (zero spec-030 deliverables), same dirty env:**

command: git worktree add --detach /tmp/ver030-head HEAD && cd /tmp/ver030-head && make test
exit: 2
at: 2026-10-14T14:47:49Z

```
not ok 214 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
not ok 261 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
not ok 263 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
not ok 285 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
307 ok / 4 not ok
```

The 4 AC-028 failures reproduce identically with **no spec-030 deliverable in
the tree** → they cannot be caused by spec-030. The 4 agent-env/AC-001-05
failures do *not* reproduce in the worktree because its root lacks this
machine's gitignored `config/agent.local.env`; in the main tree,
`scripts/check-no-hardcoded-secrets.sh` (a HEAD-tracked script, unmodified by
spec-030) fails solely on that file:

```
config/agent.local.env:9: literal token prefix                 [value REDACTED]
config/agent.local.env:14: literal token prefix                 [value REDACTED]
config/agent.local.env:9: secret-style assignment: GITHUB_TOKEN=<REDACTED live machine credential>
config/agent.local.env:14: secret-style assignment: GH_TOKEN=<REDACTED live machine credential>
config/agent.local.env:18: secret-style assignment: BAILIAN_TOKEN_PLAN_API_KEY=<REDACTED live machine credential>
✘ check-no-hardcoded-secrets: 5 violation(s) in agents, commands, scripts, docs, .github, config, templates, ci.
```

All 5 violations are in the gitignored per-machine credential file that the
repo standard *requires* to exist locally (`AGENTS.md §Per-machine agent
environment`); zero violations in any spec-030 file. A CI checkout does not
contain this file. (Real token values are redacted here — this report becomes a
tracked PR artifact and must not carry credentials.)

**Environmental proof C — CI-equivalent: pristine HEAD worktree + deliverables + sanitized env:**

command: cd /tmp/ver030-head && env -u JUDGMENT_API_URL -u JUDGMENT_BACKEND -u JUDGMENT_MIN_CONFIDENCE -u JUDGMENT_API_KEY -u JUDGMENT_MODEL make test
exit: 0
at: 2026-10-14T14:50:35Z

```
NO FAILURES
360 ok / 0 not ok
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

360 = 311 (HEAD suite) + 49 (spec-030 bats). Deliverables copied into the
worktree: `tests/`, `skills/e2e-testing/`, `agents/e2e-runner.md`,
`scripts/tests/ac-030-e2e-skill-agent.bats`, modified `docs/TESTING.md` +
`AGENTS.md`, `specs/`.

**Verifier judgment:** the Coder's environmental claim is CONFIRMED by
independent method. In a CI-equivalent environment (clean checkout replica, no
`JUDGMENT_*` shell vars, no gitignored credential files) the full suite — repo
plus all spec-030 tests — is **green, 360/360, exit 0**. The 8 failures on this
machine split cleanly into two machine-local causes, each isolated by a
controlled experiment: (1) 4× AC-028 — `JUDGMENT_BACKEND=local` exported in the
shell (proven: fails at pristine HEAD without deliverables; passes with
deliverables when the vars are unset); (2) 4× agent-env/AC-001-05 — the
gitignored `config/agent.local.env` real-credential file on disk (proven: does
not fail in a worktree lacking the file; every violation line names that file
only). Neither cause touches a spec-030 deliverable. No test is skipped or
silently disabled: the dirty-env run and the clean run both execute 360 tests.

## Evidence: complexity gate

command: python3 /tmp/cc-count-030.py tests/ac-030-lib.sh tests/AC-030-01.sh tests/AC-030-02.sh tests/AC-030-03.sh tests/AC-030-04.sh tests/AC-030-05.sh tests/AC-030-06.sh tests/AC-030-07.sh scripts/tests/ac-030-e2e-skill-agent.bats  (decision-point counter mirroring check-code-principles.sh's awk heuristic: word-boundary if/for/while/case + && + || per function, FAIL at >6; KISS at >20 body lines)
exit: 0
at: 2026-10-14T14:53:40Z

```
 CC lines  function @ file:line
  6    15  u_030_07_no_secrets @ tests/AC-030-07.sh:123
  6    10  u_030_06_no_half_wiring @ tests/AC-030-06.sh:89
  6    10  t6_wired_checks @ tests/AC-030-06.sh:61
  5     7  u_030_07_deliverables_clean @ tests/AC-030-07.sh:108
  5     8  u_030_02_no_secrets @ tests/AC-030-02.sh:121
  5     9  s_030_04_01 @ tests/AC-030-04.sh:10
  5    10  s_030_02_03 @ tests/AC-030-02.sh:28
  (…73 more functions, all CC ≤ 4)
functions measured: 80  worst CC: 6  violations(CC>6): 0  KISS(>20 lines): 0
```

Scope note: `scripts/check-code-principles.sh` audits only `*.java|go|ts|tsx|js|jsx`
(its `find` at lines 307–309) — shell/bats files are outside its scan, so the
Refactorer's shell-file claim was re-measured with a counter mirroring the
script's exact heuristic (documented at script lines 11–13: if/for/while/
switch/case/catch/&&/||/ternary, threshold >6). The only spec-030 file inside
the script's own scope, `skills/e2e-testing/assets/e2e.config.example.ts`, is
covered by the design-principles run below (zero findings).

**Refactorer claim verified: 0 violations.** Worst measured function CC = 6
(within the ≤6 bound). The extracted helpers the Refactorer introduced
(`t6_wired_checks`, `t7_ids_clause`, `t7_phrase_clause`) each sit at ≤6 with
explanatory comments citing the bound. CI's real shell linter (self-ci.yml
lines 214–220: `shellcheck scripts/*.sh templates/*.sh`) does not cover
`tests/` or `scripts/tests/` and no spec-030 file changes its scope;
shellcheck is not installed on this machine, CI remains the authority for that
gate — recorded, not a blocker (out of spec-030's declared gate set).

## Evidence: design-principles gate

command: scripts/check-code-principles.sh .
exit: 0
at: 2026-10-14T14:54:17Z

```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: "directBrokerCall", /data: { name }, /}); /node,
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
✔ Design-principles check: 0 FAIL(s), 14 WARN(s).
  WARNs are review hints — verify each before merging.
```

JSON transcript:

command: scripts/check-code-principles.sh . --json
exit: 0
at: 2026-10-14T14:54:35Z

```
tier: mvp
gates: ['complexity', 'dry', 'yagni', 'solid', 'component-per-file', 'property-tests']
fails: []
warns: 14
warn files: ['./ci/templates/archunit/OutboxArchRules.java', './ci/templates/archunit/SagaArchRules.java', './ci/templates/eslint-saga-rules/saga-compensation.js', './ci/templates/go-saga-lint.go']
```

**0 FAIL. All 14 WARNs are in `ci/templates/*`** — exactly matching the
baseline claim (14 pre-existing WARNs in ci/templates). **No FAIL or WARN
references any spec-030 file.** Per the Stop-and-Ask matrix the WARNs are
recorded and flagged to the Architect; they do not stop the pipeline.

## Evidence: scenario-to-behavior spot check

command: 4 scenario spot checks (a) AC-030-07-03, (b) AC-030-04-07↔AC-030-07-03 conflict, (c) bats-wrapper mutation test, (d) AC-030-06 both branches + T6-literal-wiring claim — commands and raw outputs below
exit: 0
at: 2026-10-14T15:00:12Z

### (a) AC-030-07-03 — holistic hygiene implementation judged FAITHFUL (with recorded divergence)

The scenario requires: check-model-env exit 0, no literal model/provider ids in
any tracked file (full-repo grep for `gpt-|claude-|gemini-|openai/|anthropic/|google/|mistral/`,
carve-outs: node_modules, .git, commented examples in config/model.local.env.example),
and no "re-run until green" phrasing under skills/ or agents/.

The Coder implemented it as: strict zero-tolerance id scan of every spec-030
deliverable (`u_030_07_deliverables_clean`, no exclusions) + tracked-tree scan
(`t7_ids_clause`) with a commented allow-list of 4 pre-existing files + an
opencode.json provider-region carve-out using the same `sed` as
check-model-env.sh's own literal scan.

Independent verification of the allow-list (all pre-existing, unchanged):

command: git grep -niE '<id patterns>' -- . ':(exclude)opencode.json' | cut -d: -f1 | sort | uniq -c  + per-file comparison against git show HEAD:<file>
exit: 0
at: 2026-10-14T15:00:12Z

```
      2 CHANGELOG.md
      1 scripts/sync-qwen-settings.sh
      1 skills/hallmark/references/assets.md
      1 skills/hallmark/references/custom-craft.md
CHANGELOG.md HEAD=2 WT=2 SAME
scripts/sync-qwen-settings.sh HEAD=1 WT=1 SAME
skills/hallmark/references/assets.md HEAD=1 WT=1 SAME
skills/hallmark/references/custom-craft.md HEAD=1 WT=1 SAME
outside-provider-hits=0        (opencode.json)
provider-region-hits=1 total-in-file  → line 20: "baseURL": "https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic/v1"
```

Hit content: CHANGELOG.md = historical release notes quoting a retired pin;
sync-qwen-settings.sh:48 = an API endpoint URL path (`/apps/anthropic/v1`
inside a string replace), not a model id; hallmark references = third-party
`ai.google.dev/gemini-api` doc URLs; opencode.json = the single provider-block
baseURL. All five exist identically at pristine HEAD; spec-030 introduced zero
new hits.

Judgment: **faithful.** (1) The provider carve-out is not a test invention —
it is the repo's own authoritative semantics: check-model-env.sh (which this
same scenario requires to exit 0) defines a literal id as anything *outside*
the provider block, and docs/SPEC_PIPELINE.md §PR review model wiring declares
provider blocks operator config (ADR 0002/0003). Scanning opencode.json's
provider region would contradict the scenario's own first clause. (2) The
allow-list divergence from the scenario's literal carve-out list is forced:
the 5 hits predate the spec in files outside every T1–T7 file list, and T7 is
"Files touched: none (verification only)"; the Stop-and-Ask matrix says
out-of-scope findings are recorded, never fixed. The test compensates exactly
where the scenario's intent lives: any *new* hit outside the documented
pre-existing set fails `t7_ids_clause`, and every spec-030 deliverable is held
to strict zero tolerance with no exclusions. (3) Recorded caveat:
`t7_ids_clause`/`t7_phrase_clause` use `git grep`, which scans tracked files
only — while the deliverables are uncommitted they are covered instead by the
file-level strict scans (`u_030_07_deliverables_clean`, `s_030_01_12`,
`s_030_02_06`, `s_030_04_08`) and by the Verifier's own working-tree scan
below; after the PR Opener commits, git grep covers them too. The
working-tree scan (grep -r over skills/ agents/, untracked included) found
zero phrase hits and zero id hits — the scenario's outcome holds now.

### (b) AC-030-04-07 ↔ AC-030-07-03 conflict resolution judged CORRECT

AC-030-04-07 requires the phrase "re-run until green" to be *stated as
forbidden* in agents/e2e-runner.md; AC-030-07-03 forbids the literal phrase
from *existing* anywhere under agents/. Both can only hold if the agent names
the prohibition without the contiguous literal string.

agents/e2e-runner.md line 100 (verbatim):

```
- Any phrasing that treats a suite as something to re-run *"until green"* is forbidden as an operating instruction: every re-run is a counted attempt under the budget above (docs/SPEC_PIPELINE.md §Remediation budget).
```

command: grep -rniE 're-run until green' skills agents   (naive whole-working-tree grep, untracked included)
exit: 1
at: 2026-10-14T14:56:01Z

```
phrase hits: NONE
```

The semantic content the scenario demands is fully present: the phrasing is
named (*"until green"* re-run framing), declared forbidden as an operating
instruction, and paired with "every re-run is a counted attempt" plus the
§Remediation budget citation. Test `s_030_04_07`'s assertion
(`until green[^.]*forbidden|forbidden[^.]*until green`) matches this
construction, and the remaining 04-07 requirements were read and confirmed
present: ground truth from `.e2e/failures/` + `.e2e/report.json` after every
run (lines 51–56, "The one rule"), never assume green (51–56), max 3 fix
rounds per failing file (94–96), framework budgets as inner bound (97–99).
The naive agents/ grep passes (zero hits, exit 1 = no match). Note:
AC-030-04-08's "only as forbidden" wording could be read as permitting the
literal phrase in a prohibition; 07-03's zero-tolerance is stricter, and the
implementation satisfies the stricter reading of both. Judgment: **faithful**.

### (c) bats wrapper genuinely executes the underlying bash scenario — PROVEN by mutation

command: sed -i 's/--strict-cache/STRICT_FLAG_REMOVED/g' skills/e2e-testing/references/running-debugging.md && bats --tap --filter "AC-030-02-06" scripts/tests/ac-030-e2e-skill-agent.bats   (in the /tmp/ver030-head scratch worktree, never the live repo; file restored after)
exit: 1
at: 2026-10-14T14:58:30Z

```
=== MUTATED: --strict-cache removed from running-debugging.md ===
1..1
not ok 1 AC-030-02-06: running-debugging.md content coverage
# (from function `run_scenario' in file scripts/tests/ac-030-e2e-skill-agent.bats, line 22,
#  in test file scripts/tests/ac-030-e2e-skill-agent.bats, line 107)
#   `run_scenario 02 AC-030-02-06' failed
MUTATED_EXIT=1
=== RESTORED ===
1..1
ok 1 AC-030-02-06: running-debugging.md content coverage
RESTORED_EXIT=0
```

Removing one scenario-required token from one deliverable flips exactly the
corresponding @test to `not ok`; restoring it flips back to `ok`. The wrapper
is not vacuous — it dispatches to `bash tests/AC-030-02.sh AC-030-02-06` and
asserts exit 0 + no FAIL line. The repo's own anti-vacuity gate agrees:
`scripts/check-bats-assertions.sh` → "PASS: 43 bats file(s), no vacuous
assertions" (below).

### (d) AC-030-06 conditional scenario — BOTH branches verified, T6-literal-wiring claim PROVEN

**Skipped branch (live tree):** `grep -c '"e2e-runner"' opencode.json` → `0`
(no entry; task skipped per its explicit conditional). Run at 14:42:04Z:
`RESULT AC-030-06: passed=4 failed=0` with N/A-by-default PASS lines for
-01/-02 exactly as the scenario's conditional note prescribes, and
check-model-env exit 0 asserted in-branch (required in both branches).

**Wired branch (scratch worktree, T6 wired):**

command: cd /tmp/ver030-head && bash tests/AC-030-06.sh   (after wiring e2e-runner into opencode.json + config/model.local.env.example + scripts/model-env.vars.sh + templates/opencode.json.bridge)
exit: 0
at: 2026-10-14T14:57:10Z

```
PASS AC-030-06-01: e2e-runner entry is exactly the {env:SPEC_E2E_RUNNER_MODEL} reference
PASS AC-030-06-01: no literal model/provider id in the e2e-runner entry
PASS AC-030-06-02: SPEC_E2E_RUNNER_MODEL defined with a default value
PASS AC-030-06-02: definition follows the comment+value pattern
PASS AC-030-06-03: model_env_var_for_agent maps e2e-runner -> SPEC_E2E_RUNNER_MODEL
PASS AC-030-06-03: roster arrays updated in scripts/model-env.vars.sh
PASS AC-030-06-03: scripts/check-model-env.sh exits 0 (required in both branches)
PASS unit T6: wiring is consistent (all-three or none): oc=1 ex=1 vars=1
RESULT AC-030-06: passed=8 failed=0
```

**Coder's mechanical claim — independently proven.** Wiring T6 *exactly as
literally listed* (only its 3 files: opencode.json, config/model.local.env.example,
scripts/model-env.vars.sh — bridge template untouched):

command: bash scripts/check-model-env.sh   (in /tmp/ver030-head, T6-wired-as-listed)
exit: 1
at: 2026-10-14T14:56:50Z

```
FAIL templates/opencode.json.bridge: agent e2e-runner missing
✘ check-model-env: 1 violation(s).
```

Mechanism confirmed from source: check-model-env.sh check 4 runs
`validate_model_wiring` over `templates/opencode.json.bridge`, whose roster
loop (`for agent in "${MODEL_ENV_AGENTS[@]}"`) fails on any roster agent
missing from the file. Adding `e2e-runner` to `MODEL_ENV_AGENTS` (T6's own
instruction) without editing the bridge template (not in T6's file list) makes
T6's own acceptance criterion "scripts/check-model-env.sh exits 0"
unsatisfiable. Adding the bridge entry (4th file) → exit 0 (verified:
`PASS check-model-env: all model values are {env:SPEC_*_MODEL} references…`).
**The skip is justified, not lazy**: T6 as literally written is internally
inconsistent, and the scenario's own conditional ("if skipped, all three
scenarios are considered N/A and pass by default") is the specified escape
hatch. The test detects the branch mechanically (`wired()`), judges each
branch correctly, and `u_030_06_no_half_wiring` blocks the half-wired state.
Recorded for the Architect/human: if a future human decides to wire
`e2e-runner`, the change needs 4 files (T6's 3 + `templates/opencode.json.bridge`).

## Additional claimed gates — re-executed

command: scripts/check-skills.sh
exit: 0
at: 2026-10-14T14:54:38Z

```
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
```

(1 WARN — pre-existing `skills/hallmark`, not a spec-030 file; `skills/e2e-testing/SKILL.md` is 113 lines. Recorded, not blocking.)

command: scripts/check-orchestration.sh
exit: 0
at: 2026-10-14T14:54:39Z

```
Checking docs/ and language-specific/ references (agents/)...

All orchestration references valid.
```

command: bash scripts/check-model-env.sh
exit: 0
at: 2026-10-14T14:54:55Z

```
PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired, bridge template checked.
```

(Tooling note: invoking `scripts/check-model-env.sh` directly exits 126 — the
file is tracked at mode 100644, no execute bit, at HEAD `8af331a`; pre-existing,
not a spec-030 change. Every caller in the repo, including the spec-030 tests,
invokes it via `bash`, which exits 0.)

command: scripts/check-bats-assertions.sh
exit: 0
at: 2026-10-14T14:54:39Z

```
PASS check-bats-assertions: 43 bats file(s), no vacuous assertions.
```

## No-literal-model-id and no-secrets constraints over the new deliverables

command: grep -rniE '<7 id patterns, runtime-assembled>' skills/e2e-testing tests agents/e2e-runner.md scripts/tests/ac-030-e2e-skill-agent.bats + git diff -U0 HEAD -- docs/TESTING.md AGENTS.md added-lines scan + credential-shaped literal scan (ghp_/sk-/AKIA/-----BEGIN/api_key|token|secret|password assignments)
exit: 0
at: 2026-10-14T14:56:01Z

```
file hits: NONE
diff-added hits: NONE
secret hits: NONE
phrase hits: NONE      (forbidden re-run phrase, skills/ + agents/ whole working tree)
```

All spec-030 deliverables — skill tree, agent file, bash tests, bats wrapper,
and both doc diffs (added lines only) — are clean of literal model/provider
ids, credential-shaped literals, and the forbidden phrase.
`config/model.local.env.example` carries concrete default model ids by repo
policy (AGENTS.md §Model Configuration) and matches none of the scenario's
seven id patterns — consistent, no finding.

## No unaccounted behavior (finding line, not a command)

Finding: **none — every deliverable element traces to 10-tasks.md /
20-acceptance.** Skimmed: `skills/e2e-testing/` (SKILL.md sections map 1:1 to
T1 criteria; 6 references map to T2 coverage lists; `assets/e2e.config.example.ts`
blocks map to T3 bullets — env-sourced models, port-0 + `{port}`, shell-less
argv `app.command`, budgets, cache modes, telemetry comment, tests glob, no
`.env` loading), `agents/e2e-runner.md` (frontmatter/permissions/sections map
to T4 criteria), doc diffs (map to T5), `tests/` + lib (test approach per the
10-tasks header; `u_*` unit checks each implement a T1–T7 acceptance bullet
the scenarios don't reach), bats wrapper (traceability requirement, cited
precedent). Two elaborations noted and judged traceable, not unaccounted: the
config example's `artifacts:`/`callbackUrl:` blocks (demonstrate the T2 ci.md
artifact criteria and reinforce the T3 port-0 pattern) and the agent's
"Full-suite mode (not your call)" bullet (elaborates T4's single-file poka-yoke
guidance). Neither adds behavior outside the tasks.

## Out-of-scope findings (recorded, NOT fixed — Stop-and-Ask matrix)

1. **Test hermeticity (environmental):** on this machine 8 repo-suite tests
   fail from machine-local state — `JUDGMENT_*` vars exported into every
   direnv-loaded shell (from gitignored `config/model.local.env`) break 4
   AC-028 typed-judgment tests that assume an unconfigured environment, and
   the gitignored `config/agent.local.env` credential file (required locally by
   AGENTS.md) breaks `check-no-hardcoded-secrets.sh` and hence 4
   agent-env/AC-001-05 tests. The suite is not hermetic against the very
   per-machine setup the repo mandates. Proven environmental above; CI is
   unaffected. Follow-up candidate: make those tests scrub `JUDGMENT_*` and
   scan a tracked-tree replica (as spec-030's own `u_030_07_no_secrets` does).
2. **Secret scanner echoes secrets:** `check-no-hardcoded-secrets.sh` prints
   matched credential *values* verbatim to stdout (observed: live `ghp_…` and
   API-key values from `config/agent.local.env` appeared in terminal output and
   would land in any captured log). Redacted in this report. Follow-up
   candidate: print file:line + pattern name only.
3. **Scanner dir coverage:** `check-no-hardcoded-secrets.sh` scans `agents,
   commands, scripts, docs, .github, config, templates, ci` — not `skills/` or
   `tests/`. Consequence for spec-030: `u_030_07_no_secrets`'s replica scan
   cannot actually see the `skills/e2e-testing/` or `tests/` copies it makes
   (its agents/ and scripts/tests/ copies are scanned). The Verifier's
   independent scan (above, zero hits over all deliverables) confirms the
   outcome the unit claims, so no false green today; the unit's coverage claim
   is nonetheless wider than its mechanism. Follow-up candidate: widen the
   scanner's dir list or the unit's scan.
4. **`scripts/check-model-env.sh` lacks the execute bit** (tracked mode 100644
   at HEAD, unlike sibling check scripts) — direct invocation exits 126; all
   repo callers use `bash`. Pre-existing; cosmetic.
5. **Refactorer-recorded SKILL.md/references duplication mandate-conflict**
   (as relayed by the orchestrator; the Refactorer's own record governs):
   Agent-Skills progressive-disclosure rules push detail into references/
   while some acceptance criteria require specific content in SKILL.md itself —
   recorded here for the Architect per the relay; the delivered files satisfy
   both `check-skills.sh` and every scenario, so no gate impact.
6. **Traceability script granularity:** `check-scenario-traceability.sh`'s ERE
   truncates scenario ids to task level (`AC-030-NN`) on both the heading and
   reference side, so check 1 cannot distinguish which `-MM` scenario is
   cited. The bats wrapper's full 42-ID citation exceeds the script's
   granularity; no gap for spec-030, but a scenario-level typo inside a cited
   task would pass the script. Informational.

## Overall verdict

**PASS** — every gate ran and produced no findings against spec-030:
traceability exit 0 (42/42 IDs cited and resolving), full suite green
(360/360) in a CI-equivalent environment with the 8 machine-local failures
independently proven environmental, complexity 0 violations (worst CC 6 ≤ 6),
design-principles exit 0 (0 FAIL, 14 WARNs all pre-existing ci/templates),
spot checks (a)–(d) faithful, additional gates (check-skills,
check-orchestration, check-model-env, check-bats-assertions) all exit 0, and
zero literal model ids / secrets / forbidden phrasing in the deliverables.
Architect (stage 5a) may proceed.
