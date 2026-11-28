# AC-045-06: Auto-merge eligibility predicate

## AC-045-06-01 — All gates green in live mode
Given `--size-tier auto`, `--review-verdict pass`, `--mode live`
And a changed-files list with `src/a.ts`
When `scripts/pr-automerge-eligibility.sh` runs
Then stdout contains `eligible=true`
And `action=merge`
And `reason=all_green`
And `exclusions=none`
And the exit code is 0

## AC-045-06-02 — The human tier is not eligible
Given `--size-tier human` and `--review-verdict pass`
When the predicate runs
Then stdout contains `eligible=false`
And `action=none`
And `reason=size_human`

## AC-045-06-03 — The blocked tier is not eligible
Given `--size-tier blocked` and `--review-verdict pass`
When the predicate runs
Then stdout contains `eligible=false`
And `reason=size_blocked`

## AC-045-06-04 — The override tier is never auto-merged
Given `--size-tier override` and `--review-verdict pass`
When the predicate runs
Then stdout contains `eligible=false`
And `reason=size_override`

## AC-045-06-05 — A findings verdict is not eligible
Given `--size-tier auto` and `--review-verdict findings`
When the predicate runs
Then stdout contains `eligible=false`
And `reason=review_not_pass`

## AC-045-06-06 — A missing verdict is not eligible
Given `--size-tier auto` and `--review-verdict missing`
When the predicate runs
Then stdout contains `eligible=false`
And `reason=review_not_pass`

## AC-045-06-07 — Workflow changes are excluded
Given `--size-tier auto`, `--review-verdict pass`, `--mode live`
And a changed-files list containing `.github/workflows/ci.yml`
When the predicate runs
Then stdout contains `eligible=false`
And `reason=excluded_path`
And `exclusions` contains `gate_surface:.github/workflows/ci.yml`

## AC-045-06-08 — Agent and gate-script changes are excluded
Given a changed-files list containing `agents/pr-review.md` and
`scripts/check-pr-review.sh`
When the predicate runs
Then stdout contains `reason=excluded_path`
And `exclusions` contains `gate_surface:agents/pr-review.md`
And `exclusions` contains `gate_surface:scripts/check-pr-review.sh`

## AC-045-06-09 — Auth and secret code is excluded
Given a changed-files list containing `src/auth/session.ts`
When the predicate runs
Then stdout contains `reason=excluded_path`
And `exclusions` contains `auth_secret:src/auth/session.ts`

## AC-045-06-10 — Database migrations are excluded
Given a changed-files list containing `db/migrations/0007_add_users.sql`
When the predicate runs
Then stdout contains `reason=excluded_path`
And `exclusions` contains
`db_migration:db/migrations/0007_add_users.sql`

## AC-045-06-11 — Dependency changes are excluded
Given a changed-files list containing `package.json`
When the predicate runs
Then stdout contains `reason=excluded_path`
And `exclusions` contains `dependency_manifest:package.json`

## AC-045-06-12 — Report-only mode reports instead of merging
Given `--size-tier auto`, `--review-verdict pass`, `--mode report`
And no excluded path
When the predicate runs
Then stdout contains `eligible=true`
And `action=comment_only`
And `reason=report_only`

## AC-045-06-13 — An exclusion outranks report-only mode
Given `--size-tier auto`, `--review-verdict pass`, `--mode report`
And a changed-files list containing `opencode.json`
When the predicate runs
Then stdout contains `eligible=false`
And `action=none`
And `reason=excluded_path`

## AC-045-06-14 — An invalid mode is a usage error
Given `--mode sometimes`
When the predicate runs
Then the exit code is 2
And stdout contains no `eligible=` line

## AC-045-06-15 — A missing required input is a usage error
Given `--size-tier auto` and `--mode live` but no `--review-verdict`
When the predicate runs
Then the exit code is 2
And stdout contains no `eligible=` line

## AC-045-06-16 — The predicate has no repository identity
Given `scripts/pr-automerge-eligibility.sh`
When its usage text and argument parser are read
Then no argument accepts a repository name, slug, or owner/repo pair
And the output contains no repository identifier

## AC-045-06-17 — Size failure outranks an exclusion
Given `--size-tier blocked`, `--review-verdict pass`
And a changed-files list containing `.github/workflows/ci.yml`
When the predicate runs
Then stdout contains `reason=size_blocked`
