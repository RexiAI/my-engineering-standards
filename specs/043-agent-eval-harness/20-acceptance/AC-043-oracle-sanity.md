# AC-043: Oracle sanity in both directions

## AC-043-38 — The solution direction scores one
Given any task under `evals/tasks/`
When its `solution/` is overlaid on a fresh copy of its `environment/`
Then its verifier writes `1`

## AC-043-39 — The untouched environment scores zero
Given any task under `evals/tasks/`
When its `environment/` is copied with no overlay and no agent
Then its verifier writes `0`

## AC-043-40 — A task that cannot fail is rejected
Given a scratch task whose verifier writes `1` in both directions
When `scripts/check-agent-evals.sh <scratch-root>` runs
Then it exits 1
And it prints a failure containing `task cannot fail` and the task directory

## AC-043-41 — A missing or empty solution is rejected
Given a scratch task with no `solution/` directory
And a second scratch task whose `solution/` is empty
When the gate runs
Then it exits 1
And the failure names the task and the solution direction

## AC-043-42 — The oracle needs no model and no network
Given `OPENCODE_BIN` set to a nonexistent path
And no `SPEC_*_MODEL` variable exported
When the oracle runs over every task
Then it produces the same two rewards per task
And it exits 0 when every direction matches
And it starts no `opencode` process

## AC-043-43 — The oracle never touches the source tree
Given a clean worktree
When the oracle runs over every task
Then `git status --porcelain` is unchanged
And `runs.jsonl` is unchanged
And no file is created outside the `mktemp -d` workspace

## AC-043-44 — The gate reports both directions
Given the gate runs its oracle check
When the check finishes
Then it prints one line per task carrying `environment=<0|1>` and `solution=<0|1>`
And a task missing from that output fails the check
And an `evals/tasks/` directory with no tasks fails the check
