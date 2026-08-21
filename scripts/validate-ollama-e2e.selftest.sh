#!/bin/bash
# validate-ollama-e2e.selftest.sh — Hermetic regression net for
# scripts/validate-ollama-e2e.sh. No live model: the opencode invocation and the
# log file are mocked (the script reads the log via a --log path, so the test
# points it at a temp log). opencode is shimmed on PATH.
#
# Scenario traceability: every AC-003-xx ID below is the test for the matching
# 20-acceptance scenario in specs/001-ollama-context/20-acceptance/AC-003-e2e-validation.md:
#   AC-003-01  a real stage runs on the local model (opencode run --agent spec-specifier
#              with SPEC_SPECIFIER_MODEL=ollama/qwen3.8:27b exported), exit 0
#   AC-003-02  no "no user query found" (modelID=qwen3.8:27b) in the run's log slice
#   AC-003-03  thread retained: turn-2 answer contains the turn-1 marker
#   AC-003-04  decision line emitted to stdout and --out; every of 8 stages in exactly one list
#   AC-003-05  a failing stage is recorded in CLOUD_FALLBACK_STAGES, absent from LOCAL_STAGES
#   AC-003-06  tooling failure (opencode unavailable / log unreadable) -> exit 2
#
# Usage:
#   bash scripts/validate-ollama-e2e.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/scripts/validate-ollama-e2e.sh"

PASS_COUNT=0
FAIL_COUNT=0
ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── Mock opencode ────────────────────────────────────────────────────────────
# Behavior knobs (env):
#   FAKE_OPENCODE_RC       exit code for every opencode invocation (default 0)
#   FAKE_DROP_MARKER=1     turn-2 answer omits the marker  -> AC-003-03 fail
#   FAKE_NO_OPENCODE=1     no opencode on PATH            -> AC-003-06 exit 2
mkdir -p "$TMP/fakebin"
FAKE_BIN="$TMP/fakebin"
export FAKE_MARKER_STATE="$TMP/marker.state"
cat > "$FAKE_BIN/opencode" <<'FAKEOC'
#!/bin/bash
if [ "${FAKE_OPENCODE_RC:-0}" -ne 0 ]; then exit "${FAKE_OPENCODE_RC}"; fi
if printf '%s\n' "$@" | grep -q -- '-c'; then
  # Turn 2: optionally append the production failure to the log (lands after the
  # e2e's recorded offset), then reply with the persisted marker unless dropped.
  if [ "${FAKE_SLICE_FAIL:-0}" = 1 ] && [ -n "${FAKE_APPEND_LOG:-}" ]; then
    printf '%s\n' 'no user query found in messages modelID=qwen3.8:27b agent=spec-specifier' >> "$FAKE_APPEND_LOG"
  fi
  marker="$(cat "$FAKE_MARKER_STATE" 2>/dev/null || true)"
  if [ "${FAKE_DROP_MARKER:-0}" = 1 ] || [ -z "$marker" ]; then
    printf '%s\n' '{"type":"message","message":"I no longer recall the marker."}'
  else
    printf '%s\n' "{\"type\":\"message\",\"message\":\"The marker is $marker\"}"
  fi
else
  # Turn 1: capture the marker and persist it for turn 2.
  marker="$(printf '%s\n' "$@" | grep -oE 'MKT_E2E_[0-9]+_[0-9]+' | head -1)"
  printf '%s' "$marker" > "$FAKE_MARKER_STATE"
  printf '%s\n' '{"type":"message","message":"OK, turn 1 complete."}'
fi
exit 0
FAKEOC
chmod +x "$FAKE_BIN/opencode"

# ── Log fixture ──────────────────────────────────────────────────────────────
# LOG_CLEAN: no "no user query found" for the model.
LOG_CLEAN="$TMP/log-clean.log"
printf 'line one\nline two\n' > "$LOG_CLEAN"
# LOG_DIRTY: starts clean; the mock appends the error during turn 2 so it lands
# in the e2e's slice [offset, now] (AC-003-02).
LOG_DIRTY="$TMP/log-dirty.log"
printf 'line one\nline two\n' > "$LOG_DIRTY"

run_e2e() { # run_e2e <log> [extra env...]  — env passed via FAKE_* exported by caller
  rm -f "$FAKE_MARKER_STATE"
  set +e
  PATH="$FAKE_BIN:/usr/bin:/bin" bash "$E2E" --out "$TMP/decision.txt" --log "$1" > "$TMP/out" 2> "$TMP/err"
  RUN_RC=$?
  set -e
}

