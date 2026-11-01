# AC-037-05: Read-cost reduction

## AC-037-05-01 — Every stage at or under 50%
Given the split is complete
When `scripts/measure-stage-read-cost.sh` runs
Then it prints one ratio per stage agent, every ratio ≤ 0.50, and exits 0

## AC-037-05-02 — Over-budget stage fails
Given a scratch tree where one stage file plus the index exceeds 50% of the baseline bytes
When `scripts/measure-stage-read-cost.sh <scratch>` runs
Then it exits 1 and names that stage

## AC-037-05-03 — Exactly 50% passes
Given a scratch tree where a stage's cost equals exactly 50% of the baseline
When the script runs
Then that stage passes
