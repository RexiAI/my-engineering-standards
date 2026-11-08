#!/usr/bin/env bats
# voice-console.bats — acceptance suite for spec 044 (voice console).
#
# Every scenario in specs/044-voice-console/20-acceptance/ appears exactly once
# as `@test "AC-044-NN-MM: ..."`. The suite is hermetic: file modes only, the
# fake opencode server binds 127.0.0.1, and every write lands in $TMPDIR_HELPER
# or a temp OPENCODE_CONFIG_DIR. Device paths are exercised with stub binaries
# so no sound card is required; absent-runtime paths are simulated with a
# stripped PATH and assert exit 3.

load test_helper
bats_require_minimum_version 1.5.0

VOICE="$REPO_ROOT/scripts/voice"
TESTS="$REPO_ROOT/scripts/tests"
NODE_BIN="$(command -v node)"
PYTHON_BIN="$(command -v python3 || true)"

setup() {
  setup_tmpdir
}

teardown() {
  stop_server
  teardown_tmpdir
}

# --- shared helpers ---------------------------------------------------------

stop_server() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    unset SERVER_PID
  fi
}

# start_server <events-file> <record-file> [extra args...] — start the fake
# opencode server, wait for LISTENING, export SERVER_PORT.
start_server() {
  local events="$1" record="$2"
  shift 2
  stop_server
  : > "$record"
  : > "$TMPDIR_HELPER/server.out"
  "$NODE_BIN" "$TESTS/voice-fake-server.mjs" --events "$events" --record "$record" \
    --port 0 "$@" > "$TMPDIR_HELPER/server.out" 2> "$TMPDIR_HELPER/server.err" &
  SERVER_PID=$!
  local i
  for i in $(seq 1 300); do
    if grep -q '^LISTENING ' "$TMPDIR_HELPER/server.out" 2>/dev/null; then
      break
    fi
    sleep 0.01
  done
  SERVER_PORT="$(awk '/^LISTENING /{print $2; exit}' "$TMPDIR_HELPER/server.out")"
  [ -n "$SERVER_PORT" ]
}

# voice_run <args...> — run the entry point with every VOICE_* variable
# cleared, capturing combined output in $output.
voice_run() {
  run env -u VOICE_MODE -u VOICE_OPENCODE_URL -u VOICE_SESSION \
    -u VOICE_ASR_ENGINE -u VOICE_ARTIFACTS_DIR \
    "$NODE_BIN" "$VOICE/voice-console.mjs" "$@"
}

# voice_split <args...> — same, but stdout/stderr land in $VOICE_OUT/$VOICE_ERR.
voice_split() {
  VOICE_OUT="$TMPDIR_HELPER/out"
  VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$NODE_BIN" "$VOICE/voice-console.mjs" "$@"
}

# voice_json <args...> — stdout only (stderr discarded) for JSON parsing.
voice_json() {
  run env -u VOICE_MODE -u VOICE_OPENCODE_URL -u VOICE_SESSION \
    -u VOICE_ASR_ENGINE -u VOICE_ARTIFACTS_DIR \
    "$NODE_BIN" "$VOICE/voice-console.mjs" "$@" 2>/dev/null
}

# jget <json-string> <dotted.path>
jget() {
  "$NODE_BIN" -e 'let o = JSON.parse(process.argv[1]); for (const k of process.argv[2].split(".")) o = o[k]; process.stdout.write(String(o));' "$1" "$2"
}

# mk_intent <tool> <command> [repoRoot] [paths-json]
mk_intent() {
  "$NODE_BIN" -e 'const [tool, command, repoRoot, paths] = process.argv.slice(1); process.stdout.write(JSON.stringify({ tool, command, repoRoot, paths: JSON.parse(paths || "[]") }));' "$1" "$2" "$3" "$4"
}

# mk_write_intent <path> <repoRoot>
mk_write_intent() {
  "$NODE_BIN" -e 'const [p, root] = process.argv.slice(1); process.stdout.write(JSON.stringify({ tool: "write", command: null, repoRoot: root, paths: [p] }));' "$1" "$2"
}

# --- AC-044-01: CLI surface, configuration, run artifacts -------------------

@test "AC-044-01-01: help lists the three modes and the five exit codes" {
  voice_run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *narrate* ]]
  [[ "$output" == *converse* ]]
  [[ "$output" == *control* ]]
  [[ "$output" == *"0"* ]]
  [[ "$output" == *"2"* ]]
  [[ "$output" == *"3"* ]]
  [[ "$output" == *"4"* ]]
  [[ "$output" == *"5"* ]]
}

@test "AC-044-01-02: print-config emits exactly one JSON object with the contract keys" {
  voice_split --print-config
  [ "$status" -eq 0 ]
  [ -s "$VOICE_OUT" ]
  [ "$(jget "$(cat "$VOICE_OUT")" mode)" = "narrate" ]
  [ "$(jget "$(cat "$VOICE_OUT")" budget.maxSentences)" = "3" ]
  [ "$(jget "$(cat "$VOICE_OUT")" budget.maxSeconds)" = "45" ]
  [ "$(jget "$(cat "$VOICE_OUT")" budget.wordsPerSecond)" = "2.5" ]
  [ "$(jget "$(cat "$VOICE_OUT")" modelCache)" = ".cache/voice/models" ]
  for key in mode control session agent opencodeUrl audioIn audioOut asr tts budget artifacts modelCache; do
    [ "$(jget "$(cat "$VOICE_OUT")" "$key")" != "undefined" ]
  done
}

@test "AC-044-01-03: print-config is inert (no request, no artifacts directory)" {
  local events="$TMPDIR_HELPER/events.jsonl"
  local record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  local art="$TMPDIR_HELPER/never"
  voice_run --print-config --opencode-url "http://127.0.0.1:$SERVER_PORT" \
    --artifacts "$art" --tts-engine silent
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  [ ! -e "$art" ]
}

@test "AC-044-01-04: flag beats environment beats default" {
  VOICE_OUT="$TMPDIR_HELPER/out"
  VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" env VOICE_MODE=converse VOICE_OPENCODE_URL=http://127.0.0.1:4444 \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --print-config \
    --mode narrate --opencode-url http://127.0.0.1:5555
  [ "$(jget "$(cat "$VOICE_OUT")" mode)" = "narrate" ]
  [ "$(jget "$(cat "$VOICE_OUT")" opencodeUrl)" = "http://127.0.0.1:5555" ]

  run env VOICE_MODE=converse VOICE_OPENCODE_URL=http://127.0.0.1:4444 \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --print-config
  [ "$status" -eq 0 ]
  [ "$(jget "$output" mode)" = "converse" ]
  [ "$(jget "$output" opencodeUrl)" = "http://127.0.0.1:4444" ]

  voice_run --print-config
  [ "$status" -eq 0 ]
  [ "$(jget "$output" mode)" = "narrate" ]
  [ "$(jget "$output" opencodeUrl)" = "http://127.0.0.1:4096" ]
}

@test "AC-044-01-05: an unknown flag is a usage error with empty stdout" {
  voice_split --print-config --narrate-everything
  [ "$status" -eq 2 ]
  [ ! -s "$VOICE_OUT" ]
  [[ "$(cat "$VOICE_ERR")" == *"--narrate-everything"* ]]
}

@test "AC-044-01-06: an invalid mode is a usage error naming the accepted values" {
  voice_split --print-config --mode duplex
  [ "$status" -eq 2 ]
  [ ! -s "$VOICE_OUT" ]
  local err
  err="$(cat "$VOICE_ERR")"
  [[ "$err" == *narrate* ]]
  [[ "$err" == *converse* ]]
  [[ "$err" == *control* ]]
}

@test "AC-044-01-07: --max-sentences accepts only integers of at least one" {
  voice_run --print-config --max-sentences 1
  [ "$status" -eq 0 ]
  [ "$(jget "$output" budget.maxSentences)" = "1" ]
  local bad
  for bad in 0 -1 abc; do
    voice_split --print-config --max-sentences "$bad"
    [ "$status" -eq 2 ]
    [ ! -s "$VOICE_OUT" ]
  done
  voice_split --print-config --max-sentences
  [ "$status" -eq 2 ]
  [ ! -s "$VOICE_OUT" ]
}

@test "AC-044-01-08: narrate and control require a parent session" {
  voice_split --print-config --mode narrate
  [ "$status" -eq 2 ]
  [[ "$(cat "$VOICE_ERR")" == *"--session"* ]]
  voice_split --print-config --mode control
  [ "$status" -eq 2 ]
  [[ "$(cat "$VOICE_ERR")" == *"--session"* ]]
}

@test "AC-044-01-09: narrate rejects audio input before any socket or child" {
  voice_split --print-config --mode narrate --session ses_x --audio-in file:/tmp/a.wav
  [ "$status" -eq 2 ]
  [[ "$(cat "$VOICE_ERR")" == *capture* ]]
}

@test "AC-044-01-10: ledger records carry the schema, contiguous seq and no clock or pid" {
  local dir="$TMPDIR_HELPER/run"
  "$NODE_BIN" --input-type=module -e '
    const { createLedger } = await import(process.argv[1]);
    const l = createLedger(process.argv[2]);
    l.record("spoken", { turn: 1, text: "Hello." });
    l.record("deferred", { turn: 1, text: "Next." });
  ' "file://$VOICE/config.mjs" "$dir"
  local ledger="$dir/ledger.jsonl"
  [ -f "$ledger" ]
  [ -d "$dir/audio" ]
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse);
    const kinds = new Set(["spoken","deferred","resumed","prompt-sent","reply-sent","refused","pending","ignored","skipped-utterance","cancelled","nothing-more"]);
    for (let i = 0; i < lines.length; i += 1) {
      const r = lines[i];
      for (const k of ["seq","kind","turn","text","rule","detail"]) {
        if (!(k in r)) throw new Error("missing key " + k);
      }
      if (r.seq !== i + 1) throw new Error("seq gap");
      if (!kinds.has(r.kind)) throw new Error("bad kind " + r.kind);
      const raw = JSON.stringify(r);
      if (/timestamp|"pid"|processId/i.test(raw)) throw new Error("clock or pid in record");
    }
  ' "$ledger"
}

# --- AC-044-02: never-list policy classifier ---------------------------------

policy_run() {
  run "$NODE_BIN" "$VOICE/policy.mjs" --intent "$1"
}

@test "AC-044-02-01: merge commands are blocked with rule merge" {
  local cmd
  for cmd in "gh pr merge 42 --squash" "git merge origin/main" "glab mr merge 7"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" blocked)" = "true" ]
    [ "$(jget "$output" rule)" = "merge" ]
  done
}

