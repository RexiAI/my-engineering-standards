#!/bin/bash
# check-no-hardcoded-secrets.sh — Refuse hardcoded credential values in
# .github/, agents/, commands/, scripts/, config/, templates/, ci/, docs/.
#
# Scans those dirs for two classes of credential-looking content:
#   1. Literal token prefixes — GitHub fine-grained PAT (ghp/gho/ghu/ghs/ghr),
#      GitHub classic PAT (github_pat), AWS access key ids, Slack
#      bot/user/app tokens (xox b/a/p/r/s), OpenAI-style sk keys.
#   2. Secret-style assignments (KEY=value where the name ends in TOKEN,
#      SECRET, KEY, PASSWORD, or CREDENTIAL) whose value looks like a real
#      literal — not empty, not a variable reference (${...} or \${...}), and
#      not a recognized placeholder. A QUOTED value is NOT automatically
#      ignored (spec 026, AC-026-09): a real secret is normally written as
#      `TOKEN="the-actual-value"` in shell — quoting is how literals are
#      written, not evidence they are placeholders. Only the placeholder
#      content inside the quotes (or outside them) is ignored:
#      angle-bracket hints (`<...>`), the literal words PLACEHOLDER / YOUR_*,
#      and common example markers (xxx, changeme, example, dummy, sample —
#      case-insensitive).
#
# Scope (spec 026, AC-026-09): widened from the original agents/ commands/
# scripts/ docs/ to also cover .github/ (workflow YAML, where a secret is
# just as damaging), config/ (the *.local.env.example templates use the
# angle-bracket placeholder convention, still recognized below), templates/,
# and ci/. docs/changes/ stays excluded: archived spec one-pagers embed the
# 30-report, which legitimately quotes token-prefix patterns and selftest
# fixtures as documentation — historical records, not live credentials.
#
# Prints each match as file:line and exits 1 on any match. The pattern
# definitions are assembled at runtime by string concatenation so scanning
# this file — and the selftest under scripts/, both in scope — stays clean; a
# literal fixture would fail the check it proves.
#
# Usage:
#   scripts/check-no-hardcoded-secrets.sh [PROJECT_ROOT]
#   scripts/check-no-hardcoded-secrets.sh --self-test
# PROJECT_ROOT defaults to the repo root (parent of scripts/). Pass a scratch
# root to check an isolated tree (used by --self-test, and available for a
# CI-side scratch-repo check the same way other check-*.sh scripts support
# one positional scratch-root argument).
#
# Exit codes:
#   0 — no matches (brief PASS line), or --self-test: every case behaved
#   1 — at least one match (each printed as file:line), or --self-test: a
#       case did not behave as expected
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pattern assembly (runtime concatenation: see header) ─────────────────────
TOKEN_RE="ghp""_|gho""_|ghu""_|ghs""_|ghr""_|github""_pat_|AK""IA|xox[baprs]""-|sk""-[A-Za-z0-9]{20,}"
ASSIGN_RE='^(export[[:space:]]+)?[A-Z0-9_]+(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL)='
PLACEHOLDER_RE='(PLACEHOLDER|YOUR_[A-Z0-9_]*|xxx|changeme|example|dummy|sample)'

VIOLATIONS=0
DIRS="agents commands scripts docs .github config templates ci"

# report_hit FILE LINE LABEL — print one violation as <root-relative>:line and
# count it. Shared by both scan classes so the format lives in one place.
report_hit() {
  local root="$1" file="$2" line="$3" label="$4"
  echo "  ${file#$root/}:$line: $label"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# is_ignored_rhs RHS — 0 when a secret-style assignment value is a
# non-literal: empty, a variable reference (${...}, \${...}, or a quoted
# string whose content starts with $, e.g. "$HOME/.ssh/id_rsa"), an
# angle-bracket placeholder (possibly inside quotes, e.g. "<your-token>"),
# or a recognized placeholder/example word (possibly inside quotes).
# A plain quoted string that is NOT one of the above (e.g. "sk-abc123real")
# is NOT ignored — this is the fix for AC-026-09: quoting alone no longer
# exempts a value.
is_ignored_rhs() {
  local v="$1" unquoted="$1"
  case "$v" in
    '' | '${'* | '\${'*) return 0 ;;
  esac
  # Strip one layer of surrounding quotes (if present) before the
  # placeholder-content checks below, so "<...>" and "YOUR_*" are still
  # recognized whether or not the template author quoted them.
  case "$v" in
    '"'*'"') unquoted="${v#\"}"; unquoted="${unquoted%\"}" ;;
    "'"*"'") unquoted="${v#\'}"; unquoted="${unquoted%\'}" ;;
  esac
  case "$unquoted" in
    '' | '<'* | '$'*) return 0 ;;
  esac
  if echo "$unquoted" | grep -qEi "$PLACEHOLDER_RE"; then
    return 0
  fi
  return 1
}

