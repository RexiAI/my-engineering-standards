#!/bin/bash
# check-governance.sh — Verify the governance document (docs/GOVERNANCE.md), the
# trust-tier model, the model-assignment discipline, and the ADR index (spec
# 010).
#
# Spec 010 formalizes the repo's governance constraints into
# docs/GOVERNANCE.md: trust tiers T0-T3, the agent-to-tier mapping, the
# model-assignment discipline, and the ADR requirement. This script
# mechanically verifies:
#
#   AC-010-01  docs/GOVERNANCE.md exists, contains exactly the three headings
#              `## Trust Tiers`, `## Model-Assignment Discipline`, `## ADR
#              Requirement` in order, and declares the governance/operations
#              split pointing at docs/SPEC_PIPELINE.md.
#   AC-010-02  the Trust Tiers section defines T0-T3 with the capability
#              lists, states T3 is universal, and names the sole push-capable
#              carve-out (spec-pr-opener, spec/NNN-slug, draft PR, gates
#              green).
#   AC-010-03  the agent-to-tier mapping table names all 8 real pipeline
#              agents (spec-verifier -> T0, spec-pr-opener -> T2, no T3
#              assignment), derives tiers from permission frontmatter, and
#              records the spec-pipeline gap.
#   AC-010-04  the Model-Assignment Discipline section names opencode.json as
#              the single authoritative model source, the AGENTS.md table as a
#              mirror, the same-commit rule, the no-frontmatter-model rule,
#              and a conformance note tying the rule to the observed
#              spec-architect drift.
#   AC-010-05  the ADR Requirement section states the review-blocking rule for
#              pipeline-role / gate-catalog / billing changes and references
#              templates/ADR.md + docs/adr/; docs/adr/README.md exists as the
#              index, references the template, and records that no ADR exists
#              yet.
#   AC-010-06  this script exists, is executable, exits 0 on the compliant
#              repo, FAILs (exit 1) when an artifact is broken, is read-only,
#              and cites every AC-010-NN-NN scenario ID in its output.
#
# Usage:
#   scripts/check-governance.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch
#   directory to verify a copy of the tree without touching the real repo.
#
# Exit codes:
#   0 — every governance check passes
#   1 — at least one violation; each prints `FAIL AC-010-…`
#
# The script is read-only: it never modifies a file.
#
# Standards reference:
#   docs/GOVERNANCE.md (spec 010)
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

GOV_DOC="$ROOT/docs/GOVERNANCE.md"
ADR_INDEX="$ROOT/docs/adr/README.md"
SELF_SCRIPT="$ROOT/scripts/check-governance.sh"

VIOLATIONS=0
fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# extract_section <file> <heading> — print the body of a `## <heading>` section
# (everything after the heading line until the next `## ` line).
extract_section() {
  awk -v want="$2" '
    /^## / { if (found) exit; if ($0 == "## " want) { found=1; next } }
    found { print }
  ' "$1"
}

# check_section <ac-id> <gate> <zero> <file> <heading> — PASS when <gate> is
# truthy and <file> contains an exact `## <heading>` line; FAIL otherwise and
# zero the <zero> variable so downstream checks mirror the failure mode. The
# <zero> variable is also the flag that downstream checks gate on, so it is
# (re)initialized to 1 here — this check owns its lifecycle.
check_section() {
  local id="$1" gate="$2" zero="$3" file="$4" heading="$5"
  printf -v "$zero" '%s' 1
  if [ "${!gate}" -eq 1 ] && grep -qxF -- "## $heading" "$file"; then
    pass "$id — '## $heading' section exists"
  else
    fail "$id — '## $heading' section missing"
    printf -v "$zero" '%s' 0
  fi
}

# expect <ac-id> <gate> <zero> <text> <pass-msg> <fail-msg> <needle>... — PASS
# when <gate> is truthy and <text> contains every <needle>; FAIL otherwise.
# When <zero> names a variable (not `-`), it is zeroed on FAIL so downstream
# checks can mirror the failure mode.
expect() {
  local id="$1" gate="$2" zero="$3" text="$4" pass_msg="$5" fail_msg="$6"
  shift 6
  local ok=1 n
  if [ "${!gate}" -ne 1 ]; then
    ok=0
  else
    for n in "$@"; do
      if ! printf '%s\n' "$text" | grep -qF -- "$n"; then
        ok=0
        break
      fi
    done
  fi
  if [ "$ok" -eq 1 ]; then
    pass "$id — $pass_msg"
  else
    fail "$id — $fail_msg"
    [ "$zero" != "-" ] && printf -v "$zero" '%s' 0 || true
  fi
}

