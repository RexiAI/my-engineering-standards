#!/bin/bash
# run-task.sh — drive the agent under test in a detached throwaway worktree,
# grade the result, and append exactly one runs.jsonl record.
#
#   run-task.sh [--runs-file FILE] <task-dir>
#
# Isolation contract:
#   * The workspace is a detached `git worktree` whose parent is a scratch
#     `git init` repository under the eval temp root — never the source
#     repository. Its common directory lives inside the eval temp root, so it
#     has no inherited `origin` and no path back to the source. This stays true
#     in both sandbox modes; the sandbox only changes where the agent process
#     runs.
#   * `EVAL_SANDBOX=docker` (the default) runs the agent in a minimal container
#     via `evals/lib/sandbox.sh`: only the eval temp root and the opencode
#     binary are mounted, so the source repository, the host home directory,
#     `/proc` ancestors, and the Docker socket are all outside its view. If
#     Docker or the pinned image is unavailable the runner exits 2 before
#     creating a workspace and appends nothing.
#   * `EVAL_SANDBOX=none` is an explicit hermetic-test opt-out: a stub binary
#     runs on the host and the run must not claim isolation.
#   * Inside either workspace the agent runs under `env -i` with a sanitized
#     allow-list: no host HOME, no XDG/GIT_CONFIG_*/GIT_DIR/GIT_WORK_TREE, and no
#     EVAL_* or source-root variable. HOME and TMPDIR point inside the eval temp
#     root, GIT_CEILING_DIRECTORIES is the eval temp root's parent, and the
#     source snapshots live in a separate random directory the agent never
#     receives a path to.
#   * The source repository's refs (including packed and remote-tracking),
#     reflog, status (including ignored files), hooks, info/exclude, and local
#     config are snapshotted before and after the run. Any difference means the
#     agent reached the source; the run is then an environment `block` and never
#     a `pass`.
#   * A trap removes the `eval` remote (defensively) and the whole temp root on
#     success, failure, and interrupt.
#
# Exit 0 iff the record's outcome is `pass`. Preflight failures (including an
# unavailable sandbox) exit 2 with no record. The runner never pushes, never
# grants blanket approval, and adds no `origin` remote.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${EVAL_REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export EVAL_REPO_ROOT="$REPO_ROOT"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/init.sh"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/record.sh"

RUNS_FILE="${EVAL_RUNS_FILE:-$REPO_ROOT/runs.jsonl}"
TASK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --runs-file|-f)
      RUNS_FILE="${2:-}"
      [ -n "$RUNS_FILE" ] || { echo "run-task: --runs-file requires a path" >&2; exit 2; }
      shift 2 ;;
    --*)
      echo "run-task: unknown option: $1" >&2; exit 2 ;;
    *)
      TASK="$1"; shift ;;
  esac
done

[ -n "$TASK" ] || { echo "usage: run-task.sh [--runs-file FILE] <task-dir>" >&2; exit 2; }
[ -d "$TASK" ] || { echo "run-task: task directory not found: $TASK" >&2; exit 2; }
TASK="$(cd "$TASK" && pwd)"

# ── Preflight (AC-043-46): no record is appended on failure. ────────────────
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"
if ! command -v "$OPENCODE_BIN" >/dev/null 2>&1; then
  echo "run-task: preflight failed: OPENCODE_BIN '$OPENCODE_BIN' is not executable or not on PATH" >&2
  exit 2
fi
OPENCODE_BIN="$(command -v "$OPENCODE_BIN")"
if ! "$OPENCODE_BIN" --version >/dev/null 2>&1; then
  echo "run-task: preflight failed: '$OPENCODE_BIN --version' exited non-zero" >&2
  exit 2
fi
# Fail closed: no sandbox, no record. This runs before any temp directory or
# workspace exists, so a missing Docker daemon or unbuilt image leaves the
# runs file untouched.
if ! sandbox_preflight; then
  echo "run-task: preflight failed: agent sandbox unavailable (environment block); nothing appended" >&2
  exit 2
