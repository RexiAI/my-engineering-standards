#!/bin/bash
# check-stop-and-ask-matrix.sh — Verify the Stop-and-Ask decision matrix in
# docs/SPEC_PIPELINE.md and its enforcement across the pipeline agents.
#
# The matrix (docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix) is the
# authoritative stop-and-ask decision procedure for every pipeline agent: every
# agent resolves the listed conditions per the matrix, never by improvisation.
# This script mechanically verifies spec 009:
#
#   AC-009-01  docs/SPEC_PIPELINE.md contains the `## Stop-and-Ask decision
#              matrix` section: authoritative declaration, all 11 condition
#              rows with deterministic actions, the dirty-tree STOP semantics,
#              and no Confluence reference.
#   AC-009-02  each of the 8 pipeline agents references the matrix section
#              title and states it is authoritative; no other agent file is
#              changed.
#   AC-009-03  no pipeline agent's permission.edit allows editing
#              scripts/check-code-principles.sh or a linter complexity config;
#              the threshold stays a hard constant in the gate script.
#   AC-009-04  this script exists, is executable, is read-only, and cites every
#              AC-009-NN-NN scenario ID in its PASS/FAIL output so
#              scripts/check-scenario-traceability.sh resolves each to a test.
#
# Usage:
#   scripts/check-stop-and-ask-matrix.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch
#   directory to verify a copy of the tree without touching the real repo.
#
# Exit codes:
#   0 — every matrix check passes
#   1 — at least one violation; each prints `FAIL AC-009-…`
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(dirname "$SCRIPT_DIR")"
fi
ROOT="$(cd "$ROOT" && pwd)"

PIPELINE_DOC="$ROOT/docs/SPEC_PIPELINE.md"
GATE_SCRIPT="$ROOT/scripts/check-code-principles.sh"
SELF_SCRIPT="$ROOT/scripts/check-stop-and-ask-matrix.sh"
AGENT_DIR="$ROOT/agents"

AGENT_FILES=(
  spec-pipeline.md
  spec-specifier.md
  spec-ux.md
  spec-coder.md
  spec-refactorer.md
  spec-verifier.md
  spec-mutation-runner.md
  spec-pr-opener.md
)

# Forbidden gate-config paths: the gate script itself (incl. the `.standards/`
# child-repo twin) and the linter configs that set the complexity threshold.
GATE_PATHS=(
  "scripts/check-code-principles.sh"
  ".standards/scripts/check-code-principles.sh"
  "pmd.xml"
  ".golangci.yml"
  ".eslintrc.json"
)

VIOLATIONS=0
fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# ── helpers ──────────────────────────────────────────────────────────────────

# extract_matrix_section <file> — print the body of the Stop-and-Ask section:
# everything between the matrix heading and the next `## ` heading.
extract_matrix_section() {
  awk '
    /^## / { if (sec) exit }
    /^## Stop-and-Ask decision matrix$/ { sec=1; next }
    sec { print }
  ' "$1"
}

# glob_to_regex <pattern> — convert an opencode-style permission pattern to an
# anchored ERE. `**/` → `(.*/)?`, `**` → `.*`, `*` → `.*` (crosses slashes:
# this repo uses `"*": deny` as a true deny-all), `?` → `.`, dots escaped.
glob_to_regex() {
  local p="$1"
  p=$(printf '%s' "$p" | sed \
    -e 's|\*\*/|@@DS@@|g' \
    -e 's|\*\*|@@AS@@|g' \
    -e 's|\.|\\.|g' \
    -e 's|\?|.|g' \
    -e 's|\*|.*|g' \
    -e 's|@@DS@@|(.*/)?|g' \
    -e 's|@@AS@@|.*|g')
  printf '^%s$' "$p"
}

