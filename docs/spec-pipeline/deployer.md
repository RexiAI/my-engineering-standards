# Deploy Verifier stage file (stage 5c)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Stop-and-Ask decision matrix,
and §Remediation budget (phase 3).

## Deploy verification loop (phase 3)

After stage 5b opens the draft PR (spec 031), stage 5c (`spec-deployer`)
verifies the live system: it waits for the Vercel preview deployment the Git
integration built for the PR head commit, runs a health check, then delegates
E2E against the live preview URL, and records every round in
`specs/NNN-slug/40-deploy.md`. Phase 3 is bounded: its budget is **max 3**
fix-and-redeploy rounds and its counter is independent of **Phase 1** (pre-PR)
and **Phase 2** (post-PR CI) — exhaustion of one does not consume another's
budget.

Ordering is explicit: Phase 3 runs only after the phase-2 CI loop is green; on a
phase-2 FAIL verdict phase 3 does not start and the pipeline stops with the
phase-2 failure evidence. The two loops never race.

On the 3rd failed round `40-deploy.md` carries the marker line
`Phase-3 budget exhausted` and `Verdict: ESCALATED`, the pipeline STOPs before
stage 5d (the Archiver never runs for an exhausted spec —
`check-specs-archived.sh` accepts that non-archival), relays the failing check
IDs and the last log evidence from `40-deploy.md` verbatim, and escalates to the
human.

### Fix-routing (deterministic)

- E2E test runner exits non-zero against the live preview URL → route to spec-coder (behavior). Deterministic: the test runner's exit code is unambiguous.
- Vercel API returns a configuration-classified error (invalid vercel.json, wrong framework preset, env var missing from the Vercel project) → spec-deployer retries itself after the config repair. Deterministic: the Vercel error code classifies it.
- Structural or complexity gate failure → route to spec-refactorer. Deterministic: the gate script's exit code is unambiguous.

### Ambiguous cases — flagged open, escalated, never guessed

- A Vercel build failure (`BUILD_FAILED`) where the build log does not contain a
  clearly code-diagnostic or config-diagnostic pattern: STOP and escalate to the
  human.
- A health-check failure whose cause could be code or a missing runtime
  environment variable: STOP and escalate to the human.

Both cases stay open questions (spec 031 `10-tasks.md` §Open questions): the
routing rule above is the deliberate Option B — immediate escalation, no log
grepping heuristic invented. Upgrade path if a later spec adopts pattern-based
routing: extend this section and its contract test together, never the routing
silently.

## Vercel CLI access

The only permitted Vercel CLI commands (see `vercel.com/docs/cli` for each
command's own reference):

| Command | Purpose |
|---|---|
| `vercel inspect` | deployment state — build status, url, readiness |
| `vercel logs` | build/runtime log output for a deployment |
| `vercel ls` | recent deployments for the linked project |
| `vercel env pull` | sync remote env vars into a local file for inspection |
| `vercel env add` | add a missing environment variable to the project (configuration-classed repair only, never a workaround for a code defect) |
| `vercel pull` | sync project settings locally |
| `vercel domains` | verify the domain/alias the preview URL resolves through |

Auth for the CLI/API comes from the per-machine gitignored `config/agent.local.env`
(`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, loaded via direnv). Never
echo the token value.

**A missing `VERCEL_TOKEN` is NOT a defect for preview verification.** The Vercel
Git integration builds the preview and publishes its identity through channels
that need no API credential:

- the `Vercel` commit status on the PR head (`target_url` is the deployment),
- the Vercel bot's PR comment payload (`previewUrl`, inspector id),
- `vercel inspect` on the alias, using the CLI's stored operator session,
- the immutable deployment URL, which serves the same HTML as the branch alias.

Resolve the deployment from those signals first, and verify identity by matching
the deployment's `githubCommitSha` to the PR head — a branch alias can point at a
stale build, which is the failure mode that matters here (a 200 from the wrong
commit is a failure, not a pass). Report a missing token as a **note about CI
reproducibility** if and only if the deployment genuinely cannot be resolved
without an API credential; do not classify it as a configuration defect, and do
not use its absence as a reason to skip the stage or to claim the project is not
linked.

Premium/paid Vercel APIs (`vercel env add`, project settings writes) are not part
of deploy verification. Only `verify-production-deploy.sh`, the separate
post-merge lane, requires an API credential.

`vercel deploy` and `vercel deploy --prod` are absent from that list because the
Git integration owns builds: a CLI deploy next to a push-triggered build causes
a double-build, races the Git integration for the same commit, and leaves
orphaned deployments no PR or branch owns.

## What you do (frontend repos, phase 3)

Phase 3 starts only after the phase-2 post-PR CI loop is green, and runs after
the draft PR is open (5b) and before the archive (5d). One evidence run per
phase-3 attempt:

1. **Wait for the preview deployment.** Poll `vercel inspect` / `vercel ls` for
   the deployment the Git integration built for the PR head commit until it is
   READY, or the configured wait timeout expires. On timeout, record verdict
   `FAIL` with the reason
   `Preview build did not complete within <timeout> seconds` — this consumes one
   phase-3 attempt.
2. **Verify the build.** A build failure (`BUILD_FAILED`) records verdict
   `FAIL`, the Vercel error classification, and a build log excerpt pulled with
   `vercel logs`.
3. **Health check.** `curl` the deployment's preview URL; a non-2xx response or
   a connection timeout is a health-check `FAIL` — record the response code or
   the timeout.
4. **E2E against the live preview URL.** Delegate execution to the
   `e2e-runner` subagent, invoked per the e2e-testing skill
   (`skills/e2e-testing/SKILL.md`), pointed at the live preview URL — never at a
   local dev server. Record the runner's exit code and failure details.
5. **Write `40-deploy.md`** in the evidence format below.

## 40-deploy.md evidence format

Same evidence-block format as `25-verification.md` (`docs/spec-pipeline/audit-contract.md`
§Audit contract): heading, `command:` / `exit:` / `at:` markers in ISO-8601 UTC,
raw output, for every machine-readable entry. The document records the deploy
URL, build status (pass/fail/skip), health check status, E2E verdict
(pass/fail/skip), timestamp, phase-3 attempt count, and the overall `Verdict:`
line (`PASS`, `FAIL`, `ESCALATED`, or `SKIPPED`).


