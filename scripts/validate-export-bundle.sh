#!/usr/bin/env bash
# validate-export-bundle.sh — Validate that Expo web export would succeed in CI
# Part of Phase 3 (integration checks). Catches missing deps, wrong config,
# and Metro resolution issues before push.
#
# Usage: scripts/validate-export-bundle.sh [--json]
# Exit: 0=pass, 1=fail, 2=skipped (not a React Native project)

set -euo pipefail

JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

# --- Detect project type ---
APP_DIR="app"
if [[ ! -d "$APP_DIR" ]]; then
  echo "SKIP: No app/ directory found"
  exit 2
fi

if ! grep -q '"expo"' "$APP_DIR/package.json" 2>/dev/null; then
  echo "SKIP: app/ is not an Expo project"
  exit 2
fi

ERRORS=()
WARNINGS=()

# --- Check 1: Metro bundler config in app.json ---
if ! grep -q '"bundler"' "$APP_DIR/app.json" 2>/dev/null; then
  ERRORS+=("FAIL: app/app.json missing \"bundler\": \"metro\" in expo.android/ios config
  Fix: Add \"bundler\": \"metro\" to expo.android and expo ios in app/app.json
  Why: Metro bundler config is required for web export in CI")
fi

# --- Check 2: Export script exists in root package.json ---
if ! grep -q '"export"' package.json 2>/dev/null; then
  ERRORS+=("FAIL: Root package.json missing \"export\" script
  Fix: Add \"export\": \"cd app && npx expo export --platform web\" to scripts in package.json
  Why: CI ci-react-native.yml runs 'npm run export' at the repo root")
fi

# --- Check 3: Export script exists in app/package.json ---
if ! grep -q '"export"' "$APP_DIR/package.json" 2>/dev/null; then
  ERRORS+=("FAIL: app/package.json missing \"export\" script
  Fix: Add \"export\": \"npx expo export --platform web\" to scripts in app/package.json
  Why: App-level export script is used by root-level wrapper")
fi

# --- Check 4: app/node_modules exists (deps installed) ---
if [[ ! -d "$APP_DIR/node_modules" ]]; then
  ERRORS+=("FAIL: app/node_modules does not exist
  Fix: cd app && npm ci --legacy-peer-deps
  Why: Metro bundler needs all deps installed to resolve imports")
fi

# --- Check 5: react-native-safe-area-context installed ---
if [[ -d "$APP_DIR/node_modules" ]]; then
  if [[ ! -d "$APP_DIR/node_modules/react-native-safe-area-context" ]]; then
    ERRORS+=("FAIL: react-native-safe-area-context not installed in app/
    Fix: cd app && npm install react-native-safe-area-context --legacy-peer-deps
    Why: Required peer dep of expo-router, needed for Metro resolution during web export")
  fi
fi

# --- Check 6: react-native-web installed ---
if [[ -d "$APP_DIR/node_modules" ]]; then
  if [[ ! -d "$APP_DIR/node_modules/react-native-web" ]]; then
    ERRORS+=("FAIL: react-native-web not installed in app/
    Fix: cd app && npm install react-native-web --legacy-peer-deps
    Why: Required for Expo web export platform support")
  fi
fi

# --- Check 7: peer dep conflicts (ERESOLVE check) ---
if [[ -d "$APP_DIR/node_modules" ]]; then
  PEER_OUT=$(cd "$APP_DIR" && npm ls --all 2>&1 || true)
  if echo "$PEER_OUT" | grep -qi "ERESOLVE"; then
    ERRORS+=("FAIL: Peer dependency conflict detected in app/
  Fix: cd app && npm install --legacy-peer-deps
  Why: CI npm ci will fail with ERESOLVE error")
  fi
fi

# --- Output ---
if [[ "$JSON" == true ]]; then
  echo '{"script":"validate-export-bundle",'
  echo " \"errors\":${#ERRORS[@]},"
  echo " \"warnings\":${#WARNINGS[@]},"
  echo ' \"details\":['
  FIRST=true
  for msg in "${ERRORS[@]+"${ERRORS[@]}"}" "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
    [[ "$FIRST" == true ]] || echo ","
    echo -n "  \"$(echo "$msg" | sed 's/"/\\"/g' | tr '\n' ' ')\""
    FIRST=false
  done
  echo ']}'
else
  for msg in "${ERRORS[@]+"${ERRORS[@]}"}"; do
    echo "$msg" >&2
  done
  for msg in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
    echo "$msg" >&2
  done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  exit 1
fi

echo "PASS: Export bundle configuration looks correct"
exit 0