@test "AC-044-02-02: tag creation is blocked with rule tag" {
  local cmd
  for cmd in "git tag v1.2.3" "gh release create v1.2.3"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "tag" ]
  done
}

@test "AC-044-02-03: pushing to a protected branch is blocked with rule push-main" {
  local cmd
  for cmd in "git push origin main" "git push origin HEAD:master" "git push --all" "git push --mirror"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "push-main" ]
  done
  policy_run "$(mk_intent bash "git push origin spec/044-voice-console" "$REPO_ROOT")"
  [ "$(jget "$output" blocked)" = "false" ]
  [ "$(jget "$output" rule)" = "null" ]
}

@test "AC-044-02-04: force-push is blocked with rule force-push" {
  local cmd
  for cmd in "git push --force origin spec/044-voice-console" "git push -f" "git push --force-with-lease" "git push origin +spec/044-voice-console"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "force-push" ]
  done
}

@test "AC-044-02-05: branch deletion is blocked with rule delete-branch" {
  local cmd
  for cmd in "git branch -D spec/044-voice-console" "git push origin --delete spec/044-voice-console" "git push origin :spec/044-voice-console"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "delete-branch" ]
  done
}

@test "AC-044-02-06: gate-threshold edits are blocked" {
  local paths=(scripts/check-code-principles.sh config/pmd-rules.xml config/golangci-tool.yml .eslintrc.json stryker.conf.json mutation.mk pitest-profile.xml mutmut-pyproject.toml)
  local p
  for p in "${paths[@]}"; do
    policy_run "$(mk_write_intent "$p" "$REPO_ROOT")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "gate-threshold" ]
  done
}

@test "AC-044-02-07: secret creation and rotation are blocked" {
  local cmd
  for cmd in "gh secret set NPM_TOKEN" "glab variable set FOO" "security add-generic-password -a x -s y"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "secret-rotate" ]
  done
  local p
  for p in config/agent.local.env config/model.local.env .envrc; do
    policy_run "$(mk_write_intent "$p" "$REPO_ROOT")"
    [ "$(jget "$output" rule)" = "secret-rotate" ]
  done
}

@test "AC-044-02-08: writes outside the repository are blocked" {
  local repo="$TMPDIR_HELPER/repo" elsewhere="$TMPDIR_HELPER/elsewhere"
  mkdir -p "$repo" "$elsewhere"
  ln -s "$elsewhere" "$repo/link"
  policy_run "$(mk_write_intent "$elsewhere/out.txt" "$repo")"
  [ "$(jget "$output" rule)" = "write-outside-repo" ]
  policy_run "$(mk_write_intent "$repo/../elsewhere/out.txt" "$repo")"
  [ "$(jget "$output" rule)" = "write-outside-repo" ]
  policy_run "$(mk_write_intent "$repo/link/out.txt" "$repo")"
  [ "$(jget "$output" rule)" = "write-outside-repo" ]
  policy_run "$(mk_write_intent "$repo/docs/VOICE_CONSOLE.md" "$repo")"
  [ "$(jget "$output" blocked)" = "false" ]
}

@test "AC-044-02-09: git scaffolding is blocked with rule git-init" {
  local cmd
  for cmd in "git init" "git submodule add https://example.invalid/x.git vendor/x" "git submodule update --init"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "git-init" ]
  done
}

@test "AC-044-02-10: matching normalises case and whitespace" {
  local cmd
  for cmd in "  GIT   PUSH   ORIGIN   MAIN  " "Git Push Origin Main"; do
    policy_run "$(mk_intent bash "$cmd")"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" rule)" = "push-main" ]
  done
}

@test "AC-044-02-11: read-only intents need no confirmation" {
  local tool
  for tool in read grep glob; do
    policy_run "$(mk_intent "$tool" "" "$REPO_ROOT" '["/tmp/repo/docs/VOICE_CONSOLE.md"]')"
    [ "$status" -eq 0 ]
    [ "$(jget "$output" blocked)" = "false" ]
    [ "$(jget "$output" rule)" = "null" ]
    [ "$(jget "$output" requiresConfirmation)" = "false" ]
  done
}

@test "AC-044-02-12: unclassified intents require confirmation" {
  policy_run "$(mk_intent webfetch "" "$REPO_ROOT" '[]')"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" blocked)" = "false" ]
  [ "$(jget "$output" rule)" = "null" ]
  [ "$(jget "$output" requiresConfirmation)" = "true" ]
}

@test "AC-044-02-13: classification is pure and the module imports no fs or network" {
  ! grep -qE 'from "node:(fs|net|http|https)"|require\("node:(fs|net|http|https)"\)' "$VOICE/policy.mjs"
  ! grep -q 'fetch(' "$VOICE/policy.mjs"
  local before after
  before="$(git -C "$REPO_ROOT" status --porcelain)"
  policy_run '{"tool":"bash","command":"git push origin main"}'
  [ "$status" -eq 0 ]
  [ "$(jget "$output" blocked)" = "true" ]
  [ "$(jget "$output" rule)" = "push-main" ]
  after="$(git -C "$REPO_ROOT" status --porcelain)"
  [ "$before" = "$after" ]
}

# --- AC-044-03: enforcement at the outbound boundary -------------------------

@test "AC-044-03-01: a blocked action is never sent" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"git push origin main","paths":[],"repoRoot":"/tmp/repo"}}' > "$events"
  start_server "$events" "$record"
  voice_split --mode control --session ses_parent --tts-engine silent \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 4 ]
  [ ! -s "$record" ]
  grep -q '"kind":"refused"' "$TMPDIR_HELPER/run/ledger.jsonl"
  grep -q '"rule":"push-main"' "$TMPDIR_HELPER/run/ledger.jsonl"
  [[ "$(cat "$VOICE_ERR")" == *"refused: push-main"* ]]
}

@test "AC-044-03-02: no flag overrides a never-list refusal" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"git push origin main","paths":[],"repoRoot":"/tmp/repo"}}' > "$events"
  printf 'y\n' > "$TMPDIR_HELPER/script"
  start_server "$events" "$record"
  voice_split --mode control --session ses_parent --tts-engine silent \
    --input-script "$TMPDIR_HELPER/script" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 4 ]
  [ ! -s "$record" ]
  [[ "$(cat "$VOICE_ERR")" == *"refused: push-main"* ]]
  voice_split --print-config --yes
  [ "$status" -eq 2 ]
  [ ! -s "$VOICE_OUT" ]
}

@test "AC-044-03-03: one reply path, and the guard runs first" {
  [ "$(grep -rl 'sendReply' "$VOICE"/*.mjs | sort | tr '\n' ' ')" = "$VOICE/control.mjs $VOICE/opencode-client.mjs " ]
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const lines = fs.readFileSync(process.argv[1], "utf8").split("\n");
    for (let i = 0; i < lines.length; i += 1) {
      if (!lines[i].includes("sendReply(")) continue;
      let j = i - 1;
      while (j >= 0 && lines[j].trim() === "") j -= 1;
      if (j < 0 || !lines[j].includes("authorize(")) throw new Error("sendReply without a preceding guard.authorize at line " + (i + 1));
    }
  ' "$VOICE/control.mjs"
}

@test "AC-044-03-04: mutating tools need terminal confirmation" {
  run "$NODE_BIN" --input-type=module -e '
    const { authorize } = await import(process.argv[1]);
    const r = authorize({ tool: "bash", command: "rm -rf build", paths: [], repoRoot: "/tmp/repo" });
    console.log(JSON.stringify(r));
  ' "file://$VOICE/guard.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" blocked)" = "false" ]
  [ "$(jget "$output" requiresConfirmation)" = "true" ]

  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"rm -rf build","paths":[],"repoRoot":"/tmp/repo"}}' > "$events"
  printf 'n\n' > "$TMPDIR_HELPER/script"
  start_server "$events" "$record"
  voice_split --mode control --session ses_parent --tts-engine silent \
    --input-script "$TMPDIR_HELPER/script" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"kind":"refused"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-03-05: read-only tools may be answered by voice" {
  run "$NODE_BIN" --input-type=module -e '
    const { authorize } = await import(process.argv[1]);
    const r = authorize({ tool: "read", command: null, paths: [], repoRoot: "/tmp/repo" });
    console.log(JSON.stringify(r));
  ' "file://$VOICE/guard.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" requiresConfirmation)" = "false" ]

  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"read","command":null,"paths":[],"repoRoot":"/tmp/repo"}}' > "$events"
  printf 'yes\n' > "$TMPDIR_HELPER/script"
  start_server "$events" "$record"
  voice_split --mode control --session ses_parent --tts-engine silent \
    --input-script "$TMPDIR_HELPER/script" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  grep -q '"/permission/p1/reply"' "$record"
}

@test "AC-044-03-06: a policy refusal is a distinguishable exit" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"git push origin main","paths":[],"repoRoot":"/tmp/repo"}}' > "$events"
  start_server "$events" "$record"
  voice_split --mode control --session ses_parent --tts-engine silent \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 4 ]
  [[ "$(cat "$VOICE_ERR")" == *"refused: push-main"* ]]
}

# --- AC-044-04: Pocket TTS worker -------------------------------------------

worker_run() {
  run "$PYTHON_BIN" "$VOICE/tts-worker.py" "$@"
}

@test "AC-044-04-01: self-check works without optional packages" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  worker_run --self-check
  [ "$status" -eq 0 ]
  [ "$(jget "$output" pocket_tts)" = "false" ]
  [ "$(jget "$output" torch)" = "false" ]
  [ "$(jget "$output" sample_rate)" = "24000" ]
  [ -n "$(jget "$output" python)" ]
}

@test "AC-044-04-02: silent engine writes a valid WAV" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local out="$TMPDIR_HELPER/u1.wav"
  run bash -c 'printf "%s\n" "$1" | "$2" "$3" --engine silent --sample-rate 24000' _ \
    "{\"id\":\"u1\",\"text\":\"Hello there.\",\"out\":\"$out\"}" "$PYTHON_BIN" "$VOICE/tts-worker.py"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const b = fs.readFileSync(process.argv[1]);
    if (b.toString("ascii",0,4) !== "RIFF" || b.toString("ascii",8,12) !== "WAVE") throw new Error("not WAV");
    if (b.readUInt16LE(22) !== 1) throw new Error("channels");
    if (b.readUInt16LE(34) !== 16) throw new Error("bits");
    if (b.readUInt32LE(24) !== 24000) throw new Error("rate");
    if (b.readUInt32LE(40) === 0) throw new Error("no frames");
  ' "$out"
}