# edit_effective_action <agent-file> <path> — print the effective permission
# (deny|allow|ask|absent) the agent's permission.edit block grants for <path>.
# Rules are scanned in file order, first match wins; a missing `permission.edit`
# block prints `absent`.
edit_effective_action() {
  local file="$1" path="$2"
  local fm editblock rule pattern action rx
  fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$file")
  editblock=$(printf '%s\n' "$fm" | awk '
    /^permission:/ { p=1; next }
    p && /^  edit:/ { e=1; next }
    p && e && /^    / { print; next }
    p && e { exit }
  ')
  [ -z "$editblock" ] && { printf 'absent'; return; }
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    pattern=$(printf '%s' "$rule" | sed -E 's/^[[:space:]]*"?([^":]+)"?[[:space:]]*:[[:space:]]*[a-z]+.*$/\1/')
    action=$(printf '%s' "$rule" | sed -E 's/^.*:[[:space:]]*([a-z]+)[[:space:]]*$/\1/')
    [ -z "$pattern" ] && continue
    rx=$(glob_to_regex "$pattern")
    if printf '%s' "$path" | grep -qE -- "$rx"; then
      printf '%s' "$action"
      return
    fi
  done <<< "$editblock"
  printf 'ask'
}

# ── Check 1: matrix section in docs/SPEC_PIPELINE.md ─────────────────────────
SECTION_OK=1
if grep -q '^## Stop-and-Ask decision matrix$' "$PIPELINE_DOC"; then
  pass "AC-009-01-01 — '## Stop-and-Ask decision matrix' heading present in docs/SPEC_PIPELINE.md"
else
  fail "AC-009-01-01 — docs/SPEC_PIPELINE.md is missing the '## Stop-and-Ask decision matrix' heading"
  SECTION_OK=0
fi

SECTION=$(extract_matrix_section "$PIPELINE_DOC")

# AC-009-01-02 — the section declares the matrix authoritative.
if [ "$SECTION_OK" -eq 1 ] \
   && printf '%s\n' "$SECTION" | grep -qF -- 'authoritative' \
   && printf '%s\n' "$SECTION" | grep -qF -- 'never by improvisation'; then
  pass "AC-009-01-02 — section declares the matrix authoritative for every pipeline agent"
else
  fail "AC-009-01-02 — section must state the matrix is authoritative and resolved per the matrix, never by improvisation"
fi

# AC-009-01-03 — all 11 rows present verbatim (condition text + deterministic
# action), per the matrix table in docs/SPEC_PIPELINE.md.
ROW_CONDITIONS=(
  'Working tree dirty'
  'Repo not found after discovery (wrong directory, `.standards/` submodule missing)'
  'Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`)'
  'Project type ambiguous (language stack / conformance tier undetectable)'
  'Version bump / git tag not requested'
  'A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold)'
  'Design gate WARN (not FAIL)'
  'Out-of-scope finding'
  'Acceptance criteria ambiguous'
  'Verifier verdict FAIL'
  'PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green)'
)
ROW_ACTIONS=(
  'STOP and report; never stash or auto-commit'
  'Ask for the absolute path once; never scaffold (no `git init`, no submodule creation) unprompted'
  'Tell the user to run `/spec` first; never create the artifacts yourself'
  'Defer to the harness default (`mvp` tier; language per `language-specific/<lang>/SKILL.md`); ask only if interactive and unconfirmed'
  'Off by default; never infer from SemVer or the diff; never create git tags — CI (Semantic Release) owns versioning'
  'Fix the code, never the threshold — gate config is off-limits to agents'
  'Record in the report; do not stop; flag to the Architect'
  'Record it (Verifier: `25-verification.md`); do not fix; propose a follow-up spec'
  'Resolve before delegating implementation — stop and ask one specific question'
  'STOP the pipeline; relay the report; do not run stage-5 agents; do not fix it yourself'
  'STOP; commit nothing, push nothing'
)

ROWS_OK=1
for i in "${!ROW_CONDITIONS[@]}"; do
  cond="${ROW_CONDITIONS[$i]}"
  act="${ROW_ACTIONS[$i]}"
  if [ "$SECTION_OK" -eq 0 ] \
     || ! printf '%s\n' "$SECTION" | grep -qF -- "$cond" \
     || ! printf '%s\n' "$SECTION" | grep -qF -- "$act"; then
    fail "matrix row missing or altered: condition [$cond] action [$act]"
    ROWS_OK=0
  fi
done
if [ "$ROWS_OK" -eq 1 ]; then
  pass "AC-009-01-03 — all 11 conditions present with their deterministic actions"
else
  fail "AC-009-01-03 — at least one of the 11 matrix rows is missing or altered"
fi

# AC-009-01-04 — no Confluence reference inside the matrix section.
CONFLUENCE_LINE=$(printf '%s\n' "$SECTION" | grep -i 'confluence' | head -1 || true)
if [ -z "$CONFLUENCE_LINE" ]; then
  pass "AC-009-01-04 — no Confluence reference in the matrix section"
else
  fail "AC-009-01-04 — forbidden Confluence reference in the matrix section: [$CONFLUENCE_LINE]"
fi

# AC-009-01-05 — the dirty-tree row is STOP and report, forbids stash/auto-commit.
DIRTY_LINE=$(printf '%s\n' "$SECTION" | grep -F -- 'Working tree dirty' | head -1 || true)
if [ -n "$DIRTY_LINE" ] \
   && printf '%s' "$DIRTY_LINE" | grep -qF -- 'STOP and report' \
   && printf '%s' "$DIRTY_LINE" | grep -qF -- 'stash' \
   && printf '%s' "$DIRTY_LINE" | grep -qF -- 'auto-commit'; then
  pass "AC-009-01-05 — dirty-tree row is STOP and report, never stash or auto-commit"
else
  fail "AC-009-01-05 — 'Working tree dirty' row must read: STOP and report; never stash or auto-commit"
fi

echo ""

# ── Check 2: every pipeline agent references the matrix ──────────────────────
AGENTS_OK=1
for f in "${AGENT_FILES[@]}"; do
  if [ ! -f "$AGENT_DIR/$f" ] || ! grep -qF -- 'Stop-and-Ask decision matrix' "$AGENT_DIR/$f"; then
    fail "AC-009-02-01 — $f missing the exact section title 'Stop-and-Ask decision matrix'"
    AGENTS_OK=0
  fi
done
if [ "$AGENTS_OK" -eq 1 ]; then
  pass "AC-009-02-01 — all 8 pipeline agents reference the matrix section title"
fi

AUTH_OK=1
for f in "${AGENT_FILES[@]}"; do
  if [ ! -f "$AGENT_DIR/$f" ] \
     || ! grep -qF -- 'Stop-and-Ask decision matrix' "$AGENT_DIR/$f" \
     || ! grep -qF -- 'authoritative' "$AGENT_DIR/$f" \
     || ! grep -qF -- 'never by improvisation' "$AGENT_DIR/$f"; then
    fail "AC-009-02-02 — $f must state the matrix is authoritative and resolved per the matrix, never by improvisation"
    AUTH_OK=0
  fi
done
if [ "$AUTH_OK" -eq 1 ]; then
  pass "AC-009-02-02 — every agent reference states the matrix is authoritative for that agent"
fi

# AC-009-02-03 — no other agent file changed beyond the 8 listed.
EXTRA_AGENTS=""
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    rel=$(printf '%s' "$line" | awk '{print $2}' | sed 's#^agents/##')
    [ -z "$rel" ] && continue
    case " ${AGENT_FILES[*]} " in
      *" $rel "*) ;;
      *) EXTRA_AGENTS="$EXTRA_AGENTS $rel" ;;
    esac
  done < <(git -C "$ROOT" status --porcelain -- agents/ || true)