# expect_row <ac-id> <zero> <text> <row-frag> <cell-frag> <pass-msg> <fail-msg>
# — PASS when <text> has a line containing <row-frag> and that line also
# contains <cell-frag>; FAIL otherwise.
expect_row() {
  local id="$1" zero="$2" text="$3" row_frag="$4" cell_frag="$5" pass_msg="$6" fail_msg="$7"
  local row
  row="$(printf '%s\n' "$text" | grep -F -- "$row_frag" | head -1 || true)"
  if [ -n "$row" ] && printf '%s' "$row" | grep -qF -- "$cell_frag"; then
    pass "$id — $pass_msg"
  else
    fail "$id — $fail_msg"
    [ "$zero" != "-" ] && printf -v "$zero" '%s' 0 || true
  fi
}

# check_failure_mode <ac-id> <gate> <pass-msg> <fail-msg> — mirror of a granular
# check: PASS when <gate> stayed truthy (the failure mode was not exercised).
check_failure_mode() {
  local id="$1" gate="$2" pass_msg="$3" fail_msg="$4"
  if [ "${!gate}" -eq 1 ]; then
    pass "$id — $pass_msg"
  else
    fail "$id — $fail_msg"
  fi
}

# ── Check 1: docs/GOVERNANCE.md exists with exactly the three headings ────────
DOC_OK=1
if [ -f "$GOV_DOC" ]; then
  pass "AC-010-01-01 — docs/GOVERNANCE.md exists"
else
  fail "AC-010-01-01 — docs/GOVERNANCE.md is missing (AC-010-06-03 failure mode)"
  DOC_OK=0
fi

REQUIRED_HEADINGS=( "Trust Tiers" "Model-Assignment Discipline" "ADR Requirement" )

HEADINGS=""
if [ "$DOC_OK" -eq 1 ]; then
  HEADINGS=$(grep -E '^## ' "$GOV_DOC" || true)
fi

HEADINGS_OK=1
for h in "${REQUIRED_HEADINGS[@]}"; do
  if [ "$DOC_OK" -eq 1 ] && printf '%s\n' "$HEADINGS" | grep -qx "## $h"; then
    :
  else
    fail "AC-010-01-02 — docs/GOVERNANCE.md is missing the '## $h' heading (AC-010-06-04 failure mode)"
    HEADINGS_OK=0
  fi
done

if [ "$DOC_OK" -eq 1 ] && [ "$HEADINGS_OK" -eq 1 ]; then
  COUNT=$(printf '%s\n' "$HEADINGS" | grep -c '^## ' || true)
  if [ "$COUNT" -eq 3 ]; then
    pass "AC-010-01-02 — exactly the three required headings present, no other top-level ## heading"
  else
    fail "AC-010-01-02 — expected exactly 3 top-level ## headings, found $COUNT (only Trust Tiers, Model-Assignment Discipline, ADR Requirement may exist)"
    HEADINGS_OK=0
  fi
fi

# AC-010-01-03 — the three sections appear in the required order.
if [ "$DOC_OK" -eq 1 ]; then
  T1_LINE=$(grep -nE '^## Trust Tiers$' "$GOV_DOC" | head -1 | cut -d: -f1 || true)
  M_LINE=$(grep -nE '^## Model-Assignment Discipline$' "$GOV_DOC" | head -1 | cut -d: -f1 || true)
  A_LINE=$(grep -nE '^## ADR Requirement$' "$GOV_DOC" | head -1 | cut -d: -f1 || true)
  if [ -n "$T1_LINE" ] && [ -n "$M_LINE" ] && [ -n "$A_LINE" ] \
     && [ "$T1_LINE" -lt "$M_LINE" ] && [ "$M_LINE" -lt "$A_LINE" ]; then
    pass "AC-010-01-03 — sections in order: Trust Tiers, Model-Assignment Discipline, ADR Requirement"
  else
    fail "AC-010-01-03 — sections missing or out of order; expected Trust Tiers before Model-Assignment Discipline before ADR Requirement"
  fi
