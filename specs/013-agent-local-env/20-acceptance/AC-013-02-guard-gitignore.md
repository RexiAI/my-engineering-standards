# AC-013-02: the real env file is gitignored and a guard refuses to commit it

## AC-013-02-01 — The real env file path is gitignored
Given `.gitignore` in the repo root
When `git check-ignore config/agent.local.env` is run (the file need not exist on disk)
Then it exits 0
And `git check-ignore config/agent.local.env.example` does not exit 0 (the template stays trackable)

## AC-013-02-02 — The guard exits non-zero when the real file is staged
Given a scratch git repo in a temporary directory
And `config/agent.local.env` is staged in it
When `scripts/guard-env.sh --staged` runs against that repo
Then it exits 1
And its output names the offending path `config/agent.local.env`

## AC-013-02-03 — The guard exits non-zero when the real file is tracked (CI mode)
Given a scratch git repo in a temporary directory
And `config/agent.local.env` is committed (tracked) in it
When `scripts/guard-env.sh` runs against that repo with no flags
Then it exits 1
And its output names the offending path

## AC-013-02-04 — The guard exits 0 on a clean repo
Given a scratch git repo in a temporary directory with no real env file tracked or staged
When `scripts/guard-env.sh` runs against it, with and without `--staged`
Then it exits 0 in both modes
And prints a PASS line

## AC-013-02-05 — The guard runs in self-ci and a violation fails the job
Given `.github/workflows/self-ci.yml` has a `validate` job
When the job runs
Then one step runs `bash scripts/guard-env.sh` (no `continue-on-error`)
And a hypothetical committed `config/agent.local.env` in the tree makes that step exit 1
And the `validate` job fails

## AC-013-02-06 — The selftest proves the guard fires, and runs in self-ci
Given `scripts/agent-env.selftest.sh` exists under `scripts/`
When the selftest step runs in the `validate` job
Then it exercises the guard against scratch repos (staged → exit 1, tracked → exit 1, clean → exit 0)
And the step is not `continue-on-error`, so a guard regression fails the job
