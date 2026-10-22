#!/usr/bin/env bats
# media-agents.bats — acceptance tests for the media agent family (spec 031,
# ADR 0007). One @test per scenario AC-031-NN from specs/031-media-agents/
# 20-acceptance/, IDs cited per docs/SPEC_PIPELINE.md §Scenario format.
# Zero credits: nothing here calls a billable endpoint.

load test_helper
bats_require_minimum_version 1.5.0

MEDIA_AGENTS=(media-image.md media-video.md media-voice.md media-producer.md)

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-01: every media agent file exists" {
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$REPO_ROOT/agents/$f" ]
  done
}

@test "AC-031-02: media agents carry description and mode frontmatter and no pinned model" {
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -c '^description: ' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" -eq 1 ]
    run grep -c '^mode: ' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" -eq 1 ]
    run grep -c '^model: ' "$REPO_ROOT/agents/$f"
    [ "${lines[0]}" -eq 0 ]
  done
}

@test "AC-031-03: media agents deny git push in their permission block" {
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -qF -- '"git push*": deny' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
  done
}

@test "AC-031-04: voice-chat.mjs passes node --check" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node --check "$REPO_ROOT/scripts/media/voice-chat/voice-chat.mjs"
  [ "$status" -eq 0 ]
}

@test "AC-031-05: voice-chat refuses Token-Plan sk-sp- keys with a named error, no side effects" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run env BAILIAN_API_KEY=sk-sp-notarealkey node "$REPO_ROOT/scripts/media/voice-chat/voice-chat.mjs"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Token-Plan harness keys"* ]]
}

@test "AC-031-06: smoke-media.mjs exits 0 (zero credits; bl section dry-run or skipped)" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node "$REPO_ROOT/scripts/media/smoke-media.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] agent media-image.md"* ]]
  [[ "$output" == *"[OK] voice-chat.mjs parses"* ]]
}

@test "AC-031-07: install.mjs writes the complete tree into OPENCODE_CONFIG_DIR, idempotent, uninstall reverses" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  local cfg="$TMPDIR_HELPER/cfg"
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  [ "$status" -eq 0 ]
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$cfg/agents/$f" ]
  done
  [ -f "$cfg/media/voice-chat/voice-chat.mjs" ]
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  [ "$status" -eq 0 ]
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$cfg/agents/media-image.md" ]
  [ ! -f "$cfg/media/voice-chat/voice-chat.mjs" ]
}
