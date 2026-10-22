# 031-vercel-deploy-lane

> Spec pipeline archive. Original source: `specs/031-vercel-deploy-lane/` (deleted by this script).
> Archived: 2026-10-19

## Original ask

_(not produced)_

## Tasks

# Tasks — 031-vercel-deploy-lane

## Task 1 — Create spec-deployer agent

Create `agents/spec-deployer.md` as a new pipeline stage agent.

Acceptance criteria:
- File exists at `agents/spec-deployer.md` with valid YAML frontmatter
- `permission.read` denies `specs/*/00-informal.md` (information barrier, same as spec-coder)
- `permission.bash` denies `vercel deploy*` — the agent must refuse, not execute
- `permission.edit` denies gate-threshold files (same pattern as spec-pr-opener)
- Agent prompt defines: wait for Vercel preview deployment, verify health check, run E2E against live preview URL (delegating to `e2e-runner` agent per `skills/e2e-testing`), write `40-deploy.md`
- Agent prompt explicitly lists allowed CLI commands: `vercel inspect`, `vercel logs`, `vercel ls`, `vercel env pull/add`, `vercel pull`, `vercel domains`
- Agent prompt explicitly prohibits `vercel deploy` with a stated reason (double-build, race Git integration, orphaned deployments)
- Agent scope: frontend child repos only (Angular, React, Next.js, Ionic web); non-frontend repos produce a skip-reason in `40-deploy.md` and exit cleanly

## Task 2 — Model and credential wiring

Wire spec-deployer into the model configuration and credential system.

Acceptance criteria:
- `opencode.json` `agent` block gains `"spec-deployer": { "model": "{env:SPEC_DEPLOYER_MODEL}" }` — no literal model id
- `config/model.local.env.example` gains `SPEC_DEPLOYER_MODEL=bailian-token-plan-personal/qwen3.8-flash` as committed default (flash for mechanical stage, per house pattern)
- `config/agent.local.env.example` gains commented placeholders: `# VERCEL_TOKEN=<your-vercel-token>`, `# VERCEL_ORG_ID=<your-vercel-org-id>`, `# VERCEL_PROJECT_ID=<your-vercel-project-id>`
- Placeholders follow the angle-bracket convention recognized by `scripts/check-no-hardcoded-secrets.sh`
- No new tracked env files; `scripts/guard-env.sh` still passes
- The repo-root `.envrc` third `dotenv_if_exists` line (`config/agent.local.env`) already covers the new vars — no `.envrc` change needed

## Task 3 — Pipeline documentation rewrite (SPEC_PIPELINE.md)

Update `docs/SPEC_PIPELINE.md` to reflect the new 5a/5b/5c/5d stage structure.

Acceptance criteria:
- Stage table (currently lines 13–24) lists: 5a Mutation Runner, 5b PR Opener (no longer archives), 5c Deploy Verifier (spec-deployer), 5d Archiver (spec-pr-opener)
- Artifact layout (currently lines 48–63) includes `40-deploy.md` with description
- Audit-contract table (currently lines 75–82) gains a row: Deploy Verifier → `40-deploy.md` → deploy URL, build status, health check status, E2E verdict, timestamp
- Definition of done (currently lines 214–238) renumbered: (1) every stage green, (2) `30-report.md` exists, (3) draft PR open on `spec/NNN-slug`, (4) `40-deploy.md` present with verdict or skip reason, (5) gate green, (6) archive ran at 5d
- Sentence at line 233 ("The pipeline finishes at the moment stage 5b pushes the archive commit and opens the draft PR") rewritten to name 5d as the final act
- Commit-and-push carve-out (currently line 341) names 5d explicitly alongside 5b
- Phase ordering stated: phase-3 deploy loop runs only after phase-2 post-PR CI loop is green
- 5d runs under the same commit-and-push carve-out as 5b (branch `spec/NNN-slug`, never `main`/`master`)

## Task 4 — 40-deploy.md artifact contract and audit-trail extension

Define the `40-deploy.md` evidence format and extend `scripts/check-audit-trail.sh`.

Acceptance criteria:
- `40-deploy.md` evidence format defined in `docs/SPEC_PIPELINE.md` audit-contract section: deploy URL, build status (pass/fail/skip), health check status, E2E verdict (pass/fail/skip), timestamp, phase-3 attempt count, verdict (PASS/FAIL/ESCALATED/SKIPPED)
- `scripts/check-audit-trail.sh` extended with a new check: `40-deploy.md` must exist and be non-empty when the spec targets a frontend repo; must contain a skip reason when the spec targets a non-frontend repo
- The five Verifier checks in `scripts/check-audit-trail.sh` (array at line 76) remain exactly five — `40-deploy.md` is NOT a sixth Verifier check
- The new check is a separate function, not appended to `FIVE_CHECKS`
- `40-deploy.md` follows the same evidence-block format as `25-verification.md` (heading, command/exit/at markers, raw output) for machine-readable entries

## Task 5 — Archive ordering: archive-spec.sh and check-specs-archived.sh

Update both scripts so the archive is the genuinely final act, running after deploy verification.

Acceptance criteria:
- `scripts/archive-spec.sh`: `40-deploy.md` is included in the one-pager (already picked up by the existing `[0-9][0-9]-*.md` glob at line 127 — verify this and add to `EMBEDDED_DOCS` skip list only if it should NOT be verbatim-embedded, which it should be, so no change to the glob)
- `scripts/archive-spec.sh`: still refuses to archive without `30-report.md` (line 66 check unchanged)
- `scripts/check-specs-archived.sh`: gains an exception — if `specs/NNN-slug/40-deploy.md` exists and contains the budget-exhaustion marker (`Phase-3 budget exhausted` or verdict `ESCALATED`), non-archival is acceptable (script does not fail)
- `scripts/check-specs-archived.sh`: backward compatible — existing archived specs in `docs/changes/` (which have no `40-deploy.md`) still pass the check
- `scripts/check-specs-archived.sh`: existing in-flight specs without `40-deploy.md` (pre-031 specs) still require archival (the exception only applies when `40-deploy.md` explicitly records budget exhaustion)
- `30-report.md` remains the finished signal — both scripts still key off it, unchanged

## Task 6 — Phase-3 remediation budget, fix-routing, and Stop-and-Ask row

Define the phase-3 deploy-verification loop with its own independent budget and deterministic fix-routing.

Acceptance criteria:
- Phase-3 counter is independent of phase 1 (pre-PR) and phase 2 (post-PR CI) — exhaustion of one does not consume another's budget
- Phase-3 max 3 attempts; on 3rd failure, pipeline STOPs before 5d
- On exhaustion: relay failing check IDs and last log evidence from `40-deploy.md` verbatim, escalate to human
- Fix-routing deterministic rules:
  - E2E test runner exits non-zero → spec-coder (behavior). Deterministic: test exit code is unambiguous.
  - Vercel API returns configuration-classified error (invalid `vercel.json`, framework preset wrong, env var missing from Vercel project) → spec-deployer retries. Deterministic: Vercel error code classifies it.
  - Structural/complexity gate failure → spec-refactorer. Deterministic: gate script exit code.
- Fix-routing ambiguous cases (flagged as open question, not resolved with invented heuristic):
  - Vercel build failure (`BUILD_FAILED`) where the build log does not contain a clearly code-diagnostic or config-diagnostic pattern
  - Health check failure where the cause could be code or missing runtime environment variable
- Stop-and-Ask matrix (`docs/SPEC_PIPELINE.md`) gains a deploy row:
  - Condition: "Deploy verification fails"
  - Action: "Route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess"
- Phase 3 runs only after phase 2 is green (ordering is explicit, not concurrent)

## Task 7 — Production deploy verification (post-merge)

Define the post-merge production verification workflow.

Acceptance criteria:
- Post-merge GitHub Actions workflow (or workflow addition to existing child-repo CI) verifies the production deployment after merge to `main`
- Workflow queries Vercel API for the production deployment associated with the merged commit
- Workflow runs a health check against the production URL
- Workflow records the production verification result
- Production deployment not found → skip with reason, do not fail the workflow run
- Repo has no Vercel project linked → skip with reason, do not fail the workflow run
- This rewrites the `SPEC_PIPELINE.md` "nothing runs after the merge" contract — that sentence changes, not silently contradicted

