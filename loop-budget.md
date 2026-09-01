# Loop Budget — daily-triage

Per-loop cost limits for the `daily-triage` loop (spec 019). Loaded before
every run; a run must not start if any limit is already exhausted. Consumed
from the 016 template (`templates/loop-budget.md`).

## ci-sweeper (spec 026, AC-026-08)

The sweeper reacts to every failing Self CI run on this repo (not forks —
`.github/workflows/ci-sweeper.yml`'s job guard excludes fork-originated runs,
`docs/SECURITY.md §Pwn requests`). Without a ceiling, a burst of failing runs
(e.g. a broken `main` commit, or repeated pushes to a red branch) could still
spend unbounded model tokens in a short window.

- max sweeper invocations per rolling 24h: `20`
- on-exceed: the workflow's budget-guard step appends a warning to the job
  summary and exits 0 before installing/invoking opencode — same "skip
  cleanly, never fail the job" contract as the missing-API-key guard.
  No `STATE.md` kill switch is required for this loop (it is L1, stateless,
  and self-limiting); repeated cap hits are visible in the Actions run list
  for a human to act on.

## Daily token caps

- per-run token cap: `150_000`
- per-day token cap: `300_000`

The run sums today's `tokens_estimate` from `loop-run-log.md`; if the next run
would exceed the per-day cap it appends an `outcome: budget_exceeded` entry and
exits before triaging (early exit, not a hard cap mid-run).

## Max sub-agent spawns

- max sub-agent spawns per run: `0` (L1 report-only — no sub-agents)

## On-exceed actions

When a budget is exceeded: **slow** first (reduce scope or cadence), then
**pause** (halt the schedule, keep state intact), then **kill** (set the kill
switch in `STATE.md` and notify the human owner).

## Kill switch

The kill switch lives in `STATE.md` (`KILL SWITCH: on`). A loop with
`KILL SWITCH: on` does not start, regardless of remaining budget. The
`loop-pause-all` repo label also pauses the loop; either form appends an
`outcome: paused` entry and performs no triage.