echo "== AC-003-01 real stage runs on the local model =="
# Capture the invocation to verify --agent spec-specifier and the exported model.
cat > "$FAKE_BIN/opencode" <<'FAKEOC2'
#!/bin/bash
echo "$*" >> "$FAKE_CALLS"
if [ "${FAKE_OPENCODE_RC:-0}" -ne 0 ]; then exit "${FAKE_OPENCODE_RC}"; fi
if printf '%s\n' "$@" | grep -q -- '-c'; then
  marker="$(cat "$FAKE_MARKER_STATE" 2>/dev/null || true)"
  if [ "${FAKE_DROP_MARKER:-0}" = 1 ] || [ -z "$marker" ]; then printf '%s\n' 'no marker'; else printf '%s\n' "marker=$marker"; fi
else
  marker="$(printf '%s\n' "$@" | grep -oE 'MKT_E2E_[0-9]+_[0-9]+' | head -1)"
  printf '%s' "$marker" > "$FAKE_MARKER_STATE"
  printf '%s\n' 'turn1 ok'
fi
exit 0
FAKEOC2
chmod +x "$FAKE_BIN/opencode"
export FAKE_CALLS="$TMP/calls.txt"
rm -f "$FAKE_CALLS"
run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 0 ] && grep -q -- '--agent spec-specifier' "$FAKE_CALLS" \
   && grep -q -- '-m ollama/qwen3.8:27b' "$FAKE_CALLS"; then
  ok "AC-003-01 opencode run targets spec-specifier with -m ollama/qwen3.8:27b"
else
  bad "AC-003-01 opencode run targets spec-specifier + local model (rc=$RUN_RC, calls=$(tr '\n' ' ' < "$FAKE_CALLS" 2>/dev/null))"
fi

# Restore the full mock (FAKE_SLICE_FAIL + marker persistence) for the remaining
# cases; the AC-003-01 call-capture mock is narrower.
cat > "$FAKE_BIN/opencode" <<'FAKEOC'
#!/bin/bash
if [ "${FAKE_OPENCODE_RC:-0}" -ne 0 ]; then exit "${FAKE_OPENCODE_RC}"; fi
if printf '%s\n' "$@" | grep -q -- '-c'; then
  if [ "${FAKE_SLICE_FAIL:-0}" = 1 ] && [ -n "${FAKE_APPEND_LOG:-}" ]; then
    printf '%s\n' 'no user query found in messages modelID=qwen3.8:27b agent=spec-specifier' >> "$FAKE_APPEND_LOG"
  fi
  marker="$(cat "$FAKE_MARKER_STATE" 2>/dev/null || true)"
  if [ "${FAKE_DROP_MARKER:-0}" = 1 ] || [ -z "$marker" ]; then
    printf '%s\n' '{"type":"message","message":"I no longer recall the marker."}'
  else
    printf '%s\n' "{\"type\":\"message\",\"message\":\"The marker is $marker\"}"
  fi
else
  marker="$(printf '%s\n' "$@" | grep -oE 'MKT_E2E_[0-9]+_[0-9]+' | head -1)"
  printf '%s' "$marker" > "$FAKE_MARKER_STATE"
  printf '%s\n' '{"type":"message","message":"OK, turn 1 complete."}'
fi
exit 0
FAKEOC
chmod +x "$FAKE_BIN/opencode"

echo "== AC-003-02 no 'no user query found' in the log slice -> pass; dirty -> fail =="
# Clean log: exit 0.
run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 0 ]; then
  ok "AC-003-02 clean slice: no 'no user query found', exit 0"
else
  bad "AC-003-02 clean slice: exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi
# Dirty log: exit 1 and decision moves the stage to cloud.
FAKE_OPENCODE_RC=0 FAKE_SLICE_FAIL=1 FAKE_APPEND_LOG="$LOG_DIRTY" run_e2e "$LOG_DIRTY"
if [ "$RUN_RC" -eq 1 ] && grep -q 'spec-specifier' "$TMP/decision.txt" \
   && grep -q 'CLOUD_FALLBACK_STAGES=spec-specifier' "$TMP/decision.txt"; then
  ok "AC-003-02 dirty slice: 'no user query found' -> exit 1, stage -> CLOUD_FALLBACK_STAGES"
else
  bad "AC-003-02 dirty slice: exit 1 (rc=$RUN_RC, decision=$(tr '\n' ' ' < "$TMP/decision.txt"))"
fi

echo "== AC-003-03 thread retained: marker in turn-2 answer =="
# Clean log + retained marker: exit 0 and the stage stays LOCAL (not cloud).
FAKE_OPENCODE_RC=0 run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 0 ] && grep -q '^LOCAL_STAGES=.*spec-specifier' "$TMP/decision.txt" \
   && ! grep -q 'CLOUD_FALLBACK_STAGES=spec-specifier' "$TMP/decision.txt"; then
  ok "AC-003-03 marker retained across turns -> exit 0, stage stays LOCAL"
