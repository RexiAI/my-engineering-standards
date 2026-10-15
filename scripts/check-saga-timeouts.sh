#!/bin/bash
# check-saga-timeouts.sh — Verify saga step timeouts are configured.
#
# Checks:
#   Java:  @Timeout annotation or resilience4j TimeLimiterConfig per @SagaHandler method
#   Go:    context.WithTimeout in *SagaHandler functions
#   Node:  timeout property in sagaStep() calls
#   Python (ADR 0006 D3): asyncio.timeout / asyncio.wait_for / httpx|requests
#          timeout= kwarg in saga handler files
#   Rust (ADR 0006 D3): tokio::time::timeout / a timeout(..) call with a
#          Duration bound in saga handler files
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
HAS_PYTHON=false
HAS_RUST=false

# Use find-native exclusions (not grep --exclude-dir flags)
FIND_PRUNE='( -name node_modules -o -name target -o -name vendor -o -name .git -o -name dist )'

[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.java' -print 2>/dev/null | head -1)" ] && HAS_JAVA=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.go' -print 2>/dev/null | head -1)" ] && HAS_GO=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o \( -name '*.ts' -o -name '*.js' \) -print 2>/dev/null | head -1)" ] && HAS_NODE=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.py' -print 2>/dev/null | head -1)" ] && HAS_PYTHON=true
[ -n "$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.rs' -print 2>/dev/null | head -1)" ] && HAS_RUST=true

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

    # Scoped check: each SagaHandler file must have timeout logic in that SAME
    # file, or in another file in the SAME DIRECTORY (cheap approximation of
    # "same package" — no import resolution). Mirrors the Java branch's
    # same-file requirement without a repo-wide escape hatch, since Go has no
    # equivalent of a global resilience4j config.
    MISSING_TIMEOUT_GO=""
    while IFS= read -r handler_file; do
      [ -z "$handler_file" ] && continue
      dir=$(dirname "$handler_file")
      DIR_TIMEOUT=$(grep -l 'context\.WithTimeout\|context\.WithDeadline' \
        "$dir"/*.go 2>/dev/null | grep -v '_test\.go' || true)
      if [ -z "$DIR_TIMEOUT" ]; then
        MISSING_TIMEOUT_GO="${MISSING_TIMEOUT_GO}  ${handler_file}\n"
      fi
    done <<< "$SAGA_HANDLER_GO"

    if [ -z "$MISSING_TIMEOUT_GO" ]; then
      pass "Go: context.WithTimeout found in same file/directory as saga handler code"
    else
      fail "Go: *SagaHandler files with no context.WithTimeout/WithDeadline in the same " \
           "file or directory:"$'\n'"${MISSING_TIMEOUT_GO}" \
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

# ── Python: saga handler files must use asyncio.timeout / asyncio.wait_for /
#    an httpx|requests timeout= kwarg ─────────────────────────────────────────
# Identifying tokens (saga_handler / saga_orchestrator / SagaOrchestrator /
# SagaState / saga_step) and the accepted timeout idioms are HOUSE CONVENTIONS
# chosen by ADR 0006 D3. docs/SAGA_PATTERN.md §Saga Timeout mandates that every
# step has a timeout but shows only a Java table; it names no Python API. The
# check mirrors the Go branch: the timeout must appear in the SAME file or the
# SAME DIRECTORY as the saga code (cheap "same module" approximation, no import
# resolution). Comment lines (# ...) are excluded so a TODO cannot satisfy it.
if $HAS_PYTHON; then
  SAGA_HANDLER_PY=$(grep -rl 'saga_handler\|saga_orchestrator\|SagaOrchestrator\|SagaState\|saga_step\|SagaStep' \
    --include="*.py" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
    grep -v 'test_\|_test\.py\|/tests\?/\|conftest\.py' || true)

  if [ -n "$SAGA_HANDLER_PY" ]; then
    echo "Python: found saga handler code in:"
    echo "$SAGA_HANDLER_PY" | sed 's/^/  /'

    MISSING_TIMEOUT_PY=""
    while IFS= read -r handler_file; do
      [ -z "$handler_file" ] && continue
      dir=$(dirname "$handler_file")
      # asyncio.timeout / asyncio.wait_for / bare wait_for( / a timeout= kwarg
      # (httpx|requests) — in the same file or a sibling .py in the same dir.
      DIR_TIMEOUT=$(grep -lE 'asyncio\.timeout|asyncio\.wait_for|\bwait_for\(|timeout[[:space:]]*=' \
        "$dir"/*.py 2>/dev/null | grep -v 'test_\|_test\.py\|conftest\.py' | \
        while read -r tf; do grep -E 'asyncio\.timeout|asyncio\.wait_for|\bwait_for\(|timeout[[:space:]]*=' "$tf" | grep -qv '^[[:space:]]*#' && echo "$tf"; done || true)
      if [ -z "$DIR_TIMEOUT" ]; then
        MISSING_TIMEOUT_PY="${MISSING_TIMEOUT_PY}  ${handler_file}\n"
      fi
    done <<< "$SAGA_HANDLER_PY"

    if [ -z "$MISSING_TIMEOUT_PY" ]; then
      pass "Python: asyncio.timeout/asyncio.wait_for/timeout= found in same file/directory as saga handler code"
    else
      fail "Python: saga handler files with no asyncio.timeout / asyncio.wait_for / " \
           "timeout= kwarg in the same file or directory:"$'\n'"${MISSING_TIMEOUT_PY}" \
           "Each saga step must have a timeout. See docs/SAGA_PATTERN.md §Saga Timeout."
    fi
  else
    warn "Python: No saga handler code found — skipping Python timeout check."
  fi
  echo ""
fi

# ── Rust: saga handler files must use tokio::time::timeout / a timeout(..) call
#    with a Duration bound ─────────────────────────────────────────────────────
# Identifying tokens (SagaHandler / saga_handler / SagaOrchestrator / SagaState /
# Compensable / saga_step) and the accepted timeout call are HOUSE CONVENTIONS
# chosen by ADR 0006 D3. docs/SAGA_PATTERN.md §Saga Timeout mandates a per-step
# timeout but names no Rust API; language-specific/rust/PATTERNS.md points at
# `tokio::time::timeout` as the ecosystem idiom. A bare `Duration` is NOT
# accepted on its own — it must accompany a timeout call, so a Duration used for
# something else cannot masquerade as a step timeout. Same file/directory scope
# as the Go and Python branches; `//` comment lines excluded.
if $HAS_RUST; then
  SAGA_HANDLER_RS=$(grep -rl 'SagaHandler\|saga_handler\|SagaOrchestrator\|SagaState\|Compensable\|saga_step' \
    --include="*.rs" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)

  if [ -n "$SAGA_HANDLER_RS" ]; then
    echo "Rust: found saga handler code in:"
    echo "$SAGA_HANDLER_RS" | sed 's/^/  /'

    MISSING_TIMEOUT_RS=""
    while IFS= read -r handler_file; do
      [ -z "$handler_file" ] && continue
      dir=$(dirname "$handler_file")
      # tokio::time::timeout / time::timeout / a timeout( or .timeout( call,
      # in the same file or a sibling .rs in the same dir, on a non-comment line.
      DIR_TIMEOUT=$(grep -lE 'tokio::time::timeout|time::timeout|\.timeout\(|\btimeout\(|with_timeout|timeout_duration' \
        "$dir"/*.rs 2>/dev/null | \
        while read -r tf; do grep -E 'tokio::time::timeout|time::timeout|\.timeout\(|\btimeout\(|with_timeout|timeout_duration' "$tf" | grep -qv '^[[:space:]]*//' && echo "$tf"; done || true)
      if [ -z "$DIR_TIMEOUT" ]; then
        MISSING_TIMEOUT_RS="${MISSING_TIMEOUT_RS}  ${handler_file}\n"
      fi
    done <<< "$SAGA_HANDLER_RS"

    if [ -z "$MISSING_TIMEOUT_RS" ]; then
      pass "Rust: tokio::time::timeout (or a timeout(..) call) found in same file/directory as saga handler code"
    else
      fail "Rust: saga handler files with no tokio::time::timeout / timeout(..) call " \
           "in the same file or directory:"$'\n'"${MISSING_TIMEOUT_RS}" \
           "Saga steps must enforce a timeout (e.g. tokio::time::timeout with a Duration bound). " \
           "See docs/SAGA_PATTERN.md §Saga Timeout."
    fi
  else
    warn "Rust: No saga handler code found — skipping Rust timeout check."
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
