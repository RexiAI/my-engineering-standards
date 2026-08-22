#!/usr/bin/env bash
# ci-smoke-test.sh — Run what CI would run, locally, with actionable error messages
# Usage: scripts/ci-smoke-test.sh [--phase 1|2|3] [--json]
# Exit: 0=pass, 1=fail
#
# Phase 1 (<5s): Structural — YAML syntax, workflow refs, peer deps, subproject deps
# Phase 2 (<30s): Build — typecheck, lint, format, unit tests
# Phase 3 (<60s): Integration — export bundle, integration tests, E2E smoke

set -euo pipefail

PHASE="all"
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --json)  JSON=true; shift ;;
    *)       echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ERRORS=()
WARNINGS=()

# --- Helpers ---
fail() { ERRORS+=("FAIL: $1"); echo "FAIL: $1" >&2; }
pass() { echo "PASS: $1"; }
skip() { echo "SKIP: $1"; }
warn() { WARNINGS+=("WARN: $1"); echo "WARN: $1" >&2; }

run_check() {
  local label="$1"; shift
  echo -n "  $label ... "
  if OUTPUT=$("$@" 2>&1); then
    echo "ok"
    return 0
  else
    echo "FAILED"
    fail "$label"
    echo "$OUTPUT" | head -20 | sed 's/^/    /' >&2
    return 1
  fi
}

# ========================================================================
# Phase 1: Structural checks (<5s)
# ========================================================================
run_phase1() {
  echo "=== Phase 1: Structural checks ==="

  # --- CI workflow YAML validity ---
  for wf in .github/workflows/*.yml; do
    [[ -f "$wf" ]] || continue
    if command -v python3 &>/dev/null; then
      if ! python3 -c "import yaml; yaml.safe_load(open('$wf'))" 2>/dev/null; then
        fail "Invalid YAML: $wf"
      else
        pass "YAML valid: $(basename "$wf")"
      fi
    fi
  done

  # --- Reusable workflow refs are top-level (not subdirectory) ---
  for wf in .github/workflows/*.yml; do
    [[ -f "$wf" ]] || continue
    if grep -qE 'uses:.*\.github/workflows/.+/.+\.yml' "$wf" 2>/dev/null; then
      fail "Subdirectory reusable workflow ref in $(basename "$wf") (GitHub rejects these)"
    fi
  done

  # --- No secrets in if: conditions ---
  for wf in .github/workflows/*.yml; do
    [[ -f "$wf" ]] || continue
    if grep -E '^\s+if:.*secrets\.' "$wf" 2>/dev/null | grep -v '#' >/dev/null; then
      fail "Secrets reference in if: condition in $(basename "$wf") (illegal per GitHub)"
    fi
  done

  # Note: node_modules and peer dep checks are in Phase 2 (need installed deps)
}

# ========================================================================
# Phase 2: Build checks (<30s)
# ========================================================================
run_phase2() {
  echo "=== Phase 2: Build checks ==="

  # --- Subproject node_modules existence ---
  for sub in app api; do
    if [[ -f "$sub/package.json" ]] && [[ ! -d "$sub/node_modules" ]]; then
      fail "$sub/node_modules missing — run: cd $sub && npm ci --legacy-peer-deps"
    fi
  done

  # --- Peer dependency conflicts ---
  if [[ -f "app/package.json" ]] && [[ -d "app/node_modules" ]]; then
    PEER_OUT=$(cd app && npm ls --all 2>&1 || true)
    if echo "$PEER_OUT" | grep -qi "ERESOLVE"; then
      fail "Peer dependency conflict in app/ — run: cd app && npm install --legacy-peer-deps"
    fi
  fi

  # --- TypeScript typecheck ---
  if [[ -f "tsconfig.json" ]] || [[ -f "app/tsconfig.json" ]]; then
    run_check "TypeScript typecheck" npx tsc --noEmit || true
  fi

  # --- ESLint ---
  if [[ -f "eslint.config.js" ]] || [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]]; then
    run_check "ESLint" npm run lint || true
  fi

  # --- Prettier format check ---
  if [[ -f "prettier.config.js" ]] || [[ -f ".prettierrc" ]]; then
    run_check "Prettier format" npx prettier --check . || true
  fi

  # --- Unit tests ---
  if [[ -f "jest.config.js" ]] || [[ -f "jest.config.ts" ]] || [[ -f "vitest.config.ts" ]]; then
    run_check "Unit tests" npm test || true
  fi
}

# ========================================================================
# Phase 3: Integration checks (<60s, optional)
# ========================================================================
run_phase3() {
  echo "=== Phase 3: Integration checks ==="

  # --- Export Bundle (React Native only) ---
  if [[ -f "app/package.json" ]] && grep -q '"expo"' app/package.json 2>/dev/null; then
    run_check "Export bundle config" scripts/validate-export-bundle.sh || true
  fi

  # --- Integration tests (if configured) ---
  if [[ -f "jest.integration.config.js" ]] || [[ -f "jest.integration.config.ts" ]]; then
    run_check "Integration tests" npx jest --config jest.integration.config.js || true
  fi
}

# ========================================================================
# Main
# ========================================================================
case "$PHASE" in
  1) run_phase1 ;;
  2) run_phase2 ;;
  3) run_phase3 ;;
  all)
    run_phase1
    run_phase2
    run_phase3
    ;;
  *) echo "Invalid phase: $PHASE (use 1, 2, 3, or all)" >&2; exit 1 ;;
esac

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "Errors: ${#ERRORS[@]}, Warnings: ${#WARNINGS[@]}"

if [[ "$JSON" == true ]]; then
  echo '{"phase":"'"$PHASE"'","errors":'"${#ERRORS[@]}"',"warnings":'"${#WARNINGS[@]}"'}'
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: PASS"
exit 0
