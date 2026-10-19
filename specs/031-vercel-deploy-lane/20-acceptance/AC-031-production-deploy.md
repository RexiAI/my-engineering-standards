# AC-031: Production deploy verification (post-merge)

## AC-031-37 — Post-merge workflow verifies production deployment
Given a PR has been merged to `main` on a frontend child repo
And the Vercel Git integration has produced a production deployment for the merged commit
When the post-merge verification workflow runs
Then it queries the Vercel API for the production deployment, runs a health check against the production URL, and records the result

## AC-031-38 — Production deployment not found: skip, do not fail
Given the post-merge workflow runs on a commit where no production deployment exists in Vercel
When the workflow queries the Vercel API
Then it records a skip reason ("Production deployment not found for commit <sha>") and exits 0 (does not fail the workflow run)

## AC-031-39 — Repo with no Vercel project: skip, do not fail
Given the post-merge workflow runs on a child repo that has no Vercel project linked
When the workflow attempts to verify the production deployment
Then it records a skip reason ("No Vercel project linked to this repository") and exits 0 (does not fail the workflow run)

## AC-031-40 — VERCEL_TOKEN missing or invalid
Given the post-merge workflow runs with a missing or invalid `VERCEL_TOKEN` secret
When the workflow attempts to authenticate with the Vercel API
Then it records a failure with the authentication error and exits non-zero (this is a configuration defect, not a skip)

## AC-031-41 — Git integration not connected
Given the post-merge workflow runs on a child repo where the Vercel Git integration is not connected
When the workflow queries for deployments
Then it records a skip reason ("Vercel Git integration not connected") and exits 0
