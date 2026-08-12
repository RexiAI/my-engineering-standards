# AC-019-04: The loop is report-only — no code change, no PR, no merge in week one (AC-004)

## AC-019-04-01 — The run cannot edit code
Given the run is L1 report-only
When the skill's `allowed-tools` and the workflow's permissions are inspected
Then edit/write scope covers only `STATE.md`, `loop-run-log.md`, and `loop-budget.md`
And `opencode run` is never invoked with `--auto`
And no path outside the three loop files is writable by the run

## AC-019-04-02 — The run cannot create a PR or merge
Given the workflow's permission set
When the workflow `permissions:` block is inspected
Then it grants `pull-requests: read` only, never `pull-requests: write`
And no workflow step or skill instruction opens a pull request or merges

## AC-019-04-03 — State persistence touches only loop-state, never main
Given the workflow persists run state
When the final commit step runs
Then `git status` is checked before staging
And any changed path other than `STATE.md`/`loop-run-log.md` fails the workflow
And the commit pushes to the `loop-state` branch, never to `main`

## AC-019-04-04 — The triage prompt and skill contain no fix/PR/merge instruction
Given the triage prompt and `skills/loop-triage/SKILL.md`
When their text is scanned for action verbs
Then no instruction tells the loop to fix, patch, open a PR, or merge
And every actionable item is surfaced for a human decision, never acted on by the loop
