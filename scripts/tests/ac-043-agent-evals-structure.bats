#!/usr/bin/env bats
# ac-043-agent-evals-structure.bats — acceptance tests for spec 043 Tasks 1-3
# and 10 (specs/043-agent-eval-harness/20-acceptance/AC-043-adr.md,
# AC-043-package-isolation.md, AC-043-task-format.md, AC-043-ci-gate.md).
#
# The gate under test is scripts/check-agent-evals.sh. Every fixture root is a
# mktemp tree; the real repository is only read.

load test_helper
bats_require_minimum_version 1.5.0

GATE="$REPO_ROOT/scripts/check-agent-evals.sh"
ADR="$REPO_ROOT/docs/adr/0020-agent-eval-harness.md"
ADR_INDEX="$REPO_ROOT/docs/adr/README.md"
WORKFLOW="$REPO_ROOT/.github/workflows/self-ci.yml"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# write_valid_task <root> <dir-name> [toml-extra] — a structurally valid task.
write_valid_task() {
  local root="$1" name="$2" extra="${3:-}"
  local t="$root/evals/tasks/$name"
  mkdir -p "$t/environment" "$t/tests" "$t/solution"
  printf 'Do the thing.\n' > "$t/instruction.md"
  printf 'seed\n' > "$t/environment/seed.txt"
  printf 'done\n' > "$t/solution/seed.txt"
  cat > "$t/tests/run.sh" <<'VERIFIER'
#!/bin/bash
set -uo pipefail
source "$EVAL_LIB_DIR/reward.sh"
write_reward 0
VERIFIER
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
$extra
TOML
}

fixture_root() {
  local root="$TMPDIR_HELPER/root"
  mkdir -p "$root/agents" "$root/evals/tasks" "$root/docs/adr" \
           "$root/.github/workflows" "$root/scripts"
  printf '# spec-coder\n' > "$root/agents/spec-coder.md"
  echo "$root"
}

# ── Task 1: ADR ─────────────────────────────────────────────────────────────

@test "AC-043-01: ADR follows the mandated template in order and is Proposed" {
  [ -f "$ADR" ]
  local n_title n_status n_context n_decision n_alt n_cons n_comp n_notes
  n_title=$(grep -n '^## Title$' "$ADR" | cut -d: -f1)
  n_status=$(grep -n '^## Status$' "$ADR" | cut -d: -f1)
  n_context=$(grep -n '^## Context$' "$ADR" | cut -d: -f1)
  n_decision=$(grep -n '^## Decision$' "$ADR" | cut -d: -f1)
  n_alt=$(grep -n '^### Alternatives Considered$' "$ADR" | cut -d: -f1)
  n_cons=$(grep -n '^## Consequences$' "$ADR" | cut -d: -f1)
  n_comp=$(grep -n '^## Compliance$' "$ADR" | cut -d: -f1)
  n_notes=$(grep -n '^## Notes$' "$ADR" | cut -d: -f1)
  [ "$n_title" -lt "$n_status" ]
  [ "$n_status" -lt "$n_context" ]
  [ "$n_context" -lt "$n_decision" ]
  [ "$n_decision" -lt "$n_alt" ]
  [ "$n_alt" -lt "$n_cons" ]
  [ "$n_cons" -lt "$n_comp" ]
  [ "$n_comp" -lt "$n_notes" ]
  grep -q '^Proposed$' <(sed -n "/^## Status$/,/^## /p" "$ADR")
}

@test "AC-043-02: ADR records the four load-bearing decisions" {
  local decision
  decision=$(sed -n '/^## Decision$/,/^### Alternatives Considered$/p' "$ADR")
  grep -q 'scripts/check-agent-evals.sh' <<< "$decision"
  grep -q 'self-CI' <<< "$decision"
  grep -q 'evals/' <<< "$decision"
  grep -q 'pipeline never' <<< "$decision"
  grep -q 'record-gate-run.sh' <<< "$decision"
  grep -q 'runs.jsonl' <<< "$decision"
  grep -q 'eval-' <<< "$decision"
  grep -q 'BLOCKED — &lt;question&gt;\|BLOCKED — <question>' <<< "$decision"
  grep -q 'Specifier' <<< "$decision"
}