fi

TASK_ID="$(eval_task_field "$TASK" id)"
AGENT="$(eval_task_field "$TASK" agent)"
TIMEOUT_SEC="$(eval_task_field "$TASK" timeoutSec)"
REWARD_FILE="$(eval_task_field "$TASK" verifier.rewardFile)"
if [ -z "$TASK_ID" ] || [ -z "$AGENT" ] || [ -z "$TIMEOUT_SEC" ] || [ -z "$REWARD_FILE" ]; then
  echo "run-task: $TASK: task.toml is missing id, agent, timeoutSec, or verifier.rewardFile" >&2
  exit 2
fi
if [ ! -s "$TASK/instruction.md" ]; then
  echo "run-task: $TASK: instruction.md is missing or empty" >&2
  exit 2
fi
INSTRUCTION="$(cat "$TASK/instruction.md")"

START_NS="$(date +%s%N)"
TMP_ROOT="$(mktemp -d)"
WT="$TMP_ROOT/wt"
# The source snapshots live in their own random directory outside the mounted
# temp root, so neither the host-mode agent nor the container can see them.
SNAP_DIR="$(mktemp -d)"
# $HOME and $TMPDIR live inside the mounted temp root so the container sees the
# same absolute paths, and outside the workspace so they are not part of grading.
AGENT_HOME="$TMP_ROOT/home"
AGENT_TMP="$TMP_ROOT/agent-tmp"
mkdir -p "$AGENT_HOME" "$AGENT_TMP"
SOURCE_BEFORE="$SNAP_DIR/source-before.txt"
SOURCE_AFTER="$SNAP_DIR/source-after.txt"
EVAL_TMP_ROOT="$TMP_ROOT"
export EVAL_TMP_ROOT

