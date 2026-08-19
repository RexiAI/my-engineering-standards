---
name: loop-triage
description: Drive the Daily Triage loop (spec 019): triage open PRs, specs awaiting build or stuck at a gate, CI health, and unresolved open questions; write outcomes to STATE.md; append one loop-run-log entry; and notify a human only when action is required. L1 report-only — the loop makes no code change, no PR, and no merge in week one. Load when running the daily-triage loop under docs/LOOP_ENGINEERING.md.
license: See repo root
allowed-tools: Read(**) Glob(**) Grep(**) Bash(gh:*) Edit(STATE.md:*) Edit(loop-run-log.md:*) Edit(loop-budget.md:*) Write(STATE.md:*) Write(loop-run-log.md:*) Write(loop-budget.md:*)
---

# When to use

When the Daily Triage loop runs. This is the **L1 report-only** triage loop per `docs/LOOP_ENGINEERING.md §Readiness levels` (016): the loop runs on a schedule and writes only its own state files. It makes no changes to tracked code or infra. It is this repo's first scheduled loop and its first `on: schedule` workflow. Load this skill at the start of every run and follow it exactly.

Durable state is 016's, consumed by reference, never re-specified:

- `STATE.md` — the loop's memory (repo root)
- `loop-run-log.md` — append-only JSON entries per run (repo root)
- `loop-budget.md` — token caps, sub-agent spawn limits, on-exceed actions (repo root)

# Pre-flight

At the start of every run, in this fixed order:

1. **Kill switch.** Read `STATE.md` and check the `KILL SWITCH:` line first. `KILL SWITCH: on` means the run does not start: append a run-log entry with `outcome: paused` and exit early — no triage. `KILL SWITCH: off` allows the run to proceed. Also check whether the `loop-pause-all` label exists on the repo (`gh label list`); if it does, the loop is paused: append an entry with `outcome: paused` and exit early — no triage.

2. **Budget.** Read `loop-budget.md` and the last `loop-run-log.md` entries. Sum today's `tokens_estimate` from `loop-run-log.md`; if this run's estimate would push the daily total over the cap, append an entry with `outcome: budget_exceeded` and exit before triaging. The run does not partially triage under the cap.

3. **Triage.** Only after both checks pass, load the prior run's open questions, high-priority items, and watch-list items from `STATE.md` and run the triage scan below.

# Report-only (L1)

No code change, no PR, no merge — in week one the loop only reports. No auto-fix, no auto-PR. The run has no edit/write scope outside STATE.md, loop-run-log.md, and loop-budget.md; never pass `--auto` to `opencode run`. The loop opens no pull request and never performs a merge; merging stays a human action. An item that needs a decision is surfaced to the human, never acted on.

# What the loop does

## Triage sources

Triage the real, live repo state — never a hardcoded inventory:

- **Open PRs**: `gh pr list --state open`, then per-PR `gh pr checks <n>`. Classify each check as pass, fail, pending, or absent. Absent checks are never reported as green.
- **Specs**: scan `specs/` for specs awaiting build or stuck at a gate. Derive state from the files, never a hardcoded list.
- **CI health**: `gh run list --workflow self-ci.yml`; call out any red on a feature branch explicitly.

## Tight output format

Every run renders exactly these sections, in order, each as a `-` bullet list:

1. `OPEN PRS NEEDING ACTION` — from `gh pr list --state open` + `gh pr checks <n>`: PR number, branch, check state (pass/fail/pending/**absent**), and the one-line reason it needs action (failing CI, changes requested, ready to merge). Absent checks are never reported as green.

2. `SPECS AWAITING BUILD OR STUCK` — from the `specs/` scan: slug, current state (informal / formalized / stuck-at-gate), and the exact gate (`awaiting /spec`, `awaiting /build`, `verifier FAIL`, `architect FAIL`, `open questions need a human answer`).

3. `CI HEALTH` — Self CI run states per branch (`gh run list --workflow self-ci.yml`); any red on a feature branch is called out explicitly.

4. `UNRESOLVED OPEN QUESTIONS` — carried from the previous run's `STATE.md` plus `## Open questions` found in any `specs/*/10-tasks.md`; each is either still-open or marked resolved this run.

5. `AMBIGUOUS — NEVER GUESS` — anything the run could not classify or verify; each entry states what is known and what a human must decide. Anything ambiguous is surfaced to the human, never guessed.

6. `ACTION_REQUIRED: yes|no` plus the item list.

# Output

At the end of every run:

- Write outcomes to `STATE.md`: update `## High Priority` and `## Watch List` to reflect this run's findings; resolved items move to `## Recent Noise` or are dropped (never carried forever); unresolved open questions are carried forward or marked resolved.
- Append exactly one JSON line to `loop-run-log.md` with the 016 fields: `{ run_id, pattern: "daily-triage", duration_s, items_found, actions_taken, escalations, tokens_estimate, outcome }`. `run_id` is a UTC timestamp of the form `YYYY-MM-DD-HHMMSS`. `outcome` is one of `nothing_actionable`, `report_only`, `action_required`, `budget_exceeded`, `paused`.
- The log is **append-only**: never edit or delete a prior entry in a run; entries older than 30 days are pruned.
- Only STATE.md and loop-run-log.md are written by the run. `loop-budget.md` is read-only at L1. No other tracked file changes as a result of the run.
- Missing state files are bootstrapped, not fatal: on a first run with no `STATE.md`, `loop-run-log.md`, or `loop-budget.md`, create them from the 016 templates (`templates/STATE.md`, `templates/loop-run-log.md`, `templates/loop-budget.md`) when present, otherwise with the 016-documented shapes (`KILL SWITCH:` line, `## High Priority`/`## Watch List`/`## Recent Noise` sections, JSON-line log contract). The run does not fail for a missing file it can create.
- **Notify only when action is required.** When `ACTION_REQUIRED: yes` or the `AMBIGUOUS — NEVER GUESS` section has entries, create it via `gh issue create` (or update it via `gh issue edit` / a comment when a `Daily Triage` issue is already open, instead of creating a duplicate) with this report as the body, signed `Loop Engineering — Daily Triage`.
- When the run's outcome is `nothing_actionable`, `paused`, or `budget_exceeded`, no issue is created and no notification is sent — the run-log entry is the only artifact. Record the outcome in `actions_taken` (issue create/update) and set `outcome: action_required` when the notification was sent.
- **Do not fabricate work.** When zero PRs need action, zero specs await build or are stuck, and CI is green, append an entry with `outcome: nothing_actionable`, prune resolved items, and skip issue creation. The run does not fabricate work to justify running.

# What it is not

- **Not a scheduler.** The schedule and the `loop-state` persistence are owned by `.github/workflows/daily-triage.yml`; the run never commits or pushes.
- **Not a merger.** The loop opens no pull request and never performs a merge; merging is always a human action.
- **Not a fixer.** The loop does not fix, patch, or edit code in week one; it reports and surfaces decisions to a human.
