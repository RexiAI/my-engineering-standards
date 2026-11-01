#!/usr/bin/env bats
# autopilot-command.bats — acceptance tests for spec 035 Task 2
# (specs/035-autopilot-mode/20-acceptance/AC-035-command.md).
# The command is a prompt artifact, so its contract is asserted statically:
# frontmatter, ordered-queue semantics, explicit autopilot-on delegation, and a
# usage error for zero slugs.

load test_helper
bats_require_minimum_version 1.5.0

CMD="$REPO_ROOT/commands/autopilot.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate" {
  [ -f "$CMD" ]
  grep -qxF 'agent: spec-pipeline' "$CMD"
  grep -qiF 'autopilot mode' "$CMD"
  grep -qF '$ARGUMENTS' "$CMD"
  grep -qiF 'autopilot is explicitly on' "$CMD"
  grep -qiF 'human review gate' "$CMD"
  grep -qiF 'never ask' "$CMD"
  # delegates to the orchestrator rather than reimplementing the stages
  grep -qF 'spec-pipeline' "$CMD"
}

@test "AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs" {
  grep -qiF 'in the order given' "$CMD"
  grep -qiF 'each slug as its own autopilot run' "$CMD"
  grep -qF '/autopilot 001-x 002-y' "$CMD"
}

@test "AC-035-08 — /autopilot with no slugs prints usage and stops without guessing" {
  grep -qiF 'usage: /autopilot <slug> [<slug> ...]' "$CMD"
  grep -qiF 'do not guess' "$CMD"
  grep -qiF 'stop' "$CMD"
  # no fallback that invents a slug from the working tree
  ! grep -qiE 'pick the next sequence number|choose a short slug' "$CMD"
}
