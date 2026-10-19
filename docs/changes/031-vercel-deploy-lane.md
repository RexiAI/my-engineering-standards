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
Commit count: 13