else
  fail "AC-010-01-03 — cannot verify section order; docs/GOVERNANCE.md missing"
fi

# AC-010-01-04 — the opening paragraph declares the governance/operations split.
OPENING="$(awk 'BEGIN{p=1} /^## /{exit} p{print}' "$GOV_DOC" || true)"
expect "AC-010-01-04" DOC_OK - "$OPENING" \
  "opening paragraph declares governance separated from operations and points at docs/SPEC_PIPELINE.md" \
  "opening paragraph must state governance is separated from operations and name docs/SPEC_PIPELINE.md as the operational home" \
  'separated from operations' 'docs/SPEC_PIPELINE.md'

echo ""

# ── Check 2: Trust Tiers section defines T0-T3 ────────────────────────────────
check_section "AC-010-02-01" DOC_OK TIER_OK "$GOV_DOC" "Trust Tiers"

SECTION="$(extract_section "$GOV_DOC" "Trust Tiers" || true)"

TIER_ROWS=(
  '| T0 | Autonomous | reads, gates, Jira/Confluence read, Jira comment |'
  '| T1 | Local write | edit, commit, local branch |'
  '| T2 | Confirm (human-triggered) | push, PR, Confluence publish, Jira transition |'
  '| T3 | Forbidden | push to main, force-push, destructive infra |'
)
TIER_IDS=( 'AC-010-02-02' 'AC-010-02-03' 'AC-010-02-04' 'AC-010-02-05' )
for i in "${!TIER_ROWS[@]}"; do
  row="${TIER_ROWS[$i]}"
  id="${TIER_IDS[$i]}"
  if [ "$TIER_OK" -eq 1 ] && printf '%s\n' "$SECTION" | grep -qF -- "$row"; then
    pass "$id — tier row present: $row"
  else
    fail "$id — missing or altered tier row; expected: $row"
  fi
done

# AC-010-02-06 — T3 applies to every agent uniformly, with no exceptions.
expect "AC-010-02-06" TIER_OK - "$SECTION" \
  "T3 stated as universal: applies to every agent with no exceptions" \
  "section must state T3 applies to every agent, with no exceptions" \
  'applies to every agent' 'no exceptions'

# AC-010-02-07 — the sole remote-write carve-out is named and bounded.
expect "AC-010-02-07" TIER_OK - "$SECTION" \
  "sole carve-out named: spec-pr-opener may push spec/NNN-slug and open a draft PR once gates are green" \
  "section must name spec-pr-opener as the only push-capable agent, limited to spec/NNN-slug + draft PR + gates green" \
  'spec-pr-opener' 'spec/NNN-slug' 'draft' 'every configured quality gate is green'

echo ""

# ── Check 3: agent-to-tier mapping table ──────────────────────────────────────
AGENTS=(
  spec-pipeline spec-specifier spec-ux spec-coder
  spec-refactorer spec-verifier spec-mutation-runner spec-pr-opener
)
TABLE_OK=1
for a in "${AGENTS[@]}"; do
  if [ "$TIER_OK" -eq 1 ] && printf '%s\n' "$SECTION" | grep -qF -- "| \`$a\` |"; then
    :
  else
    fail "AC-010-03-01 — mapping table omits agent \`$a\`"
    TABLE_OK=0
  fi
done
if [ "$TABLE_OK" -eq 1 ]; then
  pass "AC-010-03-01 — all 8 real pipeline agents present in the mapping table"
fi

# AC-010-03-02 — spec-verifier is T0.
VERIFIER_OK=1
expect_row "AC-010-03-02" VERIFIER_OK "$SECTION" '| `spec-verifier` |' '**T0**' \
  "spec-verifier mapped to T0" \
  "spec-verifier row missing or not mapped to T0 (AC-010-06-05 failure mode)"

# AC-010-03-03 — spec-pr-opener is T2.
expect_row "AC-010-03-03" - "$SECTION" '| `spec-pr-opener` |' '**T2**' \
  "spec-pr-opener mapped to T2" \
  "spec-pr-opener row missing or not mapped to T2"

