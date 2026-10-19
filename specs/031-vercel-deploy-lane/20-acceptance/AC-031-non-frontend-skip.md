# AC-031: Non-frontend skip behavior

## AC-031-42 — Non-frontend repo produces 40-deploy.md with skip reason
Given a child repo that is a Java, Go, Rust, or Python backend (no frontend framework detected)
When the spec-deployer agent runs stage 5c
Then it writes `40-deploy.md` with verdict `SKIPPED` and a skip reason such as "Non-frontend repo — deploy verification not applicable"

## AC-031-43 — Non-frontend repo never fails deploy gate
Given a non-frontend repo with `40-deploy.md` containing verdict `SKIPPED`
When `scripts/check-audit-trail.sh <slug>` is run
Then it exits 0 (the skip reason is acceptable, no deploy-verification failure)

## AC-031-44 — GHCR container path unaffected
Given a Next.js child repo that uses both the GHCR container path and Vercel verification
When the pipeline runs
Then the GHCR image push (`.github/workflows/ci-nextjs.yml` or equivalent) executes independently of Vercel verification, and neither cancels the other

## AC-031-45 — Preview build times out
Given the Vercel preview deployment is still in progress when the configured wait timeout expires
When the spec-deployer agent's wait loop times out
Then it records the timeout in `40-deploy.md` with verdict `FAIL` and the reason "Preview build did not complete within <timeout> seconds", and the phase-3 budget is consumed for this round

## AC-031-46 — Preview build fails
Given the Vercel preview deployment completes with a build failure
When the spec-deployer agent inspects the deployment
Then it records the build failure in `40-deploy.md` with verdict `FAIL`, the Vercel error classification, and the build log excerpt, and the phase-3 fix-routing rule determines the next action

## AC-031-47 — Deploy succeeds but health check fails
Given the Vercel preview deployment succeeds (build passes, deployment is READY)
And the health check against the preview URL fails (non-2xx or timeout)
When the spec-deployer agent records the result
Then `40-deploy.md` records verdict `FAIL` with the health check response code or timeout, and the phase-3 fix-routing rule determines the next action

## AC-031-48 — E2E fails against live preview URL
Given the Vercel preview deployment succeeds and the health check passes
And the E2E test runner exits non-zero against the live preview URL
When the spec-deployer agent records the result
Then `40-deploy.md` records verdict `FAIL` with the E2E failure details, and the failure routes to spec-coder per the fix-routing rule (AC-031-30)

## AC-031-49 — No Vercel project linked to the repo
Given a frontend child repo where no Vercel project has been created or linked
When the spec-deployer agent runs stage 5c
Then it writes `40-deploy.md` with verdict `SKIPPED` and the reason "No Vercel project linked to this repository — manual setup required", and the pipeline does not fail
