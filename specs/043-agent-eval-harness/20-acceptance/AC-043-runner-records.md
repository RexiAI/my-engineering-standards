# AC-043: Runner and runs.jsonl records

## AC-043-45 — A detached throwaway worktree, linked for agent discovery
Given a repository worktree and a task
When the runner prepares the workspace
Then it creates the workspace under a `mktemp -d` directory with `git worktree add --detach`
And it links `.opencode/agents` to `../agents` inside that workspace
And it copies the task's `environment/` into the workspace
And the main worktree's HEAD and checked-out branch are unchanged

## AC-043-46 — Preflight failure appends nothing
Given `OPENCODE_BIN` is unset or names a file whose `--version` exits non-zero
When the runner starts a task
Then it exits 2
And it prints which preflight failed
And the target `runs.jsonl` gains no line

## AC-043-47 — One append per run, append-only
Given a `runs.jsonl` with N existing lines
When one task run completes
Then the file has N+1 lines
And the first N lines are byte-identical to before
And the new line was written by `scripts/record-gate-run.sh`

## AC-043-48 — The record reuses the existing schema
Given the newly appended record
When it is parsed as JSON
Then it carries `specSlug`, `gatesFailed`, `warnings`, `durationSec`, and `outcome`
And exactly one of `specSlug` and `jiraKey` is present
And `specSlug` starts with `eval-`
And `runId`, `loopCount`, `phase1Retries`, and `phase2Retries` are present

## AC-043-49 — Outcome, duration, and diagnostics map from the verifier
Given a verifier that writes `1`, emits no `FAIL` line, and emits two `WARN` lines
When the record is built
Then `outcome` is `pass`
And `gatesFailed` is `[]`
And `warnings` holds the two warning strings
And `durationSec` is a non-negative number
And a verifier that writes `0` and emits `FAIL test-suite` yields `outcome: fail` and `gatesFailed: ["test-suite"]`
And an agent that exceeds its manifest timeout yields `reward 0` and `outcome: fail`

## AC-043-50 — A harness failure after start is recorded as block
Given the workspace exists and the agent process dies on startup before grading
When the runner finishes
Then it appends exactly one record with `outcome: block`
And that task's `reward.txt` contains `0`
And the runner exits non-zero

## AC-043-51 — No auto-approval, no push, no direct JSONL write
Given every file under `evals/lib/` and `evals/runner/`
When it is scanned
Then no `opencode run` invocation carries `--auto`
And no file contains `git push`
And the probe remote is seeded with `git clone --bare`, never a push
And no file appends to a `.jsonl` file directly
And every record write goes through `scripts/record-gate-run.sh`

## AC-043-52 — Cleanup on every exit path
Given one successful run and one failed run
When each finishes
Then its temporary worktree directory is removed
And `git worktree list` contains no entry for either workspace
And any `probe.branch` created for the run is deleted
And the local bare remote and temp root are removed