@test "AC-044-04-03: event order is start, chunk, done and the worker stays alive" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local out="$TMPDIR_HELPER/u1.wav"
  run bash -c 'printf "%s\n%s\n" "$1" "$2" | "$3" "$4" --engine silent' _ \
    "{\"id\":\"u1\",\"text\":\"Hello there.\",\"out\":\"$out\"}" \
    "{\"id\":\"u2\",\"text\":\"Second.\",\"out\":\"$TMPDIR_HELPER/u2.wav\"}" \
    "$PYTHON_BIN" "$VOICE/tts-worker.py"
  [ "$status" -eq 0 ]
  "$NODE_BIN" -e '
    const lines = process.argv[1].trim().split("\n").map(JSON.parse);
    for (const id of ["u1", "u2"]) {
      const own = lines.filter((e) => e.id === id);
      if (own.length < 3) throw new Error("too few events for " + id);
      if (own[0].event !== "start") throw new Error("start not first for " + id);
      if (!own.some((e) => e.event === "chunk")) throw new Error("no chunk for " + id);
      if (own[own.length - 1].event !== "done") throw new Error("done not last for " + id);
      if (own[own.length - 1].cancelled !== false) throw new Error("cancelled flag for " + id);
    }
  ' "$output"
}

@test "AC-044-04-04: a bad request does not kill the worker" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local out="$TMPDIR_HELPER/u2.wav"
  run bash -c 'printf "%s\n%s\n" "$1" "$2" | "$3" "$4" --engine silent' _ \
    '{"id":"u1","text":"","out":"/tmp/unused.wav"}' \
    "{\"id\":\"u2\",\"text\":\"Okay.\",\"out\":\"$out\"}" \
    "$PYTHON_BIN" "$VOICE/tts-worker.py"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"code": "bad-request"'* ]]
  [[ "$output" == *'"id": "u2", "event": "done"'* ]]
}

@test "AC-044-04-05: a cancel request stops the utterance" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local fifo="$TMPDIR_HELPER/in" out="$TMPDIR_HELPER/out" text
  text="$(printf 'x%.0s' $(seq 1 2000))"
  mkfifo "$fifo"
  "$PYTHON_BIN" "$VOICE/tts-worker.py" --engine silent > "$out" 2> "$TMPDIR_HELPER/err" < "$fifo" &
  local pid=$!
  exec 8> "$fifo"
  printf '{"id":"u1","text":"%s","out":"%s"}\n' "$text" "$TMPDIR_HELPER/u1.wav" >&8
  local i
  for i in $(seq 1 300); do
    if grep -q '"event": "start"' "$out"; then break; fi
    sleep 0.01
  done
  grep -q '"event": "start"' "$out"
  printf '%s\n' '{"event":"cancel","id":"u1"}' >&8
  for i in $(seq 1 200); do
    if grep -q '"cancelled": true' "$out"; then break; fi
    sleep 0.01
  done
  grep -q '"cancelled": true' "$out"
  local done_line after
  done_line="$(grep -n '"event": "done"' "$out" | head -1 | cut -d: -f1)"
  sleep 0.2
  after="$(tail -n "+$((done_line + 1))" "$out" | grep '"event": "chunk"' | wc -l)"
  [ "$after" -eq 0 ]
  exec 8>&-
  wait "$pid"
  [ "$?" -eq 0 ]
}

@test "AC-044-04-06: SIGINT cancels and exits cleanly" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local fifo="$TMPDIR_HELPER/in" out="$TMPDIR_HELPER/out" text
  text="$(printf 'x%.0s' $(seq 1 2000))"
  mkfifo "$fifo"
  "$PYTHON_BIN" "$VOICE/tts-worker.py" --engine silent > "$out" 2> "$TMPDIR_HELPER/err" < "$fifo" &
  local pid=$!
  exec 8> "$fifo"
  printf '{"id":"u1","text":"%s","out":"%s"}\n' "$text" "$TMPDIR_HELPER/u1.wav" >&8
  local i
  for i in $(seq 1 300); do
    if grep -q '"event": "start"' "$out"; then break; fi
    sleep 0.01
  done
  kill -INT "$pid"
  local rc=0
  for i in $(seq 1 200); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.01
  done
  wait "$pid"
  rc=$?
  exec 8>&-
  [ "$rc" -eq 0 ]
  grep -q '"cancelled": true' "$out"
}

@test "AC-044-04-07: a missing Pocket TTS runtime exits 3" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  run bash -c 'printf "%s\n" "$1" | "$2" "$3" --engine pocket-tts' _ \
    "{\"id\":\"u1\",\"text\":\"Hello.\",\"out\":\"$TMPDIR_HELPER/u1.wav\"}" \
    "$PYTHON_BIN" "$VOICE/tts-worker.py"
  [ "$status" -eq 3 ]
  [[ "$output" == *'"code": "missing-runtime"'* ]]
}

@test "AC-044-04-08: duration arithmetic is exact" {
  if [ -z "$PYTHON_BIN" ]; then skip "python3 not installed"; fi
  local out="$TMPDIR_HELPER/u1.wav"
  run bash -c 'printf "%s\n" "$1" | "$2" "$3" --engine silent --sample-rate 24000' _ \
    "{\"id\":\"u1\",\"text\":\"Hello there.\",\"out\":\"$out\"}" "$PYTHON_BIN" "$VOICE/tts-worker.py"
  [ "$status" -eq 0 ]
  local duration
  duration="$(printf '%s\n' "$output" | grep '"event": "done"' | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{console.log(JSON.parse(s).durationMs)})')"
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const b = fs.readFileSync(process.argv[1]);
    const frames = b.readUInt32LE(40) / 2;
    const expected = frames * 1000 / 24000;
    const actual = Number(process.argv[2]);
    if (Math.abs(actual - expected) > 1) throw new Error("duration drift");
  ' "$out" "$duration"
}

@test "AC-044-04-09: the worker is file-only" {
  run grep -nE 'sounddevice|pyaudio|subprocess' "$VOICE/tts-worker.py"
  [ "$status" -eq 1 ]
  run grep -c 'wave.open(path' "$VOICE/tts-worker.py"
  [ "$output" -eq 1 ]
}

# --- AC-044-05: sentence chunking and the speech budget ----------------------

@test "AC-044-05-01: split on terminators and retain them" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const s = m.splitSentences("Hello there. Next one! Really? Yes.");
    console.log(JSON.stringify(s));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "4" ]
  [ "$(jget "$output" "0")" = "Hello there." ]
  [ "$(jget "$output" "3")" = "Yes." ]
}

@test "AC-044-05-02: decimals are not boundaries" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    console.log(JSON.stringify(m.splitSentences("Pi is 3.14 exactly.")));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "1" ]
}

@test "AC-044-05-03: abbreviations are not boundaries" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    console.log(JSON.stringify(m.splitSentences("Use e.g. this form. Then stop.")));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "2" ]
  [[ "$(jget "$output" "0")" == *"e.g. this form."* ]]
}

@test "AC-044-05-04: question and exclamation boundaries need no capital" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    console.log(JSON.stringify(m.splitSentences("Ready? go! done.")));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "3" ]
}

@test "AC-044-05-05: the sentence cap wins" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const s = Array.from({ length: 5 }, () => "one two three four five.");
    console.log(JSON.stringify(m.takeWindow(s, { maxSentences: 3, maxSeconds: 45, wordsPerSecond: 2.5 })));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "spoken.length")" = "3" ]
  [ "$(jget "$output" "deferred.length")" = "2" ]
}

@test "AC-044-05-06: the time cap wins when reached first" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const words = Array(80).fill("word").join(" ");
    const s = Array.from({ length: 4 }, () => words + ".");
    console.log(JSON.stringify(m.takeWindow(s, { maxSentences: 3, maxSeconds: 45, wordsPerSecond: 2.5 })));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "spoken.length")" = "1" ]
  [ "$(jget "$output" "deferred.length")" = "3" ]
  "$NODE_BIN" -e 'if (Number(process.argv[1]) > 45) throw new Error("over budget");' "$(jget "$output" estimatedSeconds)"
}

@test "AC-044-05-07: the first sentence is always spoken whole" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sentence = Array(200).fill("word").join(" ") + ".";
    console.log(JSON.stringify(m.takeWindow([sentence], { maxSentences: 3, maxSeconds: 45, wordsPerSecond: 2.5 })));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "spoken.length")" = "1" ]
  [ "$(jget "$output" "spoken.0")" = "$(printf 'word %.0s' $(seq 1 199))word." ]
}

@test "AC-044-05-08: deferred windows drain to empty" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    let pending = Array.from({ length: 5 }, (_, i) => "sentence " + i + ".");
    const windows = [];
    while (pending.length > 0) {
      const w = m.takeWindow(pending, { maxSentences: 3, maxSeconds: 45, wordsPerSecond: 2.5 });
      windows.push(w.spoken.length);
      pending = w.deferred;
    }
    const last = m.takeWindow(pending, { maxSentences: 3, maxSeconds: 45, wordsPerSecond: 2.5 });
    console.log(JSON.stringify({ windows, spoken: last.spoken.length, deferred: last.deferred.length }));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "spoken")" = "0" ]
  [ "$(jget "$output" "deferred")" = "0" ]
  [ "$(jget "$output" "windows.0")" = "3" ]
  [ "$(jget "$output" "windows.1")" = "2" ]
}

@test "AC-044-05-09: streaming emits each sentence exactly once" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const c = m.createChunker();
    const out = [];
    out.push(...c.feed("Hello"));
    out.push(...c.feed("Hello world. Se"));
    out.push(...c.feed("Hello world. Second."));
    const rest = c.finish();
    console.log(JSON.stringify({ out, rest }));
  ' "file://$VOICE/chunk.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "out.0")" = "Hello world." ]
  [ "$(jget "$output" "out.1")" = "Second." ]
  [ "$(jget "$output" "out.length")" = "2" ]
  [ "$(jget "$output" "rest")" = "" ]
}

# --- AC-044-06: opencode client and parent-only filter -----------------------

@test "AC-044-06-01: parent assistant text is spoken" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const f = m.createPartFilter({ session: "ses_parent" });
    f.accept({ event: "message.updated", messageID: "m1", role: "assistant", sessionID: "ses_parent" });
    const r = f.accept({ event: "part.updated", part: { id: "p1", type: "text", sessionID: "ses_parent", messageID: "m1", text: "Hello" } });
    console.log(JSON.stringify(r));
  ' "file://$VOICE/opencode-client.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" delta)" = "Hello" ]
}

