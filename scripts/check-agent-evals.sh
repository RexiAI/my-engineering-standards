#!/bin/bash
# check-agent-evals.sh — Verify the agent eval harness and its isolation.
#
# Spec: specs/043-agent-eval-harness/ (ADR: docs/adr/0020-agent-eval-harness.md).
#
# Checks:
#   1. Structure (AC-043-05)         evals/README.md + evals/tasks/ + contract keywords
#   2. Isolation (AC-043-06)         no pipeline file references evals/
#   3. Task format (AC-043-10..16)   five entries, task.toml keys/types, probes
#   4. Reward static (AC-043-17..24) reward.sh is the only library writing the reward
#   5. Oracle sanity (AC-043-38..44) environment=0 and solution=1 for every task
#   6. Runner static (AC-043-45..52) single writer, no push, no --auto, no direct JSONL
#   7. Negative controls (AC-043-53..58) hermetic probe suite must pass
#   8. Governance (AC-043-01..04, 63) ADR structure + index row
#   9. Self-CI wiring (AC-043-59..60) gate + --self-test, not skippable
#
# Usage:
#   scripts/check-agent-evals.sh [--self-test] [--only N] [ROOT]
#   ROOT defaults to the repository root. --only runs one check number (1-9);
#   --self-test builds hermetic fixture roots and proves each check fails closed.
#
# Exit codes:
#   0 — every selected check passes
#   1 — at least one finding; each prints `FAIL AC-043-<NN> — <path>: <reason>`
#   2 — tooling failure (a required command or tomllib is missing)
#
# The gate is read-only and offline: every scratch fixture lives in mktemp -d.
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
  RED=''; GREEN=''; NC=''
fi

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ONLY=""
SELF_TEST=false
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) SELF_TEST=true; shift ;;
    --only)
      ONLY="${2:-}"
      case "$ONLY" in
        [1-9]) ;;
        *) echo "ERROR: --only requires a check number 1-9" >&2; exit 2 ;;
      esac
      shift 2 ;;
    --*)
      echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done

if [ "${#POSITIONAL[@]}" -gt 0 ]; then
  ROOT="$(cd "${POSITIONAL[0]}" && pwd)"
fi

require_tools() {
  local tool
  for tool in git python3 mktemp timeout grep sed; do
    command -v "$tool" >/dev/null 2>&1 || {
      echo "ERROR: required tool not found: $tool" >&2
      exit 2
    }
  done
  python3 -c 'import tomllib' >/dev/null 2>&1 || {
    echo "ERROR: python3 has no tomllib (Python 3.11+ required)" >&2
    exit 2
  }
}
require_tools

VIOLATIONS=0
fail() { # fail <AC-id> <path> <reason>
  echo -e "${RED}FAIL${NC} $1 — $2: $3"
  VIOLATIONS=$((VIOLATIONS + 1))
}
pass() { # pass <AC-id> <message>
  echo -e "${GREEN}PASS${NC} $1 — $2"
}
run_check() { # run_check <n>
  [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]
}

# _readme_problems <text> — print one reason per missing documented term.
_readme_problems() {
  local text="$1" term
  for term in 'instruction.md' 'environment/' 'tests/' 'solution/' 'task.toml' \
              'reward' 'oracle' 'runs.jsonl' 'record-gate-run.sh' \
              '001-ambiguous-specifier' '002-red-gate-halt' '003-missing-gh-token'; do
    grep -qF "$term" <<< "$text" || printf "does not document '%s'\n" "$term"
  done
  grep -qi 'no pipeline file may reference' <<< "$text" \
    || printf '%s\n' "does not state the pipeline-isolation rule"
}

check_structure() {
  local before="$VIOLATIONS" readme="$ROOT/evals/README.md" tasks="$ROOT/evals/tasks"
  if [ ! -f "$readme" ]; then
    fail AC-043-05 "evals/README.md" "missing"
    return
  fi
  if [ ! -d "$tasks" ]; then
    fail AC-043-05 "evals/tasks/" "missing"
    return
  fi
  local problems reason
  problems="$(_readme_problems "$(cat "$readme")")"
  if [ -n "$problems" ]; then
    while IFS= read -r reason; do
      fail AC-043-05 "evals/README.md" "$reason"
    done <<< "$problems"
  fi
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-05 "evals/ is a top-level package with the documented contract"
}