# scan_root ROOT — walk the scoped dirs under ROOT and report class-1
# (literal token prefix) and class-2 (secret-style assignment) matches.
scan_root() {
  local root="$1" dir file text rhs
  for dir in $DIRS; do
    [ -d "$root/$dir" ] || continue
    while IFS= read -r -d '' file; do
      # Class 1: literal token prefixes
      while IFS= read -r hit; do
        report_hit "$root" "$file" "${hit%%:*}" "literal token prefix"
      done < <(grep -nE "$TOKEN_RE" "$file" || true)

      # Class 2: secret-style assignments with a literal value
      while IFS= read -r hit; do
        text="${hit#*:}"
        rhs="${text#*=}"
        if is_ignored_rhs "$rhs"; then continue; fi
        report_hit "$root" "$file" "${hit%%:*}" "secret-style assignment: $text"
      done < <(grep -nE "$ASSIGN_RE" "$file" || true)
    done < <(find "$root/$dir" -type f -not -path "*/docs/changes/*" -print0 2>/dev/null || true)
  done
}

run_check() {
  local root="$1"
  VIOLATIONS=0
  scan_root "$root"
  [ "$VIOLATIONS" -eq 0 ]
}

if [ "${1:-}" = "--self-test" ]; then
  # AC-026-09 selftest: build a scratch tree and assert the fixed behavior —
  # a quoted, real-looking secret is now caught (the regression this fix
  # closes), and every legitimate placeholder form still passes clean.
  TMPROOT="$(mktemp -d)"
  trap 'rm -rf "$TMPROOT"' EXIT
  mkdir -p "$TMPROOT/config" "$TMPROOT/.github/workflows"
  FAILURES=0

  # Case 1: quoted real-looking secret in config/ — must be CAUGHT (exit 1).
  # Built by concatenation (not a literal "sk-..." substring) so this file
  # itself keeps scanning clean under its own check (see header note).
  printf 'API_SECRET="%s"\n' "sk""-realtokvaluehere1234567890" > "$TMPROOT/config/real.env"
  rc=0; run_check "$TMPROOT" > /tmp/nhcs-case1.$$ 2>&1 || rc=$?
  rm -f "$TMPROOT/config/real.env"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL case 1: quoted real-looking secret in config/ was not caught (regression: AC-026-09)"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS case 1: quoted real-looking secret in config/ is caught"
  fi

  # Case 2: quoted angle-bracket placeholder in config/ — must PASS (exit 0).
  printf 'GH_TOKEN="<your-github-personal-access-token>"\n' > "$TMPROOT/config/placeholder.env"
  if run_check "$TMPROOT" > /tmp/nhcs-case2.$$ 2>&1; then
    echo "PASS case 2: quoted angle-bracket placeholder in config/ still passes"
  else
    echo "FAIL case 2: quoted angle-bracket placeholder in config/ was wrongly flagged"
    FAILURES=$((FAILURES + 1))
  fi
  rm -f "$TMPROOT/config/placeholder.env"

  # Case 3: unquoted YOUR_* placeholder — must PASS (exit 0).
  printf 'DB_PASSWORD=YOUR_DB_PASSWORD_HERE\n' > "$TMPROOT/config/case3.env"
  if run_check "$TMPROOT" > /tmp/nhcs-case3.$$ 2>&1; then
    echo "PASS case 3: YOUR_* placeholder still passes"
  else
    echo "FAIL case 3: YOUR_* placeholder was wrongly flagged"
    FAILURES=$((FAILURES + 1))
  fi
  rm -f "$TMPROOT/config/case3.env"

  # Case 4: a secret hardcoded in .github/ (widened scope) — must be CAUGHT.
  # Built by concatenation for the same self-scan-clean reason as Case 1.
  printf '        env:\n          GHCR_TOKEN: "%s"\n' "ghp""_1234567890abcdef1234567890abcdef1234" \
    > "$TMPROOT/.github/workflows/leaky.yml"
  rc=0; run_check "$TMPROOT" > /tmp/nhcs-case4.$$ 2>&1 || rc=$?
  rm -f "$TMPROOT/.github/workflows/leaky.yml"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL case 4: literal token prefix in .github/ (widened scope) was not caught"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS case 4: literal token prefix in .github/ (widened scope) is caught"
  fi

  rm -f /tmp/nhcs-case1.$$ /tmp/nhcs-case2.$$ /tmp/nhcs-case3.$$ /tmp/nhcs-case4.$$

  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}✘ check-no-hardcoded-secrets --self-test: $FAILURES case(s) failed.${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASS${NC} check-no-hardcoded-secrets --self-test: all cases behaved as expected."
  exit 0
fi

ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
run_check "$ROOT" || true

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-no-hardcoded-secrets: $VIOLATIONS violation(s) in ${DIRS// /, }.${NC}"
  exit 1
fi
echo -e "${GREEN}PASS${NC} check-no-hardcoded-secrets: no hardcoded credential values in ${DIRS// /, }."