@test "AC-044-06-02: subtask chatter is suppressed" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const f = m.createPartFilter({ session: "ses_parent" });
    f.accept({ event: "message.updated", messageID: "m1", role: "assistant", sessionID: "ses_parent" });
    const base = { id: "p1", type: "text", sessionID: "ses_parent", messageID: "m1", text: "hidden" };
    const results = [
      f.accept({ event: "part.updated", part: { ...base, type: "subtask" } }),
      f.accept({ event: "part.updated", part: { ...base, synthetic: true } }),
      f.accept({ event: "part.updated", part: { ...base, parentID: "ses_other" } }),
    ];
    console.log(JSON.stringify(results));
  ' "file://$VOICE/opencode-client.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "3" ]
  [ "$(jget "$output" "0")" = "null" ]
  [ "$(jget "$output" "1")" = "null" ]
  [ "$(jget "$output" "2")" = "null" ]
}

@test "AC-044-06-03: foreign sessions and user parts are suppressed" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const f = m.createPartFilter({ session: "ses_parent" });
    const a = f.accept({ event: "part.updated", part: { id: "p1", type: "text", sessionID: "ses_other", messageID: "m1", text: "x" } });
    f.accept({ event: "message.updated", messageID: "m1", role: "user", sessionID: "ses_parent" });
    const b = f.accept({ event: "part.updated", part: { id: "p2", type: "text", sessionID: "ses_parent", messageID: "m1", text: "x" } });
    const c = f.accept({ event: "part.updated", part: { id: "p3", type: "tool", sessionID: "ses_parent", messageID: "m1" } });
    console.log(JSON.stringify([a, b, c]));
  ' "file://$VOICE/opencode-client.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "0")" = "null" ]
  [ "$(jget "$output" "1")" = "null" ]
  [ "$(jget "$output" "2")" = "null" ]
}

@test "AC-044-06-04: growing parts yield only the delta" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const f = m.createPartFilter({ session: "ses_parent" });
    f.accept({ event: "message.updated", messageID: "m1", role: "assistant", sessionID: "ses_parent" });
    const a = f.accept({ event: "part.updated", part: { id: "p1", type: "text", sessionID: "ses_parent", messageID: "m1", text: "Hello" } });
    const b = f.accept({ event: "part.updated", part: { id: "p1", type: "text", sessionID: "ses_parent", messageID: "m1", text: "Hello world" } });
    console.log(JSON.stringify([a.delta, b.delta]));
  ' "file://$VOICE/opencode-client.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "0")" = "Hello" ]
  [ "$(jget "$output" "1")" = " world" ]
}

@test "AC-044-06-05: one request per prompt with the verbatim text" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const c = m.createClient({ baseUrl: process.argv[2] });
    await c.sendPrompt("ses_parent", "what stage is 044 at?");
    c.close();
  ' "file://$VOICE/opencode-client.mjs" "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  [ "$(jget "$(head -1 "$record")" "body.parts.length")" = "1" ]
  [ "$(jget "$(head -1 "$record")" "body.parts.0.text")" = "what stage is 044 at?" ]
}

@test "AC-044-06-06: one request per reply on the documented path" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const c = m.createClient({ baseUrl: process.argv[2] });
    await c.sendReply("question", "q1", { label: "Approve" });
    await c.sendReply("permission", "p1", { reply: "once" });
    c.close();
  ' "file://$VOICE/opencode-client.mjs" "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 2 ]
  [ "$(jget "$(sed -n 1p "$record")" path)" = "/question/q1/reply" ]
  [ "$(jget "$(sed -n 2p "$record")" path)" = "/permission/p1/reply" ]
}

@test "AC-044-06-07: upstream failure is bounded and loud" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record" --fail prompt=500
  run bash -c '"$1" --input-type=module -e "$2" "$3" "$4" 2>"$5"' _ \
    "$NODE_BIN" '
    const m = await import(process.argv[1]);
    const c = m.createClient({ baseUrl: process.argv[2] });
    try {
      await c.sendPrompt("ses_parent", "hello");
      process.exit(0);
    } catch (error) {
      console.error(error.message);
      process.exit(5);
    }
  ' "file://$VOICE/opencode-client.mjs" "http://127.0.0.1:$SERVER_PORT" "$TMPDIR_HELPER/client.err"
  [ "$status" -eq 5 ]
  [ "$(wc -l < "$record")" -eq 2 ]
  [[ "$(cat "$TMPDIR_HELPER/client.err")" == *"500"* ]]
  [[ "$(cat "$TMPDIR_HELPER/client.err")" == *"/message"* ]]
}

@test "AC-044-06-08: stream reconnect is bounded" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  printf '%s\n' '{"close":true}' > "$events"
  start_server "$events" "$record"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const c = m.createClient({ baseUrl: process.argv[2] });
    const started = Date.now();
    try {
      await c.connect(() => {});
      process.exit(0);
    } catch (error) {
      console.log(Date.now() - started);
      process.exit(5);
    }
  ' "file://$VOICE/opencode-client.mjs" "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 5 ]
  [ "$output" -ge 1000 ]
}

@test "AC-044-06-09: dry run sends nothing" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const c = m.createClient({ baseUrl: process.argv[2], dryRun: true });
    await c.sendPrompt("ses_parent", "hello");
    await c.sendReply("permission", "p1", { reply: "once" });
    c.close();
  ' "file://$VOICE/opencode-client.mjs" "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
  [ ! -s "$record" ]
}

@test "AC-044-06-10: the fake server prints LISTENING, records, and exits 0 on SIGTERM" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  [[ "$(cat "$TMPDIR_HELPER/server.out")" == "LISTENING $SERVER_PORT" ]]
  run "$NODE_BIN" --input-type=module -e '
    await fetch(process.argv[1] + "/session", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ agent: "voice-concierge" }) });
    await fetch(process.argv[1] + "/permission/p1/reply", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ reply: "once" }) });
  ' "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 2 ]
  kill -TERM "$SERVER_PID"
  wait "$SERVER_PID"
  local rc=$?
  unset SERVER_PID
  [ "$rc" -eq 0 ]
}

# --- AC-044-07: capture and voice-activity endpointing -----------------------

make_wav() {
  local out="$1" kind="$2"
  "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const out = process.argv[2];
    const kind = process.argv[3];
    const fs = await import("node:fs");
    const parts = kind === "two"
      ? [m.toneMs(500), m.silenceMs(900), m.toneMs(500), m.silenceMs(900)]
      : kind === "silence-tone"
        ? [m.silenceMs(1000), m.toneMs(500), m.silenceMs(2000)]
        : [m.toneMs(100), m.silenceMs(900)];
    fs.writeFileSync(out, m.wav({ sampleRate: 16000, samples: m.concatSamples(parts) }));
  ' "file://$TESTS/voice-fixtures.mjs" "$out" "$kind"
}

endpoint_run() {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const fixtures = await import(process.argv[2]);
    const kind = process.argv[3];
    const opts = JSON.parse(process.argv[4]);
    const parts = kind === "two"
      ? [fixtures.toneMs(500), fixtures.silenceMs(900), fixtures.toneMs(500), fixtures.silenceMs(900)]
      : kind === "silence-tone"
        ? [fixtures.silenceMs(1000), fixtures.toneMs(500), fixtures.silenceMs(2000)]
        : [fixtures.toneMs(100), fixtures.silenceMs(900)];
    const samples = fixtures.concatSamples(parts);
    const utterances = m.endpointSamples(samples, opts);
    console.log(JSON.stringify(utterances.map((u) => u.length)));
  ' "file://$VOICE/audio-in.mjs" "file://$TESTS/voice-fixtures.mjs" "$1" "$2"
}

@test "AC-044-07-01: two tones produce exactly two utterances" {
  endpoint_run two '{"sampleRate":16000}'
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "2" ]
  [ "$(jget "$output" "0")" -ge 7840 ]
  [ "$(jget "$output" "0")" -le 8160 ]
}

@test "AC-044-07-02: leading and trailing silence produce no extra utterance" {
  endpoint_run silence-tone '{"sampleRate":16000}'
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "1" ]
}

@test "AC-044-07-03: a short blip is dropped" {
  endpoint_run blip '{"sampleRate":16000,"minUtteranceMs":300}'
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "0" ]
}

@test "AC-044-07-04: long speech is force-split" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const f = await import(process.argv[2]);
    const utterances = m.endpointSamples(f.toneMs(3500), { sampleRate: 16000, maxUtteranceMs: 1000 });
    console.log(JSON.stringify(utterances.map((u) => u.length)));
  ' "file://$VOICE/audio-in.mjs" "file://$TESTS/voice-fixtures.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "4" ]
  local i len
  for i in 0 1 2 3; do
    len="$(jget "$output" "$i")"
    [ "$len" -ge 4800 ]
  done
}

@test "AC-044-07-05: device mode spawns arecord and reuses the endpointing path" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const fs = await import("node:fs");
    fs.writeFileSync(process.argv[2], m.wav({ sampleRate: 16000, samples: m.concatSamples([m.toneMs(500), m.silenceMs(900)]) }).subarray(44));
  ' "file://$TESTS/voice-fixtures.mjs" "$TMPDIR_HELPER/raw.pcm"
  cat > "$bin/arecord" <<SH
#!/bin/sh
printf '%s\n' "\$@" > "$TMPDIR_HELPER/arecord.args"
cat "$TMPDIR_HELPER/raw.pcm"
SH
  chmod +x "$bin/arecord"
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const lengths = [];
    await m.capture("device", {}, (u) => lengths.push(u.length));
    console.log(JSON.stringify(lengths));
  ' "file://$VOICE/audio-in.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "1" ]
  grep -q -- "-f" "$TMPDIR_HELPER/arecord.args"
  grep -q "S16_LE" "$TMPDIR_HELPER/arecord.args"
  grep -q -- "-r" "$TMPDIR_HELPER/arecord.args"
  grep -q "16000" "$TMPDIR_HELPER/arecord.args"
  grep -q -- "-c" "$TMPDIR_HELPER/arecord.args"
  grep -q -- "-t" "$TMPDIR_HELPER/arecord.args"
  grep -q "raw" "$TMPDIR_HELPER/arecord.args"
}

@test "AC-044-07-06: missing arecord is a dependency exit with no ledger" {
  mkdir -p "$TMPDIR_HELPER/emptybin"
  : > "$TMPDIR_HELPER/transcript.txt"
  VOICE_OUT="$TMPDIR_HELPER/out"; VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; PATH=$1; shift; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$TMPDIR_HELPER/emptybin" \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --mode converse --audio-in device \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 3 ]
  [[ "$(cat "$VOICE_ERR")" == *arecord* ]]
  [ ! -e "$TMPDIR_HELPER/run/ledger.jsonl" ]
}

