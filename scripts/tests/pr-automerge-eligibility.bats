#!/usr/bin/env bats
# pr-automerge-eligibility.bats — acceptance tests for spec 045 Task 6
# (specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-06-*.md).
# Contract: a fixed first-match rule order over size tier, review verdict,
# excluded paths, and report-only mode; no repository identity anywhere.

load test_helper
bats_require_minimum_version 1.5.0

PREDICATE="$REPO_ROOT/scripts/pr-automerge-eligibility.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# changed <path> ... — write the changed-files list, sets $CF.
changed() { # <path> ... → $CF
  CF="$TMPDIR_HELPER/changed.txt"
  printf '%s\n' "$@" > "$CF"
}

# eligible <args...> — run the predicate with the changed-files list appended.
eligible() { run bash "$PREDICATE" --changed-files "$CF" "$@"; }

# ── AC-045-06: eligibility predicate ────────────────────────────────────────

@test "AC-045-06-01 — all gates green in live mode" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=true"* ]]
  [[ "$output" == *"action=merge"* ]]
  [[ "$output" == *"reason=all_green"* ]]
  [[ "$output" == *"exclusions=none"* ]]
}

@test "AC-045-06-02 — the human tier is not eligible" {
  changed src/a.ts
  eligible --size-tier human --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"action=none"* ]]
  [[ "$output" == *"reason=size_human"* ]]
}

@test "AC-045-06-03 — the blocked tier is not eligible" {
  changed src/a.ts
  eligible --size-tier blocked --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"reason=size_blocked"* ]]
}

@test "AC-045-06-04 — the override tier is never auto-merged" {
  changed src/a.ts
  eligible --size-tier override --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"reason=size_override"* ]]
}

@test "AC-045-06-05 — a findings verdict is not eligible" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict findings --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"reason=review_not_pass"* ]]
}

@test "AC-045-06-06 — a missing verdict is not eligible" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict missing --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"reason=review_not_pass"* ]]
}

@test "AC-045-06-07 — workflow changes are excluded" {
  changed .github/workflows/ci.yml
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"reason=excluded_path"* ]]
  [[ "$output" == *"gate_surface:.github/workflows/ci.yml"* ]]
}

@test "AC-045-06-08 — agent and gate-script changes are excluded" {
  changed agents/pr-review.md scripts/check-pr-review.sh
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=excluded_path"* ]]
  [[ "$output" == *"gate_surface:agents/pr-review.md"* ]]
  [[ "$output" == *"gate_surface:scripts/check-pr-review.sh"* ]]
}

@test "AC-045-06-09 — auth and secret code is excluded" {
  changed src/auth/session.ts
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=excluded_path"* ]]
  [[ "$output" == *"auth_secret:src/auth/session.ts"* ]]
}

@test "AC-045-06-10 — database migrations are excluded" {
  changed db/migrations/0007_add_users.sql
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=excluded_path"* ]]
  [[ "$output" == *"db_migration:db/migrations/0007_add_users.sql"* ]]
}

@test "AC-045-06-11 — dependency changes are excluded" {
  changed package.json
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=excluded_path"* ]]
  [[ "$output" == *"dependency_manifest:package.json"* ]]
}

@test "AC-045-06-12 — report-only mode reports instead of merging" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict pass --mode report
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=true"* ]]
  [[ "$output" == *"action=comment_only"* ]]
  [[ "$output" == *"reason=report_only"* ]]
}

@test "AC-045-06-13 — an exclusion outranks report-only mode" {
  changed opencode.json
  eligible --size-tier auto --review-verdict pass --mode report
  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=false"* ]]
  [[ "$output" == *"action=none"* ]]
  [[ "$output" == *"reason=excluded_path"* ]]
}

@test "AC-045-06-14 — an invalid mode is a usage error" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict pass --mode sometimes
  [ "$status" -eq 2 ]
  [[ "$output" != *"eligible="* ]]
}

@test "AC-045-06-15 — a missing required input is a usage error" {
  changed src/a.ts
  eligible --size-tier auto --mode live
  [ "$status" -eq 2 ]
  [[ "$output" != *"eligible="* ]]
}

@test "AC-045-06-16 — the predicate has no repository identity" {
  run bash "$PREDICATE" --help
  [ "$status" -eq 0 ]
  [[ "$output" != *"--repo " && "$output" != *"--repository"* && "$output" != *"--slug"* ]]
  # No repository input is accepted by the parser either: the script text
  # carries no repository-shaped option.
  [ "$(grep -cE -- '^\s*(repo|repository|slug)\)' "$PREDICATE")" -eq 0 ]
}

@test "AC-045-06-17 — size failure outranks an exclusion" {
  changed .github/workflows/ci.yml
  eligible --size-tier blocked --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=size_blocked"* ]]
  [[ "$output" != *"excluded_path"* ]]
}

# ── Unit: output contract and argument handling ─────────────────────────────

@test "predicate: text output carries exactly one line per key" {
  changed src/a.ts
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [ "$(grep -c '^eligible=' <<< "$output")" -eq 1 ]
  [ "$(grep -c '^action=' <<< "$output")" -eq 1 ]
  [ "$(grep -c '^reason=' <<< "$output")" -eq 1 ]
  [ "$(grep -c '^exclusions=' <<< "$output")" -eq 1 ]
}

@test "predicate: an out-of-domain size tier is a usage error" {
  changed src/a.ts
  eligible --size-tier enormous --review-verdict pass --mode live
  [ "$status" -eq 2 ]
  [[ "$output" != *"eligible="* ]]
}

@test "predicate: an empty changed-files list has no exclusion" {
  : > "$TMPDIR_HELPER/empty.txt"
  CF="$TMPDIR_HELPER/empty.txt"
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"exclusions=none"* ]]
  [[ "$output" == *"action=merge"* ]]
}

@test "predicate: an empty exclusion value never wins over a real match" {
  changed src/auth/token.ts
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth_secret:src/auth/token.ts"* ]]
}

@test "predicate: a dotenv file is an auth/secret exclusion" {
  changed .env
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth_secret:.env"* ]]
}

@test "predicate: a versioned SQL migration is a db_migration exclusion" {
  changed db/migrate/V12__add_index.sql
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"db_migration:db/migrate/V12__add_index.sql"* ]]
}

@test "predicate: a lockfile is a dependency_manifest exclusion" {
  changed go.sum
  eligible --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 0 ]
  [[ "$output" == *"dependency_manifest:go.sum"* ]]
}

@test "predicate: comments-file - style stdin is not required, a path is" {
  run bash "$PREDICATE" --size-tier auto --review-verdict pass --mode live
  [ "$status" -eq 2 ]
  [[ "$output" != *"eligible="* ]]
}
