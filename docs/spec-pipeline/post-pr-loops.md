# Post-PR loops: CI remediation and production deploy verification (shared)

Shared reference. Read it from the stage file that names it; the index is
`docs/SPEC_PIPELINE.md`.

## Post-PR CI check-and-remediate loop (phase 2)

After the PR Opener opens the draft PR (stage 5b), the pipeline checks the PR's
CI status and, on FAIL, runs a bounded fix-and-repush loop. The budget *policy*
for this loop — at most 3 rounds, counter **independent of Phase 1** — comes from
spec 008's remediation-budget section (`008-remediation-budget`, "Phase 2 —
Post-PR loop"); this section defines only the *mechanics*, and is valid only once
008's section exists.

The repo's CI on a feature-branch PR is the **Self CI** workflow
(`.github/workflows/self-ci.yml`, GitHub Actions). Immediately after the PR is
opened, the Verifier queries its checks and records PASS/FAIL per check:

- Status query: `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`.
  The `bucket` field (`pass`/`fail`/`pending`) is the PASS/FAIL parse rule.
- Pending checks are polled until terminal (`gh pr checks --watch` or a bounded
  re-query); `pending` is neither a pass nor a fail.
- On FAIL, failing check IDs are captured from the checks API
  (`gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`,
  `conclusion == "failure"`, record `name` + `id`), the failing job logs are read
  (`gh run list --branch spec/NNN-slug --workflow "Self CI"` then
  `gh run view <RUN-ID> --log-failed`), and the concrete failure reason is
  recorded in `25-verification.md`.
- The CI outcome is recorded per check and per round in `25-verification.md`.

On FAIL the orchestrator routes the diagnosed fix to the Coder (behavior) or the
Refactorer (structure), the PR Opener commits and pushes the fix round — each
re-push re-triggers CI — and the Verifier re-checks. The loop runs at most 3
fix-and-repush rounds (counter independent of Phase 1). On exhaustion the pipeline
stops and escalates to the human with the failing check IDs and the last log evidence
— never a silent green.

## Production deploy verification (post-merge)

The pipeline's merge-to-`main` event gets one follow-up check (spec 031),
rewriting the old "nothing runs after the merge" sentence: the post-merge
workflow (`.github/workflows/ci-vercel-production-verify.yml`, shipped for
child repos) verifies the production deployment Vercel's Git integration built
for the merged commit. It queries the Vercel API for that deployment, runs a
health check against the production URL, and records the result in the job log.

Skip versus failure semantics — deterministic, `scripts/verify-production-deploy.sh`:

- no production deployment exists for the commit → skip with the reason
  `Production deployment not found for commit <sha>`, exit 0
- no Vercel project linked to the repository → skip with the reason
  `No Vercel project linked to this repository`, exit 0
- Vercel Git integration not connected → skip with the reason
  `Vercel Git integration not connected`, exit 0
- missing or invalid `VERCEL_TOKEN` → recorded failure with the authentication
  error, exit non-zero — this is a configuration defect, not a skip
- health check non-2xx or transport failure → recorded failure, exit non-zero

Everything else after the merge — release tagging (Semantic Release), human
review — stays out of scope. This lane is independent of the GHCR container
path: neither cancels the other.
