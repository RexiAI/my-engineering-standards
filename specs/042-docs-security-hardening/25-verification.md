# 042-docs-security-hardening — verification

**attempt 1, phase 1 (pre-PR)**

Verifier: independent re-execution of the Coder's and Refactorer's claims.
Everything below was run in this worktree
(`/home/dbueno/.local/share/opencode/worktree/471827/spec-042`) at the timestamps
recorded. Nothing here is transcribed from a prior stage's self-report.

**Verdict: PASS.** No gate produced a finding; no gate failed to run.

| # | Gate | Verdict | Gate ID |
|---|---|---|---|
| 1 | Scenario traceability | PASS | `traceability` |
| 2 | Full test suite | PASS | `test-suite` |
| 3 | Complexity gate | PASS | `complexity` |
| 3.5 | Design-principles gate | PASS (0 FAIL / 58 pre-existing WARN) | `design-principles` |
| 4 | Scenario-to-behavior spot check | PASS | `spot-check` |
| 5 | No unaccounted behavior | PASS | `unaccounted` |

## Scope note — behavior vs structural

This spec is a documentation / repo-config / gate-config spec: it adds no
runtime code path. Its 12 tasks split as

- **behavior (content contract)** — tasks 1–9: new `docs/SECURITY.md` sections
  (AC-042-01…05), `docs/OFFICIAL_REFERENCES.md` pins (AC-042-06), the
  `docs/CI_CD.md.md` reference repair (AC-042-07), the PR-only bootstrap example
  (AC-042-08), and the advisory/enforced split in `AGENTS.md` (AC-042-09). "Behavior"
  here means the document states the rule, and the test reads the rule out of the
  document.
- **structural (gate + harness config)** — tasks 10–12: the 200-line cap and
  grandfather map in `scripts/check-skills.sh` (AC-042-10), the repo-level
  `permission.bash` block in `opencode.json` (AC-042-11), and the `.gitignore` +
  `git rm` hardening (AC-042-12). These change what an existing gate or the
  harness does, so they are verified behaviorally at the fixture level
  (temporary fixture roots, real `check-skills.sh` invocations, real
  `git check-ignore` / `git ls-files`), not by grepping the script source.

The three `opencode.json` / `.gitignore` / `git rm rb_*` edits the orchestrator
flagged are all AC-042-11/12 scope — see §Spot check and §Structural gates below.

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-01T15:05:45Z

{
  "checks": [1, 2],
  "passes": ["AC-042-01 — traced to a test", "AC-042-02 — traced to a test", "AC-042-03 — traced to a test", "AC-042-04 — traced to a test", "AC-042-05 — traced to a test", "AC-042-06 — traced to a test", "AC-042-07 — traced to a test", "AC-042-08 — traced to a test", "AC-042-09 — traced to a test", "AC-042-10 — traced to a test", "AC-042-11 — traced to a test", "AC-042-12 — traced to a test"],
  "fails": []
}

The script matches `AC-NNN-NN` granularity only, so it proves each *task* is
traced, not each *scenario*. Independently re-checked at 4-part granularity:

