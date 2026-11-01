# AC-042-12: `.gitignore` hardening and `rb_*` capture removal

## AC-042-12-01 — Dotenv variants are ignored
Given `.gitignore`
When the environment-file entries are read
Then it contains a literal `.env.*` entry
And `git check-ignore --no-index .env.staging` succeeds
And `git check-ignore --no-index .env.production.local` succeeds

## AC-042-12-02 — Committed templates stay trackable
Given the new `.env.*` entry
When the repository's tracked templates are checked
Then `git check-ignore --no-index config/model.local.env.example` fails
And `git check-ignore --no-index config/agent.local.env.example` fails
And `git check-ignore --no-index templates/.envrc.example` fails

## AC-042-12-03 — Gate-run capture dumps are ignored and untracked
Given `.gitignore` and the index
When the `rb_*` entries are read and the index is searched
Then `.gitignore` contains a literal `rb_*` entry
And `git check-ignore --no-index rb_check-skills` succeeds
And `git ls-files` returns no path matching `rb_*`
And none of `rb_check-governance`, `rb_check-model-env`, `rb_check-no-hardcoded-secrets`, `rb_check-orchestration`, `rb_check-pr-review`, `rb_check-skills`, `rb_cpr2`, or `rb_model-env.selftest` exists in the worktree

## AC-042-12-04 — The telemetry ledger is not swept up
Given the removal of tracked `rb_*` files
When the index is checked for the gate-run ledger
Then `runs.jsonl` is still tracked
And the `.gitignore` comment states that `runs.jsonl` is the long-lived ledger written by `scripts/record-gate-run.sh`

## AC-042-12-05 — The secret gates still pass
Given the updated `.gitignore`
When `scripts/guard-env.sh` and `scripts/check-no-hardcoded-secrets.sh` run
Then both exit `0`
