#!/bin/bash
# gate-stats.sh — Reads the append-only runs.jsonl (one JSON record per
# pipeline run, written by scripts/record-gate-run.sh) and prints the drift
# signal: failure/retry rates, the most-failed gate, and retry creep between
# windows. Parses the fixed record schema with grep/sed/awk — no jq.
#
# Usage:
#   gate-stats.sh [-f <file>] [-n <window>]
# Defaults: <repo-root>/runs.jsonl, window 10.
#
# Output (minimum): total runs; outcome counts with percentages; failure rate
# (fail + block) / total; most-failed gate with count; total warnings; for
# loopCount / phase1Retries / phase2Retries the overall average and max plus
# the average over the last -n runs; creep detection per metric (recent-window
# average >= 1.5x the prior-window average and both conditions hold, i.e.
# recent >= 1.0 and the ratio is reached — a metric whose recent average is
# below 1.0 or does not reach the 1.5x ratio is not marked CREEP).
#
# Exit codes:
#   0 — file read and report printed (including an empty runs.jsonl)
#   1 — missing/unreadable file (message to stderr)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${GATE_RUNS_FILE:-$ROOT/runs.jsonl}"
WINDOW=10

while [ $# -gt 0 ]; do
  case "$1" in
    -f)
      FILE="${2:-}"
      [ -n "$FILE" ] || { echo "gate-stats: -f requires a file path" >&2; exit 1; }
      shift 2 ;;
    -n)
      WINDOW="${2:-}"
      case "$WINDOW" in
        ''|*[!0-9]*) echo "gate-stats: -n requires a positive integer window" >&2; exit 1 ;;
      esac
      [ "$WINDOW" -gt 0 ] || { echo "gate-stats: -n requires a positive integer window" >&2; exit 1; }
      shift 2 ;;
    *) echo "gate-stats: unknown option: $1" >&2; exit 1 ;;
  esac
done

[ -r "$FILE" ] || { echo "gate-stats: cannot read $FILE (missing or unreadable)" >&2; exit 1; }

awk -v win="$WINDOW" '
function strval(line, key,   s) {
  # "key": "value" — capture the quoted value
  if (match(line, "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")) {
    s = substr(line, RSTART, RLENGTH)
    sub(/^[^:]*:[[:space:]]*"/, "", s)
    sub(/"[[:space:]]*$/, "", s)
    return s
  }
  return ""
}
function numval(line, key,   s) {
  # "key": <digits> — capture the integer value
  if (match(line, "\"" key "\"[[:space:]]*:[[:space:]]*[0-9]+")) {
    s = substr(line, RSTART, RLENGTH)
    sub(/^[^:]*:[[:space:]]*/, "", s)
    return s + 0
  }
  return 0
}
function arr_items(line, key,   i, s, e, inner, n, a, k, out) {
  # "key": [ ... ] — return the raw array contents ("" when absent/empty)
  i = index(line, "\"" key "\"")
  if (i == 0) return ""
  s = substr(line, i + length(key) + 2)
  sub(/^[[:space:]]*:[[:space:]]*/, "", s)
  if (substr(s, 1, 1) != "[") return ""
  e = index(s, "]")
  if (e == 0) return ""
  inner = substr(s, 2, e - 2)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", inner)
  return inner
}
{
  total++
  o = strval($0, "outcome")
  if (o == "pass") pc++ ; else if (o == "fail") fc++ ; else if (o == "block") bc++
  loop[total] = numval($0, "loopCount")
  p1[total] = numval($0, "phase1Retries")
  p2[total] = numval($0, "phase2Retries")
  # warnings: count comma-separated items inside the array
  w = arr_items($0, "warnings")
  if (w != "") { n = split(w, wa, ","); warns += n }
  # gatesFailed: tally each quoted gate id
  g = arr_items($0, "gatesFailed")
  if (g != "") {
    n = split(g, ga, ",")
    for (k = 1; k <= n; k++) {
      id = ga[k]
      gsub(/[[:space:]"]/, "", id)
      if (id != "") gate_count[id]++
    }
  }
}
END {
  printf "Gate run stats from %s\n", FILENAME
  printf "Total runs: %d\n", total
  printf "Outcome breakdown:\n"
  if (total > 0) {
    printf "  pass:  %d (%.0f%%)\n", pc, pc * 100 / total
    printf "  fail:  %d (%.0f%%)\n", fc, fc * 100 / total
    printf "  block: %d (%.0f%%)\n", bc, bc * 100 / total
    printf "Failure rate (fail + block) / total: %.0f%%\n", (fc + bc) * 100 / total
  } else {
    printf "  pass:  0 (0%%)\n  fail:  0 (0%%)\n  block: 0 (0%%)\n"
    printf "Failure rate (fail + block) / total: 0%%\n"
  }
  best_gate = ""; best_n = 0
  for (gid in gate_count) {
    if (gate_count[gid] > best_n) { best_n = gate_count[gid]; best_gate = gid }
  }
  if (best_gate == "") printf "Most-failed gate: none\n"
  else printf "Most-failed gate: %s (%d runs)\n", best_gate, best_n
  printf "Total warnings: %d\n", warns

  printf "Retry metrics (overall avg, max, last-%d avg):\n", win
  for (m = 1; m <= 3; m++) {
    name = metric_name(m)
    slice(m, 1, total)
    avg = (_c > 0 ? _s / _c : 0)
    mx = _m
    start = (total - win + 1 > 1 ? total - win + 1 : 1)
    slice(m, start, total)
    printf "  %-14s avg %.1f  max %d  last %d avg %.1f\n", name, avg, mx, _c, (_c > 0 ? _s / _c : 0)
  }

  # Creep: compare the last-n average to the n before them. CREEP when the
  # recent average >= 1.5x the prior and recent >= 1.0 (both conditions must
  # hold; prior window empty => no comparison => no creep).
  printf "Creep check (last-%d vs prior %d):\n", win, win
  for (m = 1; m <= 3; m++) {
    name = metric_name(m)
    rstart = total - win + 1
    if (rstart < 1) rstart = 1
    slice(m, rstart, total)
    ravg = (_c > 0 ? _s / _c : 0)
    rc = _c
    pstart = rstart - win
    if (pstart < 1) pstart = 1
    slice(m, pstart, rstart - 1)
    pavg = (_c > 0 ? _s / _c : 0)
    if (rc > 0 && _c > 0 && ravg >= 1.5 * pavg && ravg >= 1.0) creep = 1
    else creep = 0
    if (creep) printf "  %-14s CREEP (recent %.1f, prior %.1f)\n", name, ravg, pavg
    else printf "  %-14s no creep (recent %.1f, prior %.1f)\n", name, ravg, pavg
  }
}
function metric_name(m) { return (m == 1 ? "loopCount" : (m == 2 ? "phase1Retries" : "phase2Retries")) }
function v(i, m) { return (m == 1 ? loop[i] : (m == 2 ? p1[i] : p2[i])) }
# slice(m, start, end) — sum the metric over the inclusive range into the
# scratch globals _s (sum), _c (count), _m (max).
function slice(m, start, end,   i, val) {
  _s = 0; _c = 0; _m = 0
  for (i = start; i <= end; i++) {
    val = v(i, m)
    _s += val; _c++
    if (val > _m) _m = val
  }
}
' "$FILE"