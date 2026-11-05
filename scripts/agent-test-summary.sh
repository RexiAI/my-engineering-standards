#!/bin/bash
# agent-test-summary.sh — Run a test command and put only its failures plus a
# one-line summary into the agent's context (spec 041).
#
# A full `make test` / `mvn test` / `pytest` log is mostly passes. Pasting it
# into context costs tokens and buries the signal. This helper writes the
# COMPLETE log to a caller-named path (never truncated, never rewritten), prints
# only the failure/error lines plus one `SUMMARY:` line, and exits with the
# wrapped command's status verbatim — so it is a filter, not a gate.
#
# The full log still reaches the evidence file: the stage appends it to
# 25-verification.md with a shell redirect (`cat "$LOG"`), at zero context cost.
# The canonical recipe lives in exactly one place —
# docs/spec-pipeline/verifier.md §Test-log capture.
#
# Only test-suite output is ever filtered. The design-principles gate (every
# FAIL/WARN line must stay verbatim) and the complexity linters (tool-specific
# finding shapes) are invoked directly, never through this helper.
#
# Usage:
#   scripts/agent-test-summary.sh --run <log-path> -- <command…>
#   scripts/agent-test-summary.sh --read <log-path>
#   scripts/agent-test-summary.sh -h|--help
#
# --run   runs <command…> with combined stdout+stderr redirected to <log-path>
#         (created, parents included), prints the signal block + summary, and
#         exits with the command's status verbatim (a missing command is 127,
#         like the shell). A <log-path> under any specs/ directory is refused
#         before the command runs: evidence belongs in 25-verification.md, not
#         as a scratch log inside the spec folder.
# --read  formats an existing log. Writes nothing and exits 0 on a readable log
#         even when it is full of failures — a formatter is not a gate. An
#         unreadable path exits 2 with nothing on stdout.
#
# Output (stdout):
#   <signal lines, verbatim, in log order, while both caps hold>
#   TRUNCATED: <n> more signal lines omitted; full log: <log-path>   (only when
#                                                                   lines were
#                                                                   omitted)
#   SUMMARY: mode=<run|read> exit=<code|-> signal=<n> log_lines=<m> log=<path>
# The summary line is always the last line of stdout. <n> is the true total of
# signal lines (printed + omitted); <m> is the log's line count.
#
# Exit codes:
#   0 — the wrapped command succeeded (--run), or the log was readable (--read)
#   * — --run exits with the wrapped command's status verbatim (0, 1, 42, 127…)
#   2 — usage error, refused log path under specs/, or unreadable log (--read)
#
# Standards reference:
#   docs/spec-pipeline/verifier.md §Test-log capture
#   docs/spec-pipeline/audit-contract.md §Audit contract
set -euo pipefail

# Fixed interface: these are named constants, not flags. Changing them changes
# every stage's context cost, so they are set here once.
MAX_SIGNAL_LINES=50
MAX_OUTPUT_BYTES=8192
# TAP: a passing line is `ok …`, and bats prints the test *title* after it. A
# title may itself contain "FAIL", "not ok", "WARN" or "error:" (tests that
# assert on failing-run output), so a passing TAP line is never a signal.
TAP_PASS_RE='^ok([[:space:]]|$)'
# TAP: a failing test line is `not ok …` — always a signal.
TAP_FAIL_RE='^not[[:space:]]+ok([[:space:]]|$)'
# Real failure markers in non-TAP output. FAIL/ERROR/WARN are anchored to the
# runner's line shape (bats, pytest, Maven's `[ERROR]`, Vitest's leading space,
# Go's `--- FAIL:`); `error:` stays unanchored because compilers emit it
# mid-line (`path:line:col: error: …`). Never matched inside an `ok …` title.
SIGNAL_RE='^[[:space:]]*\[?(FAIL|ERROR|WARN)|^--- FAIL|^not[[:space:]]+ok([[:space:]]|$)|error:|AssertionError|panic:|Traceback|✗|✘'
# A line that only reports a zero count is a clean run, not a signal.
ZERO_RE='failures[[:space:]]*[=:][[:space:]]*0|(^|[^[:alnum:]])0[[:space:]]+(failed|errors|failures)'

usage() {
  cat <<'EOF' >&2
usage: scripts/agent-test-summary.sh --run <log-path> -- <command…>
       scripts/agent-test-summary.sh --read <log-path>

  --run   capture the command's full output to <log-path>, print only signal
          lines plus one SUMMARY line, exit with the command's status
  --read  format an existing log (writes nothing)
  -h, --help  print this block
EOF
}