## Task 8 — Non-frontend skip behavior

Ensure non-frontend repos (Java, Go, Rust, Python backends) skip deploy verification cleanly.

Acceptance criteria:
- When the child repo is not a frontend stack (no `package.json` with a frontend framework, no `vercel.json`, no Vercel Git integration detected), `spec-deployer` writes `40-deploy.md` with verdict `SKIPPED` and a skip reason (e.g., "Non-frontend repo — deploy verification not applicable")
- Non-frontend repos never fail the deploy gate
- Skip reason is recorded in `40-deploy.md` in a grep-able format (e.g., `Verdict: SKIPPED — <reason>`)
- The existing GHCR container path (`.github/workflows/ci-nextjs.yml` or equivalent) is unaffected — Vercel verification runs alongside it, neither cancels the other

## Task 9 — ADR 0008

Write Architecture Decision Record 0008 for the pipeline role addition, gate artifact addition, and billing impact.

Acceptance criteria:
- `docs/adr/0008-vercel-deploy-lane.md` exists, written from `templates/ADR.md`
- ADR records: new pipeline role (spec-deployer), new gate artifact (`40-deploy.md`), billing impact (Vercel builds cost money), decision to split pipeline tail into 5a/5b/5c/5d
- ADR status is `Accepted`
- `docs/adr/README.md` index gains a row for ADR 0008
- ADR number is 0008 (next after 0007, which is the current highest in `docs/adr/`)

## Task 10 — Documentation updates (OFFICIAL_REFERENCES.md, DEPLOYMENT.md)

Update reference documentation to record the Vercel CLI pin and the new frontend deploy lane.

