# 25-verification — spec 031-vercel-deploy-lane

- Verifier run: attempt 1, phase 1 (first full run; no prior BLOCK, phase-1 and
  phase-2 budgets unused: SPEC_LOOP_COUNT=1, SPEC_PHASE1_RETRIES=0, SPEC_PHASE2_RETRIES=0)
- Branch verified: `main` working tree (uncommitted stage 2/3 change set — the
  pipeline's designed state; PR Opener commits only after PASS per
  docs/SPEC_PIPELINE.md §Commit and push carve-out)
- Information barrier honored: `specs/*/00-informal.md` not read (none exists in
  this folder). Verified against `10-tasks.md` + `20-acceptance/` only.
- **Overall verdict: PASS** (all five checks green; details and two confirmed
  out-of-scope findings below)

## Check results

| # | Check | Result |
|---|---|---|
| 1 | Scenario traceability | PASS — exit 0, 60/60 traced, `fails: []` |
| 2 | Full test suite | PASS — exit 0, plan `1..473`, 473 ok, 0 not ok, 0 skipped |
| 3 | Complexity gate | PASS — `make lint` exit 0 (0 FAIL); shellcheck is CI-only (not installed locally, noted) |
| 4 | Design-principles gate | PASS for this change set — blame-scoped run (`-BaseRef HEAD`) exit 0, 0 FAIL / 0 WARN attributable; plain run exit 1 with 1 pre-existing FAIL + 16 pre-existing WARNs, all in files untouched by this change set (see below; script-is-authority: both transcripts reproduced) |
| 5 | Scenario-to-behavior spot check | PASS — 6 IDs across 5 files, assertions match Given/When/Then |
| — | No unaccounted behavior | PASS (finding line, §Findings) |

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-19T14:03:42Z

```
{
  "checks": [1, 2],
  "passes": ["AC-031-01 — traced to a test", "AC-031-02 — traced to a test", ... ,
    "AC-031-59 — traced to a test", "AC-031-60 — traced to a test"],
  "fails": []
}
```

