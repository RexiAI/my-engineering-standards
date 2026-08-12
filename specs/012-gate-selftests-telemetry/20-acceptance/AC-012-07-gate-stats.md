# AC-012-07: gate-stats.sh prints failure/retry rates from runs.jsonl

## AC-012-07-01 — Prints totals, outcome breakdown, and failure rate (AC-004)
Given a `runs.jsonl` with 10 records: 8 `pass`, 1 `fail` (gatesFailed `["complexity"]`), 1 `block`
When `scripts/gate-stats.sh -f /tmp/runs.jsonl` runs
Then it prints total runs 10
And it prints the pass/fail/block counts with percentages
And it prints a failure rate of 20% (2/10, fail + block)

## AC-012-07-02 — Names the most-failed gate
Given the same 10 records, where `complexity` appears in 2 records' `gatesFailed` and `traceability` in 1
When `gate-stats.sh` runs
Then it reports `complexity` as the most-failed gate with count 2

## AC-012-07-03 — Prints loop and retry averages/max and the recent window average
Given records with `loopCount` values and `phase1Retries`/`phase2Retries` values across 10 runs
When `gate-stats.sh -f /tmp/runs.jsonl` runs
Then it prints the overall average and max of `loopCount`, `phase1Retries`, and `phase2Retries`
And it prints the average of each over the last 10 runs (the default `-n` window)

## AC-012-07-04 — Flags retry creep against the prior window
Given 20 records where `phase1Retries` averages 0.5 in the older 10 and 1.4 in the newer 10 (recent ≥ 1.5× prior and both ≥ 1.0)
When `gate-stats.sh -f /tmp/runs.jsonl` runs (default window 10)
Then it prints both window averages for `phase1Retries`
And it marks that metric `CREEP`
Given a metric whose recent average does not reach 1.5× the prior (or recent < 1.0)
When the same run happens
Then that metric is not marked `CREEP`

## AC-012-07-05 — A missing runs.jsonl is a hard error, not an empty report
Given no file at the target path
When `gate-stats.sh` runs
Then it prints an error to stderr
And it exits 1

## AC-012-07-06 — A well-formed file exits 0
Given a valid `runs.jsonl`
When `gate-stats.sh` runs
Then it exits 0
