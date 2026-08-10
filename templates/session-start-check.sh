#!/usr/bin/env bash
# session-start-check.sh — Verify project is in a healthy state before starting work
# Usage: ./session-start-check.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}OK${NC}: $1"; }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; exit 1; }
skip() { echo -e "  ${YELLOW}SKIP${NC}: $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; }

echo "=== Session Start Health Check ==="

# 1. Git working tree clean
echo "1. Git state..."
if git diff --quiet && git diff --cached --quiet; then
    pass "Working tree clean"
else
    echo "  WARNING: Uncommitted changes"
    git status --short
    echo ""
    fail "Clean working tree required before starting work. Commit or stash first."
fi

# 2. Lint
echo "2. Lint..."
if command -v rtk >/dev/null 2>&1; then
    rtk lint || fail "Lint errors"
    pass "Lint"
elif [ -f Makefile ] && grep -q "^lint:" Makefile 2>/dev/null; then
    make lint || fail "Lint errors"
    pass "Lint"
elif [ -f package.json ]; then
    if npm run lint 2>/dev/null; then
        pass "Lint"
    else
        warn "Lint failed or not configured (advisory-only for npm)"
    fi
else
    skip "No lint command found"
fi

# 3. Unit tests
echo "3. Unit tests..."
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

# 4. Integration tests (if available)
echo "4. Integration tests..."
if [ -f Makefile ] && grep -q "^integration-test:" Makefile 2>/dev/null; then
    make integration-test || fail "Integration test failures"
    pass "Integration tests"
else
    skip "No integration-test target in Makefile"
fi

echo ""
echo -e "${GREEN}=== All checks passed. Ready to work! ===${NC}"
