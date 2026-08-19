#!/bin/bash
# check-no-hardcoded-secrets.sh — Refuse hardcoded credential values in
# agents/, commands/, scripts/, docs/.
#
# Scans the four dirs the pipeline agents actually operate in for two classes
# of credential-looking content:
#   1. Literal token prefixes — GitHub fine-grained PAT (ghp/gho/ghu/ghs/ghr),
#      GitHub classic PAT (github_pat), AWS access key ids, Slack
#      bot/user/app tokens (xox b/a/p/r/s), OpenAI-style sk keys.
#   2. Secret-style assignments (KEY=value where the name ends in TOKEN,
#      SECRET, KEY, PASSWORD, or CREDENTIAL) whose value is a real literal —
#      not a placeholder (<...>), not a variable reference (${...} or \${...}),
#      not a quoted string, and not the word PLACEHOLDER or a YOUR_* hint.
#
# docs/changes/ is excluded: archived spec one-pagers embed the 30-report, which
# legitimately quotes token-prefix patterns and selftest fixtures as
# documentation — historical records, not live credentials.
#
# Prints each match as file:line and exits 1 on any match. The pattern
# definitions are assembled at runtime by string concatenation so scanning
# this file — and the selftest under scripts/, both in scope — stays clean; a
# literal fixture would fail the check it proves.
#
# Usage:
#   scripts/check-no-hardcoded-secrets.sh [PROJECT_ROOT]
# PROJECT_ROOT defaults to the repo root (parent of scripts/). Pass a scratch
# root to check an isolated agents/ commands/ scripts/ docs/ tree (selftest).
#
# Exit codes:
#   0 — no matches (brief PASS line)
#   1 — at least one match (each printed as file:line)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(dirname "$SCRIPT_DIR")}"

# ── Pattern assembly (runtime concatenation: see header) ─────────────────────
TOKEN_RE="ghp""_|gho""_|ghu""_|ghs""_|ghr""_|github""_pat_|AK""IA|xox[baprs]""-|sk""-[A-Za-z0-9]{20,}"
ASSIGN_RE='^(export[[:space:]]+)?[A-Z0-9_]+(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL)='

VIOLATIONS=0

# report_hit FILE LINE LABEL — print one violation as <root-relative>:line and
# count it. Shared by both scan classes so the format lives in one place.
report_hit() {
  local file="$1" line="$2" label="$3"
  echo "  ${file#$ROOT/}:$line: $label"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# is_ignored_rhs RHS — 0 when a secret-style assignment value is a non-literal:
# placeholder (<...>), variable reference (${...} or \${...}), quoted string, or
# the words PLACEHOLDER / YOUR_*.
is_ignored_rhs() {
  case "$1" in
    '' | '${'* | '\${'* | '<'* | '"'* | "'"* | PLACEHOLDER* | YOUR_*) return 0 ;;
  esac
  return 1
}

# scan_root ROOT — walk agents/ commands/ scripts/ docs/ under ROOT and report
# class-1 (literal token prefix) and class-2 (secret-style assignment) matches.
scan_root() {
  local root="$1" dir file text rhs
  for dir in agents commands scripts docs; do
    [ -d "$root/$dir" ] || continue
    while IFS= read -r -d '' file; do
      # Class 1: literal token prefixes
      while IFS= read -r hit; do
        report_hit "$file" "${hit%%:*}" "literal token prefix"
      done < <(grep -nE "$TOKEN_RE" "$file" || true)

      # Class 2: secret-style assignments with a literal value
      while IFS= read -r hit; do
        text="${hit#*:}"
        rhs="${text#*=}"
        if is_ignored_rhs "$rhs"; then continue; fi
        report_hit "$file" "${hit%%:*}" "secret-style assignment: $text"
      done < <(grep -nE "$ASSIGN_RE" "$file" || true)
    done < <(find "$root/$dir" -type f -not -path "*/docs/changes/*" -print0 2>/dev/null || true)
  done
}

scan_root "$ROOT"

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-no-hardcoded-secrets: $VIOLATIONS violation(s) in agents/ commands/ scripts/ docs/.${NC}"
  exit 1
fi
echo -e "${GREEN}PASS${NC} check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/."