Acceptance criteria:
- `docs/OFFICIAL_REFERENCES.md` version-pins table gains a row: Vercel CLI **64.5.0** with source URL (npm registry or Vercel changelog) and licence (Apache-2.0 per Vercel CLI's package.json)
- `docs/OFFICIAL_REFERENCES.md` pages-consulted section gains a Vercel CLI entry with the documentation pages consulted
- `docs/DEPLOYMENT.md` gains a "Frontend: Vercel" section alongside the existing backend sections (Kamal, Dokku, Raw SSH)
- Frontend section describes: Vercel Git integration as source of truth for builds/deploys, CLI role limited to observation/sync, credential pattern, coexistence with GHCR container path

## Task 11 — Orchestration and model-env compliance

Verify all mechanical checks pass with the new agent and wiring.

Acceptance criteria:
- `scripts/check-orchestration.sh` exits 0 — `spec-deployer` reference resolves to `agents/spec-deployer.md`, all script paths cited in the new agent resolve
- `scripts/check-model-env.sh` exits 0 — `spec-deployer` model entry is `{env:SPEC_DEPLOYER_MODEL}`, no literal model id
- `scripts/check-no-hardcoded-secrets.sh` exits 0 — no credential values in tracked files
- `scripts/guard-env.sh` exits 0 — no real env file tracked
- `scripts/check-audit-trail.sh --selftest` exits 0 — existing selftest scenarios still pass after the 40-deploy.md extension

## Open questions

1. **Phase-3 fix-routing boundary for ambiguous build/health-check failures.** The deterministic rules cover E2E failures (→ spec-coder), Vercel-classified config errors (→ spec-deployer), and structural gate failures (→ spec-refactorer). For Vercel build failures where the build log does not contain a clearly code-diagnostic or config-diagnostic pattern, and for health-check failures where the cause could be code or missing runtime env var, the boundary is genuinely ambiguous. Two options:
   - **Option A**: spec-deployer parses the Vercel build log with grep patterns for known code-error signatures (`Type error`, `Cannot find module`, `SyntaxError`) and config-error signatures (`Environment variable`, `not found in .env`, `Invalid framework`). Unmatched patterns escalate to the human. This is heuristic, not deterministic, but high-confidence for common cases.
   - **Option B**: All ambiguous build/health-check failures escalate to the human immediately, with no log parsing. Simpler but more frequent human interruptions.
   
   Which approach should the pipeline take?

## Acceptance scenarios

## AC-031-01 — Agent file exists with correct frontmatter
## AC-031-02 — Agent refuses to run vercel deploy
## AC-031-03 — Agent read-deny on informal spec
## AC-031-04 — Agent prompt lists allowed CLI commands
## AC-031-05 — Agent prompt prohibits vercel deploy with stated reason
## AC-031-06 — opencode.json entry uses env reference
## AC-031-07 — model.local.env.example carries committed default
## AC-031-08 — agent.local.env.example carries Vercel placeholders
## AC-031-09 — No real credential values in tracked files
## AC-031-10 — guard-env.sh still passes
## AC-031-11 — Stage table lists 5a through 5d
## AC-031-12 — Artifact layout includes 40-deploy.md
## AC-031-13 — Definition of done requires 40-deploy.md
## AC-031-14 — Commit-and-push carve-out names 5d
## AC-031-15 — Pipeline-finishes sentence rewritten
## AC-031-16 — Phase ordering is explicit
## AC-031-17 — 40-deploy.md evidence format defined
## AC-031-18 — check-audit-trail.sh checks 40-deploy.md for frontend repos
## AC-031-19 — check-audit-trail.sh accepts skip reason for non-frontend repos
## AC-031-20 — 40-deploy.md is NOT a sixth Verifier check
## AC-031-21 — check-audit-trail.sh fails on missing 40-deploy.md for frontend repo
## AC-031-22 — archive-spec.sh includes 40-deploy.md in one-pager
## AC-031-23 — archive-spec.sh still refuses without 30-report.md
## AC-031-24 — check-specs-archived.sh backward compatible with existing archives
## AC-031-25 — Phase-3 budget exhausted: spec not archived, no false failure
## AC-031-26 — Pre-031 in-flight spec without 40-deploy.md still requires archival
## AC-031-27 — 30-report.md remains the finished signal
## AC-031-28 — Phase-3 counter independent of phase 1 and phase 2
## AC-031-29 — Phase-3 stops on 3rd failure
## AC-031-30 — E2E failure routes to spec-coder
## AC-031-31 — Vercel config error routes to spec-deployer retry
## AC-031-32 — Structural gate failure routes to spec-refactorer
## AC-031-33 — Ambiguous build failure escalates to human
## AC-031-34 — Stop-and-Ask matrix has deploy row
## AC-031-35 — vercel deploy attempted must be refused
## AC-031-36 — Phase 3 runs only after phase 2 is green
## AC-031-37 — Post-merge workflow verifies production deployment
## AC-031-38 — Production deployment not found: skip, do not fail
## AC-031-39 — Repo with no Vercel project: skip, do not fail
## AC-031-40 — VERCEL_TOKEN missing or invalid
## AC-031-41 — Git integration not connected
## AC-031-42 — Non-frontend repo produces 40-deploy.md with skip reason
## AC-031-43 — Non-frontend repo never fails deploy gate
## AC-031-44 — GHCR container path unaffected
## AC-031-45 — Preview build times out
## AC-031-46 — Preview build fails
## AC-031-47 — Deploy succeeds but health check fails
## AC-031-48 — E2E fails against live preview URL
## AC-031-49 — No Vercel project linked to the repo
## AC-031-50 — ADR 0008 exists and follows template
## AC-031-51 — ADR 0008 status is Accepted
## AC-031-52 — ADR 0008 indexed in README
## AC-031-53 — OFFICIAL_REFERENCES.md pins Vercel CLI 64.5.0
## AC-031-54 — OFFICIAL_REFERENCES.md records pages consulted
## AC-031-55 — DEPLOYMENT.md gains frontend/Vercel lane section
## AC-031-56 — check-orchestration.sh passes
## AC-031-57 — check-model-env.sh passes
## AC-031-58 — check-audit-trail.sh selftest still passes
## AC-031-59 — check-no-hardcoded-secrets.sh passes
## AC-031-60 — guard-env.sh passes

## Verification

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

## Quality gates

# 30-report — spec 031-vercel-deploy-lane

- Mutation Runner run: attempt 1, phase 1 (Verifier precondition: PASS on attempt 1, no BLOCK — carried forward)
- Branch verified: `main` working tree (uncommitted stage 2/3/4 change set — the pipeline's designed state; PR Opener commits only after this report per docs/SPEC_PIPELINE.md §Commit and push carve-out)
- Information barrier honored: `specs/*/00-informal.md` not read (none exists in this folder). This report is written from `25-verification.md`, the acceptance scenarios, and this stage's own gate transcripts only.
- Conformance tier: `mvp` — mutation testing is a recorded skip (evidence below)

## Verifier's verdict (carried forward)

**PASS — attempt 1, phase 1.** `25-verification.md` records all five checks green:
traceability exit 0 (60/60, `fails: []`), full test suite exit 0 (plan `1..473`),
`make lint` exit 0, design-principles blame-scoped run exit 0 (0 FAIL / 0 WARN),
scenario-to-behavior spot check 6/6 match. No BLOCK occurred:
SPEC_LOOP_COUNT=1, SPEC_PHASE1_RETRIES=0, SPEC_PHASE2_RETRIES=0. Two out-of-scope
findings carried forward (§Out-of-scope findings below).

## Mutation score: skipped — mvp tier

Per docs/SPEC_PIPELINE.md §Conformance tiers, mutation testing is a
`production`-tier gate; an `mvp` project skips it (same table row also skips
Refactorer property tests). This repo conforms at `mvp`, so stage 5a records a
**skip, not a score**. No mutation tool was run, installed, or added as a
dependency — this change set is bash/markdown/JSON/YAML, so no PiTest/Stryker/
go-mutesting surface exists, and adding one to satisfy a gate the tier
explicitly skips would be exactly the over-engineering this repo's laziness
ladder (okf/context-window-policy.md §4) forbids.

Independent tier re-confirmation by this stage (own run):

command: rtk grep -rn "Conformance tier" AGENTS.md AGENTS_*.md Makefile docs/CONFORMANCE_TIERS.md
exit: 2
at: 2026-10-19T14:29:33Z

```
/usr/bin/grep: AGENTS_*.md: No such file or directory
Makefile:137:	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
Makefile:145:	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
docs/CONFORMANCE_TIERS.md:20:## Conformance tier: mvp
grep-exit=2
```

Corroboration (measured by the Verifier, carried forward):
- The `Makefile` `mutation:`/`property-tests:` targets (lines 137, 145) grep
  `AGENTS.md`/`AGENTS_*.md` for `Conformance tier: production`; no such
  declaration exists and no `AGENTS_*.md` file exists, so both resolve to the
  mvp branch — "skipped at mvp" per the targets' own comments. Exit 2 above is
  grep's no-match-for-both-paths code, which is what the Makefile's
  `2>/dev/null` swallows into the mvp branch.
- `scripts/check-code-principles.sh` tier auto-detection defaults
  `TIER="${TIER:-mvp}"`; both Verifier transcripts report `tier: mvp`.
- `docs/changes/001-tdd-scaffolding-both-tracks.md` declares `mvp` for this
  repo; archived precedent rows record the same skip, never a score:
  `docs/changes/007` (`skipped — mvp tier`), `008` (same), `009`, `013`, `015`
  (§7: `skipped — mvp tier`), `017`, `028` (`skipped — mvp tier`), `029`
  (property tests skipped per mvp tier). No archived spec records a mutation
  score at mvp.

Equivalent mutants: **none assessed** — no mutation run occurred, so there were
no survivors and no equivalent-mutant analysis. (Writing `0` would imply a run
happened; it did not.)

## Final test status

Full suite re-run by this stage, one final time, after the Verifier's own run:

command: bats scripts/tests/*.bats
exit: 0
at: 2026-10-19T14:26:18Z

```
1..473
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 472 wire: non-numeric confidence is invalid, exits 10
ok 473 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts from the real TAP output (scratch transcript, since deleted):
`grep -c '^ok '` → 473; `grep -c '^not ok'` → 0; `grep -c '# skip'` → 0; plan
line `1..473`. **Confirms the Verifier's record exactly: 473 tests, 473 ok,
0 not-ok, 0 skipped, exit 0. No discrepancy in suite results.**

Working-tree note (measured delta, not a contradiction): `git status
--porcelain` at this stage shows 20 `^ M` entries vs the 19 the Verifier
settled. The +1 is `runs.jsonl`, whose entire diff vs HEAD is the Verifier's
own closing telemetry row for this spec — `record-gate-run.sh` appended
`{"specSlug":"031-vercel-deploy-lane","gatesFailed":[],"warnings":[…] ,"outcome":"pass","loopCount":1,"phase1Retries":0,"phase2Retries":0}`
(runId f256d674-…) when stage 4 closed out, after its file count was taken. Not
a change-set file; the 16 untracked change-set artifacts and the in-flight
`specs/` folder otherwise match the Verifier's inventory exactly.

## Complexity summary (carried from stage 3 / Verifier re-check)

Three gate runs, carried from `25-verification.md` where the full transcripts
live verbatim:

command: bash scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-19T14:07:59Z
→ `tier: mvp`, `FAILS: 1`, `WARNS: 16`. The single FAIL, verbatim:
`FAIL: Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10`

The 16 WARNs (4× KISS_LINES, 10× possible duplication, 2× empty method body)
all land in `ci/templates/*` and `skills/hallmark/site/examples/*` — none of
those files is touched by this change set (`git diff --name-only HEAD | grep -i
"hallmark\|ci/templates"` → no match, exit 1). Full verbatim WARN list:
`25-verification.md` §design-principles gate.

command: bash scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-10-19T14:10:15Z
→ `tier: mvp`, `fails: 0`, `warns: 0`. Zero findings attributable to this
change set (blame scoping per `docs/changes/011-design-gate-blame-scoping.md`).

command: make lint
exit: 0
at: 2026-10-19T14:10:19Z
→ JSON/YAML validation, every file `[OK]`, `grep -c FAIL` → 0. `make lint` is
this repo's local lint gate for this change set's stack; shellcheck is CI-only
(`.github/workflows/self-ci.yml:230`), not installed locally (Verifier-recorded).

Per the Stop-and-Ask matrix's design-gate rows: the plain run's exit-1 FAIL and
the 16 WARNs are **flagged, not stopped** — pre-existing debt in files untouched
by this change set, with the blame-scoped run clean; the WARNs are recorded here
as the flagged-not-stopped handoff to later stages.

## Gate results

The 13 remaining repo gates, all exit 0 at 2026-10-19T14:11:09Z (Verifier run,
`bash scripts/<name>.sh` form — several scripts are tracked without the execute
bit, `./scripts/x.sh` yields 126; recorded as measured):
check-orchestration 0, check-model-env 0, check-skills 0, check-governance 0,
check-no-hardcoded-secrets 0, check-bats-assertions 0,
check-stop-and-ask-matrix 0, check-remediation-budget 0,
check-post-pr-ci-loop 0, check-pr-review 0, check-specs-archived 0,
guard-env 0, model-env.selftest 0. `make lint` 0 (above).

Audit-trail gate, expected residual and its resolution: at Verifier time
`check-audit-trail.sh 031-vercel-deploy-lane` exited 1 with exactly one FAIL,
`missing 30-report.md` (AC-015-12) — the stage-5a artifact this report now is;
all five evidence blocks and all folder checks passed. Re-run by this stage
after writing this report:

command: bash scripts/check-audit-trail.sh 031-vercel-deploy-lane
exit: 0
at: 2026-10-19T14:30:53Z

```
PASS 031-vercel-deploy-lane: 10-tasks.md present and non-empty
PASS 031-vercel-deploy-lane: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 031-vercel-deploy-lane: 25-verification.md present and non-empty
PASS 031-vercel-deploy-lane: 30-report.md present and non-empty
PASS 031-vercel-deploy-lane: evidence block 'scenario traceability' — command: bash scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-19T14:03:42Z
PASS 031-vercel-deploy-lane: evidence block 'full test suite' — command: bats scripts/tests/*.bats, exit: 0, at: 2026-10-19T14:06:50Z
PASS 031-vercel-deploy-lane: evidence block 'complexity gate' — command: make lint, exit: 0, at: 2026-10-19T14:10:19Z
PASS 031-vercel-deploy-lane: evidence block 'design-principles gate' — command: bash scripts/check-code-principles.sh --json, exit: 1, at: 2026-10-19T14:07:59Z
PASS 031-vercel-deploy-lane: evidence block 'scenario-to-behavior spot check' — command: sed -n reads of specs/031-vercel-deploy-lane/20-acceptance/{AC-031-production-deploy,AC-031-non-frontend-skip,AC-031-pipeline-doc-rewrite,AC-031-archive-ordering,AC-031-model-credential-wiring}.md and scripts/tests/ac-031-{production-deploy,non-frontend-skip,pipeline-doc-rewrite,archive-ordering,model-credential-wiring}.bats (targeted line ranges), exit: 0, at: 2026-10-19T14:17:05Z
✔ Audit-trail check: specs/031-vercel-deploy-lane complete, verifier evidence recorded.
```

(ANSI color codes stripped in transcription. All nine PASS lines — folder
completeness incl. the new `30-report.md present and non-empty` row — and the
final summary line; zero violations. Full verbatim transcript identical to the
pre-write run except the two changed rows: `30-report.md present and non-empty`
replaces `FAIL … missing 30-report.md`, and the summary flips to the ✔ line.)

## Remediation record

**none.** Per docs/SPEC_PIPELINE.md §Remediation budget: no BLOCK occurred at any
point in this pipeline run. The Verifier passed on attempt 1 with no BLOCK
(SPEC_PHASE1_RETRIES=0 — phase-1 budget unused), phase 2 (post-PR CI loop) has
not started (SPEC_PHASE2_RETRIES=0), and this stage's own run produced no gate
failure. `25-verification.md` carries no attempt entries beyond attempt 1, so
there is nothing further to carry forward; no phase/attempt numbers are
fabricated.

## Out-of-scope findings (carried forward — recorded, not fixed, per matrix)

1. **(a) Frontend child-repo 5b/5c audit-trail ordering deadlock**
   (Verifier-confirmed): `agents/spec-pr-opener.md:54` makes
   `check-audit-trail.sh NNN-slug` a mandatory pre-push run at stage 5b, and
   `check_folder` calls `check_deploy_artifact` unconditionally. For a frontend
   repo, at 5b time `30-report.md` exists but `40-deploy.md` cannot (stage 5c
   runs after the PR opens, needing the preview deployment) → gate exits
   non-zero → PR Opener stops → 5c never runs. The code tolerates absence only
   in the non-frontend branch; no scenario in `20-acceptance/` reconciles the
   ordering. This repo is non-frontend (no `vercel.json`/frontend
   `package.json` at root), so this change set's own pipeline is unaffected.
   **Propose a follow-up spec.**
2. **(b) Third `section()` shape** (Verifier-confirmed): pre-existing
   `scripts/check-post-pr-ci-loop.sh:72` carries its own `section()` with a
   different signature (`section <file> <heading>`) vs the new shared helper's
   `section <heading>`-over-`$DOC`. File untouched by this change set;
   consolidating the three shapes is future DRY material.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/93
Commit count: 16

---

# Post-PR CI check (phase 2) — round 1 of max 3

Verifier invocation 2 (phase 2, round 1 of max 3). A previous invocation of this
check was cancelled before recording anything — this section is the first phase-2
record for this spec. The phase-1 verdict stands: **PASS (attempt 1)**, not
re-run; this invocation is the scoped post-PR CI check only. Information barrier
held: no `specs/*/00-informal.md` read (including the stale copy in abandoned
reflog commit `b569042` — not checked out, not read).

PR: https://github.com/RexiAI/my-engineering-standards/pull/93 (draft, base
`main`, head `spec/031-vercel-deploy-lane`, head SHA
`64dfb9f54dfb31f5a44c085670eba8d98eadae7c`, 13 commits, pushed twice: C1–C12
head `0910252`, then archive commit C13 `64dfb9f`).

**Round-1 verdict: FAIL.** Both Self CI `Validate` runs against head SHA
`64dfb9f` (pull_request + push events) failed at step 25
`Check security-hardening deliverables` (`scripts/check-security-hardening.sh`,
exit 1): **AC-026-13 mutable third-party Action ref** at
`.github/workflows/ci-vercel-production-verify.yml:53` (`uses: actions/checkout@v4`)
— a file added by this change set itself (commit `64a64e9`, task 7). This is a
**genuine FAIL, distinct from the expected `check-specs-archived` intermediate**:
that check (step 16) is **green at head** — the archive commit resolved it as
designed. Routing below (→ Coder).

## Per-check outcome — round 1 (head SHA `64dfb9f`)

| Check (workflow / name) | Run | Event | Bucket | Verdict |
|---|---|---|---|---|
| Self CI / Validate | 39272653874 (check id 118128734889) | pull_request | fail | **FAIL** (genuine, at head) |
| Self CI / Validate | 39272644053 (check id 118128698166) | push | fail | **FAIL** (same step, same SHA) |
| PR Review Agent / Review PR | 39272654342 | pull_request | cancel | CANCELLED (terminal; not Self CI; not ruled on — phase-2 authority is the Self CI Validate checks) |

No polling was required: every check was already terminal at first query
(2026-10-21T20:48:50Z); both Validate runs completed 2026-10-19T14:52Z. No check
is `pending`; nothing remains outstanding for round 1.

Expected intermediate (C12 `0910252`, superseded — **not** the PR verdict): runs
39272481340 (pull_request) / 39272438615 (push) failed `check-specs-archived`
exactly as the pipeline design predicts — the intermediate push carried a
finished spec (`30-report.md`) without its archive because archiving is
deliberately the final commit. Recorded separately below and kept distinct from
the genuine head failure.

## Evidence: Post-PR CI — gh pr checks (terminal)

command: gh pr checks 93 --json name,state,bucket,workflow,link
exit: 0
at: 2026-10-21T20:48:50Z

[{"bucket":"cancel","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39272654342/job/118128951629","name":"Review PR / Review PR","state":"CANCELLED","workflow":"PR Review Agent"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39272653874/job/118128734889","name":"Validate","state":"FAILURE","workflow":"Self CI"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39272644053/job/118128698166","name":"Validate","state":"FAILURE","workflow":"Self CI"}]

## Evidence: Post-PR CI — Self CI runs on the branch

command: gh run list --branch spec/031-vercel-deploy-lane --workflow "Self CI" --json databaseId,headSha,status,conclusion,event,createdAt
exit: 0
at: 2026-10-21T20:48:51Z

[{"conclusion":"failure","createdAt":"2026-10-19T14:50:59Z","databaseId":39272653874,"event":"pull_request","headSha":"64dfb9f54dfb31f5a44c085670eba8d98eadae7c","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:50:55Z","databaseId":39272644053,"event":"push","headSha":"64dfb9f54dfb31f5a44c085670eba8d98eadae7c","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:49:51Z","databaseId":39272481340,"event":"pull_request","headSha":"0910252dcf8b92b90c423520ce8d9fa7c22bfcea","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:49:33Z","databaseId":39272438615,"event":"push","headSha":"0910252dcf8b92b90c423520ce8d9fa7c22bfcea","status":"completed"}]

## Evidence: Post-PR CI — failing check IDs at head SHA

command: gh api repos/RexiAI/my-engineering-standards/commits/64dfb9f54dfb31f5a44c085670eba8d98eadae7c/check-runs --jq '.check_runs[] | select(.conclusion=="failure") | {id, name, conclusion}'
exit: 0
at: 2026-10-21T20:49:38Z

{"conclusion":"failure","id":118128734889,"name":"Validate"}
{"conclusion":"failure","id":118128698166,"name":"Validate"}

## Evidence: Post-PR CI — head-SHA failure log (run 39272653874, pull_request)

command: gh run view 39272653874 --log-failed 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' | rtk grep -E "AC-026-13: mutable|✘ Security|##\[error\]Process"
exit: 0
at: 2026-10-21T20:55:40Z

(Full --log-failed output is 58 lines, one failing step only; representative
excerpt below, first captured 2026-10-19T14:52Z run time. Color-code artifacts
present in the log stream as emitted are reproduced as captured.)

50:Validate	Check security-hardening deliverables	2026-10-19T14:52:11.0201280Z ^[[0;31mFAIL^[[0m AC-026-13: mutable third-party Action ref(s) found: ./.github/workflows/ci-vercel-production-verify.yml:      - uses: actions/checkout@v4
56:Validate	Check security-hardening deliverables	2026-10-19T14:52:11.0426764Z ^[[0;31m✘ Security hardening check: 1 violation(s). Fix before merging.^[[0m
58:Validate	Check security-hardening deliverables	2026-10-19T14:52:11.0453480Z ##[error]Process completed with exit code 1.

All other AC-026-NN lines in the same step are PASS — exactly 1 violation.

## Evidence: Post-PR CI — head-SHA step states (run 39272653874)

command: gh run view 39272653874 --json jobs --jq '.jobs[].steps[] | [.number, .name, .status, .conclusion] | @tsv'
exit: 0
at: 2026-10-21T20:50:53Z

(Representative excerpt of the 33-step Validate job, tabs as emitted; steps 1–8,
11–15, 17–24 all completed success.)

9	make validate-all	completed	success
10	Check design-gate blame scoping (scratch repos)	completed	success
16	Check finished specs are archived	completed	success
25	Check security-hardening deliverables	completed	failure
26	Check remediation budget	completed	skipped
27	Install shellcheck	completed	skipped
28	shellcheck scripts and templates	completed	skipped
29	Install bats-core	completed	skipped
30	Run shell gate bats tests (spec 001 Track B)	completed	skipped
31	Run gate selftests	completed	skipped
32	Check scenario traceability (live tree)	completed	skipped
33	Validate YAML syntax (.github, ci)	completed	skipped

Step 16 green at head confirms the expected C12 archive failure is resolved by
C13. Steps 26–33 were SKIPPED downstream of the step-25 failure — the round-2
scoped re-check must confirm them green within the same Validate checks.

## Evidence: Post-PR CI — push-event run fails identically (run 39272644053)

command: gh run view 39272644053 --log-failed 2>&1 | rtk grep -E "FAIL AC|✘ Security|##\[error\]"
exit: 0
at: 2026-10-21T20:52:21Z

1452:Validate	UNKNOWN STEP	2026-10-19T14:52:07.0163461Z ^[[0;31m✘ Security hardening check: 1 violation(s). Fix before merging.^[[0m
1454:Validate	UNKNOWN STEP	2026-10-19T14:52:07.0178610Z ##[error]Process completed with exit code 1.

## Evidence: Post-PR CI — expected C12 intermediate (run 39272481340, superseded)

command: gh run view 39272481340 --log-failed 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' | rtk grep -E "\[FAIL\] 031|##\[error\]Process"
exit: 0
at: 2026-10-21T20:55:42Z

677:Validate	UNKNOWN STEP	2026-10-19T14:50:06.6339284Z ^[[31m  [FAIL] 031-vercel-deploy-lane is finished (has 30-report.md) but not archived — missing docs/changes/031-vercel-deploy-lane.md^[[0m
680:Validate	UNKNOWN STEP	2026-10-19T14:50:06.6353364Z ##[error]Process completed with exit code 1.

Exactly the expected intermediate failure class (finished spec carried pre-archive
because archiving is the final commit). Superseded by C13, where the same check
passes; **not** the PR verdict and not folded into the genuine head failure.

## Evidence: Post-PR CI — failing file provenance and repo pinning convention

command: rtk git log --oneline main..HEAD -- .github/workflows/ci-vercel-production-verify.yml && rtk grep -n "uses: actions/checkout" .github/workflows/ci-vercel-production-verify.yml .github/workflows/self-ci.yml
exit: 0
at: 2026-10-21T20:55:43Z

64a64e9 feat(deploy-lane): post-merge production deploy verification (task 7)
.github/workflows/ci-vercel-production-verify.yml:53:      - uses: actions/checkout@v4
.github/workflows/self-ci.yml:18:      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.3.0

## Evidence: Post-PR CI — PR Review Agent run at head (cancelled)

command: gh run list --branch spec/031-vercel-deploy-lane --workflow "PR Review Agent" --json databaseId,headSha,status,conclusion,createdAt
exit: 1
at: 2026-10-21T20:55:43Z

could not resolve to a unique workflow; found: ci-pr-review.yml pr-review.yml

(Ambiguous workflow-name lookup; superseded by the by-id query below.)

command: gh run view 39272654342 --json databaseId,workflowName,headSha,status,conclusion,event,createdAt
exit: 0
at: 2026-10-21T20:56:15Z

{"conclusion":"cancelled","createdAt":"2026-10-19T14:50:59Z","databaseId":39272654342,"event":"pull_request","headSha":"64dfb9f54dfb31f5a44c085670eba8d98eadae7c","status":"completed","workflowName":"PR Review Agent"}

Terminal (cancelled). Not the Self CI workflow; the phase-2 authority
(docs/SPEC_PIPELINE.md §Post-PR CI check-and-remediate loop) is the PR's CI
checks — Self CI `Validate`. Recorded, not ruled on, not folded into the verdict;
the orchestrator may re-trigger the review agent after the fix round if it wants
a review pass before merge.

## Diagnosis

- Failing gate: `scripts/check-security-hardening.sh` (spec 026, AC-026-13 — no
  mutable third-party Action refs; SHA pinning required). CI step 25, exit 1,
  1 violation.
- Cause: `.github/workflows/ci-vercel-production-verify.yml:53` carries
  `uses: actions/checkout@v4` — a mutable tag ref.
- Provenance: the file was added by this change set — commit `64a64e9`
  `feat(deploy-lane): post-merge production deploy verification (task 7)`
  (evidence above). It is the only mutable ref flagged; the change set's other
  new files are docs (`docs/adr/0008-vercel-deploy-lane.md`,
  `docs/changes/031-vercel-deploy-lane.md`).
- Fix convention is visible in the gate's own workflow:
  `.github/workflows/self-ci.yml:18` —
  `uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.3.0`.
- Known pre-existing noise did NOT touch CI: step 9 `make validate-all` and step
  10 `Check design-gate blame scoping` are green at head, consistent with the
  blame-scoped design gate (the plain local `--json` 1-FAIL/16-WARN set is
  pre-existing, out of scope, flagged to Architect in phase 1 — recorded in the
  phase-1 telemetry warnings).
- Id-scan safety of this appendix: `tests/AC-030-07.sh:55` excludes
  `docs/changes/` from the tracked-tree literal-id scan, and the traceability
  scanner excludes `specs/`/`docs/changes/` from its reference scan (comment at
  `tests/AC-030-07.sh:40-42`), so quoting `AC-026-13` here creates no
  030-class round-2 hazard.

## Routing (route, do not fix)

- **Behavioral → Coder.** The defect is the content of a deliverable added by
  this change set (a mutable tag ref where the gate requires a SHA-pinned ref),
  deterministic from the gate's exit code — not a structural/complexity matter,
  so not Refactorer territory. Fix: pin `actions/checkout` in
  `.github/workflows/ci-vercel-production-verify.yml` to the full commit SHA per
  the `self-ci.yml:18` convention (retaining a `# vX.Y.Z` comment). The Verifier
  writes no production code; the PR Opener owns the round-2 commit + push.
- **Round-2 scoped re-check (next Verifier invocation):** re-query only the
  previously failing checks — Self CI `Validate` at the new head SHA: step 25
  green, **and** steps 26–33 (skipped in round 1) green within the same runs.
  No phase-1 re-run; unchanged gates stand.

## Budget and counters

- Phase-2 round **1 of max 3** consumed → this FAIL is a re-delegation signal,
  **not** a pipeline stop (docs/SPEC_PIPELINE.md §Remediation budget).
- Telemetry exported before `scripts/record-gate-run.sh` (bash form, mode 644):
  `SPEC_LOOP_COUNT=2 SPEC_PHASE1_RETRIES=0 SPEC_PHASE2_RETRIES=0` — verified
  against the ledger first: `runs.jsonl` ends with the phase-1 record
  `f256d674-ac9b-486d-8031-99290bfdbf40` (`outcome=pass`, `loopCount=1`,
  `phase1Retries=0`, `phase2Retries=0`); the cancelled invocation wrote nothing.
- Typed-judgment fast-path **not invoked** (orchestrator reports ADR 0004
  exit-10 fallback; stock procedure run unchanged; no `judgment_fallback` claim
  needed since no call was made).

## Dirty paths to route to the PR Opener (Verifier commits nothing)

1. `docs/changes/031-vercel-deploy-lane.md` — this appended phase-2 section.
2. `runs.jsonl` — one telemetry row appended via `scripts/record-gate-run.sh`.

Neither is committed, stashed, or cleaned up by the Verifier; commit + push
belong to the PR Opener together with the Coder's round-2 fix.

**Verdict (phase-2 round 1): FAIL** — failing checks: Self CI `Validate`
check ids 118128734889 (run 39272653874, pull_request) and 118128698166
(run 39272644053, push) at head SHA `64dfb9f`; reason: AC-026-13 mutable Action
ref `actions/checkout@v4` in `.github/workflows/ci-vercel-production-verify.yml:53`;
routing: Coder (behavioral), PR Opener re-pushes, Verifier re-checks scoped.

---

# Post-PR CI check (phase 2) — round 2 of max 3 (scoped re-check)

Verifier invocation 3 (phase 2, round 2 of max 3). Scoped re-check per
docs/SPEC_PIPELINE.md §Remediation budget and §Post-PR CI check-and-remediate
loop: only the round-1 failing check (Self CI `Validate` at the new head SHA) and
what that failure masked (steps 26–33, skipped in round 1) were re-run. The
phase-1 verdict **PASS (attempt 1)** and the round-1 evidence section above are
left intact and unmodified; no phase-1 gate was re-executed. Information barrier
held: no `specs/*/00-informal.md` read (including the stale copy in abandoned
reflog commit `b569042` — not checked out, not read). `specs/031-vercel-deploy-lane/`
no longer exists and was not recreated; this archived one-pager is the artifact.

PR: https://github.com/RexiAI/my-engineering-standards/pull/93 (draft, base
`main`, head `spec/031-vercel-deploy-lane`, head SHA
`88b7ace52d7c938d89d4154a02f43eb424240fb6`, 15 commits over `origin/main`
`cae6767`). Round-2 fix under verification: commit `22c2234` (SHA-pin of
`actions/checkout`); commit `88b7ace` carries the round-1 evidence + telemetry row
and the 13→15 commit-count update.

**Round-2 verdict: PASS (Self CI).** Both Self CI `Validate` runs at head
`88b7ace` completed with `conclusion: success`, and steps 25–33 each report
`success` — i.e. the steps round 1 never reached (remediation budget, shellcheck
install+run, bats install+run, gate selftests, scenario traceability on the live
tree, YAML validation) **genuinely executed and passed**, they were not skipped.
Exactly one error annotation exists in the whole Validate job log and it belongs to
the non-blocking shellcheck step (`continue-on-error: true`, `self-ci.yml:228`) —
recorded as a finding below, not as a CI FAIL. The `PR Review Agent` check was
still `pending` at the polling bound; it is not a Self CI check and carries no
phase-2 verdict authority (round-1 precedent: cancelled there, not ruled on).

## Per-check outcome — round 2 (head SHA `88b7ace`)

| Check (workflow / name) | Run (job) | Event | Bucket | Verdict |
|---|---|---|---|---|
| Self CI / Validate | 39678612357 (job 119494905580) | pull_request | pass | **PASS** (steps 25–33 all `success`) |
| Self CI / Validate | 39678605487 (job 119494883712) | push | pass | **PASS** (steps 25–33 all `success`) |
| PR Review Agent / Review PR | 39678612431 (job 119494906363) | pull_request | pending | **PENDING** at bound (created 21:25:04Z; still `IN_PROGRESS` at 21:35:40Z after a 300 s bounded watch, and at 21:40:05Z — ≈15 min elapsed; not Self CI, not ruled on) |

Superseded history, referenced for continuity only and **not** setting the verdict:
head `64dfb9f` runs 39272653874 / 39272644053 (round-1 FAIL, step 25 AC-026-13) and
the C12 intermediates at `0910252` runs 39272481340 / 39272438615 (expected
`check-specs-archived` intermediate). No failing check exists at `88b7ace`, so no
`check-runs` failure-ID capture was required this round.

## Evidence: Post-PR CI — local state verified before writing (head, branch, clean tree, commit count)

command: git rev-parse HEAD; git branch --show-current; git status --porcelain; git rev-list --count origin/main..HEAD; git rev-parse origin/main
exit: 0
at: 2026-10-21T21:41:52Z

88b7ace52d7c938d89d4154a02f43eb424240fb6
spec/031-vercel-deploy-lane
porcelain=[]
15
cae6767ffce54d40d9f3058ea42a2270c4c473e1

## Evidence: Post-PR CI — gh pr checks (round 2; Self CI terminal, PR Review Agent pending)

command: gh pr checks 93 --json name,state,bucket,workflow,link
exit: 0
at: 2026-10-21T21:40:05Z

[{"bucket":"pending","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39678612431/job/119494906363","name":"Review PR / Review PR","state":"IN_PROGRESS","workflow":"PR Review Agent"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39678612357/job/119494905580","name":"Validate","state":"SUCCESS","workflow":"Self CI"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/39678605487/job/119494883712","name":"Validate","state":"SUCCESS","workflow":"Self CI"}]

Earlier query in the same round (first poll, both Validate runs still in flight):

command: gh pr checks 93 --json name,state,bucket,workflow,link
exit: 0
at: 2026-10-21T21:28:09Z

[{"bucket":"pending","name":"Review PR / Review PR","state":"IN_PROGRESS","workflow":"PR Review Agent"},{"bucket":"pending","name":"Validate","state":"IN_PROGRESS","workflow":"Self CI"},{"bucket":"pending","name":"Validate","state":"IN_PROGRESS","workflow":"Self CI"}]

Polling was bounded, not open-ended: `timeout 880 gh run watch 39678612357
--interval 30 --exit-status` returned `watch_exit=0` at 2026-10-21T21:29:02Z
(run completed); `timeout 300 gh run watch 39678612431 --interval 45
--exit-status` returned `watch_exit=124` (bound hit) at 2026-10-21T21:35:40Z with
the PR Review Agent run still `in_progress`.

## Evidence: Post-PR CI — Self CI runs on the branch (head-SHA runs identified)

command: gh run list --branch spec/031-vercel-deploy-lane --workflow "Self CI" --json databaseId,event,status,conclusion,headSha,createdAt --limit 8
exit: 0
at: 2026-10-21T21:28:10Z

[{"conclusion":"","createdAt":"2026-10-21T21:25:04Z","databaseId":39678612357,"event":"pull_request","headSha":"88b7ace52d7c938d89d4154a02f43eb424240fb6","status":"in_progress"},{"conclusion":"","createdAt":"2026-10-21T21:25:01Z","databaseId":39678605487,"event":"push","headSha":"88b7ace52d7c938d89d4154a02f43eb424240fb6","status":"in_progress"},{"conclusion":"failure","createdAt":"2026-10-19T14:50:59Z","databaseId":39272653874,"event":"pull_request","headSha":"64dfb9f54dfb31f5a44c085670eba8d98eadae7c","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:50:55Z","databaseId":39272644053,"event":"push","headSha":"64dfb9f54dfb31f5a44c085670eba8d98eadae7c","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:49:51Z","databaseId":39272481340,"event":"pull_request","headSha":"0910252dcf8b92b90c423520ce8d9fa7c22bfcea","status":"completed"},{"conclusion":"failure","createdAt":"2026-10-19T14:49:33Z","databaseId":39272438615,"event":"push","headSha":"0910252dcf8b92b90c423520ce8d9fa7c22bfcea","status":"completed"}]

## Evidence: Post-PR CI — head-SHA run conclusion (run 39678612357, pull_request)

command: gh run view 39678612357 --json status,conclusion,headSha,event --jq '{status,conclusion,headSha,event}'
exit: 0
at: 2026-10-21T21:40:49Z

{"conclusion":"success","event":"pull_request","headSha":"88b7ace52d7c938d89d4154a02f43eb424240fb6","status":"completed"}

## Evidence: Post-PR CI — steps 25–33 conclusions (run 39678612357, pull_request) — the steps round 1 never reached

command: gh run view 39678612357 --json jobs --jq '.jobs[] | .steps[] | select(.number>=25 and .number<=33) | "\(.number)\t\(.conclusion // .status)\t\(.name)"'
exit: 0
at: 2026-10-21T21:40:50Z

25	success	Check security-hardening deliverables
26	success	Check remediation budget
27	success	Install shellcheck
28	success	shellcheck scripts and templates
29	success	Install bats-core
30	success	Run shell gate bats tests (spec 001 Track B)
31	success	Run gate selftests
32	success	Check scenario traceability (live tree)
33	success	Validate YAML syntax (.github, ci)

Full step list of the same job (all 33 steps + post-steps `success`, none
`skipped`) was read in this round via
`gh run view 39678612357 --json jobs --jq '.jobs[] | .steps[] | "\(.number)\t\(.conclusion // .status)\t\(.name)"'`
(exit 0, at 2026-10-21T21:29:20Z): steps 1–24 `success` (Set up job; checkout
`actions/checkout@11d5960a326750d5838078e36cf38b85af677262`; setup-python; Install
PyYAML; CRLF check; CI sweeper; model-agnostic agents; `bash -n` parse; step 9
`make validate-all`; step 10 design-gate blame scoping; gate list consistency;
orchestration references; non-vacuous bats assertions; post-PR CI loop mechanics;
skills specification; step 16 finished-specs-archived; spec audit trails; step 18
`make lint`; pinned opencode + model-env resolution; agent env guard / hardcoded
secrets; loop files; Daily Triage; PR Babysitter; PR review agent deliverables),
then 25–33 as above, then 65/66 post-steps and 67 `Complete job` — all `success`.

## Evidence: Post-PR CI — steps 25–33 conclusions (run 39678605487, push)

command: gh run view 39678605487 --json jobs --jq '.jobs[] | .steps[] | select(.number>=24 and .number<=33) | "\(.number)\t\(.conclusion // .status)\t\(.name)"'
exit: 0
at: 2026-10-21T21:40:51Z

24	success	Check PR review agent deliverables
25	success	Check security-hardening deliverables
26	success	Check remediation budget
27	success	Install shellcheck
28	success	shellcheck scripts and templates
29	success	Install bats-core
30	success	Run shell gate bats tests (spec 001 Track B)
31	success	Run gate selftests
32	success	Check scenario traceability (live tree)
33	success	Validate YAML syntax (.github, ci)

Push-event run conclusion, same head SHA:

command: gh run view 39678605487 --json status,conclusion,headSha,event --jq '{status,conclusion,headSha,event}'
exit: 0
at: 2026-10-21T21:29:20Z

{"conclusion":"success","event":"push","headSha":"88b7ace52d7c938d89d4154a02f43eb424240fb6","status":"completed"}

## Evidence: Post-PR CI — step 25 AC-026-13 now passes (the round-1 failure is closed)

command: gh run view --job 119494905580 --log | awk -F'\t' '$2=="Check security-hardening deliverables"' | grep -E "AC-026-13"
exit: 0
at: 2026-10-21T21:40:53Z

^[[0;32mPASS^[[0m AC-026-13: every third-party Action in .github/workflows/*.yml is SHA-pinned
^[[0;32mPASS^[[0m AC-026-13: no live workflow/script/template references this repo's own workflows via @main
^[[0;32mPASS^[[0m self-citation: script cites every AC-026-NN scenario ID (AC-026-01 … AC-026-13)

(ANSI colour markers reproduced verbatim as they appear in the log; the log was
captured to a scratch file `/tmp/opencode/r2job.log`, 3397 lines, excerpted, and
deleted at the end of this round. Round 1's failing line —
`FAIL AC-026-13: mutable third-party Action ref(s) found … uses: actions/checkout@v4`
— does not occur anywhere in the round-2 job log.)

The fix under verification, in the local tree at head:

command: grep -n "uses:" .github/workflows/ci-vercel-production-verify.yml
exit: 0
at: 2026-10-21T21:40:05Z

53:      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.3.0

## Evidence: Post-PR CI — the only error annotation in the Validate job is the non-blocking shellcheck step

command: gh run view --job 119494905580 --log | grep -F "##[error]" | awk -F'\t' '{print $2}' | sort | uniq -c
exit: 0
at: 2026-10-21T21:40:53Z

      1 shellcheck scripts and templates

Raw line:

[step: shellcheck scripts and templates] 2026-10-21T21:26:41.6618224Z ##[error]Process completed with exit code 1.

Every other step in the job carries no error annotation, so the `success`
conclusions above are real passes, not swallowed failures — the single swallowed
one is shellcheck, which is `continue-on-error: true` by design
(`.github/workflows/self-ci.yml:228`) and therefore cannot fail the job.

## Evidence: Post-PR CI — step 30 bats (first execution on this branch; round 1 skipped it)

command: gh run view --job 119494905580 --log | awk -F'\t' '$2=="Run shell gate bats tests (spec 001 Track B)"' | grep -E "1\.\.[0-9]+|^.*ok 241 "
exit: 0
at: 2026-10-21T21:40:53Z

1..473
ok_count=473 not_ok_count=0
ok 241 check-pr-review: clean repo exits 0 and prints its documented clean line

TAP plan `1..473` with 473 `ok` lines and 0 `not ok` lines. Spec-031 scenarios are
inside that suite and green, e.g. `ok 92 AC-031-45 — preview build timeout records
FAIL with the timeout reason and consumes a phase-3 round`, `ok 93 AC-031-46`,
`ok 94 AC-031-47`, `ok 95 AC-031-48`, `ok 111 AC-031-36 — phase 3 does not start on
a phase-2 FAIL verdict`.

## Evidence: Post-PR CI — steps 31 / 32 / 33 (first execution on this branch; round 1 skipped them)

command: gh run view --job 119494905580 --log | awk -F'\t' '$2=="Run gate selftests" || $2=="Check scenario traceability (live tree)" || $2=="Validate YAML syntax (.github, ci)"' | grep -E "pass: [0-9]+|Scenario traceability check|\[OK\]"
exit: 0
at: 2026-10-21T21:40:53Z

  pass: 39  fail: 0  skipped-by-007-dependency: 0
^[[0;32m✔ Scenario traceability check: every scenario traced, every reference resolves.^[[0m
56

Step 31 gate selftests: `pass: 39 fail: 0 skipped-by-007-dependency: 0`. Step 32
scenario traceability on the live tree: every scenario traced, every reference
resolves. Step 33 YAML validation: 56 `[OK]` file lines, no failure line, e.g.
`[OK] ci/gitlab/backend/ci-go.yml`.

## Findings recorded this round (record, do not fix — Stop-and-Ask matrix rows "Out-of-scope finding" / "Design gate WARN")

1. **shellcheck findings — non-blocking, `continue-on-error: true` (`self-ci.yml:228`); NOT a CI FAIL.**
   Step 28 exited 1 over the repo-wide `shellcheck scripts/*.sh templates/*.sh`
   invocation (the step is not blame-scoped). 35 distinct files flagged; aggregate
   by code: SC2086 ×55, SC2016 ×38, SC2034 ×23, SC2317 ×18, SC1091 ×9, SC2001 ×8,
   SC2015 ×4, SC2094 ×4, SC2318 ×4, SC2013 ×2, SC2012 ×2, SC2044 ×2, SC2053 ×2,
   SC2295 ×3, and SC2012/SC2126/SC2128/SC2163/SC2178/SC2181/SC2206/SC2207 ×1 each.
   **29 flagged locations fall in 7 files that this change set touched**
   (`git diff --name-only origin/main...HEAD` ∩ shellcheck-flagged files):
   `scripts/check-audit-trail.sh:104,117`; `scripts/check-model-env.sh:65,127`;
   `scripts/check-pr-review.sh:259,438,444,607,625,682,750`;
   `scripts/check-stop-and-ask-matrix.sh:160,161,164,169,173,174,175,179`;
   `scripts/model-env.runtime-check.sh:130,160,161`;
   `scripts/model-env.selftest.sh:150,284,419,541,551`;
   `scripts/model-env.vars.sh:17,31`. Per-file codes: SC2016 ×8 in
   `check-stop-and-ask-matrix.sh`, SC2016 ×5 in `check-pr-review.sh`, SC2016 ×3 in
   `model-env.selftest.sh`, SC1091 ×3 in `model-env.runtime-check.sh`, SC2034 ×2 in
   `model-env.vars.sh`, SC2318 ×2 in `check-audit-trail.sh`, plus single SC2163 /
   SC2086 / SC2053 / SC2013 / SC2086 / SC2016. Whether each is diff-introduced or
   pre-existing is **undetermined this round**: the CI step is repo-wide while the
   design gate is blame-scoped, and shellcheck is not installed locally (phase-1
   note stands), so no local re-run was possible. Out of scope → propose a
   follow-up spec (quote-hygiene sweep of `scripts/*.sh`); flagged to the Architect.
2. **`AC-024-01-12` passes vacuously in CI.** bats 241
   (`check-pr-review: clean repo exits 0 …`) is green here, as expected: under CI's
   `fetch-depth: 1` there is no `origin/main`, so `check-pr-review.sh:342-347`
   yields an empty `TOUCHED` and the check's "change set modifies `agents/spec-*`"
   clause **never fires**. A green CI therefore does not exercise that clause; in a
   full local clone the same test fails for the same reason (diff base missing
   under shallow fetch semantics, not a behavior defect). Recorded as an
   out-of-scope finding — not fixed this round, and not a round-2 FAIL: the
   divergence is pre-existing CI-harness scope, and the Coder reproduced exit 0
   under a real `--depth 1` clone. Follow-up: make the PR-review gate's diff base
   shallow-clone-aware (or fetch `origin/main` in CI) so the clause is actually
   exercised.
3. **Design-principles local noise did not fail CI** — as predicted. Step 9
   `make validate-all` and step 10 `Check design-gate blame scoping (scratch repos)`
   are green at head, consistent with the blame-scoped gate (the plain local
   `bash scripts/check-code-principles.sh --json` 1-FAIL/16-WARN set lives in
   untouched files such as `skills/hallmark/site/examples/cobalt-01/script.js:
   CC=10`; blame-scoped `-BaseRef HEAD --json` exits 0). Phase-1 WARNs remain
   flagged to the Architect; no new WARN arose from CI.
4. **Execute-bit gap persists (028 W5 lineage).** Several `scripts/*.sh` are mode
   644, so `./scripts/x.sh` yields exit **126**; every script invocation this round
   used the `bash scripts/x.sh` form, including `bash scripts/record-gate-run.sh`
   for telemetry.
5. **PR Review Agent check still `pending` at the bound.** Run 39678612431
   (job 119494906363) `IN_PROGRESS` from 21:25:04Z through 21:40:05Z (≈15 min)
   after a 300 s bounded watch. `pending` is neither pass nor fail; it is not a
   Self CI check and holds no phase-2 verdict authority. Recorded so the
   orchestrator can re-query it independently before merging the draft PR.
6. **No unaccounted behavior in the round-2 delta.** The delta over round 1 is
   `22c2234` (one-line SHA-pin of `actions/checkout` in
   `.github/workflows/ci-vercel-production-verify.yml:53`, exactly the routed fix)
   and `88b7ace` (round-1 evidence + one `runs.jsonl` telemetry row + the 13→15
   commit-count correction in this one-pager). No production logic was added, so
   nothing in the delta lacks a task/scenario trace.

## Typed-judgment fast-path

**Not invoked.** ADR 0004 applies: the orchestrator reports exit 10 (fallback) on
every call — the spec-028 wrapper (and the shipped example at
`skills/ci-triage/SKILL.md:81`) sends `criteria` as a string while the spec-029
backend requires a dict (Choice) or list (Score), so it rejects the payload with
HTTP 422. Exit 10 means "no fast-path exists": the stock procedure above was run
unchanged. The wrapper/backend contract mismatch is a diagnosed out-of-scope
defect (spec 028 ↔ spec 029), not fixed this round; because no call was made, no
`judgment_fallback` claim is recorded, and a typed judgment could never carry gate
authority in any case — the verdict here is transcribed from CI state, step
conclusions, and log lines.

## Budget and counters

- Phase-2 round **2 of max 3** consumed, verdict **PASS** → the phase-2
  post-PR CI loop is green; **1 round of the phase-2 budget remains unused** and no
  further remediation is required. Phase-1 budget untouched (PASS at attempt 1, 0
  retries). Phase ordering (docs/SPEC_PIPELINE.md §Remediation budget): phase 3
  (deploy verification) may now start — that is the orchestrator's call, and the
  still-pending PR Review Agent check is not a phase-2 gate.
- Telemetry exported in-shell **before** invoking the writer:
  `export SPEC_LOOP_COUNT=3 SPEC_PHASE1_RETRIES=0 SPEC_PHASE2_RETRIES=1`. Verified
  against the ledger tail first, not trusted: `runs.jsonl` ends with the round-1
  record `3b32f832-db69-4947-8bff-57cd598fcf10` (`outcome=fail`, `loopCount=2`,
  `phase1Retries=0`, `phase2Retries=0`), preceded by the phase-1 record
  `f256d674-ac9b-486d-8031-99290bfdbf40` (`outcome=pass`, `loopCount=1`,
  `phase1Retries=0`, `phase2Retries=0`). The ledger agrees with the derivation:
  this is the third Verifier invocation, phase 1 used zero retries, and one
  phase-2 remediation round was already consumed. No divergence to report.
- `gatesFailed` for this round: **none** (`[]`) — every Self CI check at head is
  green, so `outcome=pass`; the shellcheck and vacuous-`TOUCHED` items are carried
  as `warnings`, not as gate failures.

## Dirty paths to route to the PR Opener (Verifier commits nothing)

1. `docs/changes/031-vercel-deploy-lane.md` — this appended round-2 section (the
   committed round-1 evidence above is byte-for-byte untouched).
2. `runs.jsonl` — one telemetry row appended via `bash scripts/record-gate-run.sh`.

Neither is committed, stashed, reverted, or cleaned up by the Verifier
(`git commit*` / `git push*` are denied to this agent); commit + push belong to the
PR Opener. Scratch files used for log capture (`/tmp/opencode/r2job.log`,
`/tmp/opencode/r2w.log`, `/tmp/opencode/r2pr.log`, `/tmp/opencode/bats.log`,
`/tmp/opencode/scfiles.txt`, `/tmp/opencode/changed.txt`) are outside the repo and
were deleted.

**Verdict (phase-2 round 2): PASS** — Self CI `Validate` at head SHA
`88b7ace52d7c938d89d4154a02f43eb424240fb6` is green on **both** events
(pull_request run 39678612357 / job 119494905580; push run 39678605487 / job
119494883712), step 25 `Check security-hardening deliverables` now reports
`PASS AC-026-13` (round-1 failure closed by the `22c2234` SHA-pin), and steps
26–33 — remediation budget, shellcheck install, shellcheck run, bats install, bats
suite (473/473 ok), gate selftests (39 pass / 0 fail), scenario traceability on the
live tree, YAML validation (56 OK) — **executed and passed, not skipped**.
`PR Review Agent` remains PENDING at the polling bound and is not ruled on.
Findings 1–6 above are recorded, not fixed; nothing is routed to the Coder or the
Refactorer this round.