cleanup() {
  local code=$?
  trap - EXIT INT TERM HUP
  # Defensive: a previous runner version wrote `remote.eval` into the source
  # config and never removed it. The scratch parent never adds it, but cleanup
  # stays idempotent so a stale entry cannot survive a run.
  remove_eval_remote "$REPO_ROOT"
  [ -n "${TMP_ROOT:-}" ] && rm -rf "$TMP_ROOT"
  [ -n "${SNAP_DIR:-}" ] && rm -rf "$SNAP_DIR"
  [ -n "${AGENT_HOME:-}" ] && rm -rf "$AGENT_HOME"
  [ -n "${AGENT_TMP:-}" ] && rm -rf "$AGENT_TMP"
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ── Workspace (AC-043-45): detached worktree of a scratch parent. ──────────
# The scratch repo is seeded from the task's `environment/` and has no remote,
# so `git worktree add --detach` gives the agent a real worktree whose
# `.git` points only into the eval temp root. The source repository is never a
# parent, never a remote, and never a config source.
SCRATCH="$TMP_ROOT/scratch"
init_scratch_repo "$SCRATCH" "$TASK/environment"
add_detached_worktree "$SCRATCH" "$WT"
# Only the fixture and the agent files are agent-visible. The worktree is fresh,
# so it inherits no remote or shared config from the scratch parent.
cp -a "$REPO_ROOT/agents" "$WT/agents"
mkdir -p "$WT/.opencode"
ln -sfn ../agents "$WT/.opencode/agents"

# Q3: a per-run permission overlay. Verified against the pinned binary: the
# agent's markdown frontmatter wins for keys it defines, so this supplies
# absent keys only. See ADR 0022 §Notes.
python3 - "$WT/opencode.json" "$AGENT" <<'PY'
import json, os, sys
path, agent = sys.argv[1], sys.argv[2]
try:
    with open(path) as fh:
        data = json.load(fh)
except (OSError, ValueError):
    data = {"$schema": "https://opencode.ai/config.json"}
entry = data.setdefault("agent", {}).setdefault(agent, {})
# The agent markdown does not pin a model; the pipeline supplies it through
# `SPEC_<AGENT>_MODEL`. Setting it here keeps a real-agent run resolvable after
# the host's global config is no longer visible inside the container.
short = agent[len("spec-"):] if agent.startswith("spec-") else agent
model = os.environ.get("SPEC_" + short.upper().replace("-", "_") + "_MODEL", "")
if model:
    entry.setdefault("model", model)
entry["permission"] = {
    "edit": {
        "*": "allow",
        "**/check-code-principles.sh": "deny",
        "**/pmd*.xml": "deny",
        "**/*golangci*.yml": "deny",
        "**/.eslintrc*": "deny",
    },
    "bash": {"*": "allow"},
}
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

apply_probe_setup "$TASK" "$WT"

# ── Agent environment: sanitized allow-list, never the host's. ──────────────
# `env -i` starts empty; only these assignments are passed. HOME/TMPDIR point
# inside the eval temp root, so the agent cannot read the host's global config
# or write into the host's home. No EVAL_*, source-root, GIT_DIR,
# GIT_WORK_TREE, GIT_CONFIG_*, proxy, SSH-agent, or GitHub credential reaches
# the child. The model key is the one deliberate exception: a real-agent run
# cannot reach the LLM without it, and it carries no repository access.
# GIT_CEILING_DIRECTORIES is not inherited: it is set here to the eval temp
# root's parent so repository discovery cannot walk upward.
# GIT_ALLOW_PROTOCOL names no real protocol, so git refuses every transport
# (`file` included): an `origin` push has no remote to reach, and a direct push
# to any local path is rejected at the transport layer. A same-UID agent can
# unset the variable or pass `-c protocol.file.allow=always`, so the source
# snapshots below remain the fail-closed detection backstop.
if [ "$(sandbox_mode)" = "docker" ]; then
  AGENT_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
else
  AGENT_PATH="$PATH"
fi
AGENT_ENV=(
  "PATH=$AGENT_PATH"
  "HOME=$AGENT_HOME"
  "TMPDIR=$AGENT_TMP"
  "GIT_CEILING_DIRECTORIES=$(dirname "$TMP_ROOT")"
  "GIT_ALLOW_PROTOCOL=eval-no-transport"
)
ENV_ARGS=()
_forbidden_agent_var() {
  [ -n "${EVAL_PROBE_UNSET_ENV:-}" ] && grep -qxF "$1" <<< "$EVAL_PROBE_UNSET_ENV"
}
for assignment in "${AGENT_ENV[@]}"; do
  _forbidden_agent_var "${assignment%%=*}" || ENV_ARGS+=("$assignment")
done
while IFS= read -r assignment; do
  [ -n "$assignment" ] || continue
  _forbidden_agent_var "${assignment%%=*}" || ENV_ARGS+=("$assignment")
done <<< "${EVAL_PROBE_ENV:-}"

# Model credentials only, and only for a containerized real-agent run. GitHub
# tokens, proxy variables, and the SSH agent are never in this list.
if [ "$(sandbox_mode)" = "docker" ]; then
  for _name in OPENCODE_API_KEY OPENCODE_BASE_URL DEEPSEEK_API_KEY; do
    [ -n "${!_name:-}" ] || continue
    _forbidden_agent_var "$_name" || ENV_ARGS+=("$_name=${!_name}")
  done
  while IFS='=' read -r _name _value; do
    case "$_name" in
      SPEC_*_MODEL) _forbidden_agent_var "$_name" || ENV_ARGS+=("$_name=$_value") ;;
    esac
  done < <(env)
fi
unset _name _value 2>/dev/null || true

# ── Source snapshot: the real repository must be byte-identical afterwards. ──
snapshot_repo_state "$REPO_ROOT" > "$SOURCE_BEFORE" || true