@test "AC-044-07-07: file mode spawns nothing" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/arecord" <<SH
#!/bin/sh
touch "$TMPDIR_HELPER/arecord.called"
exit 99
SH
  chmod +x "$bin/arecord"
  make_wav "$TMPDIR_HELPER/two.wav" two
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const lengths = [];
    m.captureFile(process.argv[2], {}, (u) => lengths.push(u.length));
    console.log(JSON.stringify(lengths));
  ' "file://$VOICE/audio-in.mjs" "$TMPDIR_HELPER/two.wav"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "length")" = "2" ]
  [ ! -e "$TMPDIR_HELPER/arecord.called" ]
}

@test "AC-044-07-08: fixtures are deterministic" {
  local a="$TMPDIR_HELPER/a.wav" b="$TMPDIR_HELPER/b.wav"
  make_wav "$a" two
  make_wav "$b" two
  cmp "$a" "$b"
}

# --- AC-044-08: local speech recognition -------------------------------------

@test "AC-044-08-01: engine precedence" {
  run "$NODE_BIN" --input-type=module -e '
    const c = await import(process.argv[1]);
    console.log(c.ASR_DEFAULT_ENGINE);
  ' "file://$VOICE/config.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == "faster-whisper" || "$output" == "sherpa-onnx" ]]
  voice_run --print-config
  [ "$status" -eq 0 ]
  [ "$(jget "$output" asr.engine)" = "$output" ] || true
  local default_engine
  default_engine="$(jget "$output" asr.engine)"
  run env VOICE_ASR_ENGINE=faster-whisper "$NODE_BIN" "$VOICE/voice-console.mjs" --print-config
  [ "$(jget "$output" asr.engine)" = "faster-whisper" ]
  run env VOICE_ASR_ENGINE=faster-whisper "$NODE_BIN" "$VOICE/voice-console.mjs" --print-config --asr-engine sherpa-onnx
  [ "$(jget "$output" asr.engine)" = "sherpa-onnx" ]
  [ "$default_engine" = "faster-whisper" ]
}

@test "AC-044-08-02: an unknown engine is a usage error" {
  voice_split --print-config --asr-engine whisper-cpp
  [ "$status" -eq 2 ]
  [[ "$(cat "$VOICE_ERR")" == *faster-whisper* ]]
  [[ "$(cat "$VOICE_ERR")" == *sherpa-onnx* ]]
}

@test "AC-044-08-03: file transcripts map by index" {
  printf 'first line\nsecond line\n' > "$TMPDIR_HELPER/transcript.txt"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const a = m.createFileAsr(process.argv[2]);
    console.log(JSON.stringify([a.transcriptFor(0), a.transcriptFor(1)]));
  ' "file://$VOICE/asr.mjs" "$TMPDIR_HELPER/transcript.txt"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "0")" = "first line" ]
  [ "$(jget "$output" "1")" = "second line" ]
}

@test "AC-044-08-04: missing transcript lines are skipped" {
  printf 'only one\n' > "$TMPDIR_HELPER/transcript.txt"
  make_wav "$TMPDIR_HELPER/two.wav" two
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  printf '%s\n' '{"event":"message.updated","messageID":"m__TURN__","role":"assistant","sessionID":"ses_parent"}' '{"event":"part.updated","part":{"id":"p__TURN__","type":"text","sessionID":"ses_parent","messageID":"m__TURN__","text":"Still running."}}' '{"event":"idle"}' > "$replies"
  start_server "$events" "$record" --reply-events "$replies"
  voice_split --mode converse --session ses_parent --audio-in "file:$TMPDIR_HELPER/two.wav" \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --tts-engine silent \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  grep -q '"kind":"skipped-utterance"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-08-05: blank transcripts produce no prompt" {
  printf '   \n' > "$TMPDIR_HELPER/transcript.txt"
  make_wav "$TMPDIR_HELPER/two.wav" two
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  voice_split --mode converse --session ses_parent --audio-in "file:$TMPDIR_HELPER/two.wav" \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --tts-engine silent \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  run grep '"kind":"prompt-sent"' "$TMPDIR_HELPER/run/ledger.jsonl"
  [ "$status" -eq 1 ]
}

@test "AC-044-08-06: no cloud path exists" {
  run grep -nE 'http://|https://' "$VOICE/asr.mjs"
  [ "$status" -eq 1 ]
  run grep -nE 'spawn\([^)]*bl' "$VOICE/asr.mjs"
  [ "$status" -eq 1 ]
  voice_run --print-config
  [ "$(jget "$output" modelCache)" = ".cache/voice/models" ]
}

@test "AC-044-08-07: a missing engine runtime exits 3 before reading audio" {
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl"
  : > "$events"
  start_server "$events" "$record"
  voice_split --mode converse --session ses_parent --audio-in "file:$TMPDIR_HELPER/never.wav" \
    --asr-engine faster-whisper --tts-engine silent \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 3 ]
  [[ "$(cat "$VOICE_ERR")" == *missing-runtime* ]]
  [[ "$(cat "$VOICE_ERR")" == *faster-whisper* ]]
  [ ! -s "$record" ]
}

@test "AC-044-08-08: documentation matches the single source of truth" {
  local default_engine
  run "$NODE_BIN" --input-type=module -e '
    const c = await import(process.argv[1]);
    console.log(c.ASR_DEFAULT_ENGINE);
  ' "file://$VOICE/config.mjs"
  default_engine="$output"
  grep -q "$default_engine" "$REPO_ROOT/docs/VOICE_CONSOLE.md"
  local other="faster-whisper"
  if [ "$default_engine" = "faster-whisper" ]; then other="sherpa-onnx"; fi
  grep -q "$other" "$REPO_ROOT/docs/VOICE_CONSOLE.md"
}

# --- AC-044-09: playback and cancellation -----------------------------------

@test "AC-044-09-01: the file sink numbers sequentially" {
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createFileSink(process.argv[2]);
    await sink.write(m.silentWav("one"));
    await sink.write(m.silentWav("two"));
    await sink.write(m.silentWav("three"));
  ' "file://$VOICE/audio-out.mjs" "$TMPDIR_HELPER/audio"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_HELPER/audio/0001.wav" ]
  [ -f "$TMPDIR_HELPER/audio/0002.wav" ]
  [ -f "$TMPDIR_HELPER/audio/0003.wav" ]
  run "$NODE_BIN" -e 'const b=require("node:fs").readFileSync(process.argv[1]); if(b.toString("ascii",0,4)!=="RIFF") process.exit(1);' "$TMPDIR_HELPER/audio/0001.wav"
  [ "$status" -eq 0 ]
}

@test "AC-044-09-02: existing files are never overwritten" {
  local dir="$TMPDIR_HELPER/audio"
  mkdir -p "$dir"
  printf 'sentinel\n' > "$dir/0001.wav"
  run "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createFileSink(process.argv[2]);
    await sink.write(m.silentWav("one"));
  ' "file://$VOICE/audio-out.mjs" "$dir"
  [ "$status" -eq 0 ]
  [ "$(cat "$dir/0001.wav")" = "sentinel" ]
  [ -f "$dir/0002.wav" ]
}

@test "AC-044-09-03: file mode spawns no child process" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/ffplay" <<SH
#!/bin/sh
touch "$TMPDIR_HELPER/ffplay.called"
exit 99
SH
  chmod +x "$bin/ffplay"
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createFileSink(process.argv[2]);
    const result = await sink.write(m.silentWav("one"));
    console.log(JSON.stringify(result));
  ' "file://$VOICE/audio-out.mjs" "$TMPDIR_HELPER/audio"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_HELPER/audio/0001.wav" ]
  [ ! -e "$TMPDIR_HELPER/ffplay.called" ]
}

@test "AC-044-09-04: device mode plays through ffplay" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/ffplay" <<SH
#!/bin/sh
case "\$*" in
  *-nodisp*) printf '%s\n' "\$@" > "$TMPDIR_HELPER/ffplay.args" ;;
esac
exit 0
SH
  chmod +x "$bin/ffplay"
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createDeviceSink();
    await sink.write(m.silentWav("one"));
  ' "file://$VOICE/audio-out.mjs"
  [ "$status" -eq 0 ]
  grep -q -- "-nodisp" "$TMPDIR_HELPER/ffplay.args"
  grep -q -- "-autoexit" "$TMPDIR_HELPER/ffplay.args"
  grep -q -- "-loglevel" "$TMPDIR_HELPER/ffplay.args"
  grep -q "quiet" "$TMPDIR_HELPER/ffplay.args"
}

@test "AC-044-09-05: missing ffplay is a dependency exit" {
  mkdir -p "$TMPDIR_HELPER/emptybin"
  printf '%s\n' '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"Hello."}}' '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  VOICE_OUT="$TMPDIR_HELPER/out"; VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; PATH=$1; shift; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$TMPDIR_HELPER/emptybin" \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --tts-engine silent --audio-out device \
    --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 3 ]
  [[ "$(cat "$VOICE_ERR")" == *ffplay* ]]
}

@test "AC-044-09-06: cancellation stops playback promptly" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/ffplay" <<'SH'
#!/bin/sh
case "$*" in *-version*) exit 0 ;; esac
trap '' TERM
sleep 5
SH
  chmod +x "$bin/ffplay"
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createDeviceSink();
    sink.write(m.silentWav("one"));
    await new Promise((r) => setTimeout(r, 50));
    const started = Date.now();
    const result = await sink.cancel();
    console.log(JSON.stringify({ result, elapsed: Date.now() - started }));
  ' "file://$VOICE/audio-out.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" "result.cancelled")" = "true" ]
  [ "$(jget "$output" "elapsed")" -lt 2000 ]
}

@test "AC-044-09-07: a new utterance supersedes the old one" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/ffplay" <<'SH'
#!/bin/sh
case "$*" in *-version*) exit 0 ;; esac
sleep 2
SH
  chmod +x "$bin/ffplay"
  run env PATH="$bin:$PATH" "$NODE_BIN" --input-type=module -e '
    const m = await import(process.argv[1]);
    const sink = m.createDeviceSink();
    const first = sink.write(m.silentWav("one"));
    await new Promise((r) => setTimeout(r, 50));
    sink.write(m.silentWav("two"));
    const result = await first;
    await sink.cancel();
    console.log(JSON.stringify(result));
  ' "file://$VOICE/audio-out.mjs"
  [ "$status" -eq 0 ]
  [ "$(jget "$output" cancelled)" = "superseded" ]
}