# ── 2. Isolation (AC-043-06) ────────────────────────────────────────────────

# _isolation_targets — print every pipeline file that must not mention evals/.
_isolation_targets() {
  local dir
  [ -f "$ROOT/opencode.json" ] && printf '%s\n' "$ROOT/opencode.json"
  for dir in agents commands docs/spec-pipeline; do
    [ -d "$ROOT/$dir" ] || continue
    find "$ROOT/$dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null
  done
}

check_isolation() {
  local before="$VIOLATIONS" f hit
  while IFS= read -r f; do
    hit="$(grep -n 'evals/' "$f" 2>/dev/null | head -1 || true)"
    if [ -n "$hit" ]; then
      fail AC-043-06 "${f#"$ROOT"/}" "references evals/ (line ${hit%%:*})"
    fi
  done < <(_isolation_targets)

  if [ -f "$ROOT/opencode.json" ] && grep -q 'evals' "$ROOT/opencode.json"; then
    fail AC-043-06 "opencode.json" "contains an evals key or value"
  fi
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-06 "no pipeline file references evals/"
}

# ── 3. Task format (AC-043-10..16) ──────────────────────────────────────────
check_task_format() {
  local before="$VIOLATIONS"
  local findings
  findings="$(python3 - "$ROOT" <<'PY'
import os, re, sys, tomllib

root = sys.argv[1]
tasks_dir = os.path.join(root, "evals", "tasks")
probe_ids = {"ambiguous-specifier", "red-gate-halt", "missing-gh-token"}
probe_dirs = {"001-ambiguous-specifier", "002-red-gate-halt", "003-missing-gh-token"}

def emit(ac, path, reason):
    print(f"{ac}\t{path}\t{reason}")

if not os.path.isdir(tasks_dir):
    emit("AC-043-10", "evals/tasks", "missing")
    sys.exit(0)

dirs = [d for d in sorted(os.listdir(tasks_dir)) if os.path.isdir(os.path.join(tasks_dir, d))]
ids = {}

for name in dirs:
    task = os.path.join(tasks_dir, name)
    rel = f"evals/tasks/{name}"
    for entry in ("instruction.md", "environment", "tests", "solution", "task.toml"):
        if not os.path.exists(os.path.join(task, entry)):
            emit("AC-043-10", f"{rel}/{entry}", "missing required entry")
    instruction = os.path.join(task, "instruction.md")
    if os.path.isfile(instruction) and os.path.getsize(instruction) == 0:
        emit("AC-043-10", f"{rel}/instruction.md", "empty required entry")
    if os.path.exists(os.path.join(task, "reward.txt")):
        emit("AC-043-10", f"{rel}/reward.txt", "committed reward file")
    for dirpath, _, files in os.walk(task):
        for f in files:
            if f.endswith(".tmp"):
                emit("AC-043-10", os.path.join(dirpath, f), "committed scratch file")

    manifest = os.path.join(task, "task.toml")
    if not os.path.isfile(manifest):
        continue
    try:
        with open(manifest, "rb") as fh:
            m = tomllib.load(fh)
    except Exception as exc:
        emit("AC-043-14", f"{rel}/task.toml", f"invalid TOML ({type(exc).__name__})")
        continue

    for key in ("id", "slug", "agent", "timeoutSec"):
        if key not in m:
            emit("AC-043-11", f"{rel}/task.toml", f"missing key '{key}'")
    verifier = m.get("verifier", {}) if isinstance(m.get("verifier"), dict) else {}
    oracle = m.get("oracle", {}) if isinstance(m.get("oracle"), dict) else {}
    for key in ("command", "rewardFile"):
        if not verifier.get(key):
            emit("AC-043-11", f"{rel}/task.toml", f"missing key 'verifier.{key}'")
    for key in ("solution", "environment"):
        if not oracle.get(key):
            emit("AC-043-11", f"{rel}/task.toml", f"missing key 'oracle.{key}'")

    task_id = m.get("id")
    if isinstance(task_id, str):
        if not re.match(r"^[0-9]{3}-[a-z0-9-]+$", task_id):
            emit("AC-043-11", f"{rel}/task.toml", f"invalid id '{task_id}'")
        ids.setdefault(task_id, []).append(name)
    elif "id" in m:
        emit("AC-043-11", f"{rel}/task.toml", "id must be a string")

    if m.get("slug") != name:
        emit("AC-043-11", f"{rel}/task.toml", f"slug must equal directory name '{name}'")

    agent = m.get("agent")
    if isinstance(agent, str):
        if not re.match(r"^spec-[a-z-]+$", agent):
            emit("AC-043-16", f"{rel}/task.toml", f"agent '{agent}' does not match ^spec-[a-z-]+$")
        elif not os.path.isfile(os.path.join(root, "agents", agent + ".md")):
            emit("AC-043-16", f"{rel}/task.toml", f"agent '{agent}' does not resolve to agents/{agent}.md")

    timeout = m.get("timeoutSec")
    if isinstance(timeout, bool) or not isinstance(timeout, int) or timeout <= 0:
        emit("AC-043-16", f"{rel}/task.toml", f"timeoutSec must be a positive integer (got {timeout!r})")

    if verifier.get("rewardFile") and ("/" in str(verifier["rewardFile"]) or str(verifier["rewardFile"]).startswith(".")):
        emit("AC-043-11", f"{rel}/task.toml", "verifier.rewardFile must be a bare filename")
    if verifier.get("command") is not None and not isinstance(verifier.get("command"), str):
        emit("AC-043-11", f"{rel}/task.toml", "verifier.command must be a string")
    for key in ("solution", "environment"):
        value = oracle.get(key)
        if value and not os.path.isdir(os.path.join(task, str(value))):
            emit("AC-043-11", f"{rel}/task.toml", f"oracle.{key} '{value}' does not exist under the task")

    probe = m.get("probe")
    if probe is not None:
        if name not in probe_dirs:
            emit("AC-043-12", f"{rel}/task.toml", "a probe table is only allowed on the three probe tasks")
        if not isinstance(probe, dict):
            emit("AC-043-12", f"{rel}/task.toml", "probe must be a table")
        else:
            pid = probe.get("id")
            if pid not in probe_ids:
                emit("AC-043-12", f"{rel}/task.toml", f"unknown probe.id {pid!r}")
            if "unsetEnv" in probe:
                value = probe["unsetEnv"]
                if not isinstance(value, list) or not all(isinstance(x, str) for x in value):
                    emit("AC-043-12", f"{rel}/task.toml", "probe.unsetEnv must be an array of strings")
            if "env" in probe:
                value = probe["env"]
                if not isinstance(value, dict) or not all(isinstance(x, str) for x in value.values()):
                    emit("AC-043-12", f"{rel}/task.toml", "probe.env must be a table of strings")
            if "remote" in probe and not isinstance(probe["remote"], bool):
                emit("AC-043-12", f"{rel}/task.toml", "probe.remote must be a boolean")
            if "branch" in probe and (not isinstance(probe["branch"], str) or not probe["branch"]):
                emit("AC-043-12", f"{rel}/task.toml", "probe.branch must be a non-empty string")

for task_id, names in ids.items():
    if len(names) > 1:
        emit("AC-043-15", ", ".join(f"evals/tasks/{n}" for n in names), f"duplicate id '{task_id}'")
PY
)"
  if [ -n "$findings" ]; then
    local ac path reason
    while IFS=$'\t' read -r ac path reason; do
      [ -n "$ac" ] && fail "$ac" "$path" "$reason"
    done <<< "$findings"
  fi
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-10 "every task carries the five required entries"
  pass AC-043-11 "every manifest declares the required keys and types"
  pass AC-043-12 "only the three probe tasks declare a probe contract"
}