check: grep -h '^## AC-042-' specs/042-docs-security-hardening/20-acceptance/*.md | wc -l  →  53
check: grep -h '^@test "AC-042-' scripts/tests/ac-042-*.bats | wc -l              →  53
check: comm -23 <scenario IDs> <test IDs>   →  (empty: no scenario without a test)
check: comm -13 <scenario IDs> <test IDs>   →  (empty: no test citing a nonexistent scenario)
check: uniq -d over test IDs                →  (empty: no duplicate IDs)

All 53 scenarios in `20-acceptance/` map one-to-one onto 53 tests; no orphans in
either direction. AC-042-01…12 all present.

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-01T15:19:40Z
(run window 2026-11-01T15:13:51Z → 2026-11-01T15:19:40Z)

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..801
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
[... 795 more ok lines ...]
ok 213 AC-042-11-01: the config stays valid and the model wiring is untouched
ok 214 AC-042-11-02: the denied commands are blocked
ok 215 AC-042-11-03: commit and push are asked, not allowed silently
[...]
ok 799 unit: a cap smaller than the marker still never exceeds the cap
ok 800 unit: state exactly at the cap is not truncated and emits no reason
ok 801 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

Counted from that log: plan line `1..801`, `801` lines starting `ok `, and
`grep -E '^not ok|# skip'` → no matches. No test skipped, disabled, or silently
not run; the 801 total matches the Coder's claim. A second, earlier full run of
the same command (2026-11-01T15:05:51Z start) also exited 0; the block above is
the captured one.

## Evidence: complexity gate

command: shellcheck scripts/check-skills.sh
exit: 0
at: 2026-11-01T15:11:59Z

(no output)

`scripts/check-skills.sh` is the only `.sh` this spec changes (the rest of the
diff is Markdown, JSON, .gitignore and `.bats` files).

command: ./scripts/check-code-principles.sh --gates complexity --json
exit: 0
at: 2026-11-01T15:11:59Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}

Zero FAILs; the three WARNs name files this spec does not touch (`ci/templates/`,
`skills/hallmark/site/examples/`), so they are pre-existing and not attributable
to this diff.

Repo-wide `shellcheck scripts/*.sh templates/*.sh` exits `1` with 1162 lines of
pre-existing findings and **zero** findings naming `scripts/check-skills.sh`
(`grep -c 'check-skills' <log>` → 0). That CI step is `continue-on-error: true`
in `.github/workflows/self-ci.yml`, i.e. advisory, and is unchanged by this spec.

## Evidence: design-principles gate

command: ./scripts/check-code-principles.sh --json
exit: 0
at: 2026-11-01T15:11:42Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [ ...58 entries, reproduced verbatim below... ]
}

Summary line, verbatim:

✔ Design-principles check: 0 FAIL(s), 58 WARN(s).
  WARNs are review hints — verify each before merging.

Baseline comparison (run against a pristine `git archive HEAD` tree in
`/tmp/opencode/baseline042`, since deleted):

BASELINE fails=0 warns=58
diff <baseline WARN set> <current WARN set>   →  IDENTICAL_WARN_SETS

`jq '[.warns[] | select(.file|test("check-skills|ac-042|test_helper|test-helper"))] | length'`
→ `0`. **This spec introduces no design-principles finding of either severity.**
All 58 WARNs are pre-existing repo debt, reproduced verbatim for the Architect:

WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38
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
WARN Comments: section-divider comment (./scripts/init-ci.sh:43)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:39)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:49)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:67)
WARN Comments: commented-out code (./scripts/token-stats.sh:10)
WARN Comments: commented-out code (./scripts/guard-env.sh:21)
WARN Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)
WARN Comments: commented-out code (./scripts/check-security-hardening.sh:39)
WARN Comments: commented-out code (./scripts/judgment-preflight.sh:16)
WARN Comments: commented-out code (./scripts/check-model-env.sh:30)
WARN Comments: commented-out code (./scripts/gate-stats.sh:20)
WARN Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)
WARN Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)
WARN Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
WARN Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)
WARN Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)
WARN Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)

WARN disposition per `docs/SPEC_PIPELINE.md §Stop-and-Ask`: recorded, not a stop;
flagged to the Architect. None is on a file this spec changed.

## Evidence: scenario-to-behavior spot check

command: bats --tap scripts/tests/ac-042-*.bats scripts/tests/test-helper.bats scripts/tests/check-skills.bats
exit: 0
at: 2026-11-01T15:12:36Z

1..68
ok 1 AC-042-07-01: the tag bullet cites the real document
[...]
ok 23 AC-042-12-03: gate-run capture dumps are ignored and untracked
ok 24 AC-042-12-04: the telemetry ledger is not swept up
ok 25 AC-042-12-05: the secret gates still pass
[...]
ok 48 AC-042-05-05: audience and issuer are validated; the section closes the block
ok 54 AC-042-10-05: a grandfathered guide that grows fails
ok 68 check-skills: a skills/ guide at exactly 500 lines is not warned

A passing test with the right ID proves nothing on its own. Two scenarios picked
and read line by line against their Given/When/Then, plus two more read during
the AC-042-11/12 review the orchestrator asked for:

**AC-042-12-03 — gate-run capture dumps are ignored and untracked.** Then-clauses:
`.gitignore` has a literal `rb_*` entry; `git check-ignore --no-index rb_check-skills`
succeeds; `git ls-files` returns no `rb_*`; none of the eight named files exists in
the worktree. The test asserts all four (`grep -qxF 'rb_*'`, `git check-ignore -q`,
`git ls-files` output checked against `rb_check`/`rb_cpr2`/`rb_model-env.selftest`,
and `[ ! -e ]` per file). Re-run myself, independently of the test:

run: git check-ignore --no-index --verbose rb_check-skills
  .gitignore:50:rb_*	rb_check-skills
run: git ls-files | grep -c '^rb_'
  0
run: ls rb_*
  ls: cannot access 'rb_*': No such file or directory
run: git ls-files -- runs.jsonl
  runs.jsonl
Plus the tracked-template guard AC-042-12-02 needs (a new `.env.*` pattern that
swallowed a template would be a real defect): every tracked dotenv-ish path —
`config/agent.local.env.example`, `config/model.local.env.example`,
`templates/.envrc.child`, `templates/.envrc.example` — returns "not ignored",
while `.env.staging`, `.env.production.local` and `rb_check-skills` are ignored.
`.envrc` remains ignored by its own pre-existing entry. **Assertions match the
scenario; no false green.**

**AC-042-10-05 — a grandfathered guide that grows fails.** Then-clauses: exit 1, a
`[FAIL]` line naming `language-specific/java/SKILL.md`, and the same ceiling for
python 271 / rust 241 / go 223. The test loops all four (`ceiling + 1` lines each)
asserting `status -eq 1`, the FAIL line, and the measured count. Re-ran the gate by
hand on a scratch fixture root (`/tmp/opencode/skillfix.*`, since deleted) holding a
283-line java guide and a 201-line new guide:

run: bash scripts/check-skills.sh /tmp/opencode/skillfix.XXXX
exit: 1
Checking SKILL.md files...
[FAIL] language-specific/java/SKILL.md — Body has 283 lines (> grandfathered ceiling of 282 for this guide — it is frozen at its current size and may not grow; move detail to a sibling file such as PATTERNS.md or TESTING.md, then remove its grandfather entry)
[FAIL] language-specific/foo/SKILL.md — Body has 201 lines (> 200-line limit for language-specific/*/SKILL.md — move detail to a sibling file such as PATTERNS.md or TESTING.md)

