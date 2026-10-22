# Architecture Decision Record (ADR)

## Title

Stage-split deploy-artifact gate: `--require-deploy` for the stage-5d final run

## Status

Accepted

## Context

Spec 031 wired `scripts/check-audit-trail.sh` to require `40-deploy.md` in a
frontend repo (AC-031-18, AC-031-21). But stage 5b (the PR Opener) runs that
gate **pre-push**, while stage 5c (the Deploy Verifier) can only write
`40-deploy.md` **after the PR opens** — it verifies a live Vercel preview
deployment. A frontend child repo therefore could never pass 5b's mandatory
gate: the artifact it demanded could not exist yet. The deploy lane was dead
on arrival for its actual consumers (Angular, React, Next.js, Ionic web).

Spec 031's Coder implemented the non-frontend-tolerant reading and documented
the ceiling in the gate itself: the script could not distinguish "pre-5c" from
"5c skipped writing it", with an explicit upgrade path — "a `--require-deploy`
flag once 5d owns the final gate run". This ADR records taking that documented
path, not a new mechanism.

## Decision

We add a `--require-deploy` flag to `scripts/check-audit-trail.sh` and split
the frontend missing-artifact rule by pipeline stage:

- Default invocation (stage 5b, pre-push): a *missing* `40-deploy.md` in a
  frontend repo is tolerated and reported as a PASS line; a present-but-empty
  or malformed artifact still fails, preserving AC-031-19's guarantee.
- `--require-deploy` invocation (stage 5d, final gate): a missing
  `40-deploy.md` in a frontend repo fails — AC-031-21's existing semantics,
  now enforced at the stage where the artifact can actually exist.
- Non-frontend behavior is flag-independent and byte-identical to before.
- The exit-code contract (0/1/2) and the PASS/FAIL line format are unchanged;
  the requirement still binds, just at the stage that can satisfy it. This is
  a stage-correctness fix, not a relaxation.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Skip the deploy check entirely at 5b | Simple | Loses the AC-031-19 guarantee (present-but-empty/malformed artifacts would ship unflagged) |
| Move 5b's gate run after the PR opens | Keeps one gate semantics | Inverts the pipeline: the pre-push gate exists to stop bad pushes; PR Opener's carve-out requires gates green before push |
| Have 5c write a placeholder `40-deploy.md` at 5b time | Gate unchanged | Forgery: an audit artifact asserting a deployment that never happened — defeats the audit contract |
| Flag on the gate, split by stage (chosen) | Minimal, exactly the path spec 031 documented; both guarantees survive at the right stage | 5d must remember to pass the flag (mitigated: stated in §The gate, which the agent must read) |

## Consequences

- Frontend child repos can complete 5b and reach 5c; the deploy lane becomes
  usable by its consumers.
- The 5b gate output gains one new PASS line ("tolerated pre-5c") so the
  tolerance is visible in the evidence, never silent.
- Stage 5d's final gate run becomes the authoritative AC-031-21 check; if 5c
  failed to write the artifact, the pipeline cannot archive past 5d.
- The "ponytail ceiling" comment in the gate is retired; the upgrade path is
  no longer an open follow-up.
- Tests: AC-031-21's bats case amended to invoke `--require-deploy` (with
  inline justification); new cases pin the tolerated default, the preserved
  empty-artifact failure, and flag-independence for non-frontend repos. No
  test deleted.

## Compliance

- `scripts/tests/ac-031-deploy-artifact-contract.bats` and
  `scripts/tests/ac-031-non-frontend-skip.bats` exercise both modes against
  hermetic fixtures; `scripts/check-audit-trail.sh --selftest` keeps the
  negative-case corpus green.
- `docs/SPEC_PIPELINE.md §The gate` states which stage passes the flag; the
  pipeline agents are required to read that section.
- The PR Opener's pre-push gate run and self-ci remain flagless; any future
  5d wiring must use `--require-deploy` (review checklist).

## Notes

- 2026-10-22: Decision recorded on branch `fix/audit-trail-require-deploy`
  (stacked on spec 031's lane, PR #93). The instruction carrier is
  `docs/SPEC_PIPELINE.md`, not `agents/spec-pr-opener.md`, to avoid colliding
  with the `check-pr-review.sh` base-ref fix landing on PR #95.
