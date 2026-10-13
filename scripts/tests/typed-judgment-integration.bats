#!/usr/bin/env bats
# typed-judgment-integration.bats — acceptance tests for spec 028 tasks 2–7:
# config entries (AC-028-21…25), ci-triage wiring (AC-028-26…31), spec-ux
# wiring (AC-028-32…39), ADR 0004 (AC-028-40…42), docs updates (AC-028-43…44),
# OKF docs (AC-028-45…48), and the Bats-test conventions themselves
# (AC-028-49…56). These are content contracts over tracked files: skill and
# agent behavior is prompt-defined, so the tests assert the prompt files
# carry the required directives; file/config/doc ACs are asserted directly.

load test_helper
bats_require_minimum_version 1.5.0

SKILL="$REPO_ROOT/skills/ci-triage/SKILL.md"
AGENT="$REPO_ROOT/agents/spec-ux.md"
SCRIPT="$REPO_ROOT/scripts/typed-judgment.sh"
BATS_SCRIPTS="$REPO_ROOT/scripts/tests/typed-judgment.bats"
MODEL_EX="$REPO_ROOT/config/model.local.env.example"
AGENT_EX="$REPO_ROOT/config/agent.local.env.example"
ADR="$REPO_ROOT/docs/adr/0004-typed-judgment-layer.md"
ADR_README="$REPO_ROOT/docs/adr/README.md"
PIPE="$REPO_ROOT/docs/SPEC_PIPELINE.md"
LOOP="$REPO_ROOT/docs/LOOP_ENGINEERING.md"
OKF_DOC="$REPO_ROOT/okf/when-to-use-typesafe.md"

# grep_file <file> <pattern...> — every pattern must appear in the file
grep_file() {
  local file="$1"; shift
  local pat
  for pat in "$@"; do
    grep -qE -- "$pat" "$file" || { echo "missing pattern: $pat (in $file)" >&2; return 1; }
  done
}

# bats_names_tests <AC-ID...> — every ID must appear as a test name in
# typed-judgment.bats (the convention checks AC-028-49…55 share this shape).
bats_names_tests() {
  local id
  for id in "$@"; do
    grep -q "$id" "$BATS_SCRIPTS" || { echo "missing test id: $id" >&2; return 1; }
  done
}

# md_tracked_excluding <regex...> — tracked .md files outside okf/, config/,
# specs/, docs/changes/ (spec artifacts are pre-existing requirement sources,
# not outputs of this change; docs/changes/ holds the archived one-pagers —
# same content as specs/ in its post-archive lifecycle state, per
# docs/SPEC_PIPELINE.md's treatment of both as ID sources excluded from
# reference scans). Echoes matching paths.
md_tracked_excluding() {
  git -C "$REPO_ROOT" ls-files -z '*.md' \
    | grep -zv '^(okf|config|specs|docs/changes)/' --perl-regexp \
    | xargs -0 grep -lE "$@" 2>/dev/null || true
}

# ── Task 2: config entries ────────────────────────────────────────────────────

@test "AC-028-21: model.local.env.example has commented typed-judgment entries incl. 0.6 default" {
  grep_file "$MODEL_EX" \
    '^[[:space:]]*#.*JUDGMENT_API_URL' \
    '^[[:space:]]*#.*JUDGMENT_MODEL' \
    '^[[:space:]]*#.*JUDGMENT_MIN_CONFIDENCE' \
    '^[[:space:]]*#.*JUDGMENT_MIN_CONFIDENCE.*0\.6' \
    '^[[:space:]]*#.*JUDGMENT_DAILY_CAP'
}

@test "AC-028-22: agent.local.env.example has a commented JUDGMENT_API_KEY entry" {
  grep_file "$AGENT_EX" '^[[:space:]]*#.*JUDGMENT_API_KEY'
}

@test "AC-028-23: every JUDGMENT_* line in both examples is commented out" {
  ! grep -qE '^[[:space:]]*JUDGMENT[A-Z0-9_]*=' "$MODEL_EX"
  ! grep -qE '^[[:space:]]*JUDGMENT[A-Z0-9_]*=' "$AGENT_EX"
}

@test "AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/" {
  matches=$(md_tracked_excluding 'https?://[^[:space:])"]*judgment' 'JUDGMENT_API_URL=.*://')
  [ -z "$matches" ]
}

@test "AC-028-25: check-model-env.sh still passes with the new config entries" {
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$REPO_ROOT"
  assert_exit_code 0 "$status"
}

# ── Task 3: ci-triage skill integration ───────────────────────────────────────