2 error(s) found in SKILL.md files (0 warning(s))!

The grandfather map is exact-path (`repo config`-adjacent unit test
`check-skills: the grandfather map is exact-path, not a wildcard` covers the
wildcard confusion), and the real guides measure exactly at their ceilings:
`wc -l language-specific/*/SKILL.md` → java 282, python 271, rust 241, go 223.
**Assertions match the scenario.**

Also read against their scenarios while reviewing the flagged edits:
`AC-042-11-04` (asserts `keys[0] == "*"` and `max(ask) < min(deny)` — a real
ordering assertion, not a presence check) and `AC-042-05-05` (asserts the JWT
heading's line number is after `## Input Validation` and the four sibling
sections and before `## Upstream Error Responses Must Not Reach the Client`).

## No unaccounted behavior

Finding line, not a command — `docs/SPEC_PIPELINE.md §The five Verifier
checks` says this skim is not a runnable check:

Finding: none. Every changed path maps to a task:

| Changed path | Task / AC |
|---|---|
| `docs/SECURITY.md` | 1–5 / AC-042-01…05 |
| `docs/OFFICIAL_REFERENCES.md` | 6 / AC-042-06 |
| `AGENTS.md` | 7 + 9 / AC-042-07, AC-042-09 |
| `docs/CI_CD.md` | 8 / AC-042-08 |
| `scripts/check-skills.sh` | 10 / AC-042-10 |
| `docs/AGENTS_AND_SKILLS.md` | 10 + 11 docs clauses / AC-042-10-07, AC-042-11-05 |
| `opencode.json` | 11 / AC-042-11 |
| `.gitignore`, 8 × `git rm rb_*` | 12 / AC-042-12 |
| `scripts/tests/ac-042-*.bats` (6 files) | the 53 scenario tests |
| `scripts/tests/check-skills.bats` (+5) | unit coverage for AC-042-10's cap (Refactorer) |
| `scripts/tests/test_helper.bash` (+`md_section`, `make_skill`) | Refactorer dedup of the doc-section / fixture extraction |
| `scripts/tests/test-helper.bats` (new) | unit tests for those two helpers |
| `specs/042-docs-security-hardening/` | spec artifacts |

