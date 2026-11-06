#!/usr/bin/env bats
# ac-038-trimmed-agents.bats — acceptance tests for spec 038 Task 3
# (specs/038-trim-agent-prompts/20-acceptance/AC-038-03-extract-procedures.md).

load test_helper
bats_require_minimum_version 1.5.0

CAP=120
TRIMMED=(spec-verifier spec-ux spec-pr-opener spec-pipeline spec-deployer)
DOCS="$REPO_ROOT/docs/spec-pipeline"

@test "AC-038-03-01 — every formerly over-cap agent is at or under 120 lines" {
  local agent lines
  for agent in "${TRIMMED[@]}"; do
    lines="$(wc -l < "$REPO_ROOT/agents/$agent.md" | tr -d ' ')"
    [ "$lines" -le "$CAP" ] || {
      echo "agents/$agent.md is $lines lines (cap $CAP)" >&2
      return 1
    }
  done
}

@test "AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists" {
  local agent path
  for agent in "${TRIMMED[@]}"; do
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      repo_path_exists "$REPO_ROOT" "$path" && continue
      echo "agents/$agent.md cites missing $path" >&2
      return 1
    done < <(agent_cited_paths "$REPO_ROOT/agents/$agent.md")
  done
}

# agent_mentions <agent-name> <literal> — the agent prompt contains the literal.
agent_mentions() {
  grep -qF "$2" "$REPO_ROOT/agents/$1.md"
}

@test "unit — each trimmed agent points at the stage doc that now carries its procedure" {
  local agent
  for agent in spec-verifier spec-ux spec-pr-opener spec-deployer; do
    agent_mentions "$agent" "docs/spec-pipeline/${agent#spec-}.md" || {
      echo "agents/$agent.md does not cite its stage doc" >&2
      return 1
    }
  done
}

# Stage doc + heading table for the procedures extracted out of the agent
# prompts: "<doc under docs/spec-pipeline/>|<heading that must exist verbatim>".
EXTRACTED_PROCEDURES=(
  'verifier.md|## Checks in order'
  'verifier.md|## Report format'
  'ux.md|## Applicability fast-path (typed judgment)'
  'ux.md|## 15-design.md template'
  'pr-opener.md|## Stage 5b — commit, push, open the draft PR'
  'pr-opener.md|## Stage 5d — archive, then push the archive commit'
  'deployer.md|## Vercel CLI access'
)

@test "unit — the extracted procedures are headings of the stage doc they moved to" {
  local doc heading entry
  for entry in "${EXTRACTED_PROCEDURES[@]}"; do
    doc="${entry%%|*}"
    heading="${entry#*|}"
    grep -qxF "$heading" "$DOCS/$doc" || {
      echo "docs/spec-pipeline/$doc has no heading '$heading'" >&2
      return 1
    }
  done
}

@test "unit — each trimmed agent still declares the Stop-and-Ask matrix authoritative" {
  local agent phrase
  for agent in "${TRIMMED[@]}"; do
    for phrase in 'Stop-and-Ask decision matrix' 'never by improvisation'; do
      agent_mentions "$agent" "$phrase" || {
        echo "agents/$agent.md does not mention '$phrase'" >&2
        return 1
      }
    done
  done
}

@test "unit — the extracted stage docs stay inside each stage's read-cost budget" {
  run bash "$REPO_ROOT/scripts/measure-stage-read-cost.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Every stage reads at most 50% of the unsplit document."* ]]
}
