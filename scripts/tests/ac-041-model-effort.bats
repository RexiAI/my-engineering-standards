#!/usr/bin/env bats
# ac-041-model-effort.bats — acceptance tests for spec 041 Task 6
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-model-effort-guidance.md).
#
# The guidance is documentation only: shipped defaults must stay byte-identical
# (AC-041-49), which the hash assertions below pin.

load test_helper
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/spec-pipeline/model-config.md"
HEADING='## Mechanical-stage model and effort guidance'

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# guidance — the section body, heading through EOF (it is appended last).
guidance() {
  awk -v want="$HEADING" '$0 == want { inblock = 1 } inblock { print }' "$DOC"
}

@test "AC-041-45 — the guidance section names every mechanical stage" {
  local section stage
  section="$(guidance)"
  [ -n "$section" ]
  [[ "$section" == *"$HEADING"* ]]
  for stage in spec-deployer spec-pr-opener spec-mutation-runner spec-pipeline; do
    [[ "$section" == *"| \`$stage\`"* ]]
  done
  [[ "$section" == *"Work shape"* ]]
  [[ "$section" == *"Capability class"* ]]
  [[ "$section" == *"Preferred effort"* ]]
}

@test "AC-041-46 — the effort-location finding is recorded" {
  local section
  section="$(guidance)"
  [[ "$section" == *'**provider model** options'* ]]
  [[ "$section" == *'`models.<id>.options`'* ]]
  [[ "$section" == *"applies to every stage that resolves to"* ]]
  [[ "$section" == *'`config/model.local.env.example`'* ]]
  [[ "$section" == *"contains no \`effort\`"* ]]
}

@test "AC-041-47 — the verified per-agent lever is recorded" {
  local section
  section="$(guidance)"
  [[ "$section" == *'`agent.<name>.options: { "effort": "<level>" }`'* ]]
  [[ "$section" == *'`agent.<name>.request.body.effort`'* ]]
  [[ "$section" == *'`opencode debug config`'* ]]
  [[ "$section" == *"no \`request.body\` key"* ]]
}

@test "AC-041-48 — no model id or provider id appears in the section" {
  local section tokens token
  section="$(guidance)"
  ! grep -qiE 'qwen|bailian|anthropic|deepseek|glm' <<< "$section"
  tokens="$(grep -oE '[a-z0-9-]+/[a-z0-9.-]+' <<< "$section" | sort -u)"
  while IFS= read -r token; do
    [ -n "$token" ] || continue
    case "$token" in
      config/model.local.env|config/model.local.env.example) ;;
      *) return 1 ;;
    esac
  done <<< "$tokens"
}

@test "AC-041-49 — shipped defaults are unchanged and the decision is recorded" {
  # Re-measured at the stacked base (spec/038 tip, 4dbf164): the literal values
  # quoted in 10-tasks.md predate spec 037's rewrite of both files. The invariant
  # AC-041-49 pins is "unchanged by this spec", so the test pins the base tree's
  # bytes — editing either file fails it.
  [ "$(sha256sum "$REPO_ROOT/config/model.local.env.example" | awk '{print $1}')" \
    = "194765aea7d621ba6014a38bc7503e7ca1df3b29e081edbb0e094b9a36a2e62f" ]
  [ "$(sha256sum "$REPO_ROOT/opencode.json" | awk '{print $1}')" \
    = "49ecd5edc66d3de16a9227fa0eb32d6cf2baf808fd50c19bcd15715832008ce3" ]
  guidance | grep -q 'Decision: documented, not shipped'
  guidance | grep -q 'config/model.local.env'
  guidance | grep -q 'restart opencode'
  guidance | grep -q 'commit nothing'
}