else
  bad "AC-003-03 marker retained -> exit 0 (rc=$RUN_RC, decision=$(tr '\n' ' ' < "$TMP/decision.txt"))"
fi
# Marker dropped: exit 1, stage -> cloud.
FAKE_OPENCODE_RC=0 FAKE_DROP_MARKER=1 run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 1 ] && grep -q 'CLOUD_FALLBACK_STAGES=spec-specifier' "$TMP/decision.txt"; then
  ok "AC-003-03 marker dropped -> exit 1, stage -> CLOUD_FALLBACK_STAGES"
else
  bad "AC-003-03 marker dropped -> exit 1 (rc=$RUN_RC, decision=$(tr '\n' ' ' < "$TMP/decision.txt"))"
fi

echo "== AC-003-04 decision line emitted; all 8 stages in exactly one list =="
run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 0 ] && grep -q '^LOCAL_STAGES=' "$TMP/out" && grep -q '^CLOUD_FALLBACK_STAGES=' "$TMP/out" \
   && grep -q '^LOCAL_STAGES=' "$TMP/decision.txt" && grep -q '^CLOUD_FALLBACK_STAGES=' "$TMP/decision.txt"; then
  local_list="$(grep '^LOCAL_STAGES=' "$TMP/decision.txt" | sed 's/^LOCAL_STAGES=//')"
  cloud_list="$(grep '^CLOUD_FALLBACK_STAGES=' "$TMP/decision.txt" | sed 's/^CLOUD_FALLBACK_STAGES=//')"
  all8="spec-specifier spec-ux spec-verifier spec-mutation-runner spec-pr-opener spec-coder spec-refactorer spec-pipeline"
  covered=1
  for a in $all8; do
    in_local=$(printf '%s\n' $local_list | grep -qx "$a" && echo 1 || echo 0)
    in_cloud=$(printf '%s\n' $cloud_list | grep -qx "$a" && echo 1 || echo 0)
    if [ "$in_local" = "1" ] && [ "$in_cloud" = "1" ]; then covered=0; fi
    if [ "$in_local" = "0" ] && [ "$in_cloud" = "0" ]; then covered=0; fi
  done
  if [ "$covered" = "1" ]; then
    ok "AC-003-04 decision line to stdout + file; all 8 stages in exactly one list"
  else
    bad "AC-003-04 all 8 stages in exactly one list (local='$local_list' cloud='$cloud_list')"
  fi
else
  bad "AC-003-04 decision line emitted (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-003-05 failing stage recorded as cloud fallback, absent from LOCAL =="
# Non-zero turn-2 exit -> stage to cloud, others stay local.
FAKE_OPENCODE_RC=7 run_e2e "$LOG_CLEAN"
if [ "$RUN_RC" -eq 1 ] && grep -q 'CLOUD_FALLBACK_STAGES=spec-specifier' "$TMP/decision.txt" \
   && ! grep -q '^LOCAL_STAGES=.*spec-specifier' "$TMP/decision.txt"; then
  ok "AC-003-05 non-zero stage exit -> in CLOUD_FALLBACK_STAGES, absent from LOCAL_STAGES"
else
  bad "AC-003-05 failing stage -> cloud (rc=$RUN_RC, decision=$(tr '\n' ' ' < "$TMP/decision.txt"))"
fi

echo "== AC-003-06 tooling failure exits 2 =="
# opencode unavailable.
mkdir -p "$TMP/emptybin"
set +e
PATH="$TMP/emptybin:/usr/bin:/bin" bash "$E2E" --out "$TMP/decision.txt" --log "$LOG_CLEAN" > "$TMP/out" 2> "$TMP/err"
RUN_RC=$?
set -e
if [ "$RUN_RC" -eq 2 ] && grep -qi 'opencode' "$TMP/err"; then
  ok "AC-003-06 opencode unavailable -> exit 2, message names opencode"
else
  bad "AC-003-06 opencode unavailable -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi
# log unreadable (nonexistent path).
set +e
PATH="$FAKE_BIN:/usr/bin:/bin" bash "$E2E" --out "$TMP/decision.txt" --log "$TMP/nope.log" > "$TMP/out" 2> "$TMP/err"
RUN_RC=$?
set -e
if [ "$RUN_RC" -eq 2 ] && grep -qi 'log' "$TMP/err"; then
  ok "AC-003-06 log unreadable -> exit 2, message names the log"
else
  bad "AC-003-06 log unreadable -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ validate-ollama-e2e.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ validate-ollama-e2e.selftest: all cases pass.${NC}"