# --- AC-044-10: narrate mode ------------------------------------------------

write_narrate_events() {
  local path="$1"
  cat > "$path" <<'JSONL'
{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}
{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"One. Two. Three. Four. Five."}}
{"event":"part.updated","part":{"id":"sub1","type":"subtask","sessionID":"ses_parent","messageID":"m1","text":"SECRET SUBTASK PARAGRAPH."}}
{"event":"idle"}
JSONL
}

@test "AC-044-10-01: narrate never captures and never transcribes" {
  local bin="$TMPDIR_HELPER/bin"
  mkdir -p "$bin"
  cat > "$bin/arecord" <<SH
#!/bin/sh
touch "$TMPDIR_HELPER/arecord.called"
exit 99
SH
  chmod +x "$bin/arecord"
  printf '%s\n' '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"Hello."}}' \
    '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  run env PATH="$bin:$PATH" "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" \
    --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR_HELPER/arecord.called" ]
  run grep -E '"kind":"(prompt-sent|skipped-utterance)"' "$TMPDIR_HELPER/run/ledger.jsonl"
  [ "$status" -eq 1 ]
}

@test "AC-044-10-02: budget and parent-only filtering end to end" {
  write_narrate_events "$TMPDIR_HELPER/events.jsonl"
  voice_run --mode narrate --session ses_parent --events "$TMPDIR_HELPER/events.jsonl" \
    --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 0 ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 3 ]
  [ "$(grep -c '"kind":"deferred"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]
  [ "$(ls "$TMPDIR_HELPER/audio" | tr '\n' ' ')" = "0001.wav 0002.wav 0003.wav " ]
  run grep -q 'SECRET' "$TMPDIR_HELPER/run/ledger.jsonl"
  [ "$status" -eq 1 ]
  run grep -vc '"turn":1' "$TMPDIR_HELPER/run/ledger.jsonl"
  [ "$output" -eq 0 ]
  "$NODE_BIN" -e '
    const lines = require("node:fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse);
    lines.forEach((r, i) => { if (r.seq !== i + 1) throw new Error("seq gap"); });
  ' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-10-03: the operator can ask for the rest" {
  write_narrate_events "$TMPDIR_HELPER/events.jsonl"
  printf 'm\n' > "$TMPDIR_HELPER/script"
  voice_run --mode narrate --session ses_parent --events "$TMPDIR_HELPER/events.jsonl" \
    --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    --input-script "$TMPDIR_HELPER/script"
  [ "$status" -eq 0 ]
  grep -q '"kind":"resumed"' "$TMPDIR_HELPER/run/ledger.jsonl"
  [ "$(ls "$TMPDIR_HELPER/audio" | wc -l)" -eq 5 ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 5 ]
}

@test "AC-044-10-04: requesting more after exhaustion is recorded" {
  write_narrate_events "$TMPDIR_HELPER/events.jsonl"
  printf 'm\nm\n' > "$TMPDIR_HELPER/script"
  voice_run --mode narrate --session ses_parent --events "$TMPDIR_HELPER/events.jsonl" \
    --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    --input-script "$TMPDIR_HELPER/script"
  [ "$status" -eq 0 ]
  [ "$(grep -c '"kind":"nothing-more"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]
  [ "$(ls "$TMPDIR_HELPER/audio" | wc -l)" -eq 5 ]
}

@test "AC-044-10-05: stop cancels the current utterance and the process continues" {
  printf '%s\n' \
    '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"First."}}' \
    '{"event":"idle"}' \
    '{"event":"message.updated","messageID":"m2","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p2","type":"text","sessionID":"ses_parent","messageID":"m2","text":"Second."}}' \
    '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  printf 'stop\n' > "$TMPDIR_HELPER/script"
  voice_run --mode narrate --session ses_parent --events "$TMPDIR_HELPER/events.jsonl" \
    --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    --input-script "$TMPDIR_HELPER/script"
  [ "$status" -eq 0 ]
  [ "$(grep -c '"kind":"cancelled"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 2 ]
}

@test "AC-044-10-06: SIGINT exits cleanly, twice forces exit" {
  printf '%s\n' \
    '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"Hello."}}' \
    '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --pace-ms 2000 --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    > "$TMPDIR_HELPER/out" 2>&1 &
  local pid=$!
  sleep 0.3
  kill -INT "$pid"
  local rc=0 i
  for i in $(seq 1 200); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.01
  done
  rc=0
  wait "$pid" || rc=$?
  [ "$rc" -eq 0 ]
  [ "$(grep -c '"kind":"cancelled"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]

  rm -rf "$TMPDIR_HELPER/run" "$TMPDIR_HELPER/audio"
  "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --pace-ms 2000 --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    > "$TMPDIR_HELPER/out" 2>&1 &
  pid=$!
  sleep 0.3
  kill -INT "$pid"
  sleep 0.01
  kill -INT "$pid"
  for i in $(seq 1 200); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.01
  done
  rc=0
  wait "$pid" || rc=$?
  [ "$rc" -eq 130 ]
}

@test "AC-044-10-07: non-interactive stdin never blocks" {
  printf '%s\n' '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"Hello."}}' \
    '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  run timeout 5 "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" < /dev/null
  [ "$status" -eq 0 ]
}

# --- AC-044-11: converse mode -----------------------------------------------

write_reply_events() {
  local path="$1" text="$2"
  printf '%s\n' \
    '{"event":"message.updated","messageID":"m__TURN__","role":"assistant","sessionID":"ses_parent"}' \
    "{\"event\":\"part.updated\",\"part\":{\"id\":\"p__TURN__\",\"type\":\"text\",\"sessionID\":\"ses_parent\",\"messageID\":\"m__TURN__\",\"text\":\"$text\"}}" \
    '{"event":"idle"}' > "$path"
}

converse_run() {
  voice_split --mode converse --session ses_parent --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" "$@"
}

@test "AC-044-11-01: two utterances become two prompts and two replies" {
  make_wav "$TMPDIR_HELPER/two.wav" two
  printf 'first question\nsecond question\n' > "$TMPDIR_HELPER/transcript.txt"
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  write_reply_events "$replies" "Still running."
  start_server "$events" "$record" --reply-events "$replies"
  converse_run --audio-in "file:$TMPDIR_HELPER/two.wav" --asr "file:$TMPDIR_HELPER/transcript.txt" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 2 ]
  [ "$(jget "$(sed -n 1p "$record")" "body.parts.0.text")" = "first question" ]
  [ "$(jget "$(sed -n 2p "$record")" "body.parts.0.text")" = "second question" ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 2 ]
  grep -q 'Still running.' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-11-02: turns increment and stay contiguous" {
  make_wav "$TMPDIR_HELPER/two.wav" two
  printf 'first question\nsecond question\n' > "$TMPDIR_HELPER/transcript.txt"
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  write_reply_events "$replies" "Still running."
  start_server "$events" "$record" --reply-events "$replies"
  converse_run --audio-in "file:$TMPDIR_HELPER/two.wav" --asr "file:$TMPDIR_HELPER/transcript.txt" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  "$NODE_BIN" -e '
    const rows = require("node:fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse);
    const turns = rows.filter((r) => r.kind === "prompt-sent" || r.kind === "spoken").map((r) => r.turn);
    if (turns.join(",") !== "1,1,2,2") throw new Error("turn order " + turns.join(","));
    for (let i = 1; i < rows.length; i += 1) if (rows[i].seq !== rows[i-1].seq + 1) throw new Error("seq gap");
  ' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-11-03: an empty transcript sends nothing" {
  make_wav "$TMPDIR_HELPER/two.wav" two
  printf '   \nsecond question\n' > "$TMPDIR_HELPER/transcript.txt"
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  write_reply_events "$replies" "Still running."
  start_server "$events" "$record" --reply-events "$replies"
  converse_run --audio-in "file:$TMPDIR_HELPER/two.wav" --asr "file:$TMPDIR_HELPER/transcript.txt" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  [ "$(grep -c '"kind":"skipped-utterance"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]
}

@test "AC-044-11-04: the reply budget applies and more resumes it" {
  make_wav "$TMPDIR_HELPER/two.wav" two
  printf 'one question\n' > "$TMPDIR_HELPER/transcript.txt"
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  write_reply_events "$replies" "One. Two. Three. Four."
  start_server "$events" "$record" --reply-events "$replies"
  printf 'm\n' > "$TMPDIR_HELPER/script"
  converse_run --audio-in "file:$TMPDIR_HELPER/two.wav" --asr "file:$TMPDIR_HELPER/transcript.txt" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT" --input-script "$TMPDIR_HELPER/script"
  [ "$status" -eq 0 ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -ge 4 ]
  [ "$(grep -c '"kind":"deferred"' "$TMPDIR_HELPER/run/ledger.jsonl")" -eq 1 ]
}

@test "AC-044-11-05: a missing session is created with the concierge agent" {
  make_wav "$TMPDIR_HELPER/two.wav" two
  printf 'hello\n' > "$TMPDIR_HELPER/transcript.txt"
  local events="$TMPDIR_HELPER/events.jsonl" record="$TMPDIR_HELPER/record.jsonl" replies="$TMPDIR_HELPER/replies.jsonl"
  : > "$events"
  write_reply_events "$replies" "Still running."
  start_server "$events" "$record" --reply-events "$replies"
  voice_split --mode converse --tts-engine silent --audio-out "file:$TMPDIR_HELPER/audio" \
    --artifacts "$TMPDIR_HELPER/run" --audio-in "file:$TMPDIR_HELPER/two.wav" \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(jget "$(sed -n 1p "$record")" "body.agent")" = "voice-concierge" ]
  "$NODE_BIN" -e '
    const rows = require("node:fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse);
    const first = rows.find((r) => r.kind === "prompt-sent");
    if (first.detail !== "ses_created") throw new Error("detail " + first.detail);
  ' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-11-06: device capture without a device fails loudly" {
  mkdir -p "$TMPDIR_HELPER/emptybin"
  : > "$TMPDIR_HELPER/transcript.txt"
  VOICE_OUT="$TMPDIR_HELPER/out"; VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; PATH=$1; shift; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$TMPDIR_HELPER/emptybin" \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --mode converse --audio-in device \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --audio-out "file:$TMPDIR_HELPER/audio" \
    --tts-engine silent --artifacts "$TMPDIR_HELPER/run"
  [ "$status" -eq 3 ]
  [[ "$(cat "$VOICE_ERR")" == *arecord* ]]
}

# --- AC-044-12: gated control ------------------------------------------------

control_run() {
  voice_split --mode control --session ses_parent --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" "$@"
}

write_question_events() {
  local path="$1" options="$2" header="$3"
  printf '{"event":"question.asked","sessionID":"ses_parent","id":"q1","header":"%s","options":%s}\n' \
    "$header" "$options" > "$path"
}

@test "AC-044-12-01: control is opt-in" {
  printf '%s\n' '{"event":"question.asked","sessionID":"ses_parent","id":"q1","header":"Choose","options":[{"label":"Approve"}]}' > "$TMPDIR_HELPER/events.jsonl"
  local record="$TMPDIR_HELPER/record.jsonl"
  : > "$record"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  voice_split --mode narrate --session ses_parent --tts-engine silent \
    --audio-out "file:$TMPDIR_HELPER/audio" --artifacts "$TMPDIR_HELPER/run" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"kind":"ignored"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-02: questions surface numbered options" {
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[{"label":"Approve"},{"label":"Reject"},{"label":"Later"}]' "Choose one"
  printf '1\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  grep -q '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl"
  grep -q 'Choose one' "$TMPDIR_HELPER/run/ledger.jsonl"
  grep -q '1. Approve' "$TMPDIR_HELPER/run/ledger.jsonl"
  grep -q '3. Later' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-03: answers by number or label" {
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[{"label":"Approve"},{"label":"Reject"},{"label":"Later"}]' "Choose"
  printf '2\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(jget "$(head -1 "$record")" "body.label")" = "Reject" ]

  rm -rf "$TMPDIR_HELPER/run" "$TMPDIR_HELPER/audio"
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[{"label":"Approve"},{"label":"Reject"}]' "Choose"
  printf 'approve\n' > "$TMPDIR_HELPER/script"
  : > "$record"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(jget "$(head -1 "$record")" "body.label")" = "Approve" ]
}

@test "AC-044-12-04: unmatched answers re-prompt once and then stay pending" {
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[{"label":"Approve"},{"label":"Reject"}]' "Choose"
  printf 'banana\nbanana\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  [ "$(grep -c '"kind":"spoken"' "$TMPDIR_HELPER/run/ledger.jsonl")" -ge 2 ]
  grep -q '"kind":"pending"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-05: free-text questions send the transcript verbatim" {
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[]' "What stage"
  printf 'stage four\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(jget "$(head -1 "$record")" "body.text")" = "stage four" ]
}

@test "AC-044-12-06: read-only permissions are answerable by voice" {
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"read","command":null,"paths":[],"repoRoot":"/tmp/repo"}}' > "$TMPDIR_HELPER/events.jsonl"
  printf 'yes\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  [ "$(jget "$(head -1 "$record")" "body.reply")" = "once" ]
}

@test "AC-044-12-07: mutating permissions wait for the terminal" {
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"rm -rf build","paths":[],"repoRoot":"/tmp/repo"}}' > "$TMPDIR_HELPER/events.jsonl"
  printf 'y\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  [ "$(jget "$(head -1 "$record")" "body.reply")" = "once" ]
  grep -q 'rm -rf build' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-08: declined or abandoned confirmations send nothing" {
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"rm -rf build","paths":[],"repoRoot":"/tmp/repo"}}' > "$TMPDIR_HELPER/events.jsonl"
  printf 'n\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"rule":"not-confirmed"' "$TMPDIR_HELPER/run/ledger.jsonl"

  rm -rf "$TMPDIR_HELPER/run" "$TMPDIR_HELPER/audio"
  : > "$TMPDIR_HELPER/script"
  : > "$record"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"kind":"pending"' "$TMPDIR_HELPER/run/ledger.jsonl"

  rm -rf "$TMPDIR_HELPER/run" "$TMPDIR_HELPER/audio"
  : > "$record"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --confirm-timeout 0.01 --input-script "$TMPDIR_HELPER/script" \
    --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"kind":"pending"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-09: blocked permissions are refused and not overridable" {
  printf '%s\n' '{"event":"permission.asked","sessionID":"ses_parent","id":"p1","intent":{"tool":"bash","command":"git push origin main","paths":[],"repoRoot":"/tmp/repo"}}' > "$TMPDIR_HELPER/events.jsonl"
  printf 'y\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 4 ]
  [ ! -s "$record" ]
  grep -q '"rule":"push-main"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

@test "AC-044-12-10: slash prompts need terminal confirmation" {
  write_question_events "$TMPDIR_HELPER/events.jsonl" '[]' "Command"
  printf '/build 044-voice-console\ny\n' > "$TMPDIR_HELPER/script"
  local record="$TMPDIR_HELPER/record.jsonl"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$record")" -eq 1 ]
  [ "$(jget "$(head -1 "$record")" "body.parts.0.text")" = "/build 044-voice-console" ]

  rm -rf "$TMPDIR_HELPER/run" "$TMPDIR_HELPER/audio"
  printf '/build 044-voice-console\nn\n' > "$TMPDIR_HELPER/script"
  : > "$record"
  start_server "$TMPDIR_HELPER/events.jsonl" "$record"
  control_run --input-script "$TMPDIR_HELPER/script" --opencode-url "http://127.0.0.1:$SERVER_PORT"
  [ "$status" -eq 0 ]
  [ ! -s "$record" ]
  grep -q '"rule":"not-confirmed"' "$TMPDIR_HELPER/run/ledger.jsonl"
}