# ── Invocation (AC-043-45): scoped approval, never blanket approval. ────────
# The sandbox changes where the process runs, not what the workspace is: the
# detached worktree and its common directory stay host-side under TMP_ROOT.
AGENT_STATUS=0
if [ "$(sandbox_mode)" = "docker" ]; then
  # shellcheck disable=SC2034  # read by sandbox_run in the sourced library
  SANDBOX_ENV=("${ENV_ARGS[@]}")
  ( cd "$WT" && sandbox_run "$TMP_ROOT" "$WT" "$OPENCODE_BIN" \
      env -i "${ENV_ARGS[@]}" timeout "$TIMEOUT_SEC" /usr/local/bin/opencode \
      run --agent "$AGENT" --title "eval: $TASK_ID" "$INSTRUCTION" ) \
    > "$WT/agent-output.txt" 2>&1 || AGENT_STATUS=$?
else
  ( cd "$WT" && env -i "${ENV_ARGS[@]}" timeout "$TIMEOUT_SEC" "$OPENCODE_BIN" \
      run --agent "$AGENT" --title "eval: $TASK_ID" "$INSTRUCTION" ) \
    > "$WT/agent-output.txt" 2>&1 || AGENT_STATUS=$?
fi

# ── Grading (AC-043-49): read the reward before cleanup. ────────────────────
REWARD_PATH="$WT/$REWARD_FILE"
GRADE_OUT="$(run_verifier "$TASK" "$WT" 2>&1)" || true
[ -n "$GRADE_OUT" ] && printf '%s\n' "$GRADE_OUT"
REWARD="$(sed -n '1p' "$REWARD_PATH" 2>/dev/null || echo 0)"
END_NS="$(date +%s%N)"
DURATION="$(awk -v s="$START_NS" -v e="$END_NS" 'BEGIN { printf "%.1f", (e - s) / 1000000000 }')"
GRADE_REASON="$(printf '%s\n' "$GRADE_OUT" | sed -n 's/^REASON=//p' | head -1)"

GATES="$(printf '%s\n' "$GRADE_OUT" | sed -n 's/^FAIL //p')"
WARNINGS="$(printf '%s\n' "$GRADE_OUT" | sed -n 's/^WARN //p')"
if [ "$AGENT_STATUS" -ne 0 ]; then
  WARNINGS="${WARNINGS}${WARNINGS:+$'\n'}agent exited with status $AGENT_STATUS"
fi

# ── Isolation check: any source mutation is a block, never a pass. ──────────
snapshot_repo_state "$REPO_ROOT" > "$SOURCE_AFTER" || true
ISOLATION_BREACH=false
if ! cmp -s "$SOURCE_BEFORE" "$SOURCE_AFTER"; then
  ISOLATION_BREACH=true
  echo "FAIL isolation-breach"
  EVAL_REWARD_FILE="$REWARD_PATH" write_reward 0 || true
  echo "REWARD=0"
  echo "REASON=isolation-breach"
  REWARD=0
  GATES="${GATES}${GATES:+$'\n'}isolation-breach"
  WARNINGS="${WARNINGS}${WARNINGS:+$'\n'}source repository changed during the run"
fi

if [ "$ISOLATION_BREACH" = true ]; then
  OUTCOME="block"
elif [ "$REWARD" = "1" ]; then
  OUTCOME="pass"
elif [ "$AGENT_STATUS" -eq 126 ] || [ "$AGENT_STATUS" -eq 127 ]; then
  OUTCOME="block"
else
  case "$GRADE_REASON" in
    verifier-timeout|verifier-exit-*) OUTCOME="block" ;;
    *) OUTCOME="fail" ;;
  esac
fi

# ── Record (AC-043-47/48): one append through the single writer. ────────────
export EVAL_RECORD_SLUG="eval-$TASK_ID"
export EVAL_RECORD_GATES="$GATES"
export EVAL_RECORD_WARNINGS="$WARNINGS"
export EVAL_RECORD_DURATION="$DURATION"
export EVAL_RECORD_OUTCOME="$OUTCOME"
RECORD="$(build_eval_record)"
if ! bash "$EVAL_REPO_ROOT/scripts/record-gate-run.sh" -record "$RECORD" -f "$RUNS_FILE"; then
  echo "run-task: record validation failed; nothing appended" >&2
  exit 1
fi

[ "$OUTCOME" = "pass" ] && exit 0
exit 1