Recorded, not findings:

- The Refactorer's `md_section` / `make_skill` helpers are test *infrastructure*
  shared by the doc assertions and the line-cap fixtures; `test-helper.bats` covers
  them (4 + 3 cases) so the extraction is itself verified.
- No file under `agents/` or `commands/` was touched (`git status --porcelain |
  grep -E '^[MADRU?]+ +(agents|commands)/'` → empty), which is the spec's global
  constraint; Task 9's `AGENTS.md` edits are the repo instruction file, not
  `agents/`, and need no ADR.
- Working tree is dirty only with this spec's own uncommitted work (the PR Opener
  commits later); nothing outside `specs/042-docs-security-hardening/` and the
  task-listed paths is touched.

## Supplementary gates (task-list global constraints)

All run at 2026-11-01T15:10Z–15:12Z in this worktree:

| Command | exit | Result |
|---|---|---|
| `make validate-all` | 0 | all 36 files present, cross-references valid, `All SKILL.md files valid (1 warning(s))` |
| `./scripts/check-bats-assertions.sh` | 0 | `77 bats file(s), no vacuous assertions` |
| `./scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `bash scripts/check-model-env.sh` | 0 | `PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired, bridge template checked.` |
| `./scripts/check-no-hardcoded-secrets.sh` | 0 | `PASS ... no hardcoded credential values in agents, commands, scripts, docs, .github, config, templates, ci.` |
| `./scripts/check-gate-consistency.sh` | 0 | `Gate consistency check: PASSED` |
| `./scripts/check-security-hardening.sh` | 0 | `Security hardening check: every check passed.` |
| `./scripts/check-skills.sh` | 0 | `All SKILL.md files valid (1 warning(s))` — the one warning is `skills/hallmark/SKILL.md` at 562 lines (>500), i.e. the `skills/` warning AC-042-10-06 says must be preserved |
| `bash scripts/guard-env.sh` | 0 | `PASS guard-env: no config/agent.local.env in the scanned set (tracked mode).` |
| `python3 -m json.tool opencode.json` | 0 | `opencode.json` parses |

Two tooling notes, both pre-existing and **not** spec-042 findings:

- `scripts/check-model-env.sh` and `scripts/guard-env.sh` are mode `100644` in the
  index (last touched in spec 031's commit), so `./scripts/x.sh` returns
  `126 Permission denied`; invoked as `bash scripts/x.sh` (the form the ACs and
  self-ci use) both exit 0. No agent may change file modes to work around this —
  it is a follow-up finding, not a gate failure here.
- `./scripts/check-audit-trail.sh 042-docs-security-hardening` currently exits 1
  naming `missing 25-verification.md` and `missing 30-report.md`. That is the
  expected in-flight state: this report supplies the first, the Mutation Runner
  supplies the second. It is recorded so the PR Opener's pre-push run of the same
  gate is expected to pass, not as a finding against the Coder.

## Out-of-scope findings carried from the task list (not fixed here)

Recorded so they are not lost, per `§Stop-and-Ask` "Out-of-scope finding":

- `docs/GIT_WORKFLOW.md §Adding the Standards Submodule` (lines 179–182) still has
  the commit-then-push shape Task 8 fixed in `docs/CI_CD.md`.
- `make validate-docs` / `validate-refs` use the regex `docs/[A-Z_]+\.md`, which
  matches the valid prefix of `docs/CI_CD.md.md` and therefore cannot catch the
  defect Task 7 repaired.
- `docs/OFFICIAL_REFERENCES.md` still has no `## Pages consulted` sections for
  Java, Go, or React Native.

One independent fact-check the ACs do not require but the pin's truth depends on:
`https://registry.npmjs.org/react-native/0.88.1` resolves, `version 0.88.1`,
`engines.node ^22.13.0 || ^24.3.0 || >= 26.0.0`, `peerDependencies.react ^19.3.0`.
The row in `docs/OFFICIAL_REFERENCES.md` states exactly that. Java 21 matches
`language-specific/java/SKILL.md` ("Java version: 21"); the Go row's "resolved from
`go.mod`" is the documented intent, not a version claim.

