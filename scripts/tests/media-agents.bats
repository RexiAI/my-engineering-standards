#!/usr/bin/env bats
# media-agents.bats — characterization tests for the provider-agnostic media
# agent family (ADR 0016). No AC prefix: the archived spec scenarios described
# the retired vendor-specific implementation, so these assert the contract
# that ships now. Zero credits and zero network: nothing here invokes a backend.

load test_helper
bats_require_minimum_version 1.5.0

MEDIA_AGENTS=(media-image.md media-video.md media-voice.md media-producer.md)
# Vendor tokens assembled at runtime so this test file carries none literally.
V_A="ali""baba"; V_B="ali""yun"; V_C="dash""scope"; V_D="bai""lian"; V_E="qw""en"
VENDOR_RE="$V_A|$V_B|$V_C|$V_D|$V_E"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "media-agents: every agent file exists" {
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$REPO_ROOT/agents/$f" ]
  done
}

@test "media-agents: description and mode frontmatter, no pinned model" {
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

@test "media-agents: deny git push and rm -rf in the permission block" {
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -qF -- '"git push*": deny' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
    run grep -qF -- '"rm -rf *": deny' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
  done
}

@test "media-agents: each agent references the backend contract" {
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -qF 'backends.json' "$REPO_ROOT/agents/$f"
    [ "$status" -eq 0 ]
  done
}

@test "media-agents: no vendor-specific token in agents, docs, or contract example" {
  run grep -riE "$VENDOR_RE" \
    "$REPO_ROOT/agents/media-image.md" \
    "$REPO_ROOT/agents/media-video.md" \
    "$REPO_ROOT/agents/media-voice.md" \
    "$REPO_ROOT/agents/media-producer.md" \
    "$REPO_ROOT/docs/MEDIA_AGENTS.md" \
    "$REPO_ROOT/scripts/media/backends.example.json" \
    "$REPO_ROOT/scripts/media/install.mjs" \
    "$REPO_ROOT/scripts/media/smoke-media.mjs"
  [ "$status" -eq 1 ]
}

@test "media-agents: contract example parses and carries every core operation" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node -e '
    const c = require(process.argv[1]);
    const need = { image: ["generate", "edit"], video: ["generate"], tts: ["command"], asr: ["command"] };
    for (const [s, ops] of Object.entries(need)) {
      if (!c[s]) throw new Error(`missing section ${s}`);
      for (const op of ops) {
        if (!Array.isArray(c[s][op]) || c[s][op].length === 0) throw new Error(`missing ${s}.${op}`);
      }
    }
  ' "$REPO_ROOT/scripts/media/backends.example.json"
  [ "$status" -eq 0 ]
}

@test "media-agents: smoke-media.mjs exits 0 with the expected OK lines" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  run node "$REPO_ROOT/scripts/media/smoke-media.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] agent media-image.md"* ]]
  [[ "$output" == *"[OK] backends.example.json parses"* ]]
}

@test "media-agents: install survives dangling symlinks in the config dir" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  local cfg="$TMPDIR_HELPER/cfg2"
  local realmedia="$TMPDIR_HELPER/realmedia"
  local realagents="$TMPDIR_HELPER/realagents"
  mkdir -p "$cfg" "$realmedia" "$realagents"
  ln -s "$realmedia" "$cfg/media"
  ln -s "$realagents" "$cfg/agents"
  rm -rf "$realmedia" "$realagents"   # both links now dangle

  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  [ "$status" -eq 0 ]
  [ -d "$realmedia" ]
  [ -d "$realagents" ]
  [ -f "$cfg/media/backends.json" ]
  [ -f "$cfg/agents/media-image.md" ]
}

@test "media-agents: install writes the tree, is idempotent, keeps user config, uninstall reverses" {
  if ! command -v node >/dev/null 2>&1; then skip "node not installed"; fi
  local cfg="$TMPDIR_HELPER/cfg"
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  [ "$status" -eq 0 ]
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$cfg/agents/$f" ]
  done
  [ -f "$cfg/media/backends.json" ]
  [ -f "$cfg/media/backends.example.json" ]

  # user edit survives a re-run
  printf '{"image":{"generate":["echo","edited"]}}\n' > "$cfg/media/backends.json"
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  [ "$status" -eq 0 ]
  run grep -q 'edited' "$cfg/media/backends.json"
  [ "$status" -eq 0 ]

  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$cfg/agents/media-image.md" ]
  [ ! -f "$cfg/media/backends.example.json" ]
  [ -f "$cfg/media/backends.json" ]
}
