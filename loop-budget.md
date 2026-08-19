# Loop Budget — daily-triage

Per-loop cost limits for the `daily-triage` loop (spec 019). Loaded before
every run; a run must not start if any limit is already exhausted. Consumed
from the 016 template (`templates/loop-budget.md`).

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
