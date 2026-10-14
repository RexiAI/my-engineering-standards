#!/usr/bin/env bash
# tests/AC-030-07.sh — T7: gate verification (final holistic check)
# Scenarios from specs/030-e2e-skill-agent/20-acceptance/AC-030-07.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"

# run_gate <id> <script...> — the named gate must exit 0
run_gate() {
  local id="$1"; shift
  local log rc=0 out
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "$id: $* exited 0 — $(printf '%s' "$out" | tail -1 | cut -c1-120)"
  else
    fail "$id: $* exited $rc — $(printf '%s' "$out" | grep -E 'FAIL|BROKEN|error|violation' | head -3 | tr '\n' ' ')"
  fi
}

# AC-030-07-01 — check-skills.sh exits 0
s_030_07_01() { run_gate "AC-030-07-01" bash scripts/check-skills.sh; }

# AC-030-07-02 — check-orchestration.sh exits 0
s_030_07_02() { run_gate "AC-030-07-02" bash scripts/check-orchestration.sh; }

# Clause A — no literal model/provider ids in any tracked file. Full-tree
# grep for the scenario's patterns. Documented scoping (the tree predates
# this spec; out-of-scope findings recorded, never fixed — Stop-and-Ask
# matrix "Out-of-scope finding"):
#   * opencode.json provider block: operator config, carved out by ADR
#     0002/0003 and by check-model-env.sh itself — scanned only outside the
#     provider region (same sed as check-model-env.sh).
#   * CHANGELOG.md: historical release notes quoting retired pins.
#   * scripts/sync-qwen-settings.sh: an API endpoint URL path, not a model id.
#   * skills/hallmark/references/*.md: third-party design doc URLs.
#   * specs/ and docs/changes/ path prefixes: the pipeline's own artifact
#     prose, live and archived alike. Both lifecycle states quote these
#     patterns as their job — the acceptance scenario lists them and any
#     faithful verification report quotes them back — and SPEC_PIPELINE.md
#     §Archive in the PR already treats specs/*/ and docs/changes/*.md as
#     the same content in two states (the traceability scanner excludes both
#     from its reference scan for exactly this reason). The archive commit
#     moves the quoting prose from one prefix to the other, so excluding
#     only the live state is the defect that tripped the 028 phase-2 round-1
#     CI failure; this filter follows that fix's shape (option A, phase-2
#     round-1 diagnosis in docs/changes/030-e2e-skill-agent.md). Directory
#     prefixes carry no trailing-`:` anchor: git grep lines are `path:line:
#     content`, so the prefix match alone scopes the whole subtree.
# Every other tracked match is a violation; deliverable files (below) must be
# strictly clean with no exclusions.
# Extracted from s_030_07_03 to keep both under the ≤6 decision-point bound.
t7_ids_clause() {
  local hits rest
  hits="$(git grep -niE "$ID_PATTERNS" -- . ':(exclude)opencode.json' 2>/dev/null || true)"
  rest="$(printf '%s\n' "$hits" | grep -vE '^(CHANGELOG\.md|scripts/sync-qwen-settings\.sh|skills/hallmark/references/assets\.md|skills/hallmark/references/custom-craft\.md):|^specs/|^docs/changes/' | grep -v '^$' || true)"
  if [ -z "$rest" ]; then
    pass "AC-030-07-03: tracked-tree scan clean outside the documented pre-existing allow-list"
  else
    fail "AC-030-07-03: unexpected literal model/provider id matches: $rest"
  fi
  local oc_scan
  oc_scan="$(sed -E 's/"[[:space:]]*\$schema[[:space:]]*"[[:space:]]*:[[:space:]]*"[^"]*"[[:space:]]*[,]?//' opencode.json | sed -E '/^[[:space:]]*"provider"[[:space:]]*:/,$d')"
  if printf '%s' "$oc_scan" | grep -qiE "$ID_PATTERNS"; then
    fail "AC-030-07-03: opencode.json carries a literal id outside its provider block"
  else
    pass "AC-030-07-03: opencode.json clean outside the provider block (provider is operator config, ADR 0002/0003)"
  fi
}

# Clause B — no forbidden re-run phrasing in any tracked file under skills/
# or agents/. Extracted from s_030_07_03 (see bound note above).
t7_phrase_clause() {
  local phits
  phits="$(git grep -niE "$(forbidden_phrase)" -- skills agents 2>/dev/null || true)"
  if [ -z "$phits" ]; then
    pass "AC-030-07-03: forbidden re-run phrasing absent from tracked skills/ and agents/"
  else
    fail "AC-030-07-03: forbidden re-run phrasing present: $phits"
  fi
}

# AC-030-07-03 — check-model-env.sh exits 0 (T6 executed or not), plus the
# holistic hygiene clauses of the scenario.
s_030_07_03() {
  run_gate "AC-030-07-03" bash scripts/check-model-env.sh
  t7_ids_clause
  t7_phrase_clause
}

# Spec-030 deliverable files, strictly id-clean (no allow-list — see clause A
# scoping above). File-level constant: the list is data, not function logic.
DELIVERABLE_FILES=(
  "skills/e2e-testing/SKILL.md"
  "skills/e2e-testing/references/setup.md"
  "skills/e2e-testing/references/writing-tests.md"
  "skills/e2e-testing/references/running-debugging.md"
  "skills/e2e-testing/references/bug-bash.md"
  "skills/e2e-testing/references/ci.md"
  "skills/e2e-testing/references/mobile-rn.md"
  "skills/e2e-testing/assets/e2e.config.example.ts"
  "agents/e2e-runner.md"
  "docs/TESTING.md"
  "AGENTS.md"
  "opencode.json"
  "config/model.local.env.example"
)

# t7_file_id_clean <file> — exit 0 when the file carries no literal
# model/provider id. opencode.json is scanned outside its provider block
# only (operator config, ADR 0002/0003).
t7_file_id_clean() {
  if [ "$1" = "opencode.json" ]; then
    if sed -E '/^[[:space:]]*"provider"[[:space:]]*:/,$d' "$1" | grep -qiE "$ID_PATTERNS"; then return 1; fi
    return 0
  fi
  if grep -qiE "$ID_PATTERNS" "$1"; then return 1; fi
  return 0
}

# unit — every spec-030 deliverable file exists and is strictly id-clean
u_030_07_deliverables_clean() {
  local f bad=""
  for f in "${DELIVERABLE_FILES[@]}"; do
    [ -f "$f" ] || { bad="$bad missing:$f"; continue; }
    if ! t7_file_id_clean "$f"; then bad="$bad $f"; fi
  done
  if [ -z "$bad" ]; then pass "unit T7: all deliverable files present and id-clean"; else fail "unit T7: deliverables with id matches or missing:$bad"; fi
}

# unit — no hardcoded secrets in the shipped tree (T7 bullet). The repo's own
# scanner runs against a replica of what CI checks out: tracked files at their
# working-tree content, plus this spec's new deliverables. The live working
# directory additionally holds the gitignored per-machine credential files
# (config/agent.local.env) that the repo standard says must exist locally and
# must never be tracked — a local-tree scan would flag those and misreport.
u_030_07_no_secrets() {
  local tmp rc=0
  tmp="$(mktemp -d)"
  git ls-files -z | tar --null -cf - -T - 2>/dev/null | tar -xf - -C "$tmp"
  mkdir -p "$tmp/skills" "$tmp/agents" "$tmp/scripts/tests"
  cp -R skills/e2e-testing "$tmp/skills/" 2>/dev/null || true
  cp agents/e2e-runner.md "$tmp/agents/" 2>/dev/null || true
  cp scripts/tests/ac-030-e2e-skill-agent.bats "$tmp/scripts/tests/" 2>/dev/null || true
  bash "$AC030_ROOT/scripts/check-no-hardcoded-secrets.sh" "$tmp" >/tmp/ac030-07-secrets.log 2>&1 || rc=$?
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    pass "unit T7: no hardcoded secrets in tracked tree + deliverables (clean-checkout replica scan)"
  else
    fail "unit T7: secrets scan exited $rc — $(grep -E 'literal|assignment' /tmp/ac030-07-secrets.log | head -3 | tr '\n' ' ')"
  fi
}

main_dispatch "030_07" "${1:-all}"
finish "AC-030-07"
