#!/usr/bin/env bats
# ac-038-gates-intact.bats — acceptance tests for spec 038 Tasks 4 and 5
# (specs/038-trim-agent-prompts/20-acceptance/AC-038-04-no-gate-weakened.md and
# AC-038-05-checks-green.md).

load test_helper
bats_require_minimum_version 1.5.0

AGENTS="$REPO_ROOT/agents"

# Gate scripts cited by agents/spec-*.md before spec 038's trim, measured on the
# branch base. Frozen so the assertion cannot drift with the change it checks.
BASE_GATES=(
  check-audit-trail.sh
  check-code-principles.sh
  check-scenario-traceability.sh
  check-specs-archived.sh
)

# cited_scripts [agents-dir] — every scripts/*.sh the given agent files cite.
# Filtered to .sh on purpose: gate_reachable greps the cited script's body, and
# skills/*.md bodies name gates too, which would make the reachability vacuous.
cited_scripts() {
  local dir="${1:-$AGENTS}"
  agent_cited_paths "$dir"/spec-*.md | grep -E '^scripts/[A-Za-z0-9._-]+\.sh$' || true
}

# body_of <agent-file> — the prompt after the YAML frontmatter, so a gate named
# only in a permission deny rule (e.g. "**/check-code-principles.sh": deny) does
# not count as reachable: the deny rule is the opposite of an invocation.
body_of() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm' "$1"
}

# gate_reachable <gate-name> [agents-dir] — 0 when the gate is named in an
# agent's body, or in the body of a script such an agent cites. Frontmatter is
# excluded (see body_of).
gate_reachable() {
  local gate="$1" dir="${2:-$AGENTS}" agent script
  for agent in "$dir"/spec-*.md; do
    [ -f "$agent" ] || continue
    body_of "$agent" | grep -qF -- "$gate" && return 0
  done
  while IFS= read -r script; do
    [ -f "$REPO_ROOT/$script" ] || continue
    grep -qF -- "$gate" "$REPO_ROOT/$script" && return 0
  done < <(cited_scripts "$dir")
  return 1
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# fixture_agent <dir> <name> <body-line> — a minimal agent file whose
# frontmatter names check-code-principles.sh and whose body is the given line.
fixture_agent() {
  local dir="$1" name="$2" body="$3"
  mkdir -p "$dir"
  printf -- '---\ndescription: fixture\ndescription: check-code-principles.sh\nmode: subagent\npermission:\n  edit:\n    "**/check-code-principles.sh": deny\n    "*": deny\n---\n\n%s\n' \
    "$body" > "$dir/$name"
}

@test "AC-038-04-01 — every gate script the agents cited before the trim is still reachable" {
  local gate
  for gate in "${BASE_GATES[@]}"; do
    gate_reachable "$gate" || {
      echo "gate $gate is no longer cited by any agents/spec-*.md or the scripts they cite" >&2
      return 1
    }
  done
}

@test "AC-038-04-02 — the complexity threshold is still 6" {
  run bash -c "grep -cF '> 6' '$REPO_ROOT/scripts/check-code-principles.sh'"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]
  run grep -F 'complexity ≤6' "$REPO_ROOT/docs/SPEC_PIPELINE.md"
  [ "$status" -eq 0 ]
}

@test "AC-038-04-02 — the skill line-limit threshold is still 500" {
  run grep -F 'total_lines > 500' "$REPO_ROOT/scripts/check-skills.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"500"* ]]
}

@test "AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value" {
  run bash -c "grep -E '^MAX_LINES=[0-9]+$' '$REPO_ROOT/scripts/check-agent-line-cap.sh'"
  [ "$status" -eq 0 ]
  [ "$output" = "MAX_LINES=120" ]
}

@test "unit — a gate named only in frontmatter is not reachable" {
  local dir="$TMPDIR_HELPER/agents"
  fixture_agent "$dir" spec-frontmatter-only.md "No gate is invoked in this prompt body."
  run gate_reachable check-code-principles.sh "$dir"
  [ "$status" -eq 1 ]
}

@test "unit — a gate named in the agent body is reachable" {
  local dir="$TMPDIR_HELPER/agents"
  fixture_agent "$dir" spec-body.md "Run scripts/check-code-principles.sh yourself."
  run gate_reachable check-code-principles.sh "$dir"
  [ "$status" -eq 0 ]
}

@test "unit — no agent cites a gate script that does not exist" {
  local script
  while IFS= read -r script; do
    [ -n "$script" ] || continue
    [ -f "$REPO_ROOT/$script" ] || {
      echo "dangling gate citation: $script" >&2
      return 1
    }
  done < <(cited_scripts)
}
