# CI Sweeper loop (react to failing CI, diagnose, propose, escalate)

A loop that watches CI on this repo's branches and PRs, reacts to failures
quickly, proposes minimal fixes, and escalates when it can't confidently resolve.
Brings the ci-sweeper pattern from cobusgreyling/loop-engineering.

## What it must provide

1. **Trigger.** GitHub Actions self-ci on push + PR; the loop reacts to a failing
   run on a feature branch or PR. Event-driven (workflow_run on failure) or a
   short-cadence scheduled `opencode run` (cron/systemd) — choose the mechanism
   that exists in this repo, do not invent a scheduler.

2. **Triage skill.** `skills/ci-triage/SKILL.md` — parse the failing job's logs,
   identify failing job/step, classify the failure: flake vs real regression vs
   infrastructure vs config. Flake (seen before, intermittent, passed on retry
   with no code change) → Watch, never auto-fix.

3. **Minimal fix.** Only the smallest change that addresses the specific failure.
   In an isolated worktree; verifier checks: fix addresses the failure, no
   unrelated changes, tests/lint pass.

4. **Bounded remediation.** Circuit breaker per failure: max 3 attempts, tracked
   in `loop-run-log.md` (or loop-ledger.json). Same failure recurs N× or attempts
   exceed max → escalate to human with pruned context, never loop forever.

5. **Escalation conditions.** Infrastructure failure (runner OOM, registry down,
   secrets missing), failure touching >5 files or core architecture, security
   sensitive, max attempts exceeded, intermittent flakes needing quarantine.

6. **State.** `STATE.md` CI Sweeper section: last run, failing commit SHA, failing
   job, attempt count, worktree/PR link, outcome. Prune resolved failures.

## Acceptance criteria

- AC-001: a CI-triage skill exists with the classify output format (flake /
  regression / infra / config) and the flake rule (never auto-fix).
- AC-002: the loop reacts to a failing CI run — the trigger mechanism is named
  and wired in this repo's `.github/workflows/`.
- AC-003: fix attempts run in an isolated worktree and are verified by a separate
  checker before proposing a PR/comment.
- AC-004: remediation is bounded (max 3 attempts per failure); exhaustion
  escalates to the human with the failing job + last log evidence.
- AC-005: STATE.md CI Sweeper section is updated each run and pruned on resolve.
- AC-006: cost guidance documented (early exit when CI is green; no full sweep on
  a no-op run).
