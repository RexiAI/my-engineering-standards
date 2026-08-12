# 016-loop-engineering-foundation

> Spec pipeline archive. Original source: `specs/016-loop-engineering-foundation/` (deleted by this script).
> Archived: 2026-08-12

## Original ask

# Loop engineering foundation (LOOP.md / STATE.md / budget / run-log / constraints)

Stop prompting the agent; design the loop that prompts it. This spec brings the
loop-engineering foundation (cobusgreyling/loop-engineering) to this repo: the
durable files and safety rules every loop needs, before any loop runs.

## What it must provide

1. **Loop design doc + readiness levels.** `docs/LOOP_ENGINEERING.md` documents:
   - The five primitives + memory (scheduling, worktrees, skills, MCP
     connectors, sub-agent maker/checker split, durable state).
   - Readiness levels **L0 draft → L1 report → L2 assisted → L3 unattended** and
     the rule: a new pattern never skips L1 on a production repo.
   - The loop design checklist (purpose/scope, scheduling, skills, maker/checker,
     state, human handoff, connectors, cost, observability, safety).
   - When to slow / pause / kill a loop; kill checklist; incident response.

2. **Durable loop files** (templates under `templates/`):
   - `LOOP.md` — active loops: pattern, cadence, level, state file, budget, kill
     switch. (Mirror of loop-engineering's LOOP.md.)
   - `STATE.md` — durable loop state: what are we working on, what did we try last
     time, what waits on a human, prune resolved items each run.
   - `loop-run-log.md` — append-only JSON entries per run
     { run_id, pattern, duration_s, items_found, actions_taken, escalations,
       tokens_estimate, outcome }; prune older than 30 days.
   - `loop-budget.md` — daily token caps per loop, max sub-agent spawns/run,
     on-exceed actions, kill switch.
   - `loop-constraints.md` — binding rules loaded before every loop run.
   - `gate.yaml` — machine-readable path denylist (secrets, auth, payments,
     infra, migrations) + auto-merge allowlist.

3. **Safety rules** (from loop-engineering safety.md), adapted to this repo:
   - Path denylist: never auto-edit `.env*`, `**/secrets/**`, `auth/**`,
     `k8s/production/**`, migrations without human approval.
   - Default no auto-merge; strict allowlist if ever enabled.
   - MCP connectors least-privilege (read + comment, not merge).
   - Human gates always required for: security/auth, payments, infra, dependency
     upgrades, >N files, third failed attempt on same item.
   - Kill switch documented (label or flag in STATE.md).

4. **Reference in AGENTS.md** "Reading the Standards" + a note in AGENTS.md that
   loops must never skip L1.

## Acceptance criteria

- AC-001: docs/LOOP_ENGINEERING.md exists with the primitives, readiness levels,
  design checklist, and slow/pause/kill guidance.
- AC-002: templates/ contains LOOP.md, STATE.md, loop-run-log.md, loop-budget.md,
  loop-constraints.md, gate.yaml.
- AC-003: the path denylist and no-auto-merge rule are documented verbatim.
- AC-004: AGENTS.md links the new doc in "Reading the Standards".
- AC-005: a `scripts/check-loop-files.sh` verifies the six files exist (exit 0
  only when complete), wired into self-ci.

## Tasks

# Spec 016 — Loop engineering foundation

Formalized from `specs/016-loop-engineering-foundation/00-informal.md`. Brings the
loop-engineering foundation (cobusgreyling/loop-engineering) to this repo: a design
doc, six durable loop files under `templates/`, the safety rules, an AGENTS.md
pointer, and a mechanical gate that verifies the whole bundle is present before any
loop runs.

This repo has no JVM/Go/Node test suite. Per the established precedent (specs 009,
010, 015), the shipped shell check script is the test carrier: it must reference
every task-level scenario ID (`AC-016-01`…`AC-016-05`) so
`scripts/check-scenario-traceability.sh` resolves them. The script is the only
"test" this spec produces.

## Task 1 — Write docs/LOOP_ENGINEERING.md

Maps informal AC-001 (doc exists with primitives, readiness levels, checklist,
slow/pause/kill) and the documentation half of AC-003 (denylist + no-auto-merge
verbatim).

**Acceptance criteria**

- `docs/LOOP_ENGINEERING.md` exists and is non-empty.
- A section documents the five primitives plus memory, each by name: scheduling,
  worktrees, skills, MCP connectors, sub-agent maker/checker split, and durable
  state.
- A section documents readiness levels with a one-line definition each:
  - **L0 Draft** — pattern sketched; runs only by hand on the author's machine;
    no schedule, no state files, no unattended changes.
  - **L1 Report** — loop runs on a schedule and writes only its own state files
    (`STATE.md`, `loop-run-log.md`); it makes no changes to tracked code or
    infra. A new pattern never skips L1 on a production repo.
  - **L2 Assisted** — loop may propose changes, but every change requires human
    sign-off before it lands (no unattended edits, no auto-merge).
  - **L3 Unattended** — loop runs with no human in the loop; merging any pull
    request it produces is still a human action.
- The readiness section states verbatim the rule: a new pattern never skips L1 on
  a production repo.
- A section documents the loop design checklist, one item each: purpose/scope,
  scheduling, skills, maker/checker, state, human handoff, connectors, cost,
  observability, safety.
- A section documents when to slow, when to pause, and when to kill a loop, plus
  the kill checklist (kill switch set, run-log entry written, schedule paused,
  human notified).
- A section documents incident response: detect, stop the loop, preserve the
  run-log and state, notify the human owner, classify, remediate, and add a
  constraint to `loop-constraints.md` or a checklist item so it does not recur.
- A safety section documents the path denylist with the exact line
  (verbatim, in a fenced code block):
  ```text
  .env*, **/secrets/**, auth/**, payments/**, k8s/production/**, migrations/**
  ```
- The same safety section documents the no-auto-merge rule with the exact line
  (verbatim, in a fenced code block):
  ```text
  Loops never auto-merge. Merging a loop's pull request is always a human action.
  ```
- The safety section documents: MCP connectors run least-privilege (read +
  comment, never merge); human gates always required for security/auth, payments,
  infra, dependency upgrades, a per-loop file-count threshold `N` (default 10),
  and a third failed attempt on the same item; and the kill switch, which lives as
  a flag in `STATE.md` that every loop checks at the start of each run.
- Follows the house doc style (`docs/ARCHITECTURE.md`, `docs/TESTING.md`): title
  H1, `##` sections, code fences for verbatim rules.

**Scenarios:** AC-016-01-01 — AC-016-01-09

## Task 2 — Add the six durable loop templates under templates/

Maps informal AC-002 (six files exist with the documented shapes).

**Acceptance criteria**

- `templates/LOOP.md` — a template listing active loops as a markdown table, one
  row per loop, with columns for pattern, cadence, level (L0–L3), state file,
  budget file, and kill-switch status. (Mirror of loop-engineering's LOOP.md.)
- `templates/STATE.md` — a durable-state template with the sections
  `## High Priority`, `## Watch List`, and `## Recent Noise` (resolved items are
  pruned, not carried forever), plus a `KILL SWITCH:` line at the top (values
  `off`/`on`) that every loop checks at run start.
- `templates/loop-run-log.md` — an append-only template documenting that each run
  appends one JSON line: `{ run_id, pattern, duration_s, items_found,
  actions_taken, escalations, tokens_estimate, outcome }`, with a pruning rule of
  entries older than 30 days.
- `templates/loop-budget.md` — a budget template documenting per-loop daily token
  caps, a max sub-agent spawns/run, on-exceed actions (slow, pause, then kill),
  and a kill switch.
- `templates/loop-constraints.md` — a template for binding rules that are loaded
  before every loop run and cannot change per-run (safety, scope, path denylist,
  human-gate thresholds).
- `templates/gate.yaml` — machine-readable, valid YAML, with:
  - a `denylist:` array containing all six categories: `.env*`,
    `**/secrets/**`, `auth/**`, `payments/**`, `k8s/production/**`,
    `migrations/**`;
  - `autoMergeEnabled: false` (the default is no auto-merge);
  - `autoMergeAllowlist: []` (the strict allowlist, empty by default).
- No files beyond these six are added to `templates/`.

**Scenarios:** AC-016-02-01 — AC-016-02-07

## Task 3 — Add the AGENTS.md reference and the never-skip-L1 rule

Maps informal AC-004 (link in "Reading the Standards" + L1 note).

**Acceptance criteria**

- `AGENTS.md` "Reading the Standards" gains a bullet, placed after the
  `docs/SPEC_PIPELINE.md` bullet, reading:
  `- Read \`docs/LOOP_ENGINEERING.md\` before designing or running a loop (an automated agent cycle with durable state).`
- `AGENTS.md` "General Rules" gains a bullet, placed after the plan-mode bullet,
  reading:
  `- Loops never skip L1 (report) on a production repo — see \`docs/LOOP_ENGINEERING.md §Readiness levels\`.`
- No other AGENTS.md content changes.

**Scenarios:** AC-016-03-01 — AC-016-03-02

## Task 4 — Add the scripts/check-loop-files.sh gate script

Maps informal AC-005 (the script verifies the six files exist, exit 0 only when
complete). Per the traceability precedent (specs 009, 010, 015), the script also
carries the other task IDs so they are live checks, not dead references.

**Acceptance criteria**

- Usage `scripts/check-loop-files.sh [ROOT_DIR]`; `ROOT_DIR` defaults to `.`.
- Follows the house style of `scripts/check-*.sh`: `#!/bin/bash`,
  `set -euo pipefail`, header comment (checks, usage, exit codes, standards
  reference), `PASS`/`FAIL` lines, violation counter, summary, non-zero exit on
  violations.
- Verifies `docs/LOOP_ENGINEERING.md` exists and is non-empty.
- Verifies the six `templates/` files exist and are non-empty: `LOOP.md`,
  `STATE.md`, `loop-run-log.md`, `loop-budget.md`, `loop-constraints.md`,
  `gate.yaml`.
- Verifies `templates/gate.yaml` contains the `denylist:` and
  `autoMergeAllowlist:` keys and every one of the six denylist categories
  (`.env`, `secrets`, `auth`, `payments`, `k8s/production`, `migrations`) appears
  in it.
- Verifies `AGENTS.md` references `docs/LOOP_ENGINEERING.md` and contains the
  never-skip-L1 rule.
- Verifies `.github/workflows/self-ci.yml` references `check-loop-files.sh`.
- Exits 0 only when every check passes; exits 1 otherwise, naming each missing or
  malformed file/check.
- The negative cases (missing doc, missing template, missing gate.yaml key,
  missing AGENTS.md reference) are genuinely exercised against a temp fixture —
  not dead code.
- Passes `bash -n scripts/check-loop-files.sh` and shellcheck cleanly.
- References every task-level scenario ID `AC-016-01`…`AC-016-05` (in PASS/FAIL
  lines or comments) so `check-scenario-traceability.sh` resolves them.
- Read-only: running it against a compliant repo modifies no files.

**Scenarios:** AC-016-04-01 — AC-016-04-09

## Task 5 — Wire check-loop-files.sh into self-ci

Maps the "wired into self-ci" half of informal AC-005.

**Acceptance criteria**

- `.github/workflows/self-ci.yml`: in the `validate` job, after the `make lint`
  step and before the shellcheck step, add a step named `Run loop files check`
  running `./scripts/check-loop-files.sh`.
- The step is not marked `continue-on-error`, so a non-zero exit fails the job.
- `scripts/check-loop-files.sh` has the executable bit set.

**Scenarios:** AC-016-05-01 — AC-016-05-02

## Open questions

1. **Payments: denylist and/or human gate.** The informal spec's summary lists
   payments in the path denylist; the body's denylist bullet omits it but lists
   payments under human gates. Resolved here as *both*: `payments/**` sits in the
   gate.yaml denylist (a denied path is still editable with human approval) and
   payments stays on the always-human-gate list. Confirm.
2. **Gate script verifies more than "six files exist".** Informal AC-005 says the
   script verifies the six files exist. The traceability precedent (009, 010, 015)
   makes the gate script the carrier for every task-level AC, so the script also
   greps the AGENTS.md reference (AC-016-03) and the self-ci wiring (AC-016-05),
   and checks gate.yaml's denylist keys. Without that, AC-016-03/04/05 would only
   exist as comments. Confirm the expanded scope is acceptable.
3. **The `>N files` human gate.** The informal spec leaves `N` undefined. Resolved
   here as a per-loop configurable threshold defaulting to 10, documented in
   LOOP_ENGINEERING.md. Confirm the default.
4. **Makefile `DOCS` list not updated.** Every doc in `docs/` is registered in the
   Makefile `DOCS` list (used by `make validate`). This spec leaves it untouched —
   the informal spec wires the gate into self-ci only, and `scripts/check-loop-files.sh`
   is the gate for the new doc. Note that `make validate-refs` already picks up
   `docs/LOOP_ENGINEERING.md` references once they exist, so no Makefile change is
   required for cross-reference integrity. Flagging for completeness; add the DOCS
   entry if house consistency is preferred over literal scope.

## Acceptance scenarios

## AC-016-01-01 — The doc exists and is non-empty
## AC-016-01-02 — The doc covers the five primitives plus memory
## AC-016-01-03 — The doc defines readiness levels L0 through L3
## AC-016-01-04 — The doc states the never-skip-L1 rule
## AC-016-01-05 — The doc has the loop design checklist
## AC-016-01-06 — The doc has slow, pause, and kill guidance
## AC-016-01-07 — The doc has incident response steps
## AC-016-01-08 — The doc carries the path denylist verbatim
## AC-016-01-09 — The doc carries the no-auto-merge rule verbatim
## AC-016-02-01 — templates/LOOP.md lists active loops
## AC-016-02-02 — templates/STATE.md carries durable state
## AC-016-02-03 — templates/loop-run-log.md appends JSON entries
## AC-016-02-04 — templates/loop-budget.md caps cost and has a kill switch
## AC-016-02-05 — templates/loop-constraints.md holds binding rules
## AC-016-02-06 — templates/gate.yaml is machine-readable
## AC-016-02-07 — gate.yaml denylist covers all six categories
## AC-016-03-01 — Reading the Standards links LOOP_ENGINEERING.md
## AC-016-03-02 — General Rules states the never-skip-L1 rule
## AC-016-04-01 — Script exists and is executable
## AC-016-04-02 — Script passes on a complete repo
## AC-016-04-03 — Script fails when the doc is missing
## AC-016-04-04 — Script fails when a template is missing
## AC-016-04-05 — Script fails when gate.yaml lacks the denylist contract
## AC-016-04-06 — Script fails when AGENTS.md lacks the reference
## AC-016-04-07 — Script cites every scenario ID for traceability
## AC-016-04-08 — Script is read-only
## AC-016-04-09 — Script parses and passes shellcheck
## AC-016-05-01 — Self-CI runs the loop files check
## AC-016-05-02 — A check failure fails the job

## Verification

_(not produced)_

## Quality gates

_(not produced)_