# --- AC-044-13: read-only concierge agent -----------------------------------

@test "AC-044-13-01: the agent lives outside the default agent set" {
  [ -f "$REPO_ROOT/agents-optional/voice-concierge.md" ]
  [ ! -f "$REPO_ROOT/agents/voice-concierge.md" ]
}

@test "AC-044-13-02: frontmatter shape" {
  run grep -c '^description: ' "$REPO_ROOT/agents-optional/voice-concierge.md"
  [ "$output" -eq 1 ]
  run grep -c '^mode: primary$' "$REPO_ROOT/agents-optional/voice-concierge.md"
  [ "$output" -eq 1 ]
}

@test "AC-044-13-03: no pinned model" {
  run grep -c '^model:' "$REPO_ROOT/agents-optional/voice-concierge.md"
  [ "$output" -eq 0 ]
}

@test "AC-044-13-04: read-only permissions are structural" {
  local file="$REPO_ROOT/agents-optional/voice-concierge.md"
  run awk '/^  read:/{r=1} /^  edit:/{e=1} /^  bash:/{b=1} /^  task:/{t=1} r&&/^    "\*": allow/{ra=1} e&&/^    "\*": deny/{ed=1} b&&/^    "\*": deny/{bd=1} t&&/^    "\*": deny/{td=1} END{exit !(ra&&ed&&bd&&td)}' "$file"
  [ "$status" -eq 0 ]
}

@test "AC-044-13-05: the prompt states its limits" {
  local file="$REPO_ROOT/agents-optional/voice-concierge.md"
  grep -qi 'at most three sentences' "$file"
  grep -qi 'never perform or claim to perform a mutation' "$file"
  grep -qi 'read-only' "$file"
}

@test "AC-044-13-06: the governance row is present and T0" {
  local gov="$REPO_ROOT/docs/GOVERNANCE.md"
  grep -q '^| `voice-concierge` |' "$gov"
  run grep '^| `voice-concierge` |' "$gov"
  [[ "$output" == *'**T0**'* ]]
  [[ "$output" == *'edit `*` deny'* ]]
  [[ "$output" == *'bash `*` deny'* ]]
  [[ "$output" == *'task `*` deny'* ]]
  run bash -c 'grep -E "^\| \`[a-z-]+\` \|" "$1" | grep -F "**T3**"' _ "$gov"
  [ "$status" -eq 1 ]
  run "$REPO_ROOT/scripts/check-governance.sh"
  [ "$status" -eq 0 ]
}

@test "AC-044-13-07: the model-pin gate is not weakened" {
  run grep -oE 'SCAN_DIRS=.*|for dir in .*agents.*' "$REPO_ROOT/scripts/check-agent-models.sh"
  [ "$status" -eq 0 ]
  grep -q 'agents' "$REPO_ROOT/scripts/check-agent-models.sh"
  grep -q '.opencode/agents' "$REPO_ROOT/scripts/check-agent-models.sh"
  run node "$VOICE/smoke.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] agent voice-concierge.md"* ]]
}

# --- AC-044-14: installer, make targets, structural smoke -------------------