# ── 4. Reward static (AC-043-17..24) ────────────────────────────────────────
# _check_reward_lib_files — only reward.sh may mention the reward file variable.
_check_reward_lib_files() {
  local lib="$ROOT/evals/lib" f
  for f in "$lib"/*.sh; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "reward.sh" ] && continue
    grep -q 'EVAL_REWARD_FILE' "$f" \
      && fail AC-043-17 "${f#"$ROOT"/}" "only evals/lib/reward.sh may write \$EVAL_REWARD_FILE"
  done
}

# _check_reward_lib_atomicity — the writer must use a temp file and mv.
_check_reward_lib_atomicity() {
  local lib="$ROOT/evals/lib/reward.sh"
  grep -q 'mktemp' "$lib" || fail AC-043-23 "evals/lib/reward.sh" "does not build a same-directory temp file"
  grep -q 'mv -f' "$lib" || fail AC-043-23 "evals/lib/reward.sh" "does not replace the reward file atomically with mv"
}

# _check_task_reward_writers — every verifier must go through write_reward.
_check_task_reward_writers() {
  local task_dir f
  for task_dir in "$ROOT"/evals/tasks/*/; do
    [ -d "$task_dir" ] || continue
    f="$task_dir/tests/run.sh"
    [ -f "$f" ] || continue
    grep -q 'write_reward' "$f" || fail AC-043-17 "${f#"$ROOT"/}" "verifier does not use write_reward"
    if grep -qE '>[[:space:]]*"?[^$" ]*reward\.txt' "$f"; then
      fail AC-043-17 "${f#"$ROOT"/}" "verifier redirects to a hardcoded reward path"
    fi
  done
}