# is_signal <line> — 0 when the line reports a failure/error, not a zero count.
# A passing TAP line is checked first: what follows `ok <n>` is a test title,
# not runner output, so a marker word inside it is never a signal. A failing
# TAP line (`not ok`) is always a signal. Bash regex, not `printf | grep -q`:
# the pipeline shape can take SIGPIPE under pipefail on a long line, which
# reads as "no match" (the spec-037 O-2 flake).
is_signal() {
  local rc=1
  shopt -s nocasematch
  if [[ "$1" =~ $TAP_PASS_RE ]]; then
    rc=1
  elif [[ "$1" =~ $TAP_FAIL_RE ]]; then
    rc=0
  elif [[ "$1" =~ $SIGNAL_RE ]] && ! [[ "$1" =~ $ZERO_RE ]]; then
    rc=0
  fi
  shopt -u nocasematch
  return "$rc"
}

# line_bytes <line> — the line's byte length plus the newline it prints with.
line_bytes() {
  printf '%s\n' "$1" | wc -c | tr -d ' '
}

# log_lines <file> — the log's line count (0 for an empty file).
log_lines() {
  awk 'END { print NR }' "$1"
}

# emit_signal <line> <bytes> — print one signal line and add its byte count to
# EMITTED_BYTES (no subshell: the caller's counter moves).
emit_signal() {
  printf '%s\n' "$1"
  EMITTED_BYTES=$((EMITTED_BYTES + $2))
}

# has_cap_room <line-bytes> <printed> — 0 while both caps still allow printing
# one more signal line.
has_cap_room() {
  [ "$2" -lt "$MAX_SIGNAL_LINES" ] || return 1
  [ "$((EMITTED_BYTES + $1))" -le "$MAX_OUTPUT_BYTES" ]
}

# print_truncation <omitted> <file> — the omission line, or nothing.
print_truncation() {
  [ "$1" -gt 0 ] || return 0
  printf 'TRUNCATED: %s more signal lines omitted; full log: %s\n' "$1" "$2"
}

# process_log <file> <mode> <exit-code> — the whole output contract: signal
# lines while both caps hold, the truncation line when lines were omitted, then
# the summary. One pass; every line is counted even after printing stops.
process_log() {
  local file="$1" mode="$2" xc="$3" line total=0 printed=0 omitted=0 stopped=0 lb
  EMITTED_BYTES=0
  while IFS= read -r line || [ -n "$line" ]; do
    if ! is_signal "$line"; then continue; fi
    total=$((total + 1))
    if [ "$stopped" -eq 1 ]; then omitted=$((omitted + 1)); continue; fi
    lb="$(line_bytes "$line")"
    if has_cap_room "$lb" "$printed"; then
      emit_signal "$line" "$lb"
      printed=$((printed + 1))
      continue
    fi
    stopped=1
    omitted=$((omitted + 1))
  done < "$file"
  print_truncation "$omitted" "$file"
  printf 'SUMMARY: mode=%s exit=%s signal=%s log_lines=%s log=%s\n' \
    "$mode" "$xc" "$total" "$(log_lines "$file")" "$file"
}

# inside_specs <path> — true when any path component is specs/. Refused before
# the command runs, so no scratch log can land in the spec folder.
inside_specs() {
  case "/$1" in
    */specs/*) return 0 ;;
  esac
  return 1
}

# run_mode <log> <command…> — capture, filter, and exit with the real status.
run_mode() {
  local log="$1"
  shift
  if inside_specs "$log"; then
    echo "agent-test-summary: refusing to write a log inside specs/" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$log")"
  local xc=0
  if "$@" > "$log" 2>&1; then xc=0; else xc=$?; fi
  process_log "$log" run "$xc"
  exit "$xc"
}

# read_mode <log> — format an existing log; exit 2 when it cannot be read.
read_mode() {
  local log="$1"
  if [ ! -f "$log" ] || [ ! -r "$log" ]; then
    echo "agent-test-summary: cannot read log: $log" >&2
    exit 2
  fi
  process_log "$log" read -
}

# usage_error — a usage problem is exit 2, with the usage block on stderr.
usage_error() {
  usage
  exit 2
}

# read_invocation <log> — `--read` takes exactly one argument.
read_invocation() {
  [ "$#" -eq 1 ] || usage_error
  read_mode "$1"
}

# run_invocation <log> -- <command…> — `--run` requires the `--` separator.
run_invocation() {
  [ "$#" -ge 2 ] && [ "$2" = "--" ] || usage_error
  run_mode "$1" "${@:3}"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --read) shift; read_invocation "$@" ;;
    --run) shift; run_invocation "$@" ;;
    *) usage_error ;;
  esac
}

main "$@"
