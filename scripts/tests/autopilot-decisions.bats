#!/usr/bin/env bats
# autopilot-decisions.bats — acceptance tests for spec 035 Task 6
# (specs/035-autopilot-mode/20-acceptance/AC-035-decisions-artifact.md).
# scripts/autopilot-decisions.sh is the deterministic writer for the two
# autopilot artifacts: specs/NNN-slug/45-decisions.md and the two marker lines
# in 30-report.md.

load test_helper
bats_require_minimum_version 1.5.0

WRITER="$REPO_ROOT/scripts/autopilot-decisions.sh"

setup() {
  setup_tmpdir
  DEC="$TMPDIR_HELPER/45-decisions.md"
  REPORT="$TMPDIR_HELPER/30-report.md"
}

teardown() { teardown_tmpdir; }

@test "AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC" {
  run bash "$WRITER" add "$DEC" \
    --condition 'Acceptance criteria ambiguous' \
    --options 'conservative fix; broader rewrite' \
    --chosen 'conservative fix' \
    --why 'smallest reversible change consistent with the scenarios' \
    --reversibility 'high — one isolated commit' \
    --at '2026-10-26T03:14:07Z'
  [ "$status" -eq 0 ]
  grep -qxF 'Condition: Acceptance criteria ambiguous' "$DEC"
  grep -qxF 'Options: conservative fix; broader rewrite' "$DEC"
  grep -qxF 'Chosen: conservative fix' "$DEC"
  grep -qxF 'Why: smallest reversible change consistent with the scenarios' "$DEC"
  grep -qxF 'Reversibility: high — one isolated commit' "$DEC"
  grep -qxE '^At: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$DEC"
  [ "$(bash "$WRITER" count "$DEC")" -eq 1 ]
}

@test "AC-035-19 — a run that resolves nothing writes exactly the no-decision line" {
  run bash "$WRITER" none "$DEC"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$DEC" | tr -d ' ')" -eq 1 ]
  grep -qxF 'No autopilot decisions were required' "$DEC"
  [ "$(bash "$WRITER" count "$DEC")" -eq 0 ]
  ! grep -q '^Condition:' "$DEC"
}

@test "AC-035-20 — 30-report.md carries Autopilot: true and the entry count" {
  bash "$WRITER" add "$DEC" --condition 'Project type ambiguous' --options 'mvp; production' \
    --chosen 'mvp' --why 'harness default' --reversibility 'high' --at '2026-10-26T03:14:07Z'
  bash "$WRITER" add "$DEC" --condition 'Out-of-scope finding' --options 'fix now; propose follow-up' \
    --chosen 'propose follow-up' --why 'keeps the diff scoped' --reversibility 'high' --at '2026-10-26T03:15:00Z'
  printf '# Report\n' > "$REPORT"

  run bash "$WRITER" mark-report "$DEC" "$REPORT"
  [ "$status" -eq 0 ]
  grep -qxF 'Autopilot: true' "$REPORT"
  grep -qxF 'Autopilot decisions: 2' "$REPORT"

  # idempotent: re-marking does not duplicate the marker lines
  bash "$WRITER" mark-report "$DEC" "$REPORT"
  [ "$(grep -c '^Autopilot: true$' "$REPORT")" -eq 1 ]
  [ "$(grep -c '^Autopilot decisions: ' "$REPORT")" -eq 1 ]

  # zero entries → count 0 (fresh decisions file)
  rm -f "$DEC"
  bash "$WRITER" none "$DEC"
  bash "$WRITER" mark-report "$DEC" "$REPORT"
  grep -qxF 'Autopilot decisions: 0' "$REPORT"
}

@test "unit — add rejects a missing field and a malformed timestamp, leaving the file untouched" {
  run --separate-stderr bash "$WRITER" add "$DEC" --condition 'x' --options 'y' --chosen 'z' --why 'w'
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Reversibility"* ]]
  [ ! -f "$DEC" ]

  run --separate-stderr bash "$WRITER" add "$DEC" --condition 'x' --options 'y' --chosen 'z' \
    --why 'w' --reversibility 'r' --at '26-10-2026'
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"At"* ]]
  [ ! -f "$DEC" ]
}
