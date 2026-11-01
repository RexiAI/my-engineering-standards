#!/usr/bin/env bats
# autopilot-spec-build-token.bats — acceptance tests for spec 035 Task 3
# (specs/035-autopilot-mode/20-acceptance/AC-035-spec-build-token.md).
# Both commands must delegate detection to scripts/autopilot-trigger.sh instead
# of re-implementing the token match, and neither may change its normal-mode
# behavior.

load test_helper
bats_require_minimum_version 1.5.0

SPEC="$REPO_ROOT/commands/spec.md"
BUILD="$REPO_ROOT/commands/build.md"
TRIGGER_REF='scripts/autopilot-trigger.sh'
# commands/build.md and agents/spec-pipeline.md may not cite a `scripts/` path
# (spec 014 AC-014-04-09), so they name the trigger script bare and point at
# docs/SPEC_PIPELINE.md §Autopilot mode for the authoritative path.
BUILD_TRIGGER_REF='autopilot-trigger.sh'

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-09 — /spec with the token continues instead of stopping for human review" {
  [ -f "$SPEC" ]
  grep -qF "$TRIGGER_REF" "$SPEC"
  grep -qiF 'autopilot' "$SPEC"
  grep -qiF 'do not stop after stage 1' "$SPEC"
  grep -qiF 'human review' "$SPEC"
  # the normal-mode stop is still documented
  grep -qiF 'when it prints `normal`' "$SPEC"
}

@test "AC-035-10 — /build with the token resolves asks per autopilot and never emits BLOCKED" {
  [ -f "$BUILD" ]
  grep -qF "$BUILD_TRIGGER_REF" "$BUILD"
  grep -qiF 'disposition' "$BUILD"
  grep -qiF 'never emit' "$BUILD"
  grep -qiF 'wait for input' "$BUILD"
  # detection is delegated, not re-implemented
  ! grep -qE 'SPEC_AUTOPILOT=[^1]' "$BUILD"
}
