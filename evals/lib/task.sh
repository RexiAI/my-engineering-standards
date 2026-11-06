#!/bin/bash
# task.sh — read an eval task's task.toml. Sourced by the eval libraries.
#
# Parsing uses Python 3's tomllib (the task format contract in
# evals/README.md): the gate fails with exit 2 when tomllib is unavailable.
# This file is read-only and writes no file.

# eval_task_json <task-dir> — print the manifest as one compact JSON object.
eval_task_json() {
  local task="$1"
  python3 - "$task" <<'PY'
import json, os, sys, tomllib
task = sys.argv[1]
manifest = os.path.join(task, "task.toml")
with open(manifest, "rb") as fh:
    print(json.dumps(tomllib.load(fh), sort_keys=True))
PY
}

# eval_task_field <task-dir> <dotted.key> — print one scalar manifest value.
# Nested tables use dots (`verifier.command`). A missing path prints nothing
# and exits 0 so callers can test for emptiness.
eval_task_field() {
  local task="$1" path="$2"
  python3 - "$task" "$path" <<'PY'
import os, sys, tomllib
task, path = sys.argv[1], sys.argv[2]
with open(os.path.join(task, "task.toml"), "rb") as fh:
    value = tomllib.load(fh)
for part in path.split("."):
    if not isinstance(value, dict) or part not in value:
        sys.exit(0)
    value = value[part]
if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (str, int, float)):
    print(value)
PY
}