@test "AC-028-26: ci-triage exit-0 path sets class from typed answer and records fallback-false fields" {
  grep_file "$SKILL" \
    'exit 0' \
    '"fallback":false' \
    '"judgment_fallback":false' \
    'confidence' \
    'latency_ms' \
    'tokens' \
    'class'
}

@test "AC-028-27: ci-triage exit-10 path runs the existing LLM classification unchanged with judgment_fallback true" {
  grep_file "$SKILL" \
    'exit 10' \
    'unchanged' \
    '"judgment_fallback":true'
}

@test "AC-028-28: ci-triage state JSON carries failed_log_excerpt, changed_files, prior_state_entries" {
  grep_file "$SKILL" 'failed_log_excerpt' 'changed_files' 'prior_state_entries'
}

@test "AC-028-29: ci-triage asks exactly one Choice question with the four classes and decision-guide rubrics" {
  grep_file "$SKILL" \
    '"type":"choice"' \
    '"options":\["flake","regression","infra","config"\]' \
    'rubrics'
}

@test "AC-028-30: ci-triage allowed-tools includes Bash(scripts/typed-judgment.sh:*)" {
  grep -q 'Bash(scripts/typed-judgment.sh:\*)' "$SKILL"
}

@test "AC-028-31: ci-triage fast-path is skipped entirely when credentials are absent (stock behavior unchanged)" {
  grep_file "$SKILL" 'JUDGMENT_API_KEY' 'JUDGMENT_API_URL' 'skip' 'unchanged'
}

# ── Task 4: spec-ux agent integration ─────────────────────────────────────────

@test "AC-028-32: spec-ux maps answer run to proceeding with the design skill" {
  grep_file "$AGENT" 'typed-judgment' '"run"' 'design skill'
}

@test "AC-028-33: spec-ux maps answer skip to the SKIPPED output" {
  grep_file "$AGENT" '"skip"' 'SKIPPED'
}

@test "AC-028-34: spec-ux maps answer ambiguous to BLOCKED with one LLM-formulated question" {
  grep_file "$AGENT" '"ambiguous"' 'BLOCKED'
}

@test "AC-028-35: spec-ux maps exit 10 (low confidence) to BLOCKED" {
  grep_file "$AGENT" 'exit 10' 'BLOCKED'
}

@test "AC-028-36: spec-ux maps exit 10 (any fallback reason) to BLOCKED" {
  grep_file "$AGENT" 'fallback' 'BLOCKED'
}

@test "AC-028-37: spec-ux bash permission allow-list includes scripts/typed-judgment.sh" {
  awk '/^permission:/,/^---$/' "$AGENT" | grep -q 'scripts/typed-judgment.sh'
}

@test "AC-028-38: spec-ux fast-path is skipped entirely when credentials are absent (stock behavior unchanged)" {
  grep_file "$AGENT" 'JUDGMENT_API_KEY' 'JUDGMENT_API_URL' 'unchanged'
}

@test "AC-028-39: spec-ux records per-call telemetry fields judgment answer confidence latency_ms tokens fallback" {
  grep_file "$AGENT" 'judgment' 'answer' 'confidence' 'latency_ms' 'tokens' 'fallback'
}

@test "AC-028-32b: spec-ux sends exactly one Choice question with options run skip ambiguous over the full informal+tasks content" {
  grep_file "$AGENT" \
    '"type":"choice"' \
    '"options":\["run","skip","ambiguous"\]' \
    '00-informal.md' \
    '10-tasks.md'
}

# ── Task 5: ADR 0004 ──────────────────────────────────────────────────────────

@test "AC-028-40: ADR 0004 exists and carries every templates/ADR.md section heading" {
  [ -f "$ADR" ]
  local heading
  while IFS= read -r heading; do
    grep -qF -- "$heading" "$ADR" || { echo "missing ADR section: $heading" >&2; return 1; }
  done < <(grep '^## ' "$REPO_ROOT/templates/ADR.md")
}

@test "AC-028-41: ADR 0004 records opt-in, replace-with-fallback, 0.6 threshold, daily cap, T0 tier, unchanged gate authority" {
  grep_file "$ADR" \
    'opt-in' \
    'allback' \
    '0\.6' \
    '[Dd]aily cap' \
    'T0' \
    'never overrides'
}

@test "AC-028-42: ADR README indexes 0004-typed-judgment-layer with a one-line entry" {
  grep -qE '\| 0004 \|.*0004-typed-judgment-layer\.md' "$ADR_README"
}

# ── Task 6: docs updates ──────────────────────────────────────────────────────

@test "AC-028-43: SPEC_PIPELINE.md has a Typed-judgment layer section with the exit-code contract and stock-procedure rule" {
  grep_file "$PIPE" \
    '^## Typed-judgment layer' \
    'opt-in' \
    'scripts/typed-judgment.sh' \
    'Exit-code contract' \
    '0. = usable' \
    '10. = fallback' \
    'stock procedure'
}