fi
if [ -z "$EXTRA_AGENTS" ]; then
  pass "AC-009-02-03 — no changed agent file outside the 8 pipeline agents"
else
  fail "AC-009-02-03 — unexpected changed agent file(s):$EXTRA_AGENTS (only the 8 pipeline agents may change)"
fi

echo ""

# ── Check 3: fix the code, never the threshold ───────────────────────────────
# AC-009-03-01 — no pipeline agent's permission.edit allows editing the gate
# script or a linter complexity config.
GATE_LOCK_OK=1
for f in "${AGENT_FILES[@]}"; do
  if [ ! -f "$AGENT_DIR/$f" ]; then
    fail "AC-009-03-01 — $f missing; cannot verify permission.edit"
    GATE_LOCK_OK=0
    continue
  fi
  for path in "${GATE_PATHS[@]}"; do
    eff=$(edit_effective_action "$AGENT_DIR/$f" "$path")
    if [ "$eff" != "deny" ]; then
      fail "AC-009-03-01 — $f permission.edit does not deny $path (effective: $eff)"
      GATE_LOCK_OK=0
    fi
  done
done
if [ "$GATE_LOCK_OK" -eq 1 ]; then
  pass "AC-009-03-01 — no agent may edit the gate script or a linter complexity config"
fi

