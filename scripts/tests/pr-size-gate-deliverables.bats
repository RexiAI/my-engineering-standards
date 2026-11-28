#!/usr/bin/env bats
# pr-size-gate-deliverables.bats — acceptance tests for the artifact-shaped
# tasks of spec 045: Task 1 (ADR), Task 4 (review verdict contract), Tasks 7-8
# (the reusable and caller workflows), Task 10 (init-ci wiring), Task 11
# (self-hosting gate), and Task 12 (documentation).
#
# Sources: specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-01-*.md,
# AC-045-04-*.md, AC-045-07-*.md, AC-045-08-*.md, AC-045-10-*.md,
# AC-045-11-*.md, AC-045-12-*.md.

load test_helper
bats_require_minimum_version 1.5.0

ADR="$REPO_ROOT/docs/adr/0030-pr-size-gate-and-review-gated-auto-merge.md"
ADR_INDEX="$REPO_ROOT/docs/adr/README.md"
AGENT="$REPO_ROOT/agents/pr-review.md"
SIZE_WF="$REPO_ROOT/.github/workflows/ci-pr-size-gate.yml"
VERDICT_WF="$REPO_ROOT/.github/workflows/ci-pr-review-verdict.yml"
AUTOMERGE_WF="$REPO_ROOT/.github/workflows/ci-pr-auto-merge.yml"
CALLER_WF="$REPO_ROOT/.github/workflows/pr-automerge.yml"
SELF_CI="$REPO_ROOT/.github/workflows/self-ci.yml"
INIT_CI="$REPO_ROOT/scripts/init-ci.sh"
CATALOG="$REPO_ROOT/scripts/capabilities.tsv"
CI_CD="$REPO_ROOT/docs/CI_CD.md"
GIT_WF="$REPO_ROOT/docs/GIT_WORKFLOW.md"
BRANCH_PROT="$REPO_ROOT/templates/branch-protection.md"
PIN='21046d96796467f8238d6d613ce3a552bf3fced0'

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# section <file> <heading> — the body of the markdown section with that heading
# text, at any heading level. Ends at the next heading of the same or higher
# level, so a `##` section keeps its `###` subsections.
section() {
  awk -v h="$2" '
    {
      line = $0
      if (line ~ /^#+ /) {
        level = line
        sub(/[^#].*$/, "", level)
        text = line
        sub(/^#+ +/, "", text)
        if (!on) {
          if (text == h) { on = 1; lvl = length(level) }
          next
        }
        if (length(level) <= lvl) exit
      }
      if (on) print
    }' "$1"
}

# adr_status — the value under the ADR's `## Status` heading.
adr_status() { awk '/^## Status/{getline; while ($0 ~ /^[[:space:]]*$/) getline; print; exit}' "$ADR"; }

# init_ci <dir> <args...> — run init-ci.sh in a scratch child repo, sets
# $status/$output. A .standards symlink is the only wiring a child needs.
init_ci() { # <dir> <args...>
  local dir="$1"
  shift
  mkdir -p "$dir"
  ln -sfn "$REPO_ROOT" "$dir/.standards"
  run bash -c "cd '$dir' && bash .standards/scripts/init-ci.sh \"\$@\" < /dev/null" _ "$@"
}

# ── AC-045-01: ADR for the merge-authority reversal ─────────────────────────

@test "AC-045-01-01 — ADR exists at the next free number" {
  [ -f "$ADR" ]
  local heading
  for heading in Title Status Context Decision "Alternatives Considered" Consequences Compliance; do
    run grep -F "## $heading" "$ADR"
    [ "$status" -eq 0 ]
  done
  case "$(adr_status)" in
    Proposed | Accepted) ;;
    *) false ;;
  esac
}

@test "AC-045-01-02 — native auto-merge is the merge authority" {
  local decision
  decision="$(section "$ADR" Decision)"
  [[ "$decision" == *"native auto-merge"* ]]
  [[ "$decision" == *"required checks"* ]]
  [[ "$decision" == *"agents/pr-review.md"* ]]
  [[ "$decision" == *"never merges"* ]]
}

@test "AC-045-01-03 — Never-list distinction recorded" {
  local decision
  decision="$(section "$ADR" Decision)"
  [[ "$decision" == *"Never-list"* ]]
  [[ "$decision" == *"no merge"* ]]
  [[ "$decision" == *"docs/SPEC_PIPELINE.md"* ]]
  [[ "$decision" == *"no pipeline agent is the actor"* ]]
}

@test "AC-045-01-04 — PR-only flow preserved" {
  [[ "$(section "$ADR" Decision)$(section "$ADR" Consequences)" == *"pull request"* ]]
  [[ "$(section "$ADR" Decision)$(section "$ADR" Consequences)" == *"branch protection"* ]]
  [[ "$(section "$ADR" Decision)$(section "$ADR" Consequences)" == *"no direct push"* ]]
}

@test "AC-045-01-05 — scope-lock reversal is narrow" {
  local decision
  decision="$(section "$ADR" Decision)"
  [[ "$decision" == *"scope lock"* ]]
  [[ "$decision" == *"continues to bind the agent"* ]]
  [[ "$decision" == *"no longer forbids"* ]]
  [[ "$decision" == *"gate_surface"* ]]
}

@test "AC-045-01-06 — index row added" {
  run grep -F '| 0030 |' "$ADR_INDEX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(0030-pr-size-gate-and-review-gated-auto-merge.md)"* ]]
  [[ "$output" == *"$(adr_status)"* ]]
}

