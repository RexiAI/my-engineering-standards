# CI-failure check-and-remediate loop

After the pipeline pushes a feature branch and opens a PR, CI runs on it. When
that CI fails, the failure is the agent's to see and handle — not something it
pushes past and reports green. acdc-civ does this with a dedicated Verifier gate
(G6 CI = Jenkins build SUCCESS) plus a bounded post-PR remediation loop: on
failure, the Implementor fixes and re-pushes; the loop is capped (max 3) and
exhaustion escalates to the human.

This repo's pipeline (spec-* agents + commands) has no such loop: the PR Opener
opens the PR, then the run ends. A red CI on the just-opened PR is never checked
by an agent.

## What it must provide

- A post-PR CI check step: after the PR is opened, the pipeline queries CI status
  for the feature branch (GitHub Actions / the repo's CI) and records PASS/FAIL
  per check.
- On FAIL: the agent reads the failing job's logs, diagnoses, and feeds the
  concrete error back into a fix round.
- A bounded fix loop, independent per phase (mirror the remediation-budget spec):
  max 3 fix-and-repush rounds; each re-push re-triggers CI; exhaustion escalates
  to the human with the failing check IDs + last log evidence.
- The verdict recorded in the pipeline's report artifact (25-verification.md or
  30-report.md) so the outcome is auditable.

## Acceptance criteria

- AC-001: the pipeline has a defined post-PR CI status check (which command
  queries CI, how PASS/FAIL is parsed).
- AC-002: on CI FAIL, the pipeline reads the failing job's logs and records the
  failure reason in the report artifact.
- AC-003: fix rounds are bounded (max 3); each round re-pushes and re-checks CI.
- AC-004: budget exhaustion stops the pipeline with the failing check IDs and
  last log excerpt, escalated to the human — never a silent green.
- AC-005: the report artifact records CI outcome per check and per round.
