#!/bin/bash
# grade.sh — grade one workspace direction.
#
# Both runner/oracle.sh and runner/run-probes.sh build a workspace, apply the
# probe setup (and an optional overlay), run the verifier, then read the
# reward. Keeping that sequence in one place means the two callers cannot drift.

_apply_overlay() {
  local overlay="$1" workspace="$2"
  [ -n "$overlay" ] || return 0
  cp -a "$overlay/." "$workspace/"
  if [ -x "$overlay/mutations.sh" ]; then
    ( cd "$workspace" && EVAL_WORKSPACE="$workspace" bash "$overlay/mutations.sh" ) >/dev/null 2>&1 || true
  fi
}

# grade_workspace <task-dir> [overlay-dir] — build a throwaway workspace, apply
# probe setup and the overlay, grade, then destroy. Sets GRADE_REWARD and
# GRADE_FAILS (comma-joined FAIL names).
grade_workspace() {
  local task="$1" overlay="${2:-}" workspace out reward_file
  make_workspace "$task"
  workspace="$EVAL_WORKSPACE"
  apply_probe_setup "$task" "$workspace"
  _apply_overlay "$overlay" "$workspace"
  out="$(run_verifier "$task" "$workspace" 2>&1)" || true
  reward_file="$workspace/$(eval_task_field "$task" verifier.rewardFile)"
  GRADE_REWARD="$(sed -n '1p' "$reward_file" 2>/dev/null || echo 0)"
  GRADE_FAILS="$(printf '%s\n' "$out" | sed -n 's/^FAIL //p' | paste -sd, -)"
  destroy_workspace
}