# ── AC-045-04: the pr-review output contract carries a verdict ──────────────

@test "AC-045-04-01 — the contract names both verdict lines" {
  run grep -F 'Review-Verdict: pass' "$AGENT"
  [ "$status" -eq 0 ]
  run grep -F 'Review-Verdict: findings' "$AGENT"
  [ "$status" -eq 0 ]
}

@test "AC-045-04-02 — the verdict matches the findings count" {
  local contract
  contract="$(section "$AGENT" 'Inputs and output contract (headless CI)')"
  [[ "$contract" == *"zero findings"* ]]
  [[ "$contract" == *"one or more"* ]]
}

@test "AC-045-04-03 — omission is fail-closed, not a silent pass" {
  local contract
  contract="$(section "$AGENT" 'Inputs and output contract (headless CI)')"
  [[ "$contract" == *"case-sensitive"* ]]
  [[ "$contract" == *"fail-closed"* ]]
  [[ "$contract" == *"never a silent pass"* ]]
}

@test "AC-045-04-04 — Reviewed-SHA is unchanged" {
  local contract
  contract="$(section "$AGENT" 'Inputs and output contract (headless CI)')"
  [[ "$contract" == *"Reviewed-SHA: <head sha>"* ]]
  [[ "$contract" == *"after"* ]]
}

@test "AC-045-04-05 — scope lock and permission block are unchanged" {
  local scope
  scope="$(section "$AGENT" 'Scope lock (review + suggest fixes only)')"
  [[ "$scope" == *"auto-merge"* ]]
  [[ "$scope" == *"approve"* ]]
  [[ "$scope" == *"describe"* ]]
  [[ "$scope" == *"improve"* ]]
  [[ "$scope" == *"auto-apply"* ]]
  [[ "$scope" == *"Push"* ]]
  run grep -F 'edit:' "$AGENT"
  [ "$status" -eq 0 ]
  run grep -F 'bash:' "$AGENT"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'deny' "$AGENT")" -ge 2 ]
}

@test "AC-045-04-06 — the existing review checks stay green" {
  run bash "$REPO_ROOT/scripts/check-pr-review.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
}

# ── AC-045-07: required-check workflows ────────────────────────────────────

