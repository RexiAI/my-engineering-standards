#!/usr/bin/env bash
# tests/AC-030-06.sh — T6: conditional model wiring (AC-030-06)
# The task is explicitly conditional (specs/030-e2e-skill-agent/10-tasks.md T6):
# it runs only if e2e-runner is added to opencode.json's agent block; if
# skipped, every scenario here is N/A and passes by default. Each test detects
# which branch the tree is on and judges that branch's requirement, so the
# suite is correct under either human decision.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
OC="opencode.json"
EXAMPLE="config/model.local.env.example"
VARS="scripts/model-env.vars.sh"

wired() { grep -qE '"e2e-runner"[[:space:]]*:' "$OC" 2>/dev/null; }

# AC-030-06-01 — opencode.json e2e-runner entry uses env reference
s_030_06_01() {
  if wired; then
    local line
    line="$(grep -E '"e2e-runner"[[:space:]]*:' "$OC" || true)"
    if printf '%s' "$line" | grep -q '"model": *"{env:SPEC_E2E_RUNNER_MODEL}"'; then
      pass "AC-030-06-01: e2e-runner entry is exactly the {env:SPEC_E2E_RUNNER_MODEL} reference"
    else
      fail "AC-030-06-01: e2e-runner entry model is '$line', expected {env:SPEC_E2E_RUNNER_MODEL}"
    fi
    if printf '%s' "$line" | grep -qiE "$ID_PATTERNS"; then
      fail "AC-030-06-01: literal model/provider id present in the e2e-runner entry"
    else
      pass "AC-030-06-01: no literal model/provider id in the e2e-runner entry"
    fi
  else
    pass "AC-030-06-01: N/A — task not executed (no e2e-runner entry in opencode.json); scenario passes by default per 10-tasks.md T6"
  fi
}

# AC-030-06-02 — config/model.local.env.example defines the var
s_030_06_02() {
  if wired; then
    if grep -qE '^SPEC_E2E_RUNNER_MODEL=.+' "$EXAMPLE"; then
      pass "AC-030-06-02: SPEC_E2E_RUNNER_MODEL defined with a default value"
    else
      fail "AC-030-06-02: SPEC_E2E_RUNNER_MODEL not defined in $EXAMPLE"
    fi
    # same comment+value pattern as other SPEC_*_MODEL entries: a comment line
    # mentioning the agent directly precedes the assignment
    if grep -B1 -E '^SPEC_E2E_RUNNER_MODEL=' "$EXAMPLE" | grep -qiE '#.*(e2e.?runner|bug.?bash)'; then
      pass "AC-030-06-02: definition follows the comment+value pattern"
    else
      fail "AC-030-06-02: definition lacks the leading comment used by sibling entries"
    fi
  else
    pass "AC-030-06-02: N/A — task not executed; scenario passes by default per 10-tasks.md T6"
  fi
}

# t6_wired_checks — the executed-branch assertions of AC-030-06-03, extracted
# to keep the scenario function under the ≤6 decision-point bound. Helper
# (not s_/u_-prefixed): never dispatched on its own, runs only when wired.
# `rook` gates the summary PASS on all three checks — preserve that coupling.
t6_wired_checks() {
  local rook=1
  grep -q 'SPEC_E2E_RUNNER_MODEL' <(grep -A20 'MODEL_ENV_VARS=' "$VARS") || { fail "AC-030-06-03: SPEC_E2E_RUNNER_MODEL not in MODEL_ENV_VARS"; rook=0; }
  grep -q 'e2e-runner' <(grep -A20 'MODEL_ENV_AGENTS=' "$VARS") || { fail "AC-030-06-03: e2e-runner not in MODEL_ENV_AGENTS"; rook=0; }
  if source "$VARS" 2>/dev/null && [ "$(model_env_var_for_agent e2e-runner)" = "SPEC_E2E_RUNNER_MODEL" ]; then
    pass "AC-030-06-03: model_env_var_for_agent maps e2e-runner -> SPEC_E2E_RUNNER_MODEL"
  else
    fail "AC-030-06-03: model_env_var_for_agent does not map e2e-runner"; rook=0
  fi
  if [ "$rook" = 1 ]; then pass "AC-030-06-03: roster arrays updated in $VARS"; fi
}

# AC-030-06-03 — scripts/model-env.vars.sh roster updated + gate green
s_030_06_03() {
  local rc=0
  bash scripts/check-model-env.sh >/tmp/ac030-06-modelenv.log 2>&1 || rc=$?
  if wired; then
    t6_wired_checks
  fi
  if [ "$rc" -eq 0 ]; then
    pass "AC-030-06-03: scripts/check-model-env.sh exits 0 (required in both branches)"
  else
    fail "AC-030-06-03: scripts/check-model-env.sh exited $rc — $(tail -3 /tmp/ac030-06-modelenv.log | tr '\n' ' ')"
  fi
}

# unit — wiring consistency: an entry may not exist in one wiring file without
# the others (no half-wired state, executed-branch or skipped-branch)
u_030_06_no_half_wiring() {
  local in_oc=0 in_ex=0 in_var=0
  grep -qE '"e2e-runner"[[:space:]]*:' "$OC" && in_oc=1
  grep -q '^SPEC_E2E_RUNNER_MODEL=' "$EXAMPLE" && in_ex=1
  grep -q 'SPEC_E2E_RUNNER_MODEL' "$VARS" && in_var=1
  if [ "$in_oc$in_ex$in_var" = "000" ] || [ "$in_oc$in_ex$in_var" = "111" ]; then
    pass "unit T6: wiring is consistent (all-three or none): oc=$in_oc ex=$in_ex vars=$in_var"
  else
    fail "unit T6: half-wired state oc=$in_oc ex=$in_ex vars=$in_var"
  fi
}

main_dispatch "030_06" "${1:-all}"
finish "AC-030-06"
