# 045 — PR size gate and review-gated auto-merge

## Problem

I own several projects and cannot review every pull request by hand: PRs reach
several thousand changed lines. Research (Google eng-practices "Small CLs",
SmartBear/Cisco review study, LinearB PR-size data) says review quality drops
sharply past ~400 changed lines, and the best teams keep PRs under ~200–225.

We already have a read-only PR review agent (`agents/pr-review.md`, shared
workflow `.github/workflows/ci-pr-review.yml`, ADR 0023). I want two things:

1. A deterministic PR size gate.
2. When the PR review agent gives the OK (and every other gate is green), the PR
   is merged automatically, and a human is told.

## Requirements

### PR size gate (new deterministic check, no AI)

- Count changed lines (additions + deletions) excluding: lockfiles, generated
  code, snapshot files, and pure file deletions.
- Tiers:
  - <= 200 changed lines: eligible for auto-merge.
  - 201–400: allowed, but NOT auto-merged; needs a human approval.
  - > 400: the check fails — split the PR.
  - A `size-override` label lets a >400 PR pass the size check, but such a PR
    is never auto-merged (human merges). Only a CODEOWNER may apply it.
- Thresholds 200 / 400 are confirmed by the owner.
- Shipped as a script under `scripts/` plus a reusable workflow, wired into child
  repos via `scripts/init-ci.sh` like the other gates, and run in this repo's
  self-ci.

### Review-gated auto-merge

- The merge is performed by GitHub's native auto-merge on top of branch
  protection — NOT by an agent. The pr-review agent stays read-only (its
  permission block keeps denying edit and bash).
- The pr-review agent's existing machine-readable marker is converted by the
  workflow into a required status check. Missing, malformed, or "findings"
  output → the check fails (fail-closed).
- Auto-merge happens only when ALL of these are green: CI, the size gate
  (<= 200 tier), the review status check, and mutation report where the tier
  requires it.
- Squash merge.
- Hard exclusions — never auto-merged regardless of verdict: changes touching
  `.github/workflows/`, `agents/`, `scripts/check-*`, `opencode.json`,
  auth/secret handling code, DB migrations, and major dependency bumps.
  (A PR must not be able to weaken the gates that approve it.)
- Auto-merge must NOT depend on the repo: no per-repo allowlist. Every repo
  that wires the workflow gets the same behavior.
- Treat PR title/body/diff as untrusted input (prompt injection): the AI
  verdict alone can never cause a merge; deterministic gates are always also
  required.

### Notify the human

- Every auto-merge notifies a human: a comment on the merged PR mentioning the
  CODEOWNERS (or repo owner when no CODEOWNERS file exists), stating which
  gates passed and the review verdict. Also notify when a PR was eligible but
  blocked by an exclusion, so the human knows to look.

### Rollout

- Ship with a report-only mode first ("would have auto-merged" comment, no
  merge), per `docs/LOOP_ENGINEERING.md §Readiness levels` (no skipping L1 on a
  production repo). Switching to live mode is a single documented setting,
  identical across repos.

## Governance

This reverses existing rules and therefore needs an ADR (per
`docs/GOVERNANCE.md §ADR Requirement`):

- `agents/pr-review.md` scope lock forbids `auto-merge` — the agent itself still
  never merges; the ADR must state that GitHub's native auto-merge, gated by
  deterministic checks, performs it.
- `docs/SPEC_PIPELINE.md §Never-list` "no merge" stays true for pipeline
  agents; the ADR must clarify the distinction.
- `AGENTS.md` rules on merging / PR-only flow to `main` remain: merges still
  happen only through a PR with branch protection.

Docs to update: `AGENTS.md`, `docs/GIT_WORKFLOW.md`, `docs/CI_CD.md`,
`templates/branch-protection.md`, ADR index.
