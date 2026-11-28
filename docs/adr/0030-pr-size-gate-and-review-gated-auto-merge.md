# Architecture Decision Record (ADR)

## Title

PR size gate and review-gated auto-merge through GitHub native auto-merge

## Status

Proposed

## Context

`agents/pr-review.md` carries a blanket `auto-merge` prohibition in its scope
lock. It was written when any automatic merge had to be an agent action, and
the prohibition was the only way to keep the review agent from merging its own
findings. GitHub has since shipped native auto-merge: the repository, not an
agent, waits for the required checks and performs a squash merge.

The repo also has no size discipline: a 5,000-line PR reaches review with the
same weight as a 20-line fix. The informal spec
(`specs/045-pr-size-gate-and-auto-merge/00-informal.md`) asks for deterministic
size tiers, a CODEOWNER override, and a review-verdict check that gates
auto-merge.

Two rules appear to forbid this and must be reconciled rather than quietly
changed:

- `docs/SPEC_PIPELINE.md` §Autopilot mode's Never-list says `no merge` — an
  agent never merges.
- `agents/pr-review.md`'s scope lock forbids `auto-merge` outright.

This changes the merge authority surface, so an ADR is required per
`docs/GOVERNANCE.md §ADR Requirement`.

## Decision

GitHub's native auto-merge, gated by deterministic required checks, performs
the merge. The required checks are `pr-size`, `review-verdict`, the ordinary CI
checks, and `mutation` when the repository variable `MUTATION_REQUIRED` is
`true`. A pipeline stage runs `gh pr merge --auto --squash` to arm it; the
merge itself is GitHub's asynchronous action, executed only after every
required check is green.

`agents/pr-review.md` remains read-only and never merges. Its scope lock keeps
the blanket `auto-merge` prohibition, and that prohibition continues to bind the agent: the agent
never arms, approves, or performs a merge, and its `permission` block still
denies `edit` and `bash`. It no longer forbids the repository's
GitHub auto-merge configuration — that is a repository setting, not an agent
capability.

The distinction is explicit: `docs/SPEC_PIPELINE.md` §Autopilot mode's
Never-list `no merge` continues to bind every pipeline and autopilot agent, and
no pipeline agent is the actor that merges. The repository's GitHub
configuration is what merges, and only through the pull request's required
checks.

Merges still happen only through a pull request whose base branch has branch
protection. No direct push to `main` or `master` is introduced, and the
PR-only flow is unchanged.

The exclusion classes that keep a PR from weakening its own gates are part of
the decision: a changed path under `.github/workflows/`, `agents/`,
`scripts/check-*`, or `opencode.json` is a `gate_surface` exclusion and is
never auto-merged, together with auth/secret code, database migrations, and
dependency manifests and lockfiles.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| GitHub native auto-merge gated by required checks (chosen) | No agent merge authority; GitHub enforces the check list; squash-only; auditable in the PR | Requires the repository `allow_auto_merge` setting and branch protection to list the new contexts |
| An agent runs `gh pr merge` after review | No repository setting needed | Gives an agent merge authority — exactly what the Never-list forbids; no independent check enforcement |
| Keep auto-merge forbidden; require a human for every PR | Simplest policy | No size discipline; small safe PRs wait the same as large ones |
| Bot account with merge rights | Keeps agents out of the loop | New credential to rotate; a second merge authority outside branch protection |

## Consequences

- Small PRs (≤200 changed lines) merge through a pull request once the
  required checks are green, without a human clicking merge.
- Medium PRs (201–400) and large PRs (>400 without an authorized override)
  still need a human; the `pr-size` check fails only above 400.
- Arming requires the repository setting `allow_auto_merge` and branch
  protection that requires `pr-size` and `review-verdict`; a repo without them
  arms nothing and fails closed.
- The PR-only flow is preserved: branch protection still requires a pull
  request, and no direct push to `main` or `master` is introduced.
- The review agent's read-only posture is unchanged, so the quality of review
  is not coupled to merge authority.
- Rollout defaults to report-only: `PR_AUTOMERGE_MODE` unset means `report`,
  which comments instead of merging.

## Compliance

`scripts/check-pr-size-gate.sh` asserts the shipped artifacts and the settings
statements; `scripts/tests/pr-size-gate.bats`,
`scripts/tests/pr-review-verdict.bats`,
`scripts/tests/pr-automerge-eligibility.bats`,
`scripts/tests/pr-automerge-notify.bats`, and
`scripts/tests/pr-size-gate-deliverables.bats` cover the behaviour and every
AC-045 scenario. `scripts/check-pr-review.sh` continues to prove the review
agent's scope lock and permission block. Reviewers check that no workflow uses
`pull_request_target` or executes PR-head code, and that `gh pr merge` appears
only as `--auto --squash`.

## Notes

- 2026-11-28: Decision recorded
