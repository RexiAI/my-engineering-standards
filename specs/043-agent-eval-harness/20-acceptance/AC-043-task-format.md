# AC-043: Task format and manifest validation

## AC-043-10 — Every task carries the five required entries
Given `evals/tasks/<NNN-slug>/`
When the task directory is inspected
Then `instruction.md`, `environment/`, `tests/`, `solution/`, and `task.toml` all exist
And `instruction.md` is non-empty
And no committed `reward.txt` or `*.tmp` file exists in the task directory

## AC-043-11 — The manifest declares the required keys and types
Given a task's `task.toml`
When it is parsed
Then it declares `id`, `slug`, `agent`, `timeoutSec`, `verifier.command`, `verifier.rewardFile`, `oracle.solution`, and `oracle.environment`
And `id` matches `^[0-9]{3}-[a-z0-9-]+$`
And `slug` equals the task directory name
And `agent` resolves to an existing `agents/<agent>.md`
And `timeoutSec` is a positive integer
And both oracle directory names exist under the task

## AC-043-12 — A probe task declares its probe contract
Given a task that drives a behavior probe
When its `task.toml` is read
Then it carries a `[probe]` table whose `id` is `ambiguous-specifier`, `red-gate-halt`, or `missing-gh-token`
And optional `unsetEnv` is an array of environment-variable names
And optional `env` is a table of string values
And optional `remote` is a boolean
And optional `branch` is a non-empty string
And only the three probe tasks carry a `[probe]` table

## AC-043-13 — A missing or empty required entry fails
Given a task directory with `tests/` removed
And a second task directory whose `instruction.md` is empty
When the gate runs
Then it exits 1
And the failure names each task directory and the missing or empty entry

## AC-043-14 — Malformed TOML fails without a stack trace
Given a `task.toml` containing invalid TOML syntax
When the gate runs
Then it exits 1
And the failure names the offending `task.toml`
And neither stdout nor stderr contains a Python traceback

## AC-043-15 — Duplicate task ids are rejected
Given two task directories whose `task.toml` files declare the same `id`
When the gate runs
Then it exits 1
And the failure names both task directories

## AC-043-16 — An unresolvable agent or invalid timeout is rejected
Given a task whose `agent` is `spec-nonexistent`
And a second task whose `timeoutSec` is `0`, negative, or not an integer
When the gate runs
Then it exits 1
And the failure names each task and the offending key