@test "AC-028-43b: SPEC_PIPELINE.md typed-judgment section carries no endpoint URLs or provider/model ids" {
  awk '/^## Typed-judgment layer/{f=1;next} /^## /{f=0} f' "$PIPE" | grep -qE 'https?://' && return 1
  [ 1 ]
}

@test "AC-028-44: LOOP_ENGINEERING.md notes the typed-judgment fast-path for loop-triage classification (future phase)" {
  grep_file "$LOOP" 'typed-judgment' 'loop-triage' 'future'
}

@test "AC-028-44b: LOOP_ENGINEERING.md typed-judgment note carries no endpoint URLs" {
  grep -E 'typed-judgment|typed judgment' "$LOOP" | grep -qE 'https?://' && return 1
  [ 1 ]
}

# ── Task 7: OKF docs ──────────────────────────────────────────────────────────

@test "AC-028-45: when-to-use-typesafe.md exists with decision matrix, primitives cheat-sheet, cookbook pointers, jaggedness caveat" {
  [ -f "$OKF_DOC" ]
  grep_file "$OKF_DOC" \
    'eterministic' \
    'Choice' \
    'Noul' \
    'Score' \
    'ookbook' \
    'agged'
}

@test "AC-028-46: okf/index.md links when-to-use-typesafe.md" {
  grep -q 'when-to-use-typesafe.md' "$REPO_ROOT/okf/index.md"
}

@test "AC-028-47: okf/log.md has a typed-judgment layer entry" {
  grep -qi 'typed-judgment' "$REPO_ROOT/okf/log.md"
}

@test "AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/" {
  matches=$(md_tracked_excluding 'TypeSafe')
  [ -z "$matches" ]
}

# ── Task 8: conventions of typed-judgment.bats itself ─────────────────────────

@test "AC-028-49: typed-judgment.bats exists and loads test_helper" {
  [ -f "$BATS_SCRIPTS" ]
  grep -q 'load test_helper' "$BATS_SCRIPTS"
}

@test "AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network" {
  # Scenario: Given no JUDGMENT_API_URL or JUDGMENT_API_KEY is configured in
  # the environment and no network access is available, When bats
  # scripts/tests/typed-judgment.bats is executed, Then all tests pass (exit 0).
  # `env -u` reproduces the unconfigured machine: the nested suite sees neither
  # credential (its own setup() injects the fakes). Network is made
  # unreachable for the nested run by pointing every proxy variable curl
  # honors at a dead loopback port — any accidental real HTTP request is
  # refused instantly; the suite's fake-curl stub is a bash script and
  # ignores them, so a genuinely offline suite is unaffected.
  run env -u JUDGMENT_API_URL -u JUDGMENT_API_KEY \
      http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 \
      HTTP_PROXY=http://127.0.0.1:1 HTTPS_PROXY=http://127.0.0.1:1 \
      all_proxy=http://127.0.0.1:1 ALL_PROXY=http://127.0.0.1:1 \
      bats "$BATS_SCRIPTS"
  assert_exit_code 0 "$status"
  # Non-empty green: TAP plan line present, at least one passing test, and
  # zero failing tests — an empty or all-skipped run must not read as green.
  printf '%s\n' "$output" | grep -qE '^1\.\.[0-9]+'
  [ "$(printf '%s\n' "$output" | grep -c '^ok ')" -gt 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^not ok ')" -eq 0 ]
}

@test "AC-028-51: typed-judgment.bats names tests for key-unset, url-unset exit 10" {
  bats_names_tests AC-028-02 AC-028-03
}

@test "AC-028-52: typed-judgment.bats names tests for daily cap reached and not-reached" {
  bats_names_tests AC-028-13 AC-028-14
}

@test "AC-028-53: typed-judgment.bats names tests for HTTP 401 422 429 529 and network failure" {
  bats_names_tests AC-028-05 AC-028-06 AC-028-07 AC-028-08 AC-028-10
}

@test "AC-028-54: typed-judgment.bats names tests for fixture parsing and confidence threshold both ways" {
  bats_names_tests AC-028-01 AC-028-11 AC-028-12
}

@test "AC-028-55: typed-judgment.bats names a test for dry-run mode" {
  bats_names_tests AC-028-19
}

@test "AC-028-56: typed-judgment.bats injects the fake curl stub and never targets a real host" {
  grep -q 'BIN/curl' "$BATS_SCRIPTS"
  # only the non-routable .invalid TLD may appear as a host
  ! grep -E 'https?://' "$BATS_SCRIPTS" | grep -vE 'judgment\.invalid' | grep -q .
}
