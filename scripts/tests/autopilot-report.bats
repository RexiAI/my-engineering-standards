#!/usr/bin/env bats
# autopilot-report.bats — acceptance tests for spec 035 Task 7
# (specs/035-autopilot-mode/20-acceptance/AC-035-morning-report.md).
# scripts/autopilot-report.sh is the deterministic writer for the queue-run
# morning report. Manifest line format (see the script header):
#   slug|status|detail|decisions|followup
# status is `pr` (detail = PR URL) or `stopped` (detail = stop reason);
# decisions is a 45-decisions.md path or `-`; followup is text or `-`.

load test_helper
bats_require_minimum_version 1.5.0

REPORT="$REPO_ROOT/scripts/autopilot-report.sh"

setup() {
  setup_tmpdir
  ROOT="$TMPDIR_HELPER/repo"
  mkdir -p "$ROOT"
  MANIFEST="$TMPDIR_HELPER/manifest.txt"
}

teardown() { teardown_tmpdir; }

@test "AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md" {
  printf '%s\n' \
    '001-x|pr|https://github.com/example/repo/pull/7|specs/001-x/45-decisions.md|-' > "$MANIFEST"
  run bash "$REPORT" --root "$ROOT" --date 2026-10-26 --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$output" = "docs/changes/autopilot-2026-10-26.md" ]
  [ -f "$ROOT/docs/changes/autopilot-2026-10-26.md" ]
  grep -qF 'https://github.com/example/repo/pull/7' "$ROOT/docs/changes/autopilot-2026-10-26.md"
}

@test "AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md" {
  printf '%s\n' \
    '001-x|stopped|phase-1 budget exhausted|-|-' > "$MANIFEST"
  run bash "$REPORT" --root "$ROOT" --date 2026-10-26 --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  [ "$output" = "specs/autopilot-2026-10-26.md" ]
  [ -f "$ROOT/specs/autopilot-2026-10-26.md" ]
  [ ! -e "$ROOT/docs/changes/autopilot-2026-10-26.md" ]
}

@test "AC-035-23 — the report has ordered per-spec blocks and the conditional sections" {
  printf '%s\n' \
    '001-x|pr|https://github.com/example/repo/pull/7|specs/001-x/45-decisions.md|-' \
    '002-y|stopped|dirty tree outside the current spec folder|specs/002-y/45-decisions.md|split spec 002-y into two specs' \
    > "$MANIFEST"
  run bash "$REPORT" --root "$ROOT" --date 2026-10-26 --manifest "$MANIFEST"
  [ "$status" -eq 0 ]
  local out="$ROOT/docs/changes/autopilot-2026-10-26.md"
  [ -f "$out" ]

  # per-spec status blocks, in queue order, up to and including the stopping spec
  grep -qxF '## 001-x' "$out"
  grep -qxF '## 002-y' "$out"
  [ "$(grep -n '^## 001-x$' "$out" | cut -d: -f1)" -lt "$(grep -n '^## 002-y$' "$out" | cut -d: -f1)" ]
  grep -qF 'Status: PR https://github.com/example/repo/pull/7' "$out"
  grep -qF 'Status: STOPPED — dirty tree outside the current spec folder' "$out"

  # required sections
  grep -qxF '## Decisions' "$out"
  grep -qF 'specs/001-x/45-decisions.md' "$out"
  grep -qxF '## Stop reasons' "$out"
  grep -qF '002-y: dirty tree outside the current spec folder' "$out"
  grep -qxF '## Follow-up proposals' "$out"
  grep -qF '002-y: split spec 002-y into two specs' "$out"
}

@test "unit — a clean queue omits the stop and follow-up sections; a bad manifest is rejected" {
  printf '%s\n' \
    '001-x|pr|https://github.com/example/repo/pull/7|specs/001-x/45-decisions.md|-' > "$MANIFEST"
  bash "$REPORT" --root "$ROOT" --date 2026-10-26 --manifest "$MANIFEST" >/dev/null
  local out="$ROOT/docs/changes/autopilot-2026-10-26.md"
  ! grep -q '^## Stop reasons$' "$out"
  ! grep -q '^## Follow-up proposals$' "$out"

  printf '%s\n' '001-x|maybe|detail|-|-' > "$MANIFEST"
  run --separate-stderr bash "$REPORT" --root "$ROOT" --date 2026-10-26 --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"status"* ]]
}
