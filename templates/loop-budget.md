# Loop Budget

Per-loop cost limits. Loaded before every run; a run must not start if any limit
is already exhausted.

## Daily token caps

- per-run token cap: `[e.g. 200_000]`
- per-day token cap: `[e.g. 800_000]`

## Max sub-agent spawns

- max sub-agent spawns per run: `[e.g. 10]`

## On-exceed actions

When a budget is exceeded: **slow** first (reduce scope or cadence), then
**pause** (halt the schedule, keep state intact), then **kill** (set the kill
switch in `STATE.md` and notify the human owner).

## Kill switch

The kill switch lives in `STATE.md`. A loop with `KILL SWITCH: on` does not
start, regardless of remaining budget.
