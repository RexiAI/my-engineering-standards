#!/bin/bash
# check-saga-timeouts.sh — Verify saga step timeouts are configured.
#
# Checks:
#   Java:  @Timeout annotation or resilience4j TimeLimiterConfig per @SagaHandler method
#   Go:    context.WithTimeout in *SagaHandler functions
#   Node:  timeout property in sagaStep() calls
#
# Usage:
#   .standards/scripts/check-saga-timeouts.sh [SOURCE_DIR]
#
# SOURCE_DIR defaults to current directory.
#
# Exit codes:
#   0 — all checks pass or no saga code detected
#   1 — saga code present but timeout enforcement missing
#
# Standards reference: docs/SAGA_PATTERN.md §Saga Timeout
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VIOLATIONS=0
SOURCE_DIR="${1:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; }

GREP_EXCLUDES='--exclude-dir=node_modules --exclude-dir=target --exclude-dir=vendor --exclude-dir=.git --exclude-dir=dist'

echo "Checking saga timeout enforcement in: $SOURCE_DIR"
echo ""

# ── Detect which languages are present ────────────────────────────────────────
HAS_JAVA=false
HAS_GO=false
HAS_NODE=false

# Use find-native exclusions (not grep --exclude-dir flags)
FIND_PRUNE='( -name node_modules -o -name target -o -name vendor -o -name .git -o -name dist )'

[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.java' -print 2>/dev/null | head -1)" ] && HAS_JAVA=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.go' -print 2>/dev/null | head -1)" ] && HAS_GO=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o \( -name '*.ts' -o -name '*.js' \) -print 2>/dev/null | head -1)" ] && HAS_NODE=true

# ── Java: @SagaHandler methods must have @Timeout or resilience4j TimeLimiter ─
if $HAS_JAVA; then
  SAGA_HANDLER_FILES=$(grep -rl '@SagaHandler' \
    --include="*.java" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)

  if [ -n "$SAGA_HANDLER_FILES" ]; then
    echo "Java: found @SagaHandler in:"
    echo "$SAGA_HANDLER_FILES" | sed 's/^/  /'

    # Check per-handler-file: each file containing @SagaHandler must also reference
    # a timeout mechanism in that same file, OR a global resilience4j config exists.

    # Global resilience4j yaml/properties timeout config covers all handlers
    RESILIENCE_CONFIG=$(grep -rl 'timelimiter\|time-limiter\|timeout-duration' \
      --include="*.yml" --include="*.yaml" --include="*.properties" \
      $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
      grep -i 'resilience\|application\|config' || true)

    MISSING_TIMEOUT_FILES=""
    while IFS= read -r handler_file; do
      [ -z "$handler_file" ] && continue
      # File-level @Timeout annotation or TimeLimiter reference — exclude comment lines
      # grep (no -r) output is raw line content, so ^\s*[/*] correctly strips comments
      if ! grep '@Timeout\|TimeLimiterConfig\|TimeLimiter\b\|timeoutDuration' "$handler_file" 2>/dev/null \
           | grep -qv '^\s*[/*]\|^\s*//'; then
        # Not in file — only OK if global resilience config exists
        if [ -z "$RESILIENCE_CONFIG" ]; then
          MISSING_TIMEOUT_FILES="${MISSING_TIMEOUT_FILES}  ${handler_file}\n"
        fi
      fi
    done <<< "$SAGA_HANDLER_FILES"

    if [ -z "$MISSING_TIMEOUT_FILES" ]; then
      pass "Java: Timeout configured for all saga handler files (@Timeout or resilience4j TimeLimiter)"
    else
      fail "Java: @SagaHandler files missing @Timeout or resilience4j TimeLimiterConfig:"$'\n'"${MISSING_TIMEOUT_FILES}" \
           "Each saga step must have a timeout. See docs/SAGA_PATTERN.md §Saga Timeout."
    fi
  else
    warn "Java: No @SagaHandler found — skipping Java timeout check."
  fi
  echo ""
fi

# ── Go: *SagaHandler functions must use context.WithTimeout ───────────────────
if $HAS_GO; then
  SAGA_HANDLER_GO=$(grep -rl 'SagaHandler' \
    --include="*.go" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)

  if [ -n "$SAGA_HANDLER_GO" ]; then
    echo "Go: found SagaHandler in:"
    echo "$SAGA_HANDLER_GO" | sed 's/^/  /'

    # Exclude comment lines — grep -r output is "file:content"; filter where content is a comment
    CONTEXT_TIMEOUT=$(grep -r 'context\.WithTimeout\|context\.WithDeadline' \
      --include="*.go" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
      grep -v '_test\.go' | grep -v ':[[:space:]]*//' || true)

    if [ -n "$CONTEXT_TIMEOUT" ]; then
      pass "Go: context.WithTimeout found in saga handler code"
    else
      fail "Go: *SagaHandler functions found but no context.WithTimeout detected. " \
           "Saga handlers must use context.WithTimeout to enforce step timeouts. " \
           "See docs/SAGA_PATTERN.md §Saga Timeout."
    fi
  else
    warn "Go: No *SagaHandler found — skipping Go timeout check."
  fi
  echo ""
fi

# ── Node: sagaStep() calls must include timeout property ──────────────────────
if $HAS_NODE; then
  SAGA_STEP_FILES=$(grep -rl 'sagaStep' \
    --include="*.ts" --include="*.js" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
    grep -v 'test\|spec\|\.test\.\|\.spec\.' || true)

  if [ -n "$SAGA_STEP_FILES" ]; then
    echo "Node: found sagaStep() in:"
    echo "$SAGA_STEP_FILES" | sed 's/^/  /'

    # Check ESLint rule is active (eslint.config includes saga plugin)
    ESLINT_SAGA=$(grep -r 'saga.*step-timeout-required\|saga/step-timeout-required' \
      --include="*.js" --include="*.ts" --include="*.json" --include="*.cjs" \
      $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)

    # Check timeout property key (timeout:) in sagaStep calls — exclude comment lines
    # Require "timeout:" or "timeout :" (property key syntax), not just the word in a comment
    TIMEOUT_IN_STEPS=$(grep -r 'sagaStep' \
      --include="*.ts" --include="*.js" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
      grep -v ':[[:space:]]*//' | grep -v '/\*.*timeout.*\*/' | \
      grep 'timeout[[:space:]]*:' || true)

    if [ -n "$ESLINT_SAGA" ] || [ -n "$TIMEOUT_IN_STEPS" ]; then
      pass "Node: sagaStep() calls include timeout (or ESLint rule enforces it)"
    else
      fail "Node: sagaStep() calls found but no timeout property detected and " \
           "ESLint rule 'saga/step-timeout-required' not active. " \
           "See docs/SAGA_PATTERN.md §Saga Timeout and " \
           "ci/templates/eslint-saga-rules/saga-compensation.js."
    fi
  else
    warn "Node: No sagaStep() calls found — skipping Node timeout check."
  fi
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Saga timeout check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/SAGA_PATTERN.md §Saga Timeout"
  exit 1
else
  echo -e "${GREEN}✔ Saga timeout check: all checks passed.${NC}"
fi
