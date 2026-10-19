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