@test "AC-044-14-01: install writes the complete tree" {
  local cfg="$TMPDIR_HELPER/cfg"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs"
  [ "$status" -eq 0 ]
  [ -f "$cfg/agents/voice-concierge.md" ]
  local f
  for f in "$VOICE"/*.mjs "$VOICE/tts-worker.py"; do
    [ -f "$cfg/voice/$(basename "$f")" ]
  done
}

@test "AC-044-14-02: re-running is idempotent" {
  local cfg="$TMPDIR_HELPER/cfg"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs"
  [ "$status" -eq 0 ]
  find "$cfg" -type f -printf '%P\n' | sort > "$TMPDIR_HELPER/first.txt"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs"
  [ "$status" -eq 0 ]
  find "$cfg" -type f -printf '%P\n' | sort > "$TMPDIR_HELPER/second.txt"
  cmp "$TMPDIR_HELPER/first.txt" "$TMPDIR_HELPER/second.txt"
}

@test "AC-044-14-03: uninstall removes exactly what was installed" {
  local cfg="$TMPDIR_HELPER/cfg"
  mkdir -p "$cfg"
  printf 'keep\n' > "$cfg/sentinel.txt"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs"
  [ "$status" -eq 0 ]
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$cfg/agents/voice-concierge.md" ]
  [ ! -d "$cfg/voice" ]
  [ -f "$cfg/sentinel.txt" ]
}

@test "AC-044-14-04: dry run writes nothing" {
  local cfg="$TMPDIR_HELPER/never-cfg"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"$cfg/agents/voice-concierge.md"* ]]
  [[ "$output" == *"$cfg/voice/config.mjs"* ]]
  [ ! -e "$cfg" ]
}

@test "AC-044-14-05: a missing source aborts without partial copies" {
  local copy="$TMPDIR_HELPER/repo-copy"
  local cfg="$TMPDIR_HELPER/cfg"
  mkdir -p "$copy/scripts" "$copy/agents-optional"
  cp -R "$VOICE" "$copy/scripts/voice"
  run env OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$copy/scripts/voice/install.mjs"
  [ "$status" -eq 3 ]
  [[ "$output" == *"agents-optional/voice-concierge.md"* ]]
  [ ! -d "$cfg/voice" ]
}

@test "AC-044-14-06: no writes outside the config directory" {
  local home="$TMPDIR_HELPER/home" cfg="$TMPDIR_HELPER/outside-cfg"
  mkdir -p "$home"
  run env HOME="$home" OPENCODE_CONFIG_DIR="$cfg" "$NODE_BIN" "$VOICE/install.mjs"
  [ "$status" -eq 0 ]
  [ "$(find "$home" -type f | wc -l)" -eq 0 ]
  [ "$(find "$cfg" -type f | wc -l)" -gt 0 ]
}

@test "AC-044-14-07: make targets exist" {
  run make -n -C "$REPO_ROOT" install-voice
  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts/voice/"* ]]
  run make -n -C "$REPO_ROOT" uninstall-voice
  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts/voice/"* ]]
  run make -n -C "$REPO_ROOT" smoke-voice
  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts/voice/"* ]]
  grep -q '^\.PHONY:.*install-voice.*uninstall-voice.*smoke-voice' "$REPO_ROOT/Makefile"
  run make -C "$REPO_ROOT" help
  [[ "$output" == *install-voice* ]]
  [[ "$output" == *uninstall-voice* ]]
  [[ "$output" == *smoke-voice* ]]
}

@test "AC-044-14-08: smoke output is checkable" {
  run node "$VOICE/smoke.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] agent voice-concierge.md"* ]]
  [[ "$output" == *"[OK] policy refuses"* ]]
  [[ "$output" == *"[OK] install dry-run"* ]]
  [[ "$output" == *"[OK] print-config"* ]]
  local f
  for f in "$VOICE"/*.mjs; do
    [[ "$output" == *"[OK] $(basename "$f") parses"* ]]
  done
}

@test "AC-044-14-09: smoke is offline and Python-optional" {
  run grep -nE 'node:http|node:https|fetch\(' "$VOICE/smoke.mjs"
  [ "$status" -eq 1 ]
  mkdir -p "$TMPDIR_HELPER/emptybin"
  run env PATH="$TMPDIR_HELPER/emptybin" "$NODE_BIN" "$VOICE/smoke.mjs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] tts-worker.py"* ]]
}

# --- AC-044-15: bats acceptance suite ---------------------------------------

@test "AC-044-15-01: every scenario is cited exactly once" {
  grep -rhoE '^## (AC-044-[0-9]{2}-[0-9]{2})' "$REPO_ROOT/specs/044-voice-console/20-acceptance" \
    | sed -E 's/^## //' | sort > "$TMPDIR_HELPER/spec-ids.txt"
  grep -oE '^@test "AC-044-[0-9]{2}-[0-9]{2}:' "$REPO_ROOT/scripts/tests/voice-console.bats" \
    | sed -E 's/^@test "//; s/:$//' | sort > "$TMPDIR_HELPER/test-ids.txt"
  cmp "$TMPDIR_HELPER/spec-ids.txt" "$TMPDIR_HELPER/test-ids.txt"
  [ -z "$(uniq -d "$TMPDIR_HELPER/test-ids.txt")" ]
}

@test "AC-044-15-02: traceability passes" {
  run "$REPO_ROOT/scripts/check-scenario-traceability.sh"
  [ "$status" -eq 0 ]
}

@test "AC-044-15-03: no vacuous assertions" {
  run "$REPO_ROOT/scripts/check-bats-assertions.sh"
  [ "$status" -eq 0 ]
}

@test "AC-044-15-04: the suite runs without the optional runtime" {
  mkdir -p "$TMPDIR_HELPER/emptybin"
  : > "$TMPDIR_HELPER/transcript.txt"
  VOICE_OUT="$TMPDIR_HELPER/out"; VOICE_ERR="$TMPDIR_HELPER/err"
  run bash -c 'out=$1; err=$2; shift 2; PATH=$1; shift; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$TMPDIR_HELPER/emptybin" \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --mode converse --audio-in device \
    --asr "file:$TMPDIR_HELPER/transcript.txt" --audio-out "file:$TMPDIR_HELPER/audio" \
    --tts-engine silent --artifacts "$TMPDIR_HELPER/run1"
  [ "$status" -eq 3 ]
  printf '%s\n' '{"event":"message.updated","messageID":"m1","role":"assistant","sessionID":"ses_parent"}' \
    '{"event":"part.updated","part":{"id":"p1","type":"text","sessionID":"ses_parent","messageID":"m1","text":"Hello."}}' \
    '{"event":"idle"}' > "$TMPDIR_HELPER/events.jsonl"
  run bash -c 'out=$1; err=$2; shift 2; PATH=$1; shift; "$@" >"$out" 2>"$err"' _ \
    "$VOICE_OUT" "$VOICE_ERR" "$TMPDIR_HELPER/emptybin" \
    "$NODE_BIN" "$VOICE/voice-console.mjs" --mode narrate --session ses_parent \
    --events "$TMPDIR_HELPER/events.jsonl" --tts-engine silent --audio-out device \
    --artifacts "$TMPDIR_HELPER/run2"
  [ "$status" -eq 3 ]
  run bash -c 'grep -c "^[[:space:]]*skip " "$1"' _ "$REPO_ROOT/scripts/tests/voice-console.bats"
  run bash -c 'grep "^[[:space:]]*skip " "$1" | grep -vc "python3 not installed" || true' _ "$REPO_ROOT/scripts/tests/voice-console.bats"
  [ "$output" -eq 0 ]
}

@test "AC-044-15-05: the suite is hermetic" {
  run bash -c 'grep -oE "https?://[A-Za-z0-9][^\" ]*" "$1" | grep -v "127.0.0.1" | grep -v "example.invalid" || true' _ "$REPO_ROOT/scripts/tests/voice-console.bats"
  [ -z "$output" ]
}

@test "AC-044-15-06: temp fixtures come from the shared helper" {
  grep -q '^load test_helper$' "$REPO_ROOT/scripts/tests/voice-console.bats"
  grep -q '^setup() {' "$REPO_ROOT/scripts/tests/voice-console.bats"
  grep -q 'setup_tmpdir' "$REPO_ROOT/scripts/tests/voice-console.bats"
  grep -q 'teardown_tmpdir' "$REPO_ROOT/scripts/tests/voice-console.bats"
}

# --- AC-044-16: operator documentation, ADR, weight guard -------------------

@test "AC-044-16-01: required sections exist" {
  local doc="$REPO_ROOT/docs/VOICE_CONSOLE.md"
  local heading
  for heading in "## Modes" "## Install" "## Headless file modes" "## Configuration" "## Exit codes" "## Never-list" "## Speech budget" "## Speech recognition" "## Licensing and weights" "## API mapping" "## Troubleshooting"; do
    grep -qxF "$heading" "$doc"
  done
}

@test "AC-044-16-02: the document does not overclaim duplex" {
  local doc="$REPO_ROOT/docs/VOICE_CONSOLE.md"
  grep -qi 'half-duplex' "$doc"
  run grep -ni 'full-duplex' "$doc"
  [ "$status" -eq 0 ]
  local line
  while IFS= read -r line; do
    [[ "${line,,}" == *"not supported"* || "${line,,}" == *"out of scope"* ]]
  done <<< "$output"
}

@test "AC-044-16-03: privacy and fallback are stated" {
  local doc="$REPO_ROOT/docs/VOICE_CONSOLE.md"
  grep -q 'never leaves the machine' "$doc"
  grep -q 'Local recognition is the default' "$doc"
  grep -q 'Bailian' "$doc"
  grep -q 'URL or long audio' "$doc"
  grep -q 'sk-' "$doc"
}

@test "AC-044-16-04: licensing and weights are stated" {
  local section
  section="$(md_section "$REPO_ROOT/docs/VOICE_CONSOLE.md" "## Licensing and weights")"
  [[ "$section" == *"not redistributed"* ]]
  [[ "$section" == *"Hugging Face"* ]]
  [[ "$section" == *"voice cloning"* ]]
}

@test "AC-044-16-05: never-list and exit codes match the code" {
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const text = fs.readFileSync(process.argv[1], "utf8");
    const section = text.split("## Never-list")[1].split("## ")[0];
    const ids = [...section.matchAll(/`([a-z-]+)`/g)].map((m) => m[1]);
    const want = ["merge","tag","push-main","force-push","delete-branch","gate-threshold","secret-rotate","write-outside-repo","git-init"];
    if (ids.slice(0, 9).join(",") !== want.join(",")) throw new Error("never-list order " + ids.slice(0, 9).join(","));
    const exits = text.split("## Exit codes")[1].split("## ")[0];
    for (const code of ["0","2","3","4","5"]) {
      if (!new RegExp("\\| `" + code + "` \\|").test(exits)) throw new Error("missing exit " + code);
    }
  ' "$REPO_ROOT/docs/VOICE_CONSOLE.md"
}

@test "AC-044-16-06: configuration matches print-config" {
  local doc="$REPO_ROOT/docs/VOICE_CONSOLE.md"
  local name
  for name in VOICE_MODE VOICE_OPENCODE_URL VOICE_SESSION VOICE_ASR_ENGINE VOICE_ARTIFACTS_DIR; do
    grep -q "$name" "$doc"
  done
  voice_run --print-config
  [ "$status" -eq 0 ]
  grep -q 'http://127.0.0.1:4096' "$doc"
  [ "$(jget "$output" modelCache)" = ".cache/voice/models" ]
  grep -q '.cache/voice/models' "$doc"
  [ "$(jget "$output" mode)" = "narrate" ]
}

@test "AC-044-16-07: the ADR is recorded" {
  local adr="$REPO_ROOT/docs/adr/0026-voice-console.md"
  grep -q '^Accepted$' "$adr"
  grep -q '^## Context$' "$adr"
  grep -q '^## Decision$' "$adr"
  grep -q '^## Consequences$' "$adr"
  grep -q 'docs/adr/0007-media-agent-family.md' "$adr"
  grep -q 'docs/adr/0011-agent-model-agnostic-gate.md' "$adr"
  grep -q '0026' "$REPO_ROOT/docs/adr/README.md"
}

@test "AC-044-16-08: repo gates stay green and no weights are tracked" {
  grep -q 'docs/VOICE_CONSOLE.md' "$REPO_ROOT/Makefile"
  run make -C "$REPO_ROOT" validate
  [ "$status" -eq 0 ]
  run bash -c 'cd "$1" && git ls-files | grep -E "\.(onnx|safetensors|pt|ckpt|npz|bin)$"' _ "$REPO_ROOT"
  [ "$status" -eq 1 ]
  grep -q '^\.cache/' "$REPO_ROOT/.gitignore"
  run "$REPO_ROOT/scripts/check-orchestration.sh"
  [ "$status" -eq 0 ]
}
