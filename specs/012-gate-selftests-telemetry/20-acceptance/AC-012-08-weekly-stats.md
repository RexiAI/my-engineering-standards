# AC-012-08: weekly gate-stats view surfaces the drift signal

## AC-012-08-01 — A scheduled workflow runs gate-stats.sh weekly
Given `.github/workflows/gate-stats-weekly.yml` exists
When GitHub runs the `schedule` trigger (Monday 06:00 UTC) or `workflow_dispatch`
Then the job checks out the repo
And it runs `bash scripts/gate-stats.sh`
And the report is uploaded as a `gate-stats` artifact

## AC-012-08-02 — The workflow needs read-only permissions
Given the workflow's `permissions`
Then `contents: read` is set
And no write token is used

## AC-012-08-03 — The stats report reflects the committed runs.jsonl
Given the repo contains a committed `runs.jsonl`
When the workflow's checkout completes
Then `scripts/gate-stats.sh` reads the checked-out `runs.jsonl` at the repo root (its default path)