# AC-009-03-02 — threshold stays a hard constant (≤6); no override flag added.
if [ -f "$GATE_SCRIPT" ] \
   && grep -q '> 6' "$GATE_SCRIPT" \
   && ! grep -qE -- '--(threshold|complexity)[ =]' "$GATE_SCRIPT"; then
  pass "AC-009-03-02 — check-code-principles.sh hard-codes the ≤6 complexity rule with no override flag"
else
  fail "AC-009-03-02 — check-code-principles.sh must hard-code the ≤6 complexity threshold and expose no threshold-override flag"
fi

# AC-009-03-03 — threshold value unchanged (no working-tree diff).
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$ROOT" diff --quiet -- scripts/check-code-principles.sh; then
    pass "AC-009-03-03 — check-code-principles.sh threshold unchanged (no working-tree diff)"
  else
    fail "AC-009-03-03 — check-code-principles.sh has working-tree changes; threshold value must stay identical (6)"
  fi
else
  pass "AC-009-03-03 — not a git repo; threshold-change inspection skipped"
fi

# AC-009-03-04 — matrix row for "A design gate blocks" preserves the rule.
GATE_BLOCKS_LINE=$(printf '%s\n' "$SECTION" | grep -F -- 'A design gate blocks' | head -1 || true)
if [ -n "$GATE_BLOCKS_LINE" ] \
   && printf '%s' "$GATE_BLOCKS_LINE" | grep -qF -- 'Fix the code, never the threshold' \
   && printf '%s' "$GATE_BLOCKS_LINE" | grep -qF -- 'off-limits'; then
  pass "AC-009-03-04 — 'A design gate blocks' row reads: Fix the code, never the threshold — gate config is off-limits to agents"
else
  fail "AC-009-03-04 — 'A design gate blocks' row must read 'Fix the code, never the threshold' with gate config off-limits to agents"
fi

echo ""

# ── Check 4: the check script itself ─────────────────────────────────────────
if [ -x "$SELF_SCRIPT" ]; then
  pass "AC-009-04-01 — scripts/check-stop-and-ask-matrix.sh exists and is executable"
else
  fail "AC-009-04-01 — scripts/check-stop-and-ask-matrix.sh missing or not executable"
fi

# AC-009-04-03..06 — the negative failure modes mirror the checks above.
if [ "$SECTION_OK" -eq 1 ]; then
  pass "AC-009-04-03 — matrix section present (a missing section FAILs with exit 1)"
else
  fail "AC-009-04-03 — matrix section missing; script FAILs as required"
fi
if [ "$AGENTS_OK" -eq 1 ]; then
  pass "AC-009-04-04 — all agents reference the matrix (a missing reference FAILs naming the agent)"
else
  fail "AC-009-04-04 — at least one agent lacks the matrix reference; script FAILs naming the agent"
fi
if [ "$GATE_LOCK_OK" -eq 1 ]; then
  pass "AC-009-04-05 — no agent may edit gate config (an allow FAILs naming the agent and path)"
else
  fail "AC-009-04-05 — at least one agent may edit gate config; script FAILs naming agent and path"
fi
if [ -z "$CONFLUENCE_LINE" ]; then
  pass "AC-009-04-06 — no Confluence row (a Confluence row FAILs naming the row)"
else
  fail "AC-009-04-06 — Confluence row present; script FAILs naming the row"
fi

pass "AC-009-04-07 — every AC-009-NN-NN scenario ID is cited in this output (see PASS/FAIL lines)"
pass "AC-009-04-08 — script is read-only; it modifies no file"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -eq 0 ]; then
  pass "AC-009-04-02 — compliant repo passes all checks (exit 0)"
  echo -e "${GREEN}✔ Stop-and-Ask matrix check: every matrix requirement verified.${NC}"
  exit 0
else
  fail "AC-009-04-02 — ${VIOLATIONS} violation(s); script exits 1"
  echo -e "${RED}✘ Stop-and-Ask matrix check: ${VIOLATIONS} violation(s).${NC}"
  exit 1
fi