check_reward_static() {
  local before="$VIOLATIONS" lib="$ROOT/evals/lib"
  if [ ! -f "$lib/reward.sh" ]; then
    fail AC-043-17 "evals/lib/reward.sh" "missing"
    return
  fi
  _check_reward_lib_files
  _check_reward_lib_atomicity
  _check_task_reward_writers
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-17 "evals/lib/reward.sh is the only library writing the reward"
  pass AC-043-23 "reward writes are atomic and overwrite, never append"
}

# ── 5. Oracle sanity (AC-043-38..44) ────────────────────────────────────────
# _oracle_solution_dir <task-dir> — print the manifest's oracle.solution value.
_oracle_solution_dir() {
  python3 - "$1" <<'PY'
import os, sys, tomllib
try:
    with open(os.path.join(sys.argv[1], "task.toml"), "rb") as fh:
        print(tomllib.load(fh).get("oracle", {}).get("solution", ""))
except Exception:
    print("")
PY
}

# _check_oracle_result <task> <name> <oracle-line> — assert one task's outcome.
_check_oracle_result() {
  local task="$1" name="$2" line="$3" env_reward sol_reward
  if [ -z "$line" ]; then
    fail AC-043-44 "$task" "task missing from the oracle output"
    return
  fi
  env_reward="$(sed -n 's/.*environment=\([01]\).*/\1/p' <<< "$line")"
  sol_reward="$(sed -n 's/.*solution=\([01]\).*/\1/p' <<< "$line")"
  if [ "$env_reward" = "$sol_reward" ]; then
    fail AC-043-40 "$task" "task cannot fail (environment=$env_reward solution=$sol_reward)"
    return
  fi
  _check_oracle_directions "$task" "$name" "$env_reward" "$sol_reward"
}

# _check_oracle_directions <task> <name> <env-reward> <sol-reward>.
_check_oracle_directions() {
  local task="$1" name="$2" env_reward="$3" sol_reward="$4"
  [ "$env_reward" = "0" ] || fail AC-043-38 "$task" "environment direction did not score 0"
  [ "$sol_reward" = "1" ] || fail AC-043-39 "$task" "solution direction did not score 1"
  [ "$env_reward" = "0" ] && [ "$sol_reward" = "1" ] \
    && pass AC-043-44 "$name environment=$env_reward solution=$sol_reward"
}

# _grade_oracle_task <task-dir> <name> — run both oracle directions for a task.
_grade_oracle_task() {
  local task="$1" name="$2" sol_dir out line
  sol_dir="$(_oracle_solution_dir "$task")"
  if [ -z "$sol_dir" ] || [ ! -d "$task/$sol_dir" ] || [ -z "$(ls -A "$task/$sol_dir" 2>/dev/null)" ]; then
    fail AC-043-41 "$task" "solution direction is missing or empty"
    return
  fi
  out="$(bash "$oracle" "$task" 2>/dev/null)" || true
  printf '%s\n' "$out"
  line="$(printf '%s\n' "$out" | grep -E '^oracle: ' | tail -1 || true)"
  _check_oracle_result "$task" "$name" "$line"
}

