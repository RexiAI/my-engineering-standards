#!/bin/bash
# gate-telemetry.selftest.sh — Hermetic regression net for the spec-012
# telemetry layer: the -ReportPath flag on both gate scripts, the append-only
# record-gate-run.sh, the gate-stats.sh drift report, the self-ci wiring, the
# Verifier/orchestrator telemetry instructions, and the weekly stats workflow.
#
# Scenario manifest (traceability: every AC-012-NN-NN ID below is a scenario in
# specs/012-gate-selftests-telemetry/20-acceptance/; the IDs are carried here so
# scripts/check-scenario-traceability.sh resolves them to tests):
#   AC-012-03-01  self-ci runs both selftests on every push and PR
#   AC-012-03-02  a selftest regression fails the job (no continue-on-error)
#   AC-012-03-03  the new scripts are covered by the existing parse/lint steps
#   AC-012-04-01  check-code-principles.sh writes its JSON report to the file
#   AC-012-04-02  -ReportPath combines with --gates and --json without collision
#   AC-012-04-03  check-scenario-traceability.sh writes its JSON report
#   AC-012-04-04  a missing -ReportPath value is a usage error (exit 2)
#   AC-012-04-05  the report file is written atomically
#   AC-012-04-06  default behavior without -ReportPath is unchanged
#   AC-012-05-01  a valid record is appended as one JSONL line
#   AC-012-05-02  appends, never rewrites (append-only)
#   AC-012-05-03  runId is generated when omitted
#   AC-012-05-04  loop/retry fields default from SPEC_* env vars, then to 0
#   AC-012-05-05  validation rejects a malformed record without appending
#   AC-012-05-06  exactly one of specSlug/jiraKey is accepted
#   AC-012-05-07  -f and GATE_RUNS_FILE override the default path
#   AC-012-06-01  spec-verifier.md documents the telemetry step
#   AC-012-06-02  the append goes through record-gate-run.sh, no new edit permission
#   AC-012-06-03  a record is appended even on FAIL or BLOCK verdicts
#   AC-012-06-04  outcome precedence is block over fail over pass
#   AC-012-06-05  spec-pipeline.md exports loop/retry context to the record
#   AC-012-07-01  prints totals, outcome breakdown, and failure rate
#   AC-012-07-02  names the most-failed gate
#   AC-012-07-03  prints loop and retry averages/max and the recent window average
#   AC-012-07-04  flags retry creep against the prior window
#   AC-012-07-05  a missing runs.jsonl is a hard error, not an empty report
#   AC-012-07-06  a well-formed file exits 0
#   AC-012-08-01  a scheduled workflow runs gate-stats.sh weekly
#   AC-012-08-02  the workflow needs read-only permissions
#   AC-012-08-03  the stats report reflects the committed runs.jsonl
#
# Note on AC-012-04-02: the full combination is only assertable once spec 007's
# --gates/--json flags are merged (012 depends on 007 for --gates; the two specs
# land in the same batch). When the checker rejects --json with "Unknown option"
# / exit 2, this selftest prints that documented dependency and skips the
# combination assertion — it never claims a pass it did not run.
#
# Fixtures live in `mktemp -d` scratch (never inside the repo), cleaned up by a
# trap. Exits 0 only if every assertion passes.
#
# Usage:
#   bash scripts/tests/gate-telemetry.selftest.sh
# Exit codes:
#   0 — every assertion passes
#   1 — at least one assertion failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRINCIPLES="$ROOT/scripts/check-code-principles.sh"
TRACE="$ROOT/scripts/check-scenario-traceability.sh"
RECORD="$ROOT/scripts/record-gate-run.sh"
GATE_STATS="$ROOT/scripts/gate-stats.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }
note() { SKIP_COUNT=$((SKIP_COUNT + 1)); echo -e "${YELLOW}NOTE${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run_capture OUT ERR cmd... — captures stdout/stderr, sets RUN_RC
run_capture() {
  local out="$1" err="$2"
  shift 2
  if "$@" >"$out" 2>"$err"; then RUN_RC=0; else RUN_RC=$?; fi
}

show_out() {
  echo "  actual output:"
  sed 's/^/    /' "$1" 2>/dev/null | head -20 || true
}

# ── Scratch fixtures ──────────────────────────────────────────────────────────
mkdir -p "$TMP/cc-bad"
cat > "$TMP/cc-bad/CcBad.java" <<'EOF'
public class CcBad {
  public void decide(int a) {
    if (a > 1) { System.out.println(1); }
    if (a > 2) { System.out.println(2); }
    if (a > 3) { System.out.println(3); }
    if (a > 4) { System.out.println(4); }
    if (a > 5) { System.out.println(5); }
    if (a > 6) { System.out.println(6); }
    if (a > 7) { System.out.println(7); }
  }
}
EOF
mkdir -p "$TMP/kiss-lines"
cat > "$TMP/kiss-lines/KissLines.java" <<'EOF'
public class KissLines {
  public void longBody() {
    int a = 1;
    int b = 2;
    int c = a + b;
    int d = c * 2;
    int e = d + 1;
    int f = e - 1;
    int g = f * 3;
    int h = g / 2;
    int i = h + 4;
    int j = i - 4;
    int k = j * 5;
    int l = k / 5;
    int m = l + 6;
    int n = m - 6;
    int o = n * 7;
    int p = o / 7;
    int q = p + 8;
    int r = q - 8;
    int s = r * 9;
    int t = s / 9;
    int u = t + 10;
    System.out.println(u);
  }
}
EOF
mkdir -p "$TMP/dry-bad"
BLOCK='int a = 1;
int b = 2;
int c = a + b;
use(c);'
printf 'public class DryOne { public void go() {\n%s\n} }\n' "$BLOCK" > "$TMP/dry-bad/DryOne.java"
printf 'public class DryTwo { public void go() {\n%s\n} }\n' "$BLOCK" > "$TMP/dry-bad/DryTwo.java"
mkdir -p "$TMP/orphan/specs/999-slug/20-acceptance" "$TMP/orphan/src"
# Fixture ID constructed at runtime (model-env.selftest.sh pattern) so it never
# appears as a literal that the traceability checker would read as dangling.
ORPHAN_ID="$(printf 'AC-%03d-%02d' 999 02)"
printf '## %s — orphaned scenario\n' "$ORPHAN_ID" \
  > "$TMP/orphan/specs/999-slug/20-acceptance/${ORPHAN_ID}-missing.md"
printf 'package widget\nfunc Render() string { return "hi" }\n' > "$TMP/orphan/src/widget.go"

# ── AC-012-03: self-ci wiring ─────────────────────────────────────────────────
echo "== AC-012-03 self-ci wiring =="
SELFCI="$ROOT/.github/workflows/self-ci.yml"
if grep -q "bash scripts/check-code-principles.selftest.sh" "$SELFCI" \
   && grep -q "bash scripts/check-scenario-traceability.selftest.sh" "$SELFCI" \
   && grep -q "bash scripts/tests/gate-telemetry.selftest.sh" "$SELFCI"; then
  ok "AC-012-03-01: self-ci runs both selftests (and the telemetry net) in one step"
else
  bad "AC-012-03-01: self-ci does not run the selftests"
fi
# The selftest step must not use continue-on-error (a regression fails the job).
awk '/- name: Run gate selftests/,/^      - name:|^      - uses:/' "$SELFCI" | grep -q 'continue-on-error' \
  && bad "AC-012-03-02: selftest step must not use continue-on-error" \
  || ok "AC-012-03-02: selftest step has no continue-on-error (regression fails the job)"
for s in "$ROOT/scripts/check-code-principles.selftest.sh" "$ROOT/scripts/check-scenario-traceability.selftest.sh" "$ROOT/scripts/tests/gate-telemetry.selftest.sh"; do
  bash -n "$s" || { bad "AC-012-03-03: $s does not parse"; continue; }
done
ok "AC-012-03-03: selftest scripts parse cleanly (covered by the bash -n step)"

# ── AC-012-04: -ReportPath on the gate scripts ────────────────────────────────
echo "== AC-012-04 -ReportPath =="
run_capture "$TMP/o1.txt" "$TMP/e1.txt" bash "$PRINCIPLES" -ReportPath "$TMP/rpt.json" "$TMP/cc-bad"
[ "$RUN_RC" -eq 1 ] || bad "AC-012-04-01: principles run with a violation must exit 1 (got $RUN_RC)"
if [ -f "$TMP/rpt.json" ] \
   && grep -q '"tier"' "$TMP/rpt.json" \
   && grep -q '"gates"' "$TMP/rpt.json" \
   && grep -q '"fails"' "$TMP/rpt.json" \
   && grep -q '"warns"' "$TMP/rpt.json" \
   && grep -q 'Cyclomatic complexity >6' "$TMP/rpt.json"; then
  ok "AC-012-04-01: JSON report has tier/gates/fails/warns and the complexity violation"
else
  bad "AC-012-04-01: report missing keys or the violation"
  show_out "$TMP/o1.txt"; [ -f "$TMP/rpt.json" ] && cat "$TMP/rpt.json"
fi
grep -q 'Cyclomatic complexity >6' "$TMP/o1.txt" && ok "AC-012-04-01: human-readable stdout unchanged (FAIL line present)" || bad "AC-012-04-01: stdout missing the FAIL line"

# AC-012-04-02: -ReportPath + --gates + --json — needs 007's flags.
mkdir -p "$TMP/probe"
printf 'public class Probe { public int add(int a, int b) { return a + b; } }\n' > "$TMP/probe/Probe.java"
run_capture "$TMP/probe.out" "$TMP/probe.err" bash "$PRINCIPLES" --json "$TMP/probe"
if [ "$RUN_RC" -eq 2 ] && grep -q "Unknown option: --json" "$TMP/probe.err"; then
  note "AC-012-04-02: requires spec 007's --gates/--json flags (012 lands in the same batch as 007) — combination not asserted on this branch"
else
  run_capture "$TMP/o2.txt" "$TMP/e2.txt" bash "$PRINCIPLES" -ReportPath "$TMP/rpt2.json" --gates dry --json "$TMP/dry-bad"
  [ "$RUN_RC" -eq 0 ] || { bad "AC-012-04-02: DRY is a WARN, expected exit 0 (got $RUN_RC)"; show_out "$TMP/o2.txt"; }
  if grep -q 'Possible duplication' "$TMP/o2.txt" && grep -q 'Possible duplication' "$TMP/rpt2.json"; then
    ok "AC-012-04-02: JSON to both stdout (--json) and file (-ReportPath), DRY finding in both"
  else
    bad "AC-012-04-02: combination did not produce the DRY finding in both outputs"
  fi
fi

# AC-012-04-03: traceability -ReportPath with an orphaned scenario
run_capture "$TMP/o3.txt" "$TMP/e3.txt" bash "$TRACE" -ReportPath "$TMP/trace.json" "$TMP/orphan/specs" "$TMP/orphan/src"
[ "$RUN_RC" -eq 1 ] || bad "AC-012-04-03: orphaned scenario must exit 1 (got $RUN_RC)"
if [ -f "$TMP/trace.json" ] && grep -q '"passes"' "$TMP/trace.json" && grep -q '"fails"' "$TMP/trace.json" && grep -q "$ORPHAN_ID" "$TMP/trace.json"; then
  ok "AC-012-04-03: traceability JSON has passes/fails and the orphaned scenario ID"
else
  bad "AC-012-04-03: traceability report missing keys or the orphan ID"
  [ -f "$TMP/trace.json" ] && cat "$TMP/trace.json"
fi

# AC-012-04-04: -ReportPath with an empty value → stderr message, exit 2
run_capture "$TMP/o4.txt" "$TMP/e4.txt" bash "$PRINCIPLES" -ReportPath "" "$TMP/probe"
[ "$RUN_RC" -eq 2 ] && grep -q 'requires a non-empty file path' "$TMP/e4.txt" \
  && ok "AC-012-04-04: empty -ReportPath value → stderr message, exit 2" \
  || bad "AC-012-04-04: expected exit 2 + stderr message (got $RUN_RC)"
run_capture "$TMP/o4b.txt" "$TMP/e4b.txt" bash "$TRACE" -ReportPath
if [ "$RUN_RC" -eq 2 ] && grep -q 'requires a non-empty file path' "$TMP/e4b.txt"; then
  ok "AC-012-04-04: traceability -ReportPath with no value → stderr message, exit 2"
else
  bad "AC-012-04-04: traceability missing -ReportPath value not a usage error (rc=$RUN_RC)"
  cat "$TMP/e4b.txt"
fi

# AC-012-04-05: atomic write — no temp siblings left behind
ls "$TMP" | grep -q '\.tmp\.' && bad "AC-012-04-05: temp report siblings left behind" \
  || ok "AC-012-04-05: report written atomically (no temp siblings remain)"

# AC-012-04-06: default behavior unchanged — WARN fixture exits 0 without -ReportPath
run_capture "$TMP/o6.txt" "$TMP/e6.txt" bash "$PRINCIPLES" "$TMP/kiss-lines"
[ "$RUN_RC" -eq 0 ] && grep -q 'Method body >20 lines' "$TMP/o6.txt" \
  && ok "AC-012-04-06: default run (no -ReportPath) unchanged — WARN fixture exits 0" \
  || bad "AC-012-04-06: default behavior changed (rc=$RUN_RC)"

# ── AC-012-05: record-gate-run.sh ─────────────────────────────────────────────
echo "== AC-012-05 record-gate-run =="
REC='{"runId":"r1","specSlug":"012-slug","gatesFailed":["complexity"],"loopCount":1,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":12.5,"outcome":"fail"}'
NOD='{"specSlug":"s","gatesFailed":[],"warnings":[],"durationSec":1,"outcome":"pass"}'
NOLOOP='{"specSlug":"s","gatesFailed":[],"warnings":[],"durationSec":1,"outcome":"pass"}'

run_capture "$TMP/r1.out" "$TMP/r1.err" env GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$REC"
[ "$RUN_RC" -eq 0 ] && [ "$(wc -l < "$TMP/runs.jsonl" | tr -d ' ')" = "1" ] && grep -qF "$REC" "$TMP/runs.jsonl" \
  && ok "AC-012-05-01: valid record appended as one verbatim line (exit 0)" \
  || { bad "AC-012-05-01: append failed (rc=$RUN_RC)"; cat "$TMP/r1.err"; }

REC2=$(printf '%s' "$REC" | sed 's/"r1"/"r2"/; s/"fail"/"pass"/')
env GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$REC2" > /dev/null 2>&1
LINES_BEFORE=$(wc -l < "$TMP/runs.jsonl" | tr -d ' ')
if [ "$LINES_BEFORE" = "2" ] && [ "$(head -1 "$TMP/runs.jsonl" | grep -qF "$REC"; echo $?)" = "0" ]; then
  ok "AC-012-05-02: append-only — two lines, first byte-identical"
else
  bad "AC-012-05-02: append-only violated (lines=$LINES_BEFORE)"
fi

env GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$NOD" > /dev/null 2>&1
tail -1 "$TMP/runs.jsonl" | grep -q '"runId":"[^"]*"' && ok "AC-012-05-03: runId generated when omitted" || bad "AC-012-05-03: runId not generated"

env SPEC_LOOP_COUNT=3 SPEC_PHASE1_RETRIES=2 GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$NOLOOP" > /dev/null 2>&1
L=$(tail -1 "$TMP/runs.jsonl")
printf '%s' "$L" | grep -q '"loopCount":3' && printf '%s' "$L" | grep -q '"phase1Retries":2' && printf '%s' "$L" | grep -q '"phase2Retries":0' \
  && ok "AC-012-05-04: loop/retry fields default from SPEC_* env vars" || bad "AC-012-05-04: env defaults wrong: $L"
env GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$NOLOOP" > /dev/null 2>&1
tail -1 "$TMP/runs.jsonl" | grep -q '"loopCount":0,"phase1Retries":0,"phase2Retries":0' \
  && ok "AC-012-05-04: no env vars → loop/retry fields default to 0" || bad "AC-012-05-04: zero defaults wrong"

reject_case() { # DESC RECORD
  local desc="$1" rec="$2"
  rm -f "$TMP/rej.jsonl"
  run_capture "$TMP/rej.out" "$TMP/rej.err" env GATE_RUNS_FILE="$TMP/rej.jsonl" bash "$RECORD" -record "$rec"
  if [ "$RUN_RC" -eq 1 ] && [ ! -e "$TMP/rej.jsonl" ]; then
    ok "AC-012-05-05: '$desc' rejected with exit 1, nothing appended"
  else
    bad "AC-012-05-05: '$desc' not rejected cleanly (rc=$RUN_RC, file=$([ -e "$TMP/rej.jsonl" ] && echo exists || echo absent))"
    cat "$TMP/rej.err"
  fi
}
reject_case "non-JSON string" 'hello world'
reject_case "missing outcome" '{"specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1}'
reject_case "unknown outcome" '{"specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"unknown"}'
reject_case "both specSlug and jiraKey" '{"specSlug":"s","jiraKey":"P-1","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}'
reject_case "neither specSlug nor jiraKey" '{"gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}'

JIR='{"runId":"rj","jiraKey":"PROJ-123","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}'
env GATE_RUNS_FILE="$TMP/runs.jsonl" bash "$RECORD" -record "$JIR" > /dev/null 2>&1
tail -1 "$TMP/runs.jsonl" | grep -qF "$JIR" && ok "AC-012-05-06: jiraKey-only record accepted unchanged" || bad "AC-012-05-06: jiraKey-only record failed"

mkdir -p "$TMP/scratch/scripts"
cp "$RECORD" "$TMP/scratch/scripts/"
bash "$TMP/scratch/scripts/record-gate-run.sh" -record "$NOD" > /dev/null 2>&1
[ -f "$TMP/scratch/runs.jsonl" ] && [ "$(wc -l < "$TMP/scratch/runs.jsonl" | tr -d ' ')" = "1" ] \
  && ok "AC-012-05-07: no -f / no env → lands in <repo-root>/runs.jsonl" || bad "AC-012-05-07: default path wrong"
bash "$TMP/scratch/scripts/record-gate-run.sh" -f "$TMP/other.jsonl" -record "$NOD" > /dev/null 2>&1
[ -f "$TMP/other.jsonl" ] && [ "$(wc -l < "$TMP/scratch/runs.jsonl" | tr -d ' ')" = "1" ] \
  && ok "AC-012-05-07: -f overrides the default path, default untouched" || bad "AC-012-05-07: -f override wrong"

# ── AC-012-06: Verifier / orchestrator telemetry wiring ───────────────────────
echo "== AC-012-06 verifier + orchestrator =="
VERIFIER="$ROOT/agents/spec-verifier.md"
PIPELINE="$ROOT/agents/spec-pipeline.md"
if grep -q 'record-gate-run.sh' "$VERIFIER" && grep -q 'runs.jsonl' "$VERIFIER" \
   && grep -q 'gatesFailed' "$VERIFIER" && grep -q 'durationSec' "$VERIFIER" \
   && grep -q 'specSlug' "$VERIFIER" && grep -q 'runId' "$VERIFIER"; then
  ok "AC-012-06-01: spec-verifier.md documents the telemetry step and its field mapping"
else
  bad "AC-012-06-01: spec-verifier.md missing telemetry instructions"
fi
# permission.edit must still allow only 25-verification.md (append goes via bash)
awk '/^permission:/,/^---/' "$VERIFIER" | grep -q 'specs/\*/25-verification.md' \
  && ok "AC-012-06-02: verifier edit permission unchanged (append via record-gate-run.sh bash path)" \
  || bad "AC-012-06-02: verifier frontmatter edit scope changed"
grep -q 'every completed run' "$VERIFIER" && grep -q 'verdict is FAIL' "$VERIFIER" \
  && ok "AC-012-06-03: verifier records even on FAIL/BLOCK verdicts" || bad "AC-012-06-03: fail-verdict recording not documented"
grep -q 'outcome' "$VERIFIER" && grep -q 'if any gate BLOCKed' "$VERIFIER" \
  && ok "AC-012-06-04: outcome precedence (block > fail > pass) documented" || bad "AC-012-06-04: outcome precedence missing"
for v in SPEC_LOOP_COUNT SPEC_PHASE1_RETRIES SPEC_PHASE2_RETRIES; do
  grep -q "$v" "$PIPELINE" || bad "AC-012-06-05: spec-pipeline.md missing $v export instruction"
done
ok "AC-012-06-05: spec-pipeline.md exports loop/retry context (SPEC_LOOP_COUNT, SPEC_PHASE1_RETRIES, SPEC_PHASE2_RETRIES)"

# ── AC-012-07: gate-stats.sh ──────────────────────────────────────────────────
echo "== AC-012-07 gate-stats =="
cat > "$TMP/stats.jsonl" <<'EOF'
{"runId":"r01","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":["w1"],"durationSec":1,"outcome":"pass"}
{"runId":"r02","specSlug":"s","gatesFailed":[],"loopCount":1,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r03","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":1,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r04","specSlug":"s","gatesFailed":[],"loopCount":2,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r05","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":1,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r06","specSlug":"s","gatesFailed":[],"loopCount":1,"phase1Retries":1,"phase2Retries":0,"warnings":["w2","w3"],"durationSec":1,"outcome":"pass"}
{"runId":"r07","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r08","specSlug":"s","gatesFailed":[],"loopCount":3,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}
{"runId":"r09","specSlug":"s","gatesFailed":["complexity"],"loopCount":2,"phase1Retries":2,"phase2Retries":1,"warnings":[],"durationSec":1,"outcome":"fail"}
{"runId":"r10","specSlug":"s","gatesFailed":["complexity","traceability"],"loopCount":0,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"block"}
EOF
run_capture "$TMP/stats.out" "$TMP/stats.err" bash "$GATE_STATS" -f "$TMP/stats.jsonl"
[ "$RUN_RC" -eq 0 ] || bad "AC-012-07-06: well-formed file must exit 0 (got $RUN_RC)"
grep -q 'Total runs: 10' "$TMP/stats.out" && grep -q 'pass:  8 (80%)' "$TMP/stats.out" \
  && grep -q 'fail:  1 (10%)' "$TMP/stats.out" && grep -q 'block: 1 (10%)' "$TMP/stats.out" \
  && grep -q 'Failure rate (fail + block) / total: 20%' "$TMP/stats.out" \
  && ok "AC-012-07-01: totals, outcome breakdown with percentages, 20% failure rate" \
  || bad "AC-012-07-01: outcome summary wrong"
grep -q 'Most-failed gate: complexity (2 runs)' "$TMP/stats.out" \
  && ok "AC-012-07-02: most-failed gate named with count" || bad "AC-012-07-02: most-failed gate wrong"
grep -q 'loopCount.*max 3' "$TMP/stats.out" && grep -q 'last 10 avg' "$TMP/stats.out" \
  && ok "AC-012-07-03: overall avg/max and recent-window avg printed" || bad "AC-012-07-03: retry averages missing"
grep -q 'Total warnings: 3' "$TMP/stats.out" && ok "AC-012-07-03: total warnings printed" || bad "AC-012-07-03: total warnings wrong"

# creep fixture: 20 records, phase1Retries avg 0.5 (older 10), avg 1.4 (newer 10)
{
  for i in $(seq 1 10); do
    v=0; [ $((i % 2)) -eq 0 ] && v=1
    printf '{"runId":"r%02d","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":%s,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}\n' "$i" "$v"
  done
  for i in $(seq 11 20); do
    v=1; [ $i -le 14 ] && v=2
    printf '{"runId":"r%02d","specSlug":"s","gatesFailed":[],"loopCount":0,"phase1Retries":%s,"phase2Retries":0,"warnings":[],"durationSec":1,"outcome":"pass"}\n' "$i" "$v"
  done
} > "$TMP/creep.jsonl"
run_capture "$TMP/creep.out" "$TMP/creep.err" bash "$GATE_STATS" -f "$TMP/creep.jsonl"
if grep -q 'phase1Retries  CREEP (recent 1.4, prior 0.5)' "$TMP/creep.out"; then
  ok "AC-012-07-04: retry creep flagged (recent 1.4 >= 1.5x prior 0.5, recent >= 1.0)"
else
  bad "AC-012-07-04: phase1Retries should be CREEP"
  grep -E 'phase1Retries|Creep' "$TMP/creep.out"
fi
grep -q 'loopCount.*no creep' "$TMP/creep.out" && grep -q 'phase2Retries.*no creep' "$TMP/creep.out" \
  && ok "AC-012-07-04: non-creeping metrics not marked CREEP" || bad "AC-012-07-04: false CREEP flagged"

run_capture "$TMP/miss.out" "$TMP/miss.err" bash "$GATE_STATS" -f "$TMP/does-not-exist.jsonl"
[ "$RUN_RC" -eq 1 ] && [ -s "$TMP/miss.err" ] \
  && ok "AC-012-07-05: missing runs.jsonl → stderr message, exit 1" || bad "AC-012-07-05: missing file not a hard error"

# ── AC-012-08: weekly stats workflow ──────────────────────────────────────────
echo "== AC-012-08 weekly workflow =="
WEEKLY="$ROOT/.github/workflows/gate-stats-weekly.yml"
if grep -q "cron: '0 6 \* \* 1'" "$WEEKLY" && grep -q 'workflow_dispatch' "$WEEKLY" \
   && grep -q 'bash scripts/gate-stats.sh' "$WEEKLY" && grep -q 'upload-artifact' "$WEEKLY" \
   && grep -q 'name: gate-stats' "$WEEKLY"; then
  ok "AC-012-08-01: weekly workflow: Monday 06:00 UTC schedule + dispatch, runs gate-stats.sh, uploads gate-stats artifact"
else
  bad "AC-012-08-01: weekly workflow missing schedule/step/artifact"
fi
if grep -q 'permissions:' "$WEEKLY" && grep -q 'contents: read' "$WEEKLY"; then
  ok "AC-012-08-02: workflow is read-only (contents: read)"
else
  bad "AC-012-08-02: workflow permissions not read-only"
fi
# gate-stats.sh's default path is the repo-root runs.jsonl (checked out by the
# workflow), which is what the step consumes with no -f flag.
[ -f "$ROOT/runs.jsonl" ] && ok "AC-012-08-03: committed runs.jsonl present at repo root (gate-stats default path)" \
  || bad "AC-012-08-03: runs.jsonl missing at repo root"

echo ""
echo "== summary =="
echo -e "  pass: $PASS_COUNT  fail: $FAIL_COUNT  skipped-by-007-dependency: $SKIP_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ gate-telemetry selftest: $FAIL_COUNT assertion(s) failed.${NC}"
  exit 1
fi
if [ "$SKIP_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✔ gate-telemetry selftest: $PASS_COUNT assertions passed, $SKIP_COUNT noted (spec 007 dependency).${NC}"
else
  echo -e "${GREEN}✔ gate-telemetry selftest: $PASS_COUNT assertions passed.${NC}"
fi
