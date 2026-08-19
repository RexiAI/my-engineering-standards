---
name: pr-review-triage
description: Drive the PR Babysitter loop (spec 018): enumerate open PRs via gh or MCP, classify every check as passing/failing/pending/absent-unknown, read the required-check policy from branch protection cross-checked against .github/workflows, record per-PR triage state, propose bounded fixes through a separate implementer and verifier, label or escalate ready PRs, and never merge. Load when running the pr-babysitter loop under docs/LOOP_ENGINEERING.md.
license: See repo root
allowed-tools: Bash(gh pr list:*) Bash(gh pr checks:*) Bash(gh pr comment:*) Bash(gh pr edit:*) Bash(gh api repos/*/commits/*/check-runs:*) Bash(gh api repos/*/branches/*/protection:*) Bash(gh pr view:*) Bash(gh repo view:*)
---

# When to use

When the PR Babysitter loop runs. The loop watches every open PR in this repo,
triages it against the repo's own review and CI rules, records per-PR state,
proposes bounded fixes for failing checks, and labels or escalates ready PRs —
all without ever merging anything. This skill is the loop's operating
procedure, loaded for every watched PR, mirroring the structure of
`skills/check-principles/SKILL.md`.

# Invocation

The loop runs under 016's `LOOP.md` cadence — a short-cadence `opencode run`
per `docs/LOOP_ENGINEERING.md`. This spec invents no scheduler and no new
workflow file. PR state is read through the real GitHub mechanisms only: the
**GitHub MCP server** and the **`gh` CLI**.

At the start of every run the loop checks `STATE.md` (repo root): a
`KILL SWITCH: on` line means the run does not start, per 016.

Durable state is 016's, consumed by reference, never re-specified:

- `STATE.md` — the `## PR Babysitter` section (repo root)
- `loop-run-log.md` — append-only JSON entries per run
- `loop-budget.md` — token caps, sub-agent spawn limits, on-exceed actions

# What the loop does

## Watcher

On each run the loop enumerates open PRs with the real mechanism:
`gh pr list --state open` (fields `number,title,headRefName,isDraft,mergeable,mergeStateStatus`)
or MCP `github_list_pull_requests`. Each open PR is recorded in the watchlist
exactly once per run, regardless of which mechanism listed it.

## Check-state taxonomy

Every check report for a PR is classified into exactly one state: passing, failing, pending, or absent-unknown. Zero returned checks is classified `absent-unknown` and is never treated as green.

## Required-check policy

The required-check policy's source of truth is the branch protection rule on
the default branch — `required_status_checks.contexts` (default branch resolved
via `gh repo view --json defaultBranchRef`) — cross-checked against the
workflow files in `.github/workflows/` (this repo: `self-ci.yml`,
`archive-spec.yml`, `release.yml`) to see what CI actually runs. The policy is
known only when both reads succeed; any read failure makes the policy unknown.
The babysitter never modifies CI gating: `.github/workflows/*.yml`, branch
protection, and the required-check policy are read-only inputs.

## Review norms

Review norms, from `docs/GIT_WORKFLOW.md §PR Requirements`: PR titles follow
the conventional-commit format; at least one reviewer approval is required at
`production`+ tier (`mvp` projects may self-approve per
`docs/CONFORMANCE_TIERS.md`); no unresolved discussion threads are allowed;
merge is squash-only.

## Ready to merge

A PR is ready to merge when all of the following hold: the required-check policy is known and every required check is passing; at least the tier-required approval is present; there are no unresolved discussion threads; there is no merge conflict; and the PR is not a draft.

A PR whose policy is unknown, or any required check that is absent-unknown,
failing, or pending, is not ready to merge. Any required check that is pending,
failing, or absent-unknown blocks readiness.

## State recording

For each watched PR the loop records, in `STATE.md`: check status per check (passing/failing/pending/absent-unknown), whether the required-check policy is known, review state (approvals, unresolved threads), mergeability, and the resulting ready-to-merge verdict. Human overrides that change loop behavior are recorded in the same section.

