# 005-pr-auto-pipeline

> Spec pipeline archive. Original source: `specs/005-pr-auto-pipeline/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

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

## Tasks

# 005 — PR auto-pipeline: Tasks

`/ship <slug>` and the `openspec-ship` skill halts on BLOCK, proceeds
on PASS. No override. Additive to existing `/spec` and `/build`.

## Dependency order

1. **Task 1** (`openspec-ship` skill + `spec-ship` orchestrator +
   `/ship` command) is the user-facing spine; implement first.
2. **Task 2** (wire existing agents) depends on Task 1.
3. **Task 3** (end-to-end verify) runs last.

---

## Task 1 — Author the skill and orchestrator

- `.opencode/skills/openspec-ship/SKILL.md` — BLOCK-halt contract
  language.
- `.opencode/skills/openspec-ship/README.md` — usage examples, stop
  conditions.
- `agents/spec-ship.md` — `mode: primary`, thin pointer to the
  skill. Exposes one operation: "ship the current spec branch".
- `.opencode/commands/ship.md` — slash command, maps `/ship <slug>`
  to the skill.

Acceptance criteria:

- All four files exist at the listed paths.
- The skill's SKILL.md explicitly states: BLOCK → halt, no push, no
  PR; PASS → invoke `spec-architect`.

---

## Task 2 — Wire the existing agents

- `agents/spec-pipeline.md`: add a third invocation mode
  (`/ship <slug>`). Update its pointer to the new skill.
- `agents/spec-architect.md`: add a pre-push check that requires
  `<RepoPath>/.civ/gate-report.json` exists, `status: PASS`, and
  report's branch+SHA match `HEAD`. Refuse to push on mismatch.
- `agents/spec-verifier.md`: change verdict contract to be a
  transcription of `.civ/gate-report.json` plus
  `warnings[]` for model-vs-JSON disagreements.

Acceptance criteria:

- `spec-pipeline.md` exposes three modes: `/spec`, `/build`, `/ship`.
- `spec-architect.md` aborts on stale/missing/blocked gate report.
- `spec-verifier.md` verdict fields come from the JSON, not from
  re-execution.

---

## Task 3 — End-to-end verify

Manual end-to-end on a test branch:

1. Create `spec/NNN-test-ship/00-informal.md` with a trivial feature
   ("create `~/echo.txt` containing the word hello").
2. Run `/spec` → `/build` → `/ship`.
3. Confirm PASS path pushes the branch. (PR creation is
   user-driven; the agent pushes, the user clicks.)
4. Introduce a failing scenario on a branch. Run `/ship`. Confirm
   BLOCK halts, surfaces gate IDs, no push.
5. Remove the failure, re-run `/ship`. Confirm PASS resumes.

Plus documentation:

- `README.md` — "Ship a feature" section explaining
  `/spec` → `/build` → `/ship`.
- `.standards/instructions/00-pipeline-overview.md` — link to
  `/ship`.

Acceptance criteria:

- All four `Task 3` checks pass.
- `dry-run.sh` is green.
- README and pipeline-overview both reference `/ship`.

## Acceptance scenarios

## AC-001-01 — Skill files exist at the listed paths
## AC-001-02 — Skill language states the BLOCK-halt contract
## AC-001-03 — `spec-ship.md` is a thin orchestrator
## AC-001-04 — `/ship` slash command maps to the skill
## AC-002-01 — `spec-pipeline.md` exposes three modes
## AC-002-02 — `spec-architect.md` requires a fresh PASS report
## AC-002-03 — `spec-verifier.md` verdict is a transcription
## AC-002-04 — Stale report is rejected
## AC-003-01 — PASS path pushes the branch
## AC-003-02 — BLOCK path halts with surfacing
## AC-003-03 — Re-run after fix resumes PASS
## AC-003-04 — `README.md` documents `/ship`
## AC-003-05 — Pipeline overview links to `/ship`

## Verification

# 005 — Verification

Populated by `spec-verifier` after Coder + Refactorer finish.

## Re-execution checklist

- [ ] `.opencode/skills/openspec-ship/SKILL.md` states the BLOCK-halt
  contract
- [ ] `.opencode/skills/openspec-ship/README.md` exists
- [ ] `agents/spec-ship.md` is `mode: primary`, thin pointer, no
  procedural rules
- [ ] `.opencode/commands/ship.md` maps `/ship <slug>` to the skill
- [ ] `agents/spec-pipeline.md` lists three modes (`/spec`,
  `/build`, `/ship`)
- [ ] `agents/spec-architect.md` requires `.civ/gate-report.json`
  with `status: PASS`, matching branch + SHA
- [ ] `agents/spec-verifier.md` verdict contract is transcription +
  warnings
- [ ] Stale report is rejected

## End-to-end manual

- [ ] PASS path: `/spec` → `/build` → `/ship` on a trivial feature
- [ ] BLOCK path: introduce a failing scenario; `/ship` halts with
  gate IDs
- [ ] Re-run after fix: PASS resumes

## Verdict

- [ ] PASS
- [ ] FAIL

## Quality gates

# 005 — Architect Report

## End-to-end results

| Path | Branch | Outcome |
|---|---|---|
| PASS path | `spec/NNN-test-ship` | Push succeeded |
| BLOCK path | `spec/NNN-test-ship-blocked` | Halt + gate IDs surfaced |
| Recovery | after fix | PASS resumed |

## Gate results

(Populated by `spec-architect`.)

## Branch / commit summary

- Branch: `spec/005-pr-auto-pipeline`
- Commit count: _(populated by Architect)_
- Tasks touched: 3 of 3

## Documentation updates

- [ ] `README.md` has the "Ship a feature" section
- [ ] `.standards/instructions/00-pipeline-overview.md` links to
  `/ship`

## Verdict

(Populated by `spec-architect`.)
