#!/usr/bin/env bats
# media-agents.bats — structural contract for the media agent family (ADR 0007).
# Contract: the four media agents exist with description + mode frontmatter and
# no pinned model (governance frontmatter rule); the voice-chat app and the
# zero-credit smoke script are syntactically valid; the smoke passes without a
# bl install (its bl section skips, never false-fails).

load test_helper
bats_require_minimum_version 1.5.0

MEDIA_AGENTS=(media-image.md media-video.md media-voice.md media-producer.md)

@test "every media agent file exists" {
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$REPO_ROOT/agents/$f" ]
  done
}

@test "media agents carry description and mode frontmatter and no pinned model" {
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

@test "media agents deny git push in their permission block" {
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -qF -- '"git push*": deny' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
  done
}

@test "voice-chat.mjs passes node --check" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node --check "$REPO_ROOT/scripts/media/voice-chat/voice-chat.mjs"
  [ "$status" -eq 0 ]
}

@test "voice-chat refuses Token-Plan sk-sp- keys with a named error" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run env BAILIAN_API_KEY=sk-sp-notarealkey node "$REPO_ROOT/scripts/media/voice-chat/voice-chat.mjs"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Token-Plan harness keys"* ]]
}

@test "smoke-media.mjs exits 0 (zero credits, no network for bl)" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node "$REPO_ROOT/scripts/media/smoke-media.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] agent media-image.md"* ]]
  [[ "$output" == *"[OK] voice-chat.mjs parses"* ]]
}
