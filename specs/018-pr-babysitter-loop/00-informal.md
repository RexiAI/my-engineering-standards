# PR Babysitter loop (watch PRs, keep them moving, keep the human in the seat)

A loop that reduces human time herding pull requests through review, CI, rebase,
and merge — while keeping the human in the judgment seat. Brings the
pr-babysitter pattern from cobusgreyling/loop-engineering.

## What it must provide

1. **Watcher.** Scheduled or event-triggered check of open PRs in this repo (or a
   child repo). For each PR: run a triage skill, record status of checks
   (passing / failing / pending / absent-unknown), required-check policy,
   review comments, mergeability, ready-to-merge state.

2. **Absent/unknown is not green.** Zero returned checks = absent/unknown; a PR is
   not ready until the repo's required-check policy is known and all gates are
   satisfied. Never assume green from a missing report.

3. **Actions.**
   - Failing checks → spawn a minimal-fix sub-agent → verifier confirms →
     propose a patch / comment on the PR (never merge).
   - Ready (policy satisfied, approvals present, no blocking comments, no
     conflict) → add a "ready to merge" label or ping the human.
   - Idle too long → suggest close or hand-off.

4. **Bounded and guarded.** Circuit breaker per PR: max N fixes without progress
   (e.g. 3) → escalate, stop commenting. Human gates always required for:
   high-risk refactors, security/auth/payments/infra, >N files.

5. **State.** `pr-babysitter-state.md` (or STATE.md section): watched PRs, last
   action + outcome, human overrides. Prune merged/closed PRs every run.

6. **Identity.** Loop's PR comments are clearly signed (e.g. "Loop Engineering —
   PR Babysitter").

## Acceptance criteria

- AC-001: a pr-review-triage skill exists defining this repo's review norms,
  required checks, and what "ready to merge" means.
- AC-002: the watcher records check status with the absent/unknown distinction;
  absent is never treated as green.
- AC-003: failing-check fixes are proposed by a separate implementer + verifier,
  never merged by the loop.
- AC-004: the loop adds "ready to merge" or pings the human only when policy is
  satisfied; ambiguous/high-risk items escalate with context.
- AC-005: remediation is bounded per PR; repeated failures escalate instead of
  repeating comments.
- AC-006: state is pruned each run; loop comments are signed.
- AC-007: cost guidance documented (early exit on empty watchlist).