@test "AC-045-07-01 — both workflows are callable reusables" {
  run grep -F 'workflow_call' "$SIZE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'workflow_call' "$VERDICT_WF"
  [ "$status" -eq 0 ]
  local input
  for input in pr-number base-sha head-sha base-ref; do
    run grep -F "      $input:" "$SIZE_WF"
    [ "$status" -eq 0 ]
  done
  run grep -F '      pr-number:' "$VERDICT_WF"
  [ "$status" -eq 0 ]
  run grep -F '      head-sha:' "$VERDICT_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-07-02 — the size job evaluates labels, timeline, and the diff" {
  run grep -F 'gh pr view' "$SIZE_WF"
  [ "$status" -eq 0 ]
  run grep -F -- '--json labels' "$SIZE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'timeline' "$SIZE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'size-override' "$SIZE_WF"
  [ "$status" -eq 0 ]
  local flag
  for flag in --label --label-actor --repo-owner --codeowners; do
    run grep -F -- "$flag" "$SIZE_WF"
    [ "$status" -eq 0 ]
  done
  run grep -F 'exit "$rc"' "$SIZE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-07-03 — the verdict job fails closed" {
  run grep -F -- '--json comments' "$VERDICT_WF"
  [ "$status" -eq 0 ]
  run grep -F 'pr-review-verdict.sh' "$VERDICT_WF"
  [ "$status" -eq 0 ]
  run grep -F 'exit "$rc"' "$VERDICT_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-07-04 — only the pinned standards revision is executed" {
  local wf
  for wf in "$SIZE_WF" "$VERDICT_WF"; do
    run grep -F "ref: $PIN" "$wf"
    [ "$status" -eq 0 ]
    run grep -F 'RexiAI/my-engineering-standards' "$wf"
    [ "$status" -eq 0 ]
    [ "$(grep -c 'pull_request_target' "$wf")" -eq 0 ]
    [ "$(grep -c 'github.event.pull_request.head.sha' "$wf")" -eq 0 ]
  done
}

@test "AC-045-07-05 — permissions are read-only" {
  local wf
  for wf in "$SIZE_WF" "$VERDICT_WF"; do
    run grep -F 'contents: read' "$wf"
    [ "$status" -eq 0 ]
    run grep -F 'pull-requests: read' "$wf"
    [ "$status" -eq 0 ]
    [ "$(grep -cE '^[[:space:]]+[a-z-]+: write' "$wf")" -eq 0 ]
    [ "$(grep -c 'secrets:' "$wf")" -eq 0 ]
  done
}

@test "AC-045-07-06 — an authorized override turns a failure into a pass" {
  local co="$TMPDIR_HELPER/CODEOWNERS"
  local ns="$TMPDIR_HELPER/numstat.txt"
  local df="$TMPDIR_HELPER/pr.diff"
  printf '* @alice\n' > "$co"
  printf '900\t0\tsrc/big.ts\n' > "$ns"
  printf 'diff --git a/src/big.ts b/src/big.ts\n' > "$df"
  run bash "$REPO_ROOT/scripts/pr-size-gate.sh" --numstat-file "$ns" --diff-file "$df" \
    --label present --label-actor alice --codeowners "$co"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=override"* ]]
  [[ "$output" == *"automerge=false"* ]]
  # The job status is the script's exit code: a labeled event re-runs the same
  # job, and the workflow lets a 0 exit pass and a non-zero exit fail.
  run grep -F 'labeled' "$CALLER_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-07-07 — the check workflows never write" {
  local wf
  for wf in "$SIZE_WF" "$VERDICT_WF"; do
    [ "$(grep -cE 'gh pr comment|gh pr merge|git push|merge\(\)' "$wf")" -eq 0 ]
  done
}

# ── AC-045-08: auto-merge workflow, report-only default, live arming ───────

@test "AC-045-08-01 — the auto-merge workflow is a callable reusable" {
  run grep -F 'workflow_call' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  local input
  for input in pr-number base-sha head-sha base-ref; do
    run grep -F "      $input:" "$AUTOMERGE_WF"
    [ "$status" -eq 0 ]
  done
  run grep -F '  automerge:' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-02 — size and verdict are re-verified before arming" {
  run grep -F 'pr-size-gate.sh' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'tier=auto' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'pr-review-verdict.sh' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'verdict=pass' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-03 — mode is report unless the value is exactly live" {
  run grep -F 'vars.PR_AUTOMERGE_MODE' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F '[ "$MODE" != "live" ]' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'MODE="report"' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-04 — live mode arms native auto-merge with squash" {
  run grep -F 'gh pr merge --auto --squash' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  [ "$(grep -cE 'gh pr merge --(merge|rebase|admin)' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'pull.sh.*merge\|/merge"' "$AUTOMERGE_WF")" -eq 0 ]
}

@test "AC-045-08-05 — report mode never merges" {
  run grep -F "if: env.MODE == 'live'" "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'pr-automerge-notify.sh' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-06 — auto-merge must be enabled on the repository" {
  run grep -F -- '--jq .allow_auto_merge' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'allow_auto_merge' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-07 — there is no per-repository allowlist" {
  [ "$(grep -c 'github.repository ==' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'github.repository_owner ==' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'RexiAI/my-engineering-standards.git' "$AUTOMERGE_WF")" -eq 0 ]
}

@test "AC-045-08-08 — permissions are split by job" {
  run grep -F 'contents: write' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  run grep -F 'pull-requests: write' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'actions: write' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'id-token: write' "$AUTOMERGE_WF")" -eq 0 ]
  # Exactly one job grants the write pair: the arming job.
  [ "$(grep -c 'contents: write' "$AUTOMERGE_WF")" -eq 1 ]
  [ "$(grep -c 'pull-requests: write' "$AUTOMERGE_WF")" -eq 1 ]
}

@test "AC-045-08-09 — the caller wires three pinned jobs" {
  run grep -F "ci-pr-size-gate.yml@$PIN" "$CALLER_WF"
  [ "$status" -eq 0 ]
  run grep -F "ci-pr-review-verdict.yml@$PIN" "$CALLER_WF"
  [ "$status" -eq 0 ]
  run grep -F "ci-pr-auto-merge.yml@$PIN" "$CALLER_WF"
  [ "$status" -eq 0 ]
  run grep -F 'needs: [pr-size, review-verdict]' "$CALLER_WF"
  [ "$status" -eq 0 ]
  [ "$(grep -cE 'uses: .*@(main|master)' "$CALLER_WF")" -eq 0 ]
}

@test "AC-045-08-10 — the decision comment is idempotent per head" {
  run grep -F 'pr-automerge: ' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
  [ "$(grep -c -- '--json comments' "$AUTOMERGE_WF")" -ge 1 ]
  run grep -F 'already posted' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-08-11 — PR head code is never executed" {
  [ "$(grep -c 'pull_request_target' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'github.event.pull_request.head.sha' "$AUTOMERGE_WF")" -eq 0 ]
  [ "$(grep -c 'ref: ${{ inputs.head-sha }}' "$AUTOMERGE_WF")" -eq 0 ]
}

# ── AC-045-10: child-repo wiring ───────────────────────────────────────────

@test "AC-045-10-01 — both flags are documented and parsed" {
  run grep -F '[--with-pr-size-gate]' "$INIT_CI"
  [ "$status" -eq 0 ]
  run grep -F '[--with-pr-automerge]' "$INIT_CI"
  [ "$status" -eq 0 ]
  run grep -F 'WITH_PR_SIZE_GATE_FLAG="true"' "$INIT_CI"
  [ "$status" -eq 0 ]
  run grep -F 'WITH_PR_AUTOMERGE_FLAG="true"' "$INIT_CI"
  [ "$status" -eq 0 ]
}

@test "AC-045-10-02 — the size flag emits only the size job" {
  local dir="$TMPDIR_HELPER/size-child"
  init_ci "$dir" --with-pr-size-gate --platform github --backend go
  [ "$status" -eq 0 ]
  local wf="$dir/.github/workflows/ci.yml"
  [ "$(grep -c '^  pr-size:' "$wf")" -eq 1 ]
  run grep -F "ci-pr-size-gate.yml@$PIN" "$wf"
  [ "$status" -eq 0 ]
  run grep -F 'base-sha: ${{ github.event.pull_request.base.sha }}' "$wf"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'review-verdict' "$wf")" -eq 0 ]
  [ "$(grep -c 'pr-automerge' "$wf")" -eq 0 ]
}

@test "AC-045-10-03 — the auto-merge flag emits all three jobs" {
  local dir="$TMPDIR_HELPER/am-child"
  init_ci "$dir" --with-pr-automerge --platform github --backend go
  [ "$status" -eq 0 ]
  local wf="$dir/.github/workflows/ci.yml"
  [ "$(grep -c '^  pr-size:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  review-verdict:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  pr-automerge:' "$wf")" -eq 1 ]
  run grep -F 'needs: [pr-size, review-verdict]' "$wf"
  [ "$status" -eq 0 ]
  [ "$(grep -c "ci-pr-size-gate.yml@$PIN\|ci-pr-review-verdict.yml@$PIN\|ci-pr-auto-merge.yml@$PIN" "$wf")" -eq 3 ]
}

@test "AC-045-10-04 — both flags emit each job once" {
  local dir="$TMPDIR_HELPER/both-child"
  init_ci "$dir" --with-pr-size-gate --with-pr-automerge --platform github --backend go
  [ "$status" -eq 0 ]
  local wf="$dir/.github/workflows/ci.yml"
  [ "$(grep -c '^  pr-size:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  review-verdict:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  pr-automerge:' "$wf")" -eq 1 ]
}

@test "AC-045-10-05 — the default output is unchanged" {
  local dir="$TMPDIR_HELPER/default-child"
  init_ci "$dir" --platform github --backend go
  [ "$status" -eq 0 ]
  local wf="$dir/.github/workflows/ci.yml"
  [ "$(grep -c 'pr-size\|review-verdict\|pr-automerge' "$wf")" -eq 0 ]
  [ "$(grep -c 'PR_AUTOMERGE_MODE' "$wf")" -eq 0 ]
}

@test "AC-045-10-06 — GitLab warns and emits nothing" {
  local dir="$TMPDIR_HELPER/gl-child"
  init_ci "$dir" --with-pr-automerge --platform gitlab --backend go
  [ "$status" -eq 0 ]
  [[ "$output" == *"GitHub Actions feature"* ]]
  [ "$(grep -c 'pr-size\|pr-automerge\|auto.merge' "$dir/.gitlab-ci.yml")" -eq 0 ]
}

@test "AC-045-10-07 — both platforms emits on GitHub and warns for GitLab" {
  local dir="$TMPDIR_HELPER/bothplat-child"
  init_ci "$dir" --with-pr-size-gate --with-pr-automerge --platform both --backend go
  [ "$status" -eq 0 ]
  local wf="$dir/.github/workflows/ci.yml"
  [ "$(grep -c '^  pr-size:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  review-verdict:' "$wf")" -eq 1 ]
  [ "$(grep -c '^  pr-automerge:' "$wf")" -eq 1 ]
  [[ "$output" == *"GitHub Actions feature"* ]]
  [ "$(grep -c 'pr-size\|pr-automerge' "$dir/.gitlab-ci.yml")" -eq 0 ]
}

@test "AC-045-10-08 — the bootstrap catalog carries both capabilities" {
  local row
  for row in '--with-pr-size-gate' '--with-pr-automerge'; do
    run grep -F "|$row|" "$CATALOG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"|no|"* ]]
    [[ "$output" == *"|none|"* ]]
    [[ "$output" == *"|{ci}|"* ]]
    [[ "$output" == *"|$row|"* ]]
  done
}

@test "AC-045-10-09 — summary documents the setting and asks for no secret" {
  local dir="$TMPDIR_HELPER/note-child"
  init_ci "$dir" --with-pr-automerge --platform github --backend go
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR_AUTOMERGE_MODE"* ]]
  [[ "$output" == *"report"* ]]
  [[ "$output" == *"live"* ]]
  [[ "$output" == *"branch protection"* ]]
  [[ "$output" != *"read -rp"* ]]
  [ "$(grep -cE 'read -rp.*(AUTOMERGE|SIZE)' "$INIT_CI")" -eq 0 ]
}

# ── AC-045-11: self-hosting and self-CI ────────────────────────────────────

@test "AC-045-11-01 — the deliverable check passes on the compliant tree" {
  [ -x "$REPO_ROOT/scripts/check-pr-size-gate.sh" ]
  run bash "$REPO_ROOT/scripts/check-pr-size-gate.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "AC-045-11-02 — the deliverable check fails on a broken tree" {
  local copy="$TMPDIR_HELPER/repo"
  mkdir -p "$copy"
  cp -a "$REPO_ROOT/scripts" "$REPO_ROOT/.github" "$REPO_ROOT/agents" \
    "$REPO_ROOT/docs" "$REPO_ROOT/templates" "$REPO_ROOT/AGENTS.md" \
    "$REPO_ROOT/opencode.json" "$copy/" 2>/dev/null
  rm -f "$copy/scripts/pr-review-verdict.sh"
  run bash "$copy/scripts/check-pr-size-gate.sh" "$copy"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"pr-review-verdict.sh"* ]]
}

@test "AC-045-11-03 — self-CI runs the deliverable check and the script tests" {
  run grep -F 'scripts/check-pr-size-gate.sh' "$SELF_CI"
  [ "$status" -eq 0 ]
  local f
  for f in pr-size-gate pr-review-verdict pr-automerge-eligibility pr-automerge-notify; do
    run grep -F "scripts/tests/$f.bats" "$SELF_CI"
    [ "$status" -eq 0 ]
  done
}

@test "AC-045-11-04 — this repository self-hosts both PR gates" {
  run grep -F 'pull_request:' "$CALLER_WF"
  [ "$status" -eq 0 ]
  [ "$(grep -c "@$PIN" "$CALLER_WF")" -eq 3 ]
  [ "$(grep -cE '@(main|master)' "$CALLER_WF")" -eq 0 ]
}

@test "AC-045-11-05 — this repository rolls out report-only first" {
  run grep -rn --exclude-dir=tests 'PR_AUTOMERGE_MODE=live' "$REPO_ROOT/.github" \
    "$REPO_ROOT/scripts" "$REPO_ROOT/docs" "$REPO_ROOT/templates" "$REPO_ROOT/AGENTS.md"
  [ "$status" -ne 0 ]
  run grep -F 'MODE="report"' "$AUTOMERGE_WF"
  [ "$status" -eq 0 ]
}

@test "AC-045-11-06 — every scenario is traced" {
  run bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" \
    --spec 045-pr-size-gate-and-auto-merge
  [ "$status" -eq 0 ]
}

# ── AC-045-12: documentation ───────────────────────────────────────────────

@test "AC-045-12-01 — AGENTS.md states the auto-merge rule" {
  run grep -F 'native auto-merge' "$REPO_ROOT/AGENTS.md"
  [ "$status" -eq 0 ]
  run grep -F 'pr-review' "$REPO_ROOT/AGENTS.md"
  [ "$status" -eq 0 ]
  run grep -F 'never merges' "$REPO_ROOT/AGENTS.md"
  [ "$status" -eq 0 ]
  run grep -F 'no-direct-push' "$REPO_ROOT/AGENTS.md"
  [ "$status" -eq 0 ]
}

@test "AC-045-12-02 — GIT_WORKFLOW documents tiers and override" {
  local sec
  sec="$(section "$GIT_WF" 'PR Size and Auto-Merge')"
  [[ "$sec" == *"200"* ]]
  [[ "$sec" == *"400"* ]]
  [[ "$sec" == *"size-override"* ]]
  [[ "$sec" == *"CODEOWNER"* ]]
  [[ "$sec" == *"pr-size"* ]]
  [[ "$sec" == *"review-verdict"* ]]
}

@test "AC-045-12-03 — CI_CD documents the workflows and settings" {
  local sec
  sec="$(section "$CI_CD" 'PR Size Gate and Review-Gated Auto-Merge')"
  [[ "$sec" == *"ci-pr-size-gate.yml"* ]]
  [[ "$sec" == *"ci-pr-review-verdict.yml"* ]]
  [[ "$sec" == *"ci-pr-auto-merge.yml"* ]]
  [[ "$sec" == *"pr-size"* ]]
  [[ "$sec" == *"review-verdict"* ]]
  [[ "$sec" == *"PR_AUTOMERGE_MODE"* ]]
  [[ "$sec" == *"report"* ]]
  [[ "$sec" == *"live"* ]]
  [[ "$sec" == *"exclusion"* ]]
  [[ "$sec" == *"comment"* ]]
}

@test "AC-045-12-04 — branch protection lists the contexts and prerequisites" {
  run grep -F 'pr-size' "$BRANCH_PROT"
  [ "$status" -eq 0 ]
  run grep -F 'review-verdict' "$BRANCH_PROT"
  [ "$status" -eq 0 ]
  run grep -F 'MUTATION_REQUIRED=true' "$BRANCH_PROT"
  [ "$status" -eq 0 ]
  run grep -F 'allow_auto_merge' "$BRANCH_PROT"
  [ "$status" -eq 0 ]
  run grep -F 'squash' "$BRANCH_PROT"
  [ "$status" -eq 0 ]
}

@test "AC-045-12-05 — behavior is identical in every wired repo" {
  [[ "$(section "$CI_CD" 'PR Size Gate and Review-Gated Auto-Merge')" == *"no per-repo allowlist"* ]]
  [[ "$(section "$GIT_WF" 'PR Size and Auto-Merge')" == *"no per-repo allowlist"* ]]
  [[ "$(section "$CI_CD" 'PR Size Gate and Review-Gated Auto-Merge')" == *"same behavior"* ]]
  [[ "$(section "$GIT_WF" 'PR Size and Auto-Merge')" == *"same behavior"* ]]
}

@test "AC-045-12-06 — the setting is documented once and no agent merge is described" {
  [ "$(grep -c 'PR_AUTOMERGE_MODE' "$CI_CD")" -ge 1 ]
  run grep -F 'PR_AUTOMERGE_MODE' "$GIT_WF"
  [ "$status" -ne 0 ]
  [ "$(grep -ciE 'agent[- ]performed merge|agent merges|bot merges the PR' "$CI_CD" "$GIT_WF" | awk -F: '{s += $NF} END {print s + 0}')" -eq 0 ]
}

@test "AC-045-12-07 — review keys stay optional, the verdict check becomes required" {
  local sec
  sec="$(section "$CI_CD" 'PR Review Agent')"
  [[ "$sec" == *"optional"* ]]
  [[ "$sec" == *"not required check"* ]]
  [[ "$sec" == *"review-verdict"* ]]
  [[ "$sec" == *"required"* ]]
}
