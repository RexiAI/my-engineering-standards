#!/bin/bash
# reward.sh — the single-reward contract for eval tasks.
#
# A task verifier writes exactly one reward on every exit path, but the
# harness never trusts it: run_verifier normalizes a crash, a timeout, a
# missing value, multiple values, or an invalid value to reward 0 and reports
# one REASON token. The only writer is write_reward, which replaces the file
# atomically in its own directory.
#
# Usage, from a verifier (EVAL_LIB_DIR and EVAL_REWARD_FILE are exported by
# run_verifier):
#   source "$EVAL_LIB_DIR/reward.sh"
#   write_reward 1
#
# Usage, from a runner / oracle:
#   source "$EVAL_LIB_DIR/reward.sh"
#   run_verifier <task-dir> <workspace>

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/task.sh"

# _valid_reward <value> — true only for the two legal reward values.
_valid_reward() {
  case "${1:-}" in
    0|1) return 0 ;;
    *) return 1 ;;
  esac
}

# _replace_reward_file <0|1> — same-directory temp file plus atomic mv.
_replace_reward_file() {
  local value="$1" dir tmp
  dir="$(dirname "$EVAL_REWARD_FILE")"
  mkdir -p "$dir" || return 1
  tmp="$(mktemp "$dir/.reward.XXXXXX")" || return 1
  printf '%s\n' "$value" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$EVAL_REWARD_FILE" || { rm -f "$tmp"; return 1; }
}

# write_reward <0|1> — atomically replace $EVAL_REWARD_FILE with one value.
write_reward() {
  local value="${1:-}"
  if ! _valid_reward "$value"; then
    echo "write_reward: reward must be 0 or 1 (got '$value')" >&2
    return 1
  fi
  if [ -z "${EVAL_REWARD_FILE:-}" ]; then
    echo "write_reward: EVAL_REWARD_FILE is not set" >&2
    return 1
  fi
  _replace_reward_file "$value"
}

# reward_values <file> — one normalized value per line; blank lines dropped.
reward_values() {
  sed -e 's/[[:space:]]*$//' "$1" 2>/dev/null | grep -E '.' || true
}

# _reward_lib_dir — this library's directory.
_reward_lib_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# _verifier_manifest_invalid <command> <reward-file> <timeout> — true when any
# required manifest field is empty.
_verifier_manifest_invalid() {
  [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
}

# _classify_reward_values <values> — classify the one-value-per-line reward text.
_classify_reward_values() {
  local values="$1" count
  count="$(printf '%s\n' "$values" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    echo "0|invalid-reward-value|false"
    return
  fi
  if [ "$count" -gt 1 ]; then
    echo "0|multiple-reward-values|false"
    return
  fi
  case "$values" in
    0|1) printf '%s||true\n' "$values" ;;
    *) echo "0|invalid-reward-value|false" ;;
  esac
}

# _classify_reward_file <file> — classify a verifier that exited 0. Prints
# `final|reason|clean`; a missing reward also warns on stderr.
_classify_reward_file() {
  local reward="$1"
  if [ ! -e "$reward" ]; then
    echo "WARN verifier wrote no reward" >&2
    echo "0|no-reward-value|false"
    return
  fi
  _classify_reward_values "$(reward_values "$reward")"
}

# _classify_verifier <exit-status> <reward-file> — print `final|reason|clean`.
_classify_verifier() {
  local status="$1" reward="$2"
  if [ "$status" -eq 124 ]; then
    echo "0|verifier-timeout|false"
    return
  fi
  if [ "$status" -ne 0 ]; then
    echo "0|verifier-exit-$status|false"
    return
  fi
  _classify_reward_file "$reward"
}

# run_verifier <task-dir> <workspace> — run the manifest verifier and
# normalize its outcome. Prints REWARD=<0|1> and, on a non-passing path,
# exactly one REASON=<token> line. Returns 0 only when the verifier exited 0
# and wrote exactly one valid value (the value may itself be 0).
run_verifier() {
  local task="$1" workspace="$2"
  local command reward_file timeout_sec reward output status
  command="$(eval_task_field "$task" verifier.command)"
  reward_file="$(eval_task_field "$task" verifier.rewardFile)"
  timeout_sec="$(eval_task_field "$task" timeoutSec)"
  if _verifier_manifest_invalid "$command" "$reward_file" "$timeout_sec"; then
    echo "REWARD=0"
    echo "REASON=invalid-manifest"
    return 1
  fi

  reward="$workspace/$reward_file"
  rm -f "$reward"
  local lib_dir
  lib_dir="$(_reward_lib_dir)"
  export EVAL_WORKSPACE="$workspace"
  export EVAL_REWARD_FILE="$reward"
  export EVAL_LIB_DIR="$lib_dir"

  status=0
  output="$( cd "$task" && timeout "$timeout_sec" bash -c "$command" 2>&1 )" || status=$?
  [ -n "$output" ] && printf '%s\n' "$output"

  local final reason clean
  IFS='|' read -r final reason clean < <(_classify_verifier "$status" "$reward")

  write_reward "$final"
  echo "REWARD=$final"
  if [ "$clean" = true ]; then
    return 0
  fi
  echo "REASON=$reason"
  return 1
}