(Representative excerpt of the JSON transcript; `passes` contains exactly 60
entries, all `AC-031-01` … `AC-031-60`, verified by parsing the full file:
`passes total: 60`, `AC-031 passes: 60`, `fails: []`. Independent recount of
unique IDs in `20-acceptance/`: `grep -ho "AC-031-[0-9]*" ... | sort -u | wc -l`
→ 60. Claim 2 confirmed: 60 live IDs, exit 0. Run form note: invoked as
`bash scripts/...` because several gate scripts are tracked without the execute
bit (`./scripts/x.sh` yields 126 — a file-mode artifact, not a gate failure.)

## Evidence: full test suite

command: bats scripts/tests/*.bats
exit: 0
at: 2026-10-19T14:06:50Z

```
1..473
...
ok 471 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 472 wire: non-numeric confidence is invalid, exits 10
ok 473 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts from the real TAP output: `grep -c "^ok"` → 473; `grep -c "^not ok"` → 0;
`grep -c "# skip"` → 0 (the 21 case-insensitive "skip" hits are words inside
test *names*, not TAP skip directives — nothing was skipped or disabled).
Claim 1 confirmed: 473 tests, 473 ok, 0 fail, exit 0.

## Evidence: complexity gate

command: make lint
exit: 0
at: 2026-10-19T14:10:19Z

```
lint:
Validating JSON files...
  [OK] language-specific/javascript/... (all OK)
Validating YAML files...
  [OK] .github/workflows/ci-vercel-production-verify.yml (incl. new workflow)
  [OK] ci/gitlab/frontend/ci-angular.yml
  [OK] ci/gitlab/frontend/ci-static.yml
  [OK] ci/gitlab/gitlab-ci.yml
Done.
```

`grep -c FAIL` over the full output → 0. `make lint` is this repo's real local
linter (JSON + YAML validation; the change set is bash/md/json/yml — no Go/Java/ESLint
surface). shellcheck is wired only in CI (`.github/workflows/self-ci.yml:230`)
and is **not installed locally** (`command -v shellcheck` → empty); the post-PR
CI check (phase 2) will exercise it. Cyclomatic complexity for the change set is
covered by the design-principles gate below (complexity gate in the blocking set).

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-19T14:07:59Z

```
tier: mvp
gates: [complexity, dry, yagni, solid, component-per-file, property-tests]
FAILS: 1
FAIL: Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10
WARNS: 16
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN: Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN: Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41
WARN: Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: "problem", /docs: { /description: /meta: {
WARN: Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: "directBrokerCall", /data: { name }, /}); /node,
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
WARN: Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {
WARN: Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN: Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

command: bash scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-10-19T14:10:15Z

```
tier: mvp
fails: 0
warns: 0
```

Attribution (claim 7 confirmed): every finding in the plain run lands in
`skills/hallmark/site/examples/cobalt-01/script.js` or `ci/templates/*` —
`git diff --name-only HEAD | grep -i "hallmark\|ci/templates"` → no match
(exit 1), i.e. none of those files is touched by this change set; the CC=10 FAIL
file is tracked and unmodified here. The blame-scoped invocation (`-BaseRef HEAD`,
the deterministic mechanism from `docs/changes/011-design-gate-blame-scoping.md`)
exits 0 with zero fails and zero warns: **zero findings are attributable to this
change set**. Per repo design, pre-existing debt in untouched files does not
block this change; per the Stop-and-Ask matrix the 16 WARNs are recorded here
and flagged to the Architect, not a stop. Both transcripts are reproduced as
emitted (script-is-authority); the WARN list above is verbatim from the JSON
`warns[].message` fields.

Property-tests gate: skipped by tier (mvp) — see §Conformance tier below; the
gate itself reports tier mvp and emits no property-test FAIL.

## Evidence: scenario-to-behavior spot check

command: sed -n reads of specs/031-vercel-deploy-lane/20-acceptance/{AC-031-production-deploy,AC-031-non-frontend-skip,AC-031-pipeline-doc-rewrite,AC-031-archive-ordering,AC-031-model-credential-wiring}.md and scripts/tests/ac-031-{production-deploy,non-frontend-skip,pipeline-doc-rewrite,archive-ordering,model-credential-wiring}.bats (targeted line ranges)
exit: 0
at: 2026-10-19T14:17:05Z

6 scenarios checked (≥4 required), across 5 different scenario files:

1. **AC-031-38** (production-deploy.md) — Scenario: workflow queries Vercel API,
   no deployment exists → records skip reason "Production deployment not found
   for commit <sha>" and exits 0. Test (`ac-031-production-deploy.bats:56`):
   seeds canned `{"deployments":[]}`, runs the real
   `scripts/verify-production-deploy.sh cafebabe999`, asserts `status -eq 0` and
   output contains `Production deployment not found for commit cafebabe999`.
   **Finding: assertions genuinely verify the stated behavior — real script
   execution, exact reason string, exit code. Match.**
2. **AC-031-42** (non-frontend-skip.md) — Scenario: spec-deployer on a
   non-frontend repo writes `40-deploy.md` with verdict SKIPPED and reason
   "Non-frontend repo — deploy verification not applicable". Test
   (`ac-031-non-frontend-skip.bats:31`): asserts `agents/spec-deployer.md`
   contains `Verdict: SKIPPED`, the exact reason string, and `exit cleanly`.
   **Finding: doc-content assertion — but the agent file IS the deliverable for
   an agent-prose contract (house pattern for agent specs); the runtime
   non-failure half of the behavior is separately covered by AC-031-43, which
   runs the real gate on a seeded SKIPPED `40-deploy.md` and asserts exit 0
   (`bats` test 90, ok). Match, with that noted split.**
3. **AC-031-49** (non-frontend-skip.md) — Scenario: no Vercel project linked →
   `40-deploy.md` verdict SKIPPED, reason "No Vercel project linked to this
   repository — manual setup required", pipeline does not fail. Test
   (`ac-031-non-frontend-skip.bats:86`): asserts the agent file carries the
   exact reason and "the pipeline does not fail"; the script-level equivalent
   (AC-031-39, `ac-031-production-deploy.bats:63`) unsets `VERCEL_PROJECT_ID`
   and seeds a 404, runs the real script, asserts exit 0 + reason. **Match —
   behavior verified at the script level, contract verified at the agent level.**
4. **AC-031-13** (pipeline-doc-rewrite.md) — Scenario: definition of done
   includes a numbered item requiring `40-deploy.md` with verdict or skip
   reason. Test (`ac-031-pipeline-doc-rewrite.bats:36`): extracts the real
   `## Definition of done` section of `docs/SPEC_PIPELINE.md` via the shared
   awk helper and asserts it contains `40-deploy.md`, `verdict`, `skip reason`,
   `Stage 5d`, `archive-spec.sh`, and that the superseded 5b item is gone
   (`! grep`). **Match — positive and negative assertions on real doc content.**
5. **AC-031-22** (archive-ordering.md) — Scenario: `archive-spec.sh <slug>`
   embeds `40-deploy.md` verbatim under `## 40-deploy.md`. Test
   (`ac-031-archive-ordering.bats:29`): full end-to-end — seeds a git repo,
   writes a known `40-deploy.md`, commits, runs the real `archive-spec.sh`,
   asserts the heading exists and `diff`s the embedded section against the
   expected bytes. **Match — strongest form: byte-level verbatim diff.**
6. **AC-031-06** (model-credential-wiring.md) — Scenario: `opencode.json` agent
   block contains `"spec-deployer": { "model": "{env:SPEC_DEPLOYER_MODEL}" }`,
   no literal model id. Test (`ac-031-model-credential-wiring.bats:11`): parses
   the real JSON with python3, asserts the exact env reference, and regex-checks
   the entry line for absence of any `provider/model` literal. **Match.**

No false greens found: no test merely cites an ID while asserting nothing; every
checked test asserts the scenario's exact strings/exit codes against real files
or real script executions.

## Findings (non-runnable checks and claims)

**No unaccounted behavior (check 5-skim): PASS — none found.** Every changed or
new file traces to a scenario group: verify-production-deploy.sh +
ci-vercel-production-verify.yml → AC-031-37..41; agents/spec-deployer.md →
AC-031-42..50; docs/adr/0008 → AC-031-58..60; check-audit-trail.sh →
AC-031-17..21; archive-spec.sh + check-specs-archived.sh → AC-031-22..27;
check-remediation-budget.sh → AC-031-28..36; SPEC_PIPELINE.md →
AC-031-07..16; opencode.json / config examples / model-env.* / templates bridge →
AC-031-01..06; DEPLOYMENT/GOVERNANCE/OFFICIAL_REFERENCES/adr README →
AC-031-51..57. `archive-spec.sh` (+3/−1) and `check-remediation-budget.sh`
(+2/−1) diffs are comment-only (no logic change) — inspected verbatim.

**Claim 4 — file counts (settled with git, exact numbers):**
- Modified tracked files: **19** (`git status --porcelain | grep -c '^ M'` → 19;
  `git diff HEAD --shortstat` → `19 files changed, 312 insertions(+), 59 deletions(-)`).
- New untracked files: **28** total = **16** change-set artifacts (workflow,
  agent, ADR, verify script, 11 bats files, 1 shared bash helper) + **12** spec
  folder artifacts (`10-tasks.md` + 11 scenario files; this report adds a 13th).
- Stage 2's "16 modified + 13 new" and stage 3's "19 modified + 15 new" are both
  inexact: the truth is 19 modified + 16 new non-spec files (stage 3 undercounted
  new files by 1; stage 2 undercounted both). No file outside this set was
  touched — `git status` shows nothing else.

**Claim 5 — no gate threshold or gate config edited: CONFIRMED.**
`scripts/check-code-principles.sh` is unmodified; no `pmd*.xml`,
`*golangci*.yml`, or `.eslintrc*` appears in the diff (none modified). The four
content-contract amendments were each inspected line-by-line and are roster
extensions reflecting genuinely new required state, not loosening:
- `check-pr-review.sh`: adds `spec-deployer` to the required agent set (8→9).
  This *tightens* the check — it now fails if `agents/spec-deployer.md` is
  missing; the "extra agent" guard is unchanged. Traced to
  AC-031-orchestration-compliance.md ("every agent reference (including
  `spec-deployer`) resolves").
- `check-stop-and-ask-matrix.sh`: adds `spec-deployer.md` to `AGENT_FILES`
  (8→9) — the new agent becomes *subject to* the matrix checks (must reference
  the matrix, no forbidden edit permissions); the AC-009-02-03 outside-roster
  failure branch is intact.
- `check-model-env.sh`: message/comment wording "the 9" → "the roster"; the
  actual expected set is derived from `model-env.vars.sh`, and the equality
  check (example vars == opencode.json references) is unchanged.
- `model-env.vars.sh` (+ consumers): adds `SPEC_DEPLOYER_MODEL` /
  `spec-deployer` (9→10) — directly mandated by AC-031-model-credential-wiring.md
  scenarios 01–05. House precedent (AC-010-05-06) cited by stage 2 is consistent
  with this pattern: roster state grows when the spec adds an agent.
**Judgment: legitimate spec-driven state changes. No check was weakened.**

**Claim 6 — helper consolidation: CONFIRMED.**
`scripts/tests/ac-031-doc-section.bash` exists and defines `section()` once
(awk-based, reads `$DOC`); exactly two bats files load it
(`ac-031-pipeline-doc-rewrite.bats`, `ac-031-phase3-budget-routing.bats`, via
`load ac-031-doc-section`); no inline `section()` definition remains in any
`.bats` file (grep hits only the helper). Test count is real: plan line `1..473`,
473 ok / 0 not ok / 0 skipped — the refactor removed a duplicated definition
without removing or weakening assertions.

**Claim 8 — conformance tier is `mvp`: CONFIRMED independently.**
- No `Conformance tier: production` declaration exists anywhere: `AGENTS.md`
  carries no tier declaration and no `AGENTS_*.md` file exists
  (`grep "Conformance tier:" AGENTS.md AGENTS_*.md` → exit 2, no match), so the
  `Makefile` `mutation:` target's production grep fails → mutation skipped
  ("production tier, 80% threshold — skipped at mvp" per its own comment; same
  for `property-tests:`).
- `scripts/check-code-principles.sh` tier auto-detection defaults
  `TIER="${TIER:-mvp}"` and both runs above report `tier: mvp`.
- `docs/changes/015-auditable-agent-steps.md` §7 records the same mvp
  confirmation with gate output `Checking design principles in: . (tier: mvp)`
  and `skipped — mvp tier` as the Mutation Runner's reason; docs/changes/008,
  028, 030 carry no production-tier mutation record either.
- Per §Conformance tiers: at mvp, Refactorer property tests = skip and Architect
  mutation testing = skip — stage 5a should record `skipped — mvp tier`, not a
  score. Stage 3's property-test skip was correct.

**Remaining repo gates (claim 9) — all exit 0**, run as `bash scripts/<name>.sh`
(bash form; execute-bit artifact noted above), at 2026-10-19T14:11:09Z:
check-orchestration 0, check-model-env 0, check-skills 0, check-governance 0,
check-no-hardcoded-secrets 0, check-bats-assertions 0, check-stop-and-ask-matrix 0,
check-remediation-budget 0, check-post-pr-ci-loop 0, check-pr-review 0,
check-specs-archived 0, guard-env 0, model-env.selftest 0. `make lint` 0 (above).

## Out-of-scope findings (recorded per Stop-and-Ask matrix; not fixed)

1. **CONFIRMED — 5b/5c audit-trail ordering gap for frontend child repos.**
   `agents/spec-pr-opener.md:54` makes `check-audit-trail.sh NNN-slug` a
   mandatory pre-push run at stage 5b, and `check_folder` now calls
   `check_deploy_artifact` unconditionally. For a **frontend** repo
   (`vercel.json` or frontend `package.json` present), at 5b time
   `30-report.md` exists (5a wrote it) but `40-deploy.md` cannot exist yet (5c
   runs after the PR opens, needing the preview deployment) → the gate exits
   non-zero → the PR Opener stops → 5c can never run. Deadlock. The code
   tolerates absence only in the **non-frontend** branch ("absence is tolerated
   pre-5c … ponytail ceiling" comment) and names an upgrade path
   (`--require-deploy` flag once 5d owns the final gate run). No scenario in
   `20-acceptance/` reconciles the frontend ordering (grep for 5b/pre-push
   finds only 5a–5d role descriptions). This repo itself is non-frontend (no
   `vercel.json`/`package.json` at root), so this change set's own pipeline is
   unaffected — hence recorded, not blocking. **Propose a follow-up spec.**
2. **CONFIRMED — third `section()` shape.** Pre-existing
   `scripts/check-post-pr-ci-loop.sh:72` carries its own `section()` with a
   different signature (`section <file> <heading>`) vs the new shared helper's
   `section <heading>`-over-`$DOC`. The file is untouched by this change set;
   consolidating the three shapes is out of scope here — noted for a future
   DRY pass.

## Expected residual (not a finding against this verdict)

`bash scripts/check-audit-trail.sh 031-vercel-deploy-lane` still exits non-zero
after this report is written, for exactly one reason: `30-report.md` does not
exist yet — it is stage 5a's (Mutation Runner) artifact, written after this
stage. Folder-completeness therefore cannot hold at verifier time; this is the
pipeline's normal in-flight state ("in-flight folders without `30-report.md` are
skipped" — the finished-folder gate is the PR Opener's/self-ci's concern). Any
other audit-trail finding would be a real finding; the recorded run below shows
the missing-`30-report.md` reason is the only one.

command: bash scripts/check-audit-trail.sh 031-vercel-deploy-lane
exit: 1
at: 2026-10-19T14:19:31Z

```
PASS 031-vercel-deploy-lane: 10-tasks.md present and non-empty
PASS 031-vercel-deploy-lane: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 031-vercel-deploy-lane: 25-verification.md present and non-empty
FAIL 031-vercel-deploy-lane: missing 30-report.md (AC-015-12)
PASS 031-vercel-deploy-lane: evidence block 'scenario traceability' — command: bash scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-19T14:03:42Z
PASS 031-vercel-deploy-lane: evidence block 'full test suite' — command: bats scripts/tests/*.bats, exit: 0, at: 2026-10-19T14:06:50Z
PASS 031-vercel-deploy-lane: evidence block 'complexity gate' — command: make lint, exit: 0, at: 2026-10-19T14:10:19Z
PASS 031-vercel-deploy-lane: evidence block 'design-principles gate' — command: bash scripts/check-code-principles.sh --json, exit: 1, at: 2026-10-19T14:07:59Z
PASS 031-vercel-deploy-lane: evidence block 'scenario-to-behavior spot check' — command: sed -n reads of specs/031-vercel-deploy-lane/20-acceptance/… and scripts/tests/ac-031-….bats (targeted line ranges), exit: 0, at: 2026-10-19T14:17:05Z
✘ Audit-trail check: 1 violation(s).
```

(ANSI color codes stripped in transcription. The single violation is
`missing 30-report.md` — the expected residual; all five evidence blocks and
the folder checks pass.)

## Verdict

**PASS** — attempt 1, phase 1. All five checks green with real commands, real
exit codes, real UTC timestamps, real output. Design-principles plain-run
exit 1 is fully attributed to pre-existing debt in files untouched by this
change set (blame-scoped run exit 0, per repo design 011); the 16 WARNs are
flagged to the Architect per the matrix (record, do not stop). Two out-of-scope
findings recorded above for follow-up specs. Architect (stage 5a) may proceed;
mutation testing will record `skipped — mvp tier`.
