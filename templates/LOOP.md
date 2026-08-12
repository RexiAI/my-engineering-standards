# Loop Registry

Active loops in this repo. One row per loop; add a row when a new loop reaches
L0, remove the row when a loop is killed.

| Pattern | Cadence | Level (L0–L3) | State file | Budget file | Kill switch |
|---|---|---|---|---|---|
| `[pattern-name]` | `[cron / manual]` | `[L0/L1/L2/L3]` | `[path to STATE.md]` | `[path to loop-budget.md]` | `off` / `on` |

A loop whose kill-switch status is `on` does not start its run.