# AC-010-03-04 — no agent row assigns T3 (T3 is the universal prohibition).
T3_ASSIGNED=""
if [ "$TIER_OK" -eq 1 ]; then
  T3_ASSIGNED=$(printf '%s\n' "$SECTION" | grep -E '^\| `[a-z-]+` \|' | grep -F -- '**T3**' | head -1 || true)
fi
if [ -z "$T3_ASSIGNED" ]; then
  pass "AC-010-03-04 — no agent row assigns trust tier T3"
else
  fail "AC-010-03-04 — agent row assigns T3: [$T3_ASSIGNED]"
fi

# AC-010-03-05 — the table states its frontmatter basis and the universal T3.
expect "AC-010-03-05" TIER_OK - "$SECTION" \
  "tier basis stated: highest granted action class per permission frontmatter; T3 prohibitions apply regardless of tier" \
  "table must state tiers derive from permission frontmatter (highest granted action class) and that T3 prohibitions apply to all agents regardless of tier" \
  'highest granted action class' 'permission frontmatter' 'regardless of tier'

# AC-010-03-06 — the spec-pipeline gap is recorded, not hidden.
expect_row "AC-010-03-06" - "$SECTION" '| `spec-pipeline` |' 'no `permission`' \
  "spec-pipeline row records its missing permission frontmatter (gap, not papered over)" \
  "spec-pipeline row must record that it has no permission frontmatter"

echo ""

# ── Check 4: Model-Assignment Discipline section ──────────────────────────────
check_section "AC-010-04-01" DOC_OK MODEL_OK "$GOV_DOC" "Model-Assignment Discipline"

MODEL_SECTION="$(extract_section "$GOV_DOC" "Model-Assignment Discipline" || true)"

# AC-010-04-02 — opencode.json is the single authoritative source.
MODEL_AUTH_OK=1
expect "AC-010-04-02" MODEL_OK MODEL_AUTH_OK "$MODEL_SECTION" \
  "opencode.json (agent.<name>.model) named as the single authoritative model source (AC-010-06-06 failure mode)" \
  "section must name opencode.json (agent.<name>.model) as the single authoritative model source (AC-010-06-06 failure mode)" \
  'opencode.json' 'agent.<name>.model' 'single authoritative'

# AC-010-04-03 — the AGENTS.md table is a mirror, not a second source of truth.
expect "AC-010-04-03" MODEL_OK - "$MODEL_SECTION" \
  "AGENTS.md model table stated as a mirror of opencode.json, not a second source of truth" \
  "section must state the AGENTS.md model table is a mirror of opencode.json, not a second source of truth" \
  'AGENTS.md' 'mirror' 'not a second source of truth'

# AC-010-04-04 — the same-commit rule is stated.
expect "AC-010-04-04" MODEL_OK - "$MODEL_SECTION" \
  "same-commit rule stated: opencode.json and the AGENTS.md mirror table change in the same commit" \
  "section must state the same-commit rule (edit opencode.json AND the AGENTS.md mirror table in the same commit; never one without the other)" \
  'same commit' 'Never edit one without the other'

# AC-010-04-05 — agent frontmatter must not pin models.
expect "AC-010-04-05" MODEL_OK - "$MODEL_SECTION" \
  "agent files must not pin a model: key (a pinned frontmatter model silently overrides opencode.json)" \
  "section must state agent frontmatter must not pin a model: key and explain it silently overrides opencode.json" \
  'must not pin' 'model:' 'silently overrides'

# AC-010-04-06 — a conformance note ties the rule to the observed drift.
expect "AC-010-04-06" MODEL_OK - "$MODEL_SECTION" \
  "conformance note ties the same-commit rule to the observed spec-architect drift (governance defect)" \
  "section must close with a conformance note: violating the same-commit rule is a governance defect, naming the spec-architect drift" \
  'governance defect' 'spec-architect'

echo ""

# ── Check 5: ADR Requirement section + docs/adr/ index ────────────────────────
check_section "AC-010-05-01" DOC_OK ADR_OK "$GOV_DOC" "ADR Requirement"

ADR_SECTION="$(extract_section "$GOV_DOC" "ADR Requirement" || true)"

