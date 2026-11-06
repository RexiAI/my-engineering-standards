#!/bin/bash
# record.sh — build an eval run's runs.jsonl record and append it through the
# repository's single writer, scripts/record-gate-run.sh.
#
# The schema is the existing one; eval runs are separated by the `eval-`
# specSlug prefix. This file never opens the .jsonl file itself.

EVAL_LIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_REPO_ROOT="${EVAL_REPO_ROOT:-$(cd "$EVAL_LIB_ROOT/../.." && pwd)}"
export EVAL_REPO_ROOT

# build_eval_record — read EVAL_RECORD_SLUG, EVAL_RECORD_GATES,
# EVAL_RECORD_WARNINGS, EVAL_RECORD_DURATION, EVAL_RECORD_OUTCOME and print
# one compact JSON object. List fields are newline-separated.
build_eval_record() {
  python3 - <<'PY'
import json, os
gates = [line for line in os.environ.get("EVAL_RECORD_GATES", "").splitlines() if line]
warnings = [line for line in os.environ.get("EVAL_RECORD_WARNINGS", "").splitlines() if line]
try:
    duration = round(float(os.environ.get("EVAL_RECORD_DURATION", "0")), 1)
except ValueError:
    duration = 0.0
print(json.dumps({
    "specSlug": os.environ.get("EVAL_RECORD_SLUG", ""),
    "gatesFailed": gates,
    "warnings": warnings,
    "durationSec": duration,
    "outcome": os.environ.get("EVAL_RECORD_OUTCOME", "block"),
}, separators=(",", ":")))
PY
}
