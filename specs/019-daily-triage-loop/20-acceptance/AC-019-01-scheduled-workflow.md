# AC-019-01: A scheduled weekday workflow runs the triage loop (AC-001)

## AC-019-01-01 — The workflow exists with a weekday schedule
Given `.github/workflows/daily-triage.yml` is the loop's scheduler
And `on.schedule` contains the cron `0 6 * * 1-5` (weekdays, 06:00 UTC)
When the workflow file is read
Then it declares `on.schedule` with that cron
And it declares `on.workflow_dispatch` so the first run fires immediately and humans can re-run

## AC-019-01-02 — The workflow grants the least privilege it needs
Given the workflow must list PRs, read CI runs, write the triage issue, and persist state
When its `permissions:` block is read
Then it grants `contents: write`, `issues: write`, `pull-requests: read`, and `actions: read`
And it grants no other capability (no `pull-requests: write`, no `id-token`, no admin)

## AC-019-01-03 — The workflow seeds loop state from the loop-state branch
Given the loop persists `STATE.md` and `loop-run-log.md` on the `loop-state` branch (Decision 3)
When the job runs
Then it checks out the default branch
And it fetches `origin/loop-state` and copies `STATE.md` + `loop-run-log.md` into the worktree when they exist
And a missing `loop-state` branch on the first run does not fail the job

## AC-019-01-04 — The workflow invokes opencode run headlessly against the triage skill
Given `opencode run` is verified invocable non-interactively
When the job reaches the triage step
Then it runs `opencode run` with a prompt that names `skills/loop-triage/SKILL.md` and instructs reading it first
And the run is not passed `--auto`
And provider credentials come from a GitHub Actions secret; when the secret is absent the job exits 0 with a "not configured" message

## AC-019-01-05 — The workflow commits only the two state files to loop-state
Given the run edited `STATE.md` and appended `loop-run-log.md`
When the final step persists state
Then it stages exactly `STATE.md` and `loop-run-log.md` (no `git add -A`, no other paths)
And it commits and pushes to `loop-state`, never to `main`
And it skips the commit when neither file changed

## AC-019-01-06 — The workflow itself never creates the notification issue
Given AC-019-06 makes issue creation the run's job
When the workflow file is read
Then no workflow step runs `gh issue create` or `gh issue edit`

## AC-019-01-07 — The workflow is the repo's first scheduled workflow and says so
Given this repo previously had no `on: schedule` workflow of its own
When the workflow file is read
Then it documents in a comment the 016 L1 basis (report-only loop) and the `schedule:` trigger's best-effort delivery caveat