@test "AC-043-03: ADR records rejected alternatives and the out-of-scope list" {
  local alts
  alts=$(sed -n '/^### Alternatives Considered$/,/^## Consequences$/p' "$ADR")
  grep -qi 'separate' <<< "$alts"
  grep -qi 'schema key\|new key\|new `runs.jsonl`' <<< "$alts"
  grep -qi 'hosted' <<< "$alts"
  grep -qi 'vendor' <<< "$alts"
  grep -q 'generic coding benchmarks' "$ADR"
  grep -qi 'no root `LICENSE`' "$ADR"
  grep -q 'Modal' "$ADR"
  grep -q 'Opik' "$ADR"
  grep -q 'Kitaru' "$ADR"
  grep -qi 'sandbox backends' "$ADR"
  grep -qi 'hosted runners' "$ADR"
}

@test "AC-043-04: the ADR is indexed exactly once and governance passes" {
  [ "$(grep -c '^| 0020 |' "$ADR_INDEX")" -eq 1 ]
  grep -E '^\| 0020 \|' "$ADR_INDEX" | grep -q '0020-agent-eval-harness.md'
  grep -E '^\| 0020 \|' "$ADR_INDEX" | grep -q 'Proposed'
  run bash "$REPO_ROOT/scripts/check-governance.sh"
  [ "$status" -eq 0 ]
}

# ── Task 2: package + isolation ─────────────────────────────────────────────

@test "AC-043-05: evals/ is a top-level package with the documented contract" {
  [ -f "$REPO_ROOT/evals/README.md" ]
  [ -d "$REPO_ROOT/evals/tasks" ]
  local readme
  readme=$(cat "$REPO_ROOT/evals/README.md")
  for term in 'instruction.md' 'environment/' 'tests/' 'solution/' 'task.toml' \
              'reward' 'oracle' 'runs.jsonl' 'record-gate-run.sh' \
              '001-ambiguous-specifier' '002-red-gate-halt' '003-missing-gh-token'; do
    grep -qF "$term" <<< "$readme"
  done
  grep -qi 'no pipeline file may reference' <<< "$readme"
}

@test "AC-043-06: the pipeline surface never references evals" {
  local hits
  hits=$(grep -rn 'evals/' "$REPO_ROOT/opencode.json" "$REPO_ROOT/agents" \
           "$REPO_ROOT/commands" "$REPO_ROOT/docs/spec-pipeline" 2>/dev/null || true)
  [ -z "$hits" ]
  ! grep -q 'evals' "$REPO_ROOT/opencode.json"
}

@test "AC-043-07: the gate follows the check-script conventions" {
  [ -x "$GATE" ]
  run bash "$GATE"
  [ "$status" -eq 0 ]
  # A scratch root with no evals/ is a finding, never a shell abort.
  local root="$TMPDIR_HELPER/empty"
  mkdir -p "$root"
  run bash "$GATE" "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-'* ]]
  [[ "$output" == *'evals/'* ]]
  [[ "$output" != *'unbound variable'* ]]
  # Missing tools are a tooling failure (2), never a clean pass.
  run env PATH=/nonexistent /bin/bash "$GATE"
  [ "$status" -eq 2 ]
  # --self-test is wired.
  run bash "$GATE" --self-test
  [ "$status" -eq 0 ]
}

@test "AC-043-08: a missing package fails with a FAIL line, not a shell error" {
  local root="$TMPDIR_HELPER/nopkg"
  mkdir -p "$root"
  run bash "$GATE" "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-'* ]]
  [[ "$output" == *'evals/'* ]]
  [[ "$output" != *'No such file or directory'* ]]
  [[ "$output" != *'unbound variable'* ]]
}

@test "AC-043-09: a pipeline reference to evals fails and names the file" {
  local root; root=$(fixture_root)
  mkdir -p "$root/agents"
  printf 'Use evals/tasks here.\n' > "$root/agents/spec-coder.md"
  run bash "$GATE" --only 2 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-06'* ]]
  [[ "$output" == *'agents/spec-coder.md'* ]]
}

# ── Task 3: task format ─────────────────────────────────────────────────────

