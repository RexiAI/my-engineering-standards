#!/bin/bash
# check-pr-review.selftest.sh — Hermetic regression net for check-pr-review.sh.
# No network, no GitHub, no opencode binary. Fixtures live in mktemp -d with
# trap cleanup.
#
# The interactive secret-prompt scenarios (AC-024-04-04 / AC-024-04-05) are
# the ones the static gate cannot prove: whether OPENCODE_API_KEY is actually
# prompted depends on the flag and on a TTY. The gate checks the structural
# placement of the read; this selftest proves the *behavior* by running
# init-ci.sh under a pseudo-TTY (script(1)) with and without --with-pr-review
# and counting the OPENCODE_API_KEY prompt occurrences.
#
# Scenario traceability: the AC-024 IDs below are the tests for the
# 20-acceptance scenarios.
#
# The AC-024-01-12 change-set guard is exercised here too, against a hermetic
# scratch git repo: undocumented spec-agent change fails, an ADR in the same
# change set passes, and an unresolvable base fails loudly instead of passing
# vacuously (ADR 0009 amendment — the shallow-clone CI case cannot be
# reproduced with the static gate alone, so it is pinned here).
#
# Usage:
#   bash scripts/check-pr-review.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_CI="$ROOT/scripts/init-ci.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# require_tool NAME — the pseudo-TTY runner (script) is required for the
# interactive prompt tests.
require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required tool '$1' not found — cannot run the interactive prompt tests" >&2
    exit 2
  fi
}

require_tool script

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/child"
mkdir -p "$FIX"
ln -s "$ROOT" "$FIX/.standards"

# Interactive secrets-run helper: feed the "1) Yes, add secrets placeholders"
# choice plus enough empty answers to satisfy the earlier prompts, then count
# OPENCODE_API_KEY occurrences in the transcript. Flags passed as arguments.
count_prompt() { # count_prompt <flags...>
  local flags=("$@")
  local out
  out="$(printf '1\n\n\n\n\n\n\n\n\n' | script -qec \
    "cd '$FIX' && bash .standards/scripts/init-ci.sh ${flags[*]}" /dev/null 2>&1 || true)"
  printf '%s\n' "$out" | grep -c 'OPENCODE_API_KEY' || true
}

echo "== AC-024-04-04 / AC-024-04-05 secret prompt gating (interactive) =="

# AC-024-04-04 — With --with-pr-review, OPENCODE_API_KEY is prompted.
WITH_COUNT="$(count_prompt --with-pr-review --platform github --backend go)"
if [ "$WITH_COUNT" -gt 0 ]; then
  ok "AC-024-04-04: OPENCODE_API_KEY is prompted when --with-pr-review is set ($WITH_COUNT occurrences)"
else
  bad "AC-024-04-04: OPENCODE_API_KEY must be prompted when --with-pr-review is set (got $WITH_COUNT)"
fi
rm -rf "$FIX/.github"

# AC-024-04-05 — Without --with-pr-review, OPENCODE_API_KEY is never prompted.
rm -rf "$FIX/.github"
WITHOUT_COUNT="$(count_prompt --platform github --backend go)"
if [ "$WITHOUT_COUNT" -eq 0 ]; then
  ok "AC-024-04-05: OPENCODE_API_KEY is never prompted without --with-pr-review"
else
  bad "AC-024-04-05: OPENCODE_API_KEY must never be prompted without --with-pr-review (got $WITHOUT_COUNT)"
fi

echo ""
echo "== AC-024-01-12 change-set guard — hermetic git fixtures (ADR 0009 amendment) =="

# seed_gate_repo — a scratch repo carrying exactly the 8 spec-pipeline agent
# files at a committed base, so only the change-set clause is under test.
# Verdict lines are grepped from full output (other checks may legitimately
# fail in the minimal fixture; the FAIL/PASS color prefix is escape-coded,
# so assertions match from the AC ID onward).
GATE="$TMP/gate"
seed_gate_repo() {
  local a
  mkdir -p "$GATE/agents" "$GATE/docs/adr"
  for a in spec-coder spec-mutation-runner spec-pipeline spec-pr-opener \
    spec-refactorer spec-specifier spec-ux spec-verifier; do
    printf '# agent\n' > "$GATE/agents/$a.md"
  done
  git -C "$GATE" init -q
  git -C "$GATE" config user.email "test@example.com"
  git -C "$GATE" config user.name "Test"
  git -C "$GATE" add -A
  git -C "$GATE" commit -qm "base"
}
seed_gate_repo
GATE_BASE="$(git -C "$GATE" rev-parse HEAD)"

# gate_out — run the guard against the fixture with the given base env.
# The script exits non-zero for the fixture's other legitimately-missing
# artifacts; the verdict line under test is grepped from the output, so the
# status is swallowed (|| true) under the file's set -e.
gate_out() {
  env GITHUB_BASE_SHA="${1:-}" GITHUB_BASE_REF= \
    bash "$ROOT/scripts/check-pr-review.sh" "$GATE" 2>&1 || true
}

# (a) undocumented spec-agent change must FAIL the clause
printf '# changed agent\n' > "$GATE/agents/spec-ux.md"
OUT="$(gate_out "$GATE_BASE")"
case "$OUT" in
  *"AC-024-01-12: change set modifies agents/spec-*.md without adding or modifying a docs/adr/*.md"*)
    ok "AC-024-01-12: spec-agent change without an ADR in the set fails the guard" ;;
  *)
    bad "AC-024-01-12: spec-agent change without an ADR did not fail the guard" ;;
esac

# (b) same change PLUS an untracked docs/adr/*.md must PASS (documented change)
printf '# ADR\n' > "$GATE/docs/adr/0099-selftest-documented-change.md"
OUT="$(gate_out "$GATE_BASE")"
case "$OUT" in
  *"AC-024-01-12: change set modifies agents/spec-*.md as a documented pipeline change"*)
    ok "AC-024-01-12: spec-agent change with an ADR in the same set passes the guard" ;;
  *)
    bad "AC-024-01-12: documented spec-agent change did not pass the guard" ;;
esac

# (c) no resolvable base (no GITHUB_BASE_*, no origin/main remote ref) must
# FAIL LOUDLY — the old code passed vacuously on exactly this state
OUT="$(gate_out "")"
case "$OUT" in
  *"AC-024-01-12: cannot resolve a base ref for the change set"*)
    ok "AC-024-01-12: unresolvable base fails loudly, never a vacuous PASS" ;;
  *)
    bad "AC-024-01-12: unresolvable base did not fail loudly" ;;
esac
case "$OUT" in
  *"AC-024-01-12: no agents/spec-*.md file is modified"*)
    bad "AC-024-01-12: unresolvable base still emitted the vacuous clean line" ;;
  *)
    ok "AC-024-01-12: no vacuous clean line when the base is unresolvable" ;;
esac

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-pr-review.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-pr-review.selftest: all cases pass.${NC}"
