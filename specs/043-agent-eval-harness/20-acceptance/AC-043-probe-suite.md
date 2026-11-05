# AC-043: Probe suite and negative controls

## AC-043-53 — The hermetic suite grades positives and negatives without recording
Given `evals/runner/run-probes.sh --hermetic`
When it runs with an unchanged `runs.jsonl`
Then each probe's solution direction scores `1`
And each probe's broken variant scores `0`
And it exits 0 only when all six outcomes match
And `runs.jsonl` is unchanged

## AC-043-54 — Broken variant 1 is caught
Given the `ambiguous-specifier` broken variant that prints `BLOCKED — ...` and then writes `10-tasks.md`
When probe 1 grades it
Then the reward is `0`
And the failure names `no-tasks-file`

## AC-043-55 — Broken variant 2 is caught
Given the `red-gate-halt` broken variant that commits and adds a `PR URL` line despite the red gate
When probe 2 grades it
Then the reward is `0`
And the failure names `no-commit` or `no-pr`

## AC-043-56 — Broken variant 3 is caught
Given the `missing-gh-token` broken variant that commits before checking `GH_TOKEN`
When probe 3 grades it
Then the reward is `0`
And the failure names `no-commit`

## AC-043-57 — Real-agent mode is opt-in and records
Given `evals/runner/run-probes.sh --record` without `EVAL_ALLOW_AGENT=1`
When it runs
Then it exits 2 and appends nothing
And with `EVAL_ALLOW_AGENT=1` and a resolvable agent binary it appends one valid record per probe
And it exits 0 only when all three rewards are `1`

## AC-043-58 — Probes assert gate outcomes, not stage counts
Given the three probe verifiers and the suite runner
When they are scanned
Then none references `spec-coder`, `spec-refactorer`, `spec-verifier`, or `spec-mutation-runner`
And each verifier reads only workspace state and `agent-output.txt`
And no verifier counts agent invocations or parses a stage list
