# Architecture Decision Record (ADR)

## Title

Vercel deploy lane: a spec-deployer stage (5c), the 40-deploy.md gate artifact, and a split pipeline tail (5a/5b/5c/5d)

## Status

Accepted

## Context

The spec pipeline ended at stage 5b: commit, push, open the draft PR, archive.
Nothing checked the live system after a frontend change — a PR could merge
"green" while its Vercel preview never built, its health endpoint 500'd, or its
E2E never ran against the deployed URL. `docs/TESTING.md` demands verification
against the live system (AGENTS.md: "a diff that compiles and a diff that works
are different claims"), and for Vercel-hosted frontends the live system is the
preview deployment the Git integration produces from the pushed branch.

Adding a verification stage touches three things `docs/GOVERNANCE.md` declares
review-blocking and therefore ADR-worthy: a pipeline role, the gate catalog (a
new evidence artifact), and billing — Vercel builds cost money, and a new stage
that touches Vercel per spec run consumes real paid resources.

## Decision

We add a **Deploy Verifier stage (5c, `spec-deployer`)** and split the pipeline
tail into four stages — **5a/5b/5c/5d** — so deploy verification sits between
"PR opened" and "spec archived":

- 5b (PR Opener) commits, pushes, and opens the draft PR but **no longer
  archives**; the Git integration then builds the preview deployment.
- 5c (spec-deployer) waits for that deployment, verifies a health check, runs
  E2E against the live preview URL (delegating to `e2e-runner`), and records
  every round in the new gate artifact **`40-deploy.md`**. It never runs
  `vercel deploy` — the CLI's role is limited to observation/sync (`vercel
  inspect`, `vercel logs`, `vercel ls`, `vercel env pull/add`, `vercel pull`,
  `vercel domains`) because a CLI deploy would double-build against the Git
  integration, race it for the same commit, and leave orphaned deployments.
- 5d (Archiver — the same `spec-pr-opener` agent) runs `archive-spec.sh` as the
  genuinely final act, only after deploy verification passed or was skipped.
- The loop gets its own bounded **phase-3 budget (max 3, counter independent of
  phases 1 and 2)** with deterministic fix-routing; ambiguous build/health
  failures escalate to the human, they are never guessed.
- Non-frontend repos skip cleanly: `40-deploy.md` carries
  `Verdict: SKIPPED — <reason>` and the deploy gate never fails them.
- Post-merge, a production verification lane
  (`scripts/verify-production-deploy.sh` +
  `.github/workflows/ci-vercel-production-verify.yml`) checks the production
  deployment for the merged commit — the pipeline doc's old "nothing runs after
  the merge" sentence is rewritten, not contradicted.

**Billing impact is explicit:** Vercel builds cost money. Each phase-3 round
re-triggers a real cloud build against the account that owns the linked
project; the max-3 cap bounds the spend per spec run, and the credential
pattern (`VERCEL_TOKEN`/`VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` in the gitignored
`config/agent.local.env`) keeps the spend authority outside tracked files.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Verify via `vercel deploy` from the agent | One tool, no Git integration dependency | Double-builds, races the Git integration, orphaned deployments nobody owns; breaks the source-of-truth model |
| Keep archiving at 5b and verify after merge only | No tail change | The spec folder is gone before the live check runs, so `40-deploy.md` would have no home in the audit chain |
| Unbounded re-verify loop | "Eventually green" | Violates the spec-008 remediation-budget policy; unbounded Vercel spend |
| Heuristic log-grep routing (Option A of the open question) | Fewer human interruptions | Invented classifier; the spec deliberately escalates ambiguous failures instead (Option B) |

## Consequences

Easier: every merged frontend change has live-system evidence in the PR; the
audit trail gains a stage with a machine-checkable artifact
(`check-audit-trail.sh`); budget exhaustion is greppable
(`Phase-3 budget exhausted`) and `check-specs-archived.sh` recognizes it without
false-failing.

Harder / accepted trade-offs: the pipeline tail is four stages instead of two —
more orchestration surface; `scripts/check-stop-and-ask-matrix.sh` and
`scripts/check-model-env.sh` rosters grew by one entry each (single-source-of-
truth files, by design); frontend repos without a linked Vercel project skip
verification (manual setup is their prerogative, recorded as a skip). The
5b-timing hole this spec discovered (the PR Opener's audit-gate run happens
before 5c can exist) is documented in the gate's `# ponytail:` note and
deferred to a follow-up spec.

## Compliance

Mechanical: `scripts/check-audit-trail.sh` (deploy-artifact contract),
`scripts/check-specs-archived.sh` (budget-exhaustion exception),
`scripts/check-orchestration.sh` (the new agent resolves),
`scripts/check-model-env.sh` (`{env:SPEC_DEPLOYER_MODEL}` wiring), and the
spec-031 bats suite (`scripts/tests/ac-031-*.bats`) — all wired into self-ci.
Review checklist: any change to `agents/spec-deployer.md` permissions must keep
the `vercel deploy*` bash deny.

## Notes

- 2026-10-19: Decision recorded (spec 031-vercel-deploy-lane).