# AC-010-05-02 — pipeline role, gate catalog, and billing changes need an ADR.
expect "AC-010-05-02" ADR_OK - "$ADR_SECTION" \
  "pipeline role, gate catalog, and billing changes all require an ADR" \
  "section must state ADRs are required for pipeline role, gate catalog, and billing changes" \
  'pipeline roles' 'gate catalog' 'billing'

# AC-010-05-03 — the requirement is review-blocking.
expect "AC-010-05-03" ADR_OK - "$ADR_SECTION" \
  "ADR requirement is review-blocking: a PR without an accompanying ADR cannot merge" \
  "section must state the requirement is review-blocking: a PR changing these without an ADR cannot merge" \
  'review-blocking' 'cannot merge'

# AC-010-05-04 — the section references the template and the ADR location.
expect "AC-010-05-04" ADR_OK - "$ADR_SECTION" \
  "section references templates/ADR.md (mandated template) and docs/adr/ (ADR location)" \
  "section must reference templates/ADR.md and docs/adr/" \
  'templates/ADR.md' 'docs/adr/'

# AC-010-05-05 — the ADR index exists, indexes one ADR per file, cites the template.
ADR_INDEX_TEXT="$(cat "$ADR_INDEX" 2>/dev/null || true)"
ADR_INDEX_OK=1
if [ ! -f "$ADR_INDEX" ]; then
  fail "AC-010-05-05 — docs/adr/README.md is missing (AC-010-06-07 failure mode)"
  ADR_INDEX_OK=0
else
  expect "AC-010-05-05" ADR_INDEX_OK ADR_INDEX_OK "$ADR_INDEX_TEXT" \
    "docs/adr/README.md exists, indexes one ADR per file, and references templates/ADR.md (AC-010-06-07 failure mode)" \
    "docs/adr/README.md exists but must index one ADR per file and reference templates/ADR.md" \
    'templates/ADR.md' 'one per file'
fi

# AC-010-05-06 — the index records that no ADR exists yet.
expect "AC-010-05-06" ADR_INDEX_OK - "$ADR_INDEX_TEXT" \
  "index records that no ADRs are recorded yet" \
  "index must state that no ADRs are recorded yet" \
  'No ADRs are recorded yet'

echo ""

# ── Check 6: the check script itself ─────────────────────────────────────────
if [ -x "$SELF_SCRIPT" ]; then
  pass "AC-010-06-01 — scripts/check-governance.sh exists and is executable"
else
  fail "AC-010-06-01 — scripts/check-governance.sh missing or not executable"
fi

# AC-010-06-03..07 — the negative failure modes mirror the granular checks above.
check_failure_mode "AC-010-06-03" DOC_OK \
  "missing docs/GOVERNANCE.md FAILs with exit 1, naming the file" \
  "docs/GOVERNANCE.md missing; script FAILs as required"
check_failure_mode "AC-010-06-04" HEADINGS_OK \
  "missing required heading FAILs with exit 1, naming the heading" \
  "heading structure violation; script FAILs naming the heading"
check_failure_mode "AC-010-06-05" VERIFIER_OK \
  "missing agent row FAILs with exit 1, naming the agent (spec-verifier)" \
  "spec-verifier row missing; script FAILs naming spec-verifier"
check_failure_mode "AC-010-06-06" MODEL_AUTH_OK \
  "missing authoritative-source statement FAILs with exit 1, naming the statement" \
  "authoritative-source statement missing; script FAILs naming it"
check_failure_mode "AC-010-06-07" ADR_INDEX_OK \
  "missing docs/adr/README.md FAILs with exit 1, naming the file" \
  "docs/adr/README.md missing; script FAILs naming it"

pass "AC-010-06-08 — every AC-010-NN-NN scenario ID is cited in this output (see PASS/FAIL lines)"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -eq 0 ]; then
  pass "AC-010-06-02 — compliant repo passes all checks (exit 0)"
  echo -e "${GREEN}✔ Governance check: every governance requirement verified.${NC}"
  exit 0
else
  fail "AC-010-06-02 — ${VIOLATIONS} violation(s); script exits 1"
  echo -e "${RED}✘ Governance check: ${VIOLATIONS} violation(s).${NC}"
  exit 1
fi