@test "AC-043-10: every task carries the five required entries" {
  local tasks="$REPO_ROOT/evals/tasks"
  [ -d "$tasks" ]
  local t found=0
  for t in "$tasks"/*/; do
    [ -d "$t" ] || continue
    found=$((found + 1))
    [ -f "$t/instruction.md" ]
    [ -s "$t/instruction.md" ]
    [ -d "$t/environment" ]
    [ -d "$t/tests" ]
    [ -d "$t/solution" ]
    [ -f "$t/task.toml" ]
    [ ! -f "$t/reward.txt" ]
    [ -z "$(find "$t" -name '*.tmp' -print -quit)" ]
  done
  [ "$found" -ge 3 ]
}

@test "AC-043-11: manifests declare the required keys and types" {
  run python3 - "$REPO_ROOT" <<'PY'
import os, re, sys, tomllib
root = sys.argv[1]
tasks = os.path.join(root, 'evals', 'tasks')
seen = 0
for name in sorted(os.listdir(tasks)):
    d = os.path.join(tasks, name)
    if not os.path.isdir(d):
        continue
    seen += 1
    with open(os.path.join(d, 'task.toml'), 'rb') as f:
        m = tomllib.load(f)
    assert re.match(r'^[0-9]{3}-[a-z0-9-]+$', m['id']), name
    assert m['slug'] == name, name
    assert re.match(r'^spec-[a-z-]+$', m['agent']), name
    assert os.path.isfile(os.path.join(root, 'agents', m['agent'] + '.md')), name
    assert isinstance(m['timeoutSec'], int) and m['timeoutSec'] > 0, name
    assert m['verifier']['command'], name
    assert m['verifier']['rewardFile'], name
    assert os.path.isdir(os.path.join(d, m['oracle']['solution'])), name
    assert os.path.isdir(os.path.join(d, m['oracle']['environment'])), name
assert seen >= 3
PY
  [ "$status" -eq 0 ]
}

@test "AC-043-12: only the three probe tasks declare a probe contract" {
  run python3 - "$REPO_ROOT" <<'PY'
import os, sys, tomllib
root = sys.argv[1]
tasks = os.path.join(root, 'evals', 'tasks')
probes = {}
for name in sorted(os.listdir(tasks)):
    d = os.path.join(tasks, name)
    if not os.path.isdir(d):
        continue
    with open(os.path.join(d, 'task.toml'), 'rb') as f:
        m = tomllib.load(f)
    if 'probe' in m:
        probes[name] = m['probe']
assert set(probes) == {'001-ambiguous-specifier', '002-red-gate-halt', '003-missing-gh-token'}, probes.keys()
assert probes['001-ambiguous-specifier']['id'] == 'ambiguous-specifier'
assert probes['002-red-gate-halt']['id'] == 'red-gate-halt'
assert probes['003-missing-gh-token']['id'] == 'missing-gh-token'
for name, p in probes.items():
    assert p['id'] in {'ambiguous-specifier', 'red-gate-halt', 'missing-gh-token'}, name
    if 'unsetEnv' in p:
        assert isinstance(p['unsetEnv'], list), name
        assert all(isinstance(x, str) for x in p['unsetEnv']), name
    if 'env' in p:
        assert isinstance(p['env'], dict), name
        assert all(isinstance(v, str) for v in p['env'].values()), name
    if 'remote' in p:
        assert isinstance(p['remote'], bool), name
    if 'branch' in p:
        assert isinstance(p['branch'], str) and p['branch'], name
PY
  [ "$status" -eq 0 ]
}

@test "AC-043-13: a missing or empty required entry fails and names it" {
  local root; root=$(fixture_root)
  write_valid_task "$root" 001-missing-tests
  rm -rf "$root/evals/tasks/001-missing-tests/tests"
  write_valid_task "$root" 002-empty-instruction
  : > "$root/evals/tasks/002-empty-instruction/instruction.md"
  run bash "$GATE" --only 3 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-10'* ]]
  [[ "$output" == *'001-missing-tests'* ]]
  [[ "$output" == *'002-empty-instruction'* ]]
  [[ "$output" == *'tests'* ]]
  [[ "$output" == *'instruction.md'* ]]
}

@test "AC-043-14: malformed TOML fails without a traceback" {
  local root; root=$(fixture_root)
  write_valid_task "$root" 001-bad-toml
  printf 'id = "unterminated\n' > "$root/evals/tasks/001-bad-toml/task.toml"
  run bash "$GATE" --only 3 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-14'* ]]
  [[ "$output" == *'task.toml'* ]]
  [[ "$output" != *'Traceback'* ]]
}

@test "AC-043-15: duplicate task ids are rejected and both dirs named" {
  local root; root=$(fixture_root)
  write_valid_task "$root" 001-first
  write_valid_task "$root" 002-second
  sed -i 's/^id = "002-second"/id = "001-first"/' "$root/evals/tasks/002-second/task.toml"
  run bash "$GATE" --only 3 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-15'* ]]
  [[ "$output" == *'001-first'* ]]
  [[ "$output" == *'002-second'* ]]
}

@test "AC-043-16: an unresolvable agent or invalid timeout is rejected" {
  local root; root=$(fixture_root)
  write_valid_task "$root" 001-bad-agent
  sed -i 's/^agent = "spec-coder"/agent = "spec-nonexistent"/' \
    "$root/evals/tasks/001-bad-agent/task.toml"
  write_valid_task "$root" 002-bad-timeout
  sed -i 's/^timeoutSec = 30/timeoutSec = 0/' "$root/evals/tasks/002-bad-timeout/task.toml"
  run bash "$GATE" --only 3 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-16'* ]]
  [[ "$output" == *'001-bad-agent'* ]]
  [[ "$output" == *'agent'* ]]
  [[ "$output" == *'002-bad-timeout'* ]]
  [[ "$output" == *'timeoutSec'* ]]
}

# ── Task 10: self-CI wiring ─────────────────────────────────────────────────

@test "AC-043-59: self-CI runs the gate and its self-test" {
  grep -qF './scripts/check-agent-evals.sh' "$WORKFLOW"
  grep -qF './scripts/check-agent-evals.sh --self-test' "$WORKFLOW"
}

@test "AC-043-60: the agent-eval step cannot be skipped" {
  local step
  step=$(awk '
    /- name: / { if (seen) exit; if ($0 ~ /[Aa]gent eval/) { seen=1 } }
    seen { print }
  ' "$WORKFLOW")
  [ -n "$step" ]
  [[ "$step" != *'continue-on-error: true'* ]]
  grep -qE '^permissions:$' "$WORKFLOW"
  grep -qE '^  contents: read$' "$WORKFLOW"
}

@test "AC-043-61: the self-test fails closed on its fixture set" {
  run bash "$GATE" --self-test
  [ "$status" -eq 0 ]
  for fixture in 'missing task entry' 'task cannot fail' 'missing ADR row' 'missing self-CI step'; do
    [[ "$output" == *"$fixture"* ]]
  done
  # A broken fixture is reported with an AC-043 id.
  local root; root=$(fixture_root)
  write_valid_task "$root" 001-missing-tests
  rm -rf "$root/evals/tasks/001-missing-tests/tests"
  run bash "$GATE" --only 3 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-10'* ]]
}

@test "AC-043-62: the gate is read-only and offline" {
  local before_status before_runs after_status after_runs
  before_status=$(cd "$REPO_ROOT" && git status --porcelain)
  before_runs=$(sha256sum "$REPO_ROOT/runs.jsonl" | awk '{print $1}')
  run bash "$GATE"
  [ "$status" -eq 0 ]
  run bash "$GATE" --self-test
  [ "$status" -eq 0 ]
  after_status=$(cd "$REPO_ROOT" && git status --porcelain)
  after_runs=$(sha256sum "$REPO_ROOT/runs.jsonl" | awk '{print $1}')
  [ "$before_status" = "$after_status" ]
  [ "$before_runs" = "$after_runs" ]
  ! grep -q 'OPENCODE_BIN' "$GATE"
  ! grep -qE 'curl|wget' "$GATE"
}

@test "AC-043-63: the governance link is enforced" {
  local root; root=$(fixture_root)
  run bash "$GATE" --only 8 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-63'* ]]
  [[ "$output" == *'0020-agent-eval-harness.md'* ]]

  cat > "$root/docs/adr/0020-agent-eval-harness.md" <<'ADR'
## Title
x
## Status
Proposed
## Context
x
## Decision
x
### Alternatives Considered
x
## Consequences
x
## Compliance
x
## Notes
x
ADR
  cat > "$root/docs/adr/README.md" <<'IDX'
# Index
| ADR  | Title | Status |
| ---- | ----- | ------ |
| 0001 | [Other](0001-other.md) | Accepted |
IDX
  run bash "$GATE" --only 8 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-63'* ]]
  [[ "$output" == *'docs/adr/README.md'* ]]
}
