# 005 — PR auto-pipeline: the gate before the push

## Why

The spec pipeline today stops at "implementation done, mutation-tested,
draft PR opened." A user who says "open a PR", "ship it", or "merge it"
gets a verbal hand-off back from the orchestrator — every remount of
context re-decides what to do, what to skip, and which gate verdicts
count. The Verifier stage checks prior claims, but nothing re-checks
*the act of opening the PR* itself: is the branch from `spec/...`, are
the commits prefixed, does the PR body include the checklist, did any
gate between the last commit and now flip.

Reference: ACDC's `acdc-coordinator` plus an OpenSpec-style "ship it"
handler calls the full gate-runner before any push. PASS → push and
open the draft PR. BLOCK → halt and surface the failing gate IDs.

This is **Phase D**. Depends on Phases B (gate-runner) and C (hooks).

## What I want

A new `.opencode/skills/openspec-ship/` skill (SKILL.md + README.md),
plus a thin `agents/spec-ship.md` orchestrator and a `/ship <slug>`
slash command. When the user says "open a PR", "ship it", or anything
equivalent:

1. Resolve the gate-runner via `scripts/gates/find-harness.sh`.
2. Run `gate-runner.sh -Phase all -BaseRef develop` on the current
   `spec/<slug>` branch.
3. Read `<RepoPath>/.civ/gate-report.json`.
4. **PASS** → invoke `spec-architect` to push and open the draft PR.
5. **BLOCK** → halt. Surface `status: BLOCK`, `blockingGates[]`, and
   the evidence object. No push. No PR.

Plus updates to existing agents:

- `agents/spec-pipeline.md` — gain a third invocation mode (`/ship
  <slug>`) that delegates to the skill before touching the remote.
- `agents/spec-architect.md` — pre-push check that requires a fresh
  PASS gate report (`<RepoPath>/.civ/gate-report.json` exists,
  `status: PASS`, branch + SHA match `HEAD`).
- `agents/spec-verifier.md` — verdict contract becomes a transcription
  of the JSON report, not an independent judgement call.

## What I don't want

- Override of a BLOCK verdict regardless of how the user phrases the
  request. ("ship it anyway", "just push", "open a draft") The
  verdict originates in `gate-report.json`, not in the agent.
- A change to the existing `/spec` or `/build` flows. `/ship` is
  additive.
- Auto-opening the PR via `gh` (or push-to-create). The user clicks
  the PR-creation UI; the AI does not bypass that. Matches this
  repo's existing "AI never creates a PR without explicit user
  action" policy.
- Changes to gates themselves (those are Phase B).
- Changes to `archive-spec.sh` (it still runs after merge).

## Out of scope

- A separate plugin install path. Bundled with this repo, one
  install (matches ACDC's `acdc` plugin pattern).
- Mutation testing integration. SKIP-if-missing is fine; mutation
  coverage lands in a future `add-mutation-testing` spec.

## How child repos will use this

The skill, orchestrator, and slash command live at their normal
`.opencode/` and `agents/` paths. Vendored via the `.standards/`
submodule. A child repo that enables the hook layer (Phase C) will
also gain automatic enforcement at every `bash` and `edit|create`
tool call.