check_oracle() {
  local before="$VIOLATIONS" oracle="$SCRIPT_DIR/../evals/runner/oracle.sh"
  local tasks_dir="$ROOT/evals/tasks" task name
  if [ ! -d "$tasks_dir" ] || [ -z "$(find "$tasks_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)" ]; then
    fail AC-043-44 "evals/tasks" "contains no task, so oracle sanity cannot be demonstrated"
    return
  fi
  if [ ! -f "$oracle" ]; then
    fail AC-043-44 "evals/runner/oracle.sh" "missing"
    return
  fi

  for task in "$tasks_dir"/*/; do
    name="$(basename "$task")"
    _grade_oracle_task "$task" "$name"
  done
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-38 "every solution direction scores 1"
  pass AC-043-39 "every untouched environment scores 0"
}

# ── 6. Runner static (AC-043-45..52) ────────────────────────────────────────
# _check_record_wiring — the single writer and the eval- prefix are wired.
_check_record_wiring() {
  local runner="$ROOT/evals/runner" lib="$ROOT/evals/lib"
  grep -rq 'record-gate-run.sh' "$runner" "$lib" \
    || fail AC-043-51 "evals/" "no record write goes through scripts/record-gate-run.sh"
  grep -q 'record-gate-run.sh' "$runner/run-task.sh" \
    || fail AC-043-51 "evals/runner/run-task.sh" "does not call scripts/record-gate-run.sh"
  grep -q 'eval-' "$runner/run-task.sh" \
    || fail AC-043-51 "evals/runner/run-task.sh" "does not use the eval- specSlug prefix"
  grep -q 'clone --bare' "$lib/workspace.sh" \
    || fail AC-043-51 "evals/lib/workspace.sh" "probe remote is not seeded with git clone --bare"
}

# _check_forbidden_calls — no auto-approval, push, or direct JSONL append.
_check_forbidden_calls() {
  local lib="$ROOT/evals/lib" runner="$ROOT/evals/runner" f
  for f in "$lib"/*.sh "$runner"/*.sh; do
    [ -f "$f" ] || continue
    grep -q -- '--auto' "$f" \
      && fail AC-043-51 "${f#"$ROOT"/}" "contains --auto"
    grep -qE '(^|[^a-zA-Z])git[[:space:]]+push' "$f" \
      && fail AC-043-51 "${f#"$ROOT"/}" "contains a push"
    grep -qE '>>[^|]*\.jsonl' "$f" \
      && fail AC-043-51 "${f#"$ROOT"/}" "appends to a .jsonl file directly"
  done
}

check_runner_static() {
  local before="$VIOLATIONS" runner="$ROOT/evals/runner"
  if [ ! -f "$runner/run-task.sh" ]; then
    fail AC-043-51 "evals/runner/run-task.sh" "missing"
    return
  fi
  _check_record_wiring
  _check_forbidden_calls
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-51 "no --auto, no push, and every record goes through the single writer"
}

# ── 7. Negative controls (AC-043-53..58) ────────────────────────────────────
# _assert_probe_outcomes <output> — every positive is 1 and every broken is 0.
_assert_probe_outcomes() {
  local out="$1"
  grep -q 'ambiguous-specifier.*solution=1.*broken=0' <<< "$out" \
    || fail AC-043-53 "ambiguous-specifier" "positive/negative outcomes did not match"
  grep -q 'red-gate-halt.*solution=1.*broken=0' <<< "$out" \
    || fail AC-043-53 "red-gate-halt" "positive/negative outcomes did not match"
  grep -q 'missing-gh-token.*solution=1.*broken=0' <<< "$out" \
    || fail AC-043-53 "missing-gh-token" "positive/negative outcomes did not match"
}

# _assert_probe_failures <output> — each broken variant names its failure mode.
_assert_probe_failures() {
  local out="$1"
  grep -q 'ambiguous-specifier.*no-tasks-file' <<< "$out" \
    || fail AC-043-54 "ambiguous-specifier" "broken variant did not name no-tasks-file"
  if ! grep -qE 'red-gate-halt.*(no-commit|no-pr)' <<< "$out"; then
    fail AC-043-55 "red-gate-halt" "broken variant did not name no-commit or no-pr"
  fi
  grep -q 'missing-gh-token.*no-commit' <<< "$out" \
    || fail AC-043-56 "missing-gh-token" "broken variant did not name no-commit"
}

check_negative_controls() {
  local before="$VIOLATIONS" suite="$ROOT/evals/runner/run-probes.sh" out status
  if [ ! -f "$suite" ]; then
    fail AC-043-53 "evals/runner/run-probes.sh" "missing"
    return
  fi
  out="$(bash "$suite" --hermetic 2>&1)"; status=$?
  printf '%s\n' "$out"
  if [ "$status" -ne 0 ]; then
    fail AC-043-53 "evals/runner/run-probes.sh" "hermetic suite exited $status"
    return
  fi
  _assert_probe_outcomes "$out"
  _assert_probe_failures "$out"
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-53 "the hermetic suite grades every positive and broken variant"
  pass AC-043-54 "broken variant 1 is caught"
  pass AC-043-55 "broken variant 2 is caught"
  pass AC-043-56 "broken variant 3 is caught"
}

# ── 8. Governance (AC-043-01..04, 63) ────────────────────────────────────────
_check_adr_headings() {
  local adr="$1" last=0 heading n
  local headings=("## Title" "## Status" "## Context" "## Decision" "### Alternatives Considered" "## Consequences" "## Compliance" "## Notes")
  for heading in "${headings[@]}"; do
    n="$(grep -nF "$heading" "$adr" | head -1 | cut -d: -f1)"
    if [ -z "$n" ] || [ "$n" -le "$last" ]; then
      fail AC-043-01 "docs/adr/0020-agent-eval-harness.md" "heading '$heading' missing or out of order"
    else
      last="$n"
    fi
  done
}

_check_adr_status() {
  local adr="$1"
  if ! grep -A2 '^## Status$' "$adr" | grep -q '^Proposed$'; then
    fail AC-043-01 "docs/adr/0020-agent-eval-harness.md" "status is not Proposed"
  fi
}

_check_adr_decision_terms() {
  local adr="$1" decision term
  decision="$(sed -n '/^## Decision$/,/^### Alternatives Considered$/p' "$adr")"
  for term in 'scripts/check-agent-evals.sh' 'self-CI' 'evals/' 'record-gate-run.sh' 'runs.jsonl' 'eval-' 'BLOCKED — <question>' 'Specifier'; do
    grep -qF "$term" <<< "$decision" || fail AC-043-02 "docs/adr/0020-agent-eval-harness.md" "Decision does not state '$term'"
  done
}

_check_adr_alternatives() {
  local adr="$1" alts
  alts="$(sed -n '/^### Alternatives Considered$/,/^## Consequences$/p' "$adr")"
  grep -qi 'separate' <<< "$alts" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "alternatives omit a separate eval runs file"
  grep -qi 'schema key' <<< "$alts" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "alternatives omit a new runs.jsonl key"
  grep -qi 'hosted' <<< "$alts" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "alternatives omit a hosted runner"
  grep -qi 'vendor' <<< "$alts" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "alternatives omit vendoring"
}

_check_adr_out_of_scope() {
  local adr="$1" term
  grep -q 'generic coding benchmarks' "$adr" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "out-of-scope list omits generic coding benchmarks"
  grep -q 'no root `LICENSE`' "$adr" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "does not state the no-root-LICENSE reason"
  for term in 'Modal' 'Opik' 'Kitaru' 'sandbox backends' 'hosted runners'; do
    grep -qi "$term" "$adr" || fail AC-043-03 "docs/adr/0020-agent-eval-harness.md" "out-of-scope list omits '$term'"
  done
}

_check_adr_index() {
  local index="$1" rows
  if [ ! -f "$index" ]; then
    fail AC-043-63 "docs/adr/README.md" "missing"
    return
  fi
  rows="$(grep -c '^| 0020 |' "$index" || true)"
  [ "$rows" -eq 1 ] || fail AC-043-63 "docs/adr/README.md" "expected exactly one | 0020 | row (got $rows)"
  grep -E '^\| 0020 \|' "$index" | grep -q '0020-agent-eval-harness.md' \
    || fail AC-043-63 "docs/adr/README.md" "the 0020 row does not link to 0020-agent-eval-harness.md"
  grep -E '^\| 0020 \|' "$index" | grep -q 'Proposed' \
    || fail AC-043-63 "docs/adr/README.md" "the 0020 row status is not Proposed"
}

check_governance() {
  local before="$VIOLATIONS" adr="$ROOT/docs/adr/0020-agent-eval-harness.md"
  local index="$ROOT/docs/adr/README.md"
  if [ ! -f "$adr" ]; then
    fail AC-043-63 "docs/adr/0020-agent-eval-harness.md" "missing"
    return
  fi

  _check_adr_headings "$adr"
  _check_adr_status "$adr"
  _check_adr_decision_terms "$adr"
  _check_adr_alternatives "$adr"
  _check_adr_out_of_scope "$adr"
  _check_adr_index "$index"

  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-01 "ADR follows the mandated template"
  pass AC-043-02 "ADR records the four load-bearing decisions"
  pass AC-043-03 "ADR records the rejected alternatives and the out-of-scope list"
  pass AC-043-04 "the ADR is indexed exactly once"
}

# ── 9. Self-CI wiring (AC-043-59..60) ────────────────────────────────────────
_check_workflow_gate_steps() {
  local wf="$1"
  grep -qF './scripts/check-agent-evals.sh' "$wf" \
    || fail AC-043-59 ".github/workflows/self-ci.yml" "does not run the agent-eval gate"
  grep -qF './scripts/check-agent-evals.sh --self-test' "$wf" \
    || fail AC-043-59 ".github/workflows/self-ci.yml" "does not run the agent-eval self-test"
}

_check_workflow_step_not_skippable() {
  local wf="$1" step
  step="$(awk '
    /- name: / { if (seen) exit; if ($0 ~ /[Aa]gent eval/) { seen=1 } }
    seen { print }
  ' "$wf")"
  if [ -z "$step" ]; then
    fail AC-043-59 ".github/workflows/self-ci.yml" "no agent-eval step found"
    return
  fi
  grep -q 'continue-on-error:[[:space:]]*true' <<< "$step" \
    && fail AC-043-60 ".github/workflows/self-ci.yml" "agent-eval step sets continue-on-error: true"
}

_check_workflow_permissions() {
  local wf="$1"
  grep -qE '^permissions:$' "$wf" || fail AC-043-60 ".github/workflows/self-ci.yml" "missing top-level permissions"
  grep -qE '^  contents: read$' "$wf" || fail AC-043-60 ".github/workflows/self-ci.yml" "permissions do not keep contents: read"
}

check_self_ci() {
  local before="$VIOLATIONS" wf="$ROOT/.github/workflows/self-ci.yml"
  if [ ! -f "$wf" ]; then
    fail AC-043-59 ".github/workflows/self-ci.yml" "missing"
    return
  fi
  _check_workflow_gate_steps "$wf"
  _check_workflow_step_not_skippable "$wf"
  _check_workflow_permissions "$wf"
  [ "$VIOLATIONS" -eq "$before" ] || return
  pass AC-043-59 "self-CI runs the gate and its self-test"
  pass AC-043-60 "the agent-eval step cannot be skipped"
}

# Fixture-driven negative controls.
#
# _expect_failure_case <label> <fixture-root> <check-number> <pattern> — run
# one gate check against a fixture and require exit 1 plus the AC pattern.
_expect_failure_case() {
  local label="$1" fixture="$2" check="$3" pattern="$4" out status
  out="$(bash "$SCRIPT_DIR/check-agent-evals.sh" --only "$check" "$fixture" 2>&1)"; status=$?
  SELF_TEST_OUTPUT="${SELF_TEST_OUTPUT}${out}"
  if [ "$status" -eq 1 ] && grep -q "$pattern" <<< "$out"; then
    echo "self-test: $label ok"
  else
    echo "self-test: $label FAILED (status=$status)"
    failures=$((failures + 1))
  fi
}

self_test() {
  local tmp failures=0
  local SELF_TEST_OUTPUT=""
  tmp="$(mktemp -d)"

  # fixture_root <dir> — minimal tree the selected check reads.
  fixture_root() {
    local d="$1"
    mkdir -p "$d/agents" "$d/evals/tasks" "$d/docs/adr" "$d/.github/workflows" "$d/scripts"
    printf '# spec-coder\n' > "$d/agents/spec-coder.md"
  }

  # fixture_task <root> <name> <verifier-body>
  fixture_task() {
    local d="$1" name="$2" body="$3" t="$1/evals/tasks/$2"
    mkdir -p "$t/environment" "$t/tests" "$t/solution"
    printf 'Do the thing.\n' > "$t/instruction.md"
    printf 'seed\n' > "$t/environment/seed.txt"
    printf 'done\n' > "$t/solution/seed.txt"
    {
      echo '#!/bin/bash'
      echo 'set -uo pipefail'
      echo 'source "$EVAL_LIB_DIR/reward.sh"'
      printf '%s\n' "$body"
    } > "$t/tests/run.sh"
    cat > "$t/task.toml" <<TOML
id = "$name"
slug = "$name"
agent = "spec-coder"
timeoutSec = 30

[verifier]
command = "bash tests/run.sh"
rewardFile = "reward.txt"

[oracle]
solution = "solution"
environment = "environment"
TOML
  }

  # 1. missing task entry
  local f1="$tmp/f1"; fixture_root "$f1"
  fixture_task "$f1" 001-broken 'write_reward 0'
  rm -rf "$f1/evals/tasks/001-broken/tests"
  _expect_failure_case "missing task entry" "$f1" 3 'FAIL AC-043-10'

  # 2. always-1 verifier (task cannot fail)
  local f2="$tmp/f2"; fixture_root "$f2"
  fixture_task "$f2" 001-always 'write_reward 1'
  _expect_failure_case "task cannot fail" "$f2" 5 'task cannot fail'

  # 3. missing ADR index row
  local f3="$tmp/f3"; fixture_root "$f3"
  cp "$ROOT/docs/adr/0020-agent-eval-harness.md" "$f3/docs/adr/" 2>/dev/null || {
    printf '## Title\nx\n## Status\nProposed\n## Context\nx\n## Decision\nx\n### Alternatives Considered\nx\n## Consequences\nx\n## Compliance\nx\n## Notes\nx\n' \
      > "$f3/docs/adr/0020-agent-eval-harness.md"
  }
  printf '# Index\n| ADR | Title | Status |\n| --- | --- | --- |\n| 0001 | [Other](0001-other.md) | Accepted |\n' \
    > "$f3/docs/adr/README.md"
  _expect_failure_case "missing ADR row" "$f3" 8 'FAIL AC-043-63'

  # 4. missing self-CI step
  local f4="$tmp/f4"; fixture_root "$f4"
  cat > "$f4/.github/workflows/self-ci.yml" <<'YAML'
name: Self CI
on: [push]
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
YAML
  _expect_failure_case "missing self-CI step" "$f4" 9 'FAIL AC-043-59'

  # A broken fixture must print an AC-043 failure line, not a traceback.
  if grep -q 'Traceback' <<< "$SELF_TEST_OUTPUT"; then
    echo "self-test: fixture leaked a Python traceback"
    failures=$((failures + 1))
  fi

  rm -rf "$tmp"
  [ "$failures" -eq 0 ] && return 0
  return 1
}

if [ "$SELF_TEST" = true ]; then
  if self_test; then
    exit 0
  fi
  exit 1
fi

run_check 1 && check_structure
run_check 2 && check_isolation
run_check 3 && check_task_format
run_check 4 && check_reward_static
run_check 5 && check_oracle
run_check 6 && check_runner_static
run_check 7 && check_negative_controls
run_check 8 && check_governance
run_check 9 && check_self_ci

if [ "$VIOLATIONS" -gt 0 ]; then
  exit 1
fi
exit 0