## Spec-pipeline draft PRs

For draft PRs on `spec/NNN-slug` branches the loop records state only: it does
not propose fixes for CI failures, does not add labels, and does not comment on
the pipeline's own failures (the pipeline's Verifier/Architect own those);
once the PR is green and no longer a draft it may ping the human.

## Failing-check remediation

When a watched PR has a failing check, the loop spawns a separate
minimal-fix sub-agent that produces the smallest change addressing that
specific check, in an isolated worktree — never editing the PR branch in place.

A separate verifier sub-agent (the 016 maker/checker split, per `docs/LOOP_ENGINEERING.md`) independently confirms that the change addresses the failing check, that no unrelated files were touched, and that tests and lint still pass in the worktree. The implementer never marks its own work done.

The loop proposes the fix — as a patch on the PR or a PR comment — and never merges the PR; no auto-merge path exists. MCP/gh permissions are read + comment only (016 least-privilege).

## Circuit breaker

Circuit breaker per PR: max 3 fix attempts without progress (no new commits from the author between attempts, or the same check failing at the same head SHA). On exhaustion the loop escalates to the human with the failing check and last-attempt evidence and stops commenting on that PR.

A repeated failure (same PR, same failing check, N times) escalates instead of repeating the same comment.

## Human gates

Human gates before any fix proposal: high-risk refactor, changes touching security/auth/payments/infra (the 016 `gate.yaml` path denylist), or a PR touching more than 10 files. These never go to the fix sub-agent without a human decision.

## Idle PRs

A watched PR with no commits and no loop or human action for more than 3 days gets a single suggestion to close or hand off, recorded in state, and is not re-pinged on later runs.

## Ready-to-merge action

On a ready verdict the loop adds the `"ready to merge"` label via
`gh pr edit <n> --add-label "ready to merge"`; if label creation fails (label
missing or no permission) it pings the human instead with a comment mentioning
the PR author or reviewers.

No label and no ready notice are added on any non-ready verdict — unknown
policy, any absent-unknown/failing/pending required check, missing approval,
unresolved threads, conflict, or draft all suppress the action.

Ambiguous or high-risk items escalate to the human with the PR link and what is
uncertain; no `"ready to merge"` label is added.

## Pruning

Merged or closed PRs are pruned from the `## PR Babysitter` section on the run
that observes them, and the prune is recorded in the run-log.

## Comment signing

Every comment the loop writes on a PR is signed with the exact string
`Loop Engineering — PR Babysitter`.

## Run-log

Each run appends one JSON entry to `loop-run-log.md` in the 016 format —
`{ run_id, pattern: "pr-babysitter", duration_s, items_found, actions_taken, escalations, tokens_estimate, outcome }` —
including no-op runs.

# What it is not

- **Not a scheduler.** The loop runs under 016's `LOOP.md` cadence; it does not
  invent its own trigger.
- **Not a merger.** No auto-merge, no `gh pr merge`, no branch-protection
  changes. Merging a PR is always a human action (016).
- **Not a CI configurator.** `.github/workflows/*.yml`, branch protection, and
  the required-check policy are read-only inputs.
- **Not the spec pipeline.** It does not fix or comment on spec-pipeline draft
  PRs' own CI failures; it records their state and may ping the human when one
  is green and undrafted.

# Cost

## Early exit on empty watchlist

When `gh pr list --state open` returns zero PRs, the loop exits immediately
after appending the no-op run-log entry — no triage, no sub-agent spawns, no
comments.

## Cost table

| Run | Token estimate |
|---|---|
| no-op | ≈ 3k tokens |
| triage | ≈ 80k tokens |
| fix attempt | ≈ 250k tokens |

Budget is spent from `loop-budget.md` (016's `templates/loop-budget.md`);
on-exceed and kill behavior are defined there, not here.
