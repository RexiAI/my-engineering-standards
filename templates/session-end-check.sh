#!/usr/bin/env bash
# session-end-check.sh — Verify project is ready to commit before ending session
# Usage: ./session-end-check.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}OK${NC}: $1"; }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; exit 1; }
skip() { echo -e "  ${YELLOW}SKIP${NC}: $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; }

echo "=== Session End Health Check ==="

# 1. Full test suite
echo "1. Running full test suite..."
if command -v rtk >/dev/null 2>&1; then
    rtk test || fail "Unit test failures"
    pass "Unit tests"
elif [ -f Makefile ] && grep -q "^test:" Makefile 2>/dev/null; then
    make test || fail "Unit test failures"
    pass "Unit tests"
elif [ -f pom.xml ]; then
    mvn test -q || fail "Unit test failures"
    pass "Unit tests"
elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
    ./gradlew test 2>/dev/null || fail "Unit test failures"
    pass "Unit tests"
elif [ -f go.mod ]; then
    go test ./... || fail "Unit test failures"
    pass "Unit tests"
elif [ -f package.json ]; then
    npm test -- --passWithNoTests 2>/dev/null || npm test 2>/dev/null || fail "Unit test failures"
    pass "Unit tests"
else
    skip "No recognized test framework"
fi

# 2. Lint
echo "2. Lint/format..."
if command -v rtk >/dev/null 2>&1; then
    rtk lint || fail "Lint errors"
    pass "Lint"
elif [ -f Makefile ] && grep -q "^lint:" Makefile 2>/dev/null; then
    make lint || fail "Lint errors"
    pass "Lint"
elif [ -f package.json ]; then
    npm run lint 2>/dev/null || true
    pass "Lint (best effort)"
else
    skip "No lint command found"
fi

# 3. No debug code
echo "3. Checking for debug artifacts..."
# Portable POSIX ERE (no PCRE \d/lookaheads used, so semantics unchanged).
DEBUG_PATTERNS='console\.log|print\(|fmt\.Print|System\.out|System\.err|TODO|FIXME|debugger'
DEBUG_FOUND=0
for f in $(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true); do
    if [ -f "$f" ] && grep -qE "$DEBUG_PATTERNS" "$f" 2>/dev/null; then
        echo "  WARNING: Debug/todo markers in $f"
        DEBUG_FOUND=1
    fi
done
if [ "$DEBUG_FOUND" -eq 1 ]; then
    warn "Debug/todo markers found in staged files (see warnings above)"
else
    pass "No obvious debug artifacts"
fi

# 4. Talisman secret scan (if available)
echo "4. Secret scan..."
if command -v talisman >/dev/null 2>&1; then
    talisman --scan 2>/dev/null || fail "Talisman found potential secrets"
    pass "Secret scan"
else
    skip "Talisman not installed (recommended: curl https://thoughtworks.github.io/talisman/install.sh | sh)"
fi

# 5. Check working tree
echo "5. Git state..."
if git diff --quiet && git diff --cached --quiet; then
    skip "No changes to commit"
else
    pass "Changes staged or tracked"
    echo ""
    git status --short
fi

echo ""
echo -e "${GREEN}=== Session end checks passed. Ready to commit! ===${NC}"
