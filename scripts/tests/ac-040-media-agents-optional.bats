#!/usr/bin/env bats
# ac-040-media-agents-optional.bats — acceptance fixtures for spec 040
# ("media agents opt-in for child repos").
#
# One test per scenario in specs/040-media-agents-optional/20-acceptance/.
# The ID in each test name is what scripts/check-scenario-traceability.sh greps
# for (docs/spec-pipeline/specifier.md §Scenario format).
#
# Fixture model (same shape as spec 033's): make_child_repo builds a hermetic
# child repo that consumes this standards tree the way a real child does —
# <child>/.standards/ holds symlinks to the standards subdirectories, while
# scripts/bootstrap.sh and scripts/capabilities.tsv are real copies so a test
# never writes into the standards repo itself.
load test_helper

MEDIA_AGENTS=(media-image.md media-video.md media-voice.md media-producer.md)
CHILD=""

setup() {
  setup_tmpdir
  CHILD="$TMPDIR_HELPER/child"
  make_child_repo "$CHILD"
  export CHILD
}

teardown() {
  teardown_tmpdir
}

# ── fixtures ─────────────────────────────────────────────────────────────────

make_child_repo() { # make_child_repo DIR
  local child="$1" d f
  mkdir -p "$child/.standards/scripts"
  git -C "$child" init -q
  git -C "$child" config user.email "test@example.com"
  git -C "$child" config user.name "Test"
  for d in templates language-specific agents agents-optional commands skills ci okf .github; do
    ln -s "$REPO_ROOT/$d" "$child/.standards/$d"
  done
  for f in "$REPO_ROOT"/scripts/*; do
    ln -s "$f" "$child/.standards/scripts/$(basename "$f")"
  done
  rm -f "$child/.standards/scripts/bootstrap.sh" \
        "$child/.standards/scripts/capabilities.tsv"
  cp "$REPO_ROOT/scripts/bootstrap.sh" "$child/.standards/scripts/bootstrap.sh"
  cp "$REPO_ROOT/scripts/capabilities.tsv" "$child/.standards/scripts/capabilities.tsv"
}

run_bootstrap() { # run_bootstrap [FLAGS...]
  run bash -c 'cd "$1"; shift; exec bash ./.standards/scripts/bootstrap.sh "$@"' _ "$CHILD" "$@"
}

require_node() {
  command -v node >/dev/null 2>&1 || skip "node not installed"
}

# Every media agent file reachable from a path, following symlinks (the child's
# .opencode/agents is a symlink into .standards/, so find must follow it).
media_files_under() { # media_files_under DIR
  find -L "$1" -maxdepth 3 -name 'media-*.md' -print 2>/dev/null || true
}

# The family is opt-in: nothing media-shaped may be reachable from DIR unless the
# test explicitly bootstrapped --with-media. CONTEXT names the failure in TAP.
refute_media_under() { # refute_media_under DIR CONTEXT
  local hit
  hit=$(media_files_under "$1")
  [ -z "$hit" ] || { echo "$2: $hit"; return 1; }
}

# ── Task 1: relocation (AC-040-01) ──────────────────────────────────────────

@test "AC-040-01-01: the four agents live in agents-optional/ and not in agents/" {
  local f hit
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$REPO_ROOT/agents-optional/$f" ] || { echo "missing agents-optional/$f"; return 1; }
  done
  hit=$(find "$REPO_ROOT/agents" -maxdepth 1 -name 'media-*.md' -print)
  [ -z "$hit" ] || { echo "default agent set still carries: $hit"; return 1; }
}

@test "AC-040-01-02: a bridged child without opt-in exposes no media agent" {
  run_bootstrap --none
  assert_exit_code 0 "$status"
  [ -L "$CHILD/.opencode/agents" ] || { echo ".opencode/agents is not the bridge symlink"; return 1; }
  refute_media_under "$CHILD/.opencode/agents" "the bridge exposes"
}

@test "AC-040-01-03: default agents/ and commands/ never name a media agent" {
  run grep -rhoE 'media-(image|video|voice|producer)' "$REPO_ROOT/agents" "$REPO_ROOT/commands"
  [ "$status" -eq 1 ] || { echo "dangling reference(s): $output"; return 1; }
}

# ── Task 2: opt-in mechanisms (AC-040-02) ───────────────────────────────────

@test "AC-040-02-01: the global installer copies from agents-optional/" {
  require_node
  local cfg="$TMPDIR_HELPER/global" f
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  assert_exit_code 0 "$status"
  for f in "${MEDIA_AGENTS[@]}"; do
    [ -f "$cfg/agents/$f" ] || { echo "not installed: $f"; return 1; }
    cmp -s "$REPO_ROOT/agents-optional/$f" "$cfg/agents/$f" \
      || { echo "$f does not match agents-optional/$f"; return 1; }
  done
}

@test "AC-040-02-02: --uninstall removes them" {
  require_node
  local cfg="$TMPDIR_HELPER/global"
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs"
  assert_exit_code 0 "$status"
  run env OPENCODE_CONFIG_DIR="$cfg" node "$REPO_ROOT/scripts/media/install.mjs" --uninstall
  assert_exit_code 0 "$status"
  refute_media_under "$cfg/agents" "uninstall left"
}

@test "AC-040-02-03: the media-agents catalog row keeps the --with-media flag" {
  local row flag
  row=$(awk -F'|' '$1 == "media-agents"' "$REPO_ROOT/scripts/capabilities.tsv")
  [ -n "$row" ] || { echo "no media-agents row in capabilities.tsv"; return 1; }
  flag=$(printf '%s' "$row" | cut -d'|' -f5)
  [ "$flag" = "--with-media" ] || { echo "flag column is '$flag'"; return 1; }
}

@test "AC-040-02-04: a child bootstrapped without the flag carries no media agent" {
  run_bootstrap --none
  assert_exit_code 0 "$status"
  refute_media_under "$CHILD/.opencode" "media agent file present under .opencode/"
  run grep -q 'media-image' "$CHILD/opencode.json"
  [ "$status" -eq 1 ] || { echo "opencode.json carries a media agent entry"; return 1; }
}

# ── Task 3: ADR amendment (AC-040-03) ───────────────────────────────────────

@test "AC-040-03-01: ADR 0018 amends the media agent family decision" {
  local adr="$REPO_ROOT/docs/adr/0018-media-agents-opt-in.md" h
  [ -f "$adr" ] || { echo "missing docs/adr/0018-media-agents-opt-in.md"; return 1; }
  for h in Context Decision Consequences; do
    grep -qE "^## $h\$" "$adr" || { echo "ADR 0018 has no '## $h' section"; return 1; }
  done
  run bash -c 'cd "$1" && sed -n "/^## Status$/,/^## /p" docs/adr/0018-media-agents-opt-in.md' _ "$REPO_ROOT"
  assert_exit_code 0 "$status"
  [[ "$output" == *Accepted* ]] || { echo "ADR 0018 status is not Accepted: $output"; return 1; }
  run grep -qF '0007-media-agent-family.md' "$adr"
  [ "$status" -eq 0 ] || { echo "ADR 0018 does not reference 0007-media-agent-family.md"; return 1; }
}

@test "AC-040-03-02: the media family record points forward and the index lists it" {
  local old="$REPO_ROOT/docs/adr/0007-media-agent-family.md"
  [ -f "$old" ] || { echo "missing docs/adr/0007-media-agent-family.md"; return 1; }
  run bash -c 'cd "$1" && sed -n "/^## Status$/,/^## /p" docs/adr/0007-media-agent-family.md' _ "$REPO_ROOT"
  assert_exit_code 0 "$status"
  [[ "$output" == *0016* ]] || { echo "ADR 0007 status does not mention 0016: $output"; return 1; }
  run grep -qE '^\| 0016 ' "$REPO_ROOT/docs/adr/README.md"
  [ "$status" -eq 0 ] || { echo "the ADR index does not list 0016"; return 1; }
  run grep -qE '^\| 0018 ' "$REPO_ROOT/docs/adr/README.md"
  [ "$status" -eq 0 ] || { echo "the ADR index does not list 0018"; return 1; }
  run grep -qE '^\| 0007 ' "$REPO_ROOT/docs/adr/README.md"
  [ "$status" -eq 0 ] || { echo "the ADR index does not list 0007"; return 1; }
}

# ── Task 4: docs, tests and gates consistent (AC-040-04) ────────────────────

@test "AC-040-04-01: MEDIA_AGENTS.md documents the opt-in and the relocated paths" {
  local doc="$REPO_ROOT/docs/MEDIA_AGENTS.md" f
  run grep -nE '(^|[`/ ])agents/media-' "$doc"
  [ "$status" -eq 1 ] || { echo "stale agents/media path: $output"; return 1; }
  for f in "${MEDIA_AGENTS[@]}"; do
    run grep -qF "agents-optional/$f" "$doc"
    [ "$status" -eq 0 ] || { echo "component table omits agents-optional/$f"; return 1; }
  done
  run grep -qiE 'not loaded by default' "$doc"
  [ "$status" -eq 0 ] || { echo "doc does not state the agents are not loaded by default"; return 1; }
  run grep -qF -- '--with-media' "$doc"
  [ "$status" -eq 0 ] || { echo "doc does not name the --with-media opt-in"; return 1; }
  run grep -qF 'make install-media' "$doc"
  [ "$status" -eq 0 ] || { echo "doc does not name the global installer opt-in"; return 1; }
}

@test "AC-040-04-02: no stale agents/media path survives in the docs" {
  run bash -c 'cd "$1" && grep -rn "agents/media-" docs \
    --exclude-dir=changes --exclude-dir=adr | grep -v "^docs/adr/0007-"' _ "$REPO_ROOT"
  [ "$status" -eq 1 ] || { echo "stale path(s): $output"; return 1; }
}

@test "AC-040-04-03: the orchestration and skills gates stay green" {
  run bash "$REPO_ROOT/scripts/check-orchestration.sh"
  assert_exit_code 0 "$status"
  run bash "$REPO_ROOT/scripts/check-skills.sh"
  assert_exit_code 0 "$status"
}

@test "AC-040-04-04: the media agent bats suite is green against agents-optional/" {
  run grep -qF 'agents-optional/' "$REPO_ROOT/scripts/tests/media-agents.bats"
  [ "$status" -eq 0 ] || { echo "media-agents.bats does not target agents-optional/"; return 1; }
  command -v bats >/dev/null 2>&1 || skip "bats not on PATH to run the nested suite"
  run bats "$REPO_ROOT/scripts/tests/media-agents.bats"
  assert_exit_code 0 "$status"
}

# ── Unit coverage: behavior the scenarios imply but do not spell out ────────

@test "media-agents unit: --with-media writes file-prompt agent entries into opencode.json" {
  require_node
  run_bootstrap --with-media
  assert_exit_code 0 "$status"
  run node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    for (const n of ["media-image", "media-video", "media-voice", "media-producer"]) {
      const want = `{file:.standards/agents-optional/${n}.md}`;
      if (!c.agent || !c.agent[n]) throw new Error(`missing agent.${n}`);
      if (c.agent[n].prompt !== want) throw new Error(`agent.${n}.prompt is ${JSON.stringify(c.agent[n].prompt)}`);
    }
  ' "$CHILD/opencode.json"
  assert_exit_code 0 "$status"
  refute_media_under "$CHILD/.opencode" "opt-in must not place files under .opencode/"
}

@test "media-agents unit: --with-media merges into an existing opencode.json and is idempotent" {
  require_node
  printf '%s\n' '{"$schema":"https://opencode.ai/config.json","agent":{"spec-coder":{"model":"{env:SPEC_CODER_MODEL}"}},"instructions":[".standards/AGENTS.md"]}' \
    > "$CHILD/opencode.json"
  run_bootstrap --with-media
  assert_exit_code 0 "$status"
  local first
  first=$(cksum < "$CHILD/opencode.json")
  run_bootstrap --with-media
  assert_exit_code 0 "$status"
  [ "$(cksum < "$CHILD/opencode.json")" = "$first" ] || { echo "second run rewrote opencode.json"; return 1; }
  run node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (c.agent["spec-coder"].model !== "{env:SPEC_CODER_MODEL}") throw new Error("existing agent entry lost");
    if (!Array.isArray(c.instructions) || c.instructions[0] !== ".standards/AGENTS.md") throw new Error("unrelated keys lost");
    if (Object.keys(c.agent).length !== 5) throw new Error(`expected 5 agent entries, got ${Object.keys(c.agent).length}`);
  ' "$CHILD/opencode.json"
  assert_exit_code 0 "$status"
}

@test "media-agents unit: --with-media --dry-run plans opencode.json and writes nothing" {
  run_bootstrap --with-media --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF 'CREATED media-agents: opencode.json' \
    || { echo "plan omits the media-agents row: $output"; return 1; }
  [ ! -e "$CHILD/opencode.json" ] || { echo "dry run wrote opencode.json"; return 1; }
}

@test "media-agents unit: --all writes the four entries and --none writes none" {
  require_node
  run_bootstrap --none
  assert_exit_code 0 "$status"
  run node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const n = Object.keys(c.agent || {}).filter((k) => k.startsWith("media-")).length;
    console.log(n);
  ' "$CHILD/opencode.json"
  assert_exit_code 0 "$status"
  [ "$output" = "0" ] || { echo "--none wrote $output media entry/entries"; return 1; }

  run_bootstrap --all
  assert_exit_code 0 "$status"
  run node -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const n = Object.keys(c.agent || {}).filter((k) => k.startsWith("media-")).length;
    console.log(n);
  ' "$CHILD/opencode.json"
  assert_exit_code 0 "$status"
  [ "$output" = "4" ] || { echo "--all wrote $output media entries, expected 4"; return 1; }
  local hit
  hit=$(media_files_under "$CHILD/.opencode")
  [ -z "$hit" ] || { echo "--all must still place no media file under .opencode/: $hit"; return 1; }
}

@test "media-agents unit: an existing non-JSON opencode.json is left untouched and reported" {
  printf '{ "agent": { /* jsonc comment */ } }\n' > "$CHILD/opencode.json"
  local before
  before=$(cksum < "$CHILD/opencode.json")
  run_bootstrap --with-media
  assert_exit_code 0 "$status"
  [ "$(cksum < "$CHILD/opencode.json")" = "$before" ] || { echo "unparsable config was rewritten"; return 1; }
  printf '%s\n' "$output" | grep -qE 'WARN: .*opencode\.json' \
    || { echo "no warning for the unparsable config: $output"; return 1; }
}
