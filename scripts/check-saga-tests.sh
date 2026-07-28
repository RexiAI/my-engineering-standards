#!/bin/bash
# check-saga-tests.sh — Verify integration tests exist for saga and outbox code.
#
# Checks:
#   1. Saga code present → *SagaTest*, *saga*_test*, or saga.integration.test.* exists
#      AND test file contains compensation/failure scenario
#   2. Outbox code present → *OutboxTest*, *outbox*_test*, or outbox.integration.test.* exists
#      AND test file contains relay/publish scenario
#   3. Saga handler code present → idempotency test exists (duplicate event test)
#
# Usage:
#   SAGA_DETECTED=true OUTBOX_DETECTED=true \
#     .standards/scripts/check-saga-tests.sh [SOURCE_DIR]
#
# SAGA_DETECTED / OUTBOX_DETECTED can be set by sourcing detect-saga-outbox.sh first.
# If unset, script auto-detects.
#
# Exit codes:
#   0 — all required tests found
#   1 — missing tests
#
# Standards reference:
#   docs/SAGA_PATTERN.md §Testing Sagas
#   docs/OUTBOX_PATTERN.md §Required Tests
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

# ── Auto-detect if env vars not set ───────────────────────────────────────────
SAGA_DETECTED="${SAGA_DETECTED:-}"
OUTBOX_DETECTED="${OUTBOX_DETECTED:-}"

if [ -z "$SAGA_DETECTED" ] || [ -z "$OUTBOX_DETECTED" ]; then
  source "$(dirname "$0")/detect-saga-outbox.sh" >/dev/null 2>&1 || true
fi

echo "Checking saga/outbox integration tests in: $SOURCE_DIR"
echo "SAGA_DETECTED=$SAGA_DETECTED  OUTBOX_DETECTED=$OUTBOX_DETECTED"
echo ""

# ── Check 1: Saga integration tests ───────────────────────────────────────────
if [ "${SAGA_DETECTED:-false}" = "true" ]; then

  # Find saga test files
  SAGA_TEST_FILES=$(find "$SOURCE_DIR" \
    \( -name '*SagaTest*' -o -name '*saga*test*' -o -name '*saga*_test*' -o \
       -name 'saga.integration.test.*' -o -name '*saga*.integration.*' \) \
    -not -path '*/node_modules/*' -not -path '*/target/*' \
    -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null || true)

  if [ -z "$SAGA_TEST_FILES" ]; then
    fail "Saga code detected but no saga integration test file found. " \
         "Required: *SagaTest*, *saga*_test.go, or saga.integration.test.ts. " \
         "See docs/SAGA_PATTERN.md §Required Tests and " \
         "ci/templates/tests/SagaIntegrationTestTemplate.java (or .go / .ts)."
  else
    echo "Found saga test file(s):"
    echo "$SAGA_TEST_FILES" | sed 's/^/  /'

    # Check for compensation/failure scenario — must contain a compensation-specific
    # term. Bare generic terms like "on.*Failed" or "step.*fail"/"fail.*step" were
    # dropped: they match almost any test file that mentions failure at all
    # (e.g. a TODO comment about a failing step), without proving compensation
    # is actually being tested.
    COMPENSATION_TEST=$(grep -l \
      'compensat\|Compensat\|onPaymentFailed\|onInventoryFailed\|rollback\|Rollback' \
      $SAGA_TEST_FILES 2>/dev/null || true)

    if [ -n "$COMPENSATION_TEST" ]; then
      pass "Saga: compensation/failure test scenario found"
    else
      fail "Saga test file(s) found but no compensation or failure scenario detected. " \
           "Integration tests must verify compensation triggers on step failure. " \
           "See docs/SAGA_PATTERN.md §Testing Sagas (row: Integration — " \
           "'Compensation is triggered on step failure')."
    fi

    # Check for idempotency / duplicate event test
    IDEMPOTENCY_TEST=$(grep -l \
      'idempoten\|Idempoten\|duplicate\|Duplicate\|already.*processed\|AlreadyProcessed' \
      $SAGA_TEST_FILES 2>/dev/null || true)

    if [ -n "$IDEMPOTENCY_TEST" ]; then
      pass "Saga: idempotency test scenario found"
    else
      warn "No idempotency test detected in saga test files. " \
           "Recommended: test that duplicate event delivery leaves saga state unchanged. " \
           "See docs/IDEMPOTENCY.md and docs/SAGA_PATTERN.md §Testing Sagas."
      # Warn only — idempotency in saga tests is strongly recommended, not hard-blocked
    fi

    echo ""

    # Check for saga state persistence test (recovery test)
    RECOVERY_TEST=$(grep -l \
      'restart\|Restart\|recovery\|Recovery\|state.*store\|StateStore\|survives\|persist' \
      $SAGA_TEST_FILES 2>/dev/null || true)

    if [ -n "$RECOVERY_TEST" ]; then
      pass "Saga: state persistence/recovery test scenario found"
    else
      warn "No state persistence/recovery test detected. " \
           "Recommended: test that saga resumes from state store after app restart. " \
           "See docs/SAGA_PATTERN.md §Saga State Store."
    fi
  fi

  echo ""
fi

# ── Check 2: Outbox integration tests ─────────────────────────────────────────
if [ "${OUTBOX_DETECTED:-false}" = "true" ]; then

  OUTBOX_TEST_FILES=$(find "$SOURCE_DIR" \
    \( -name '*OutboxTest*' -o -name '*outbox*test*' -o -name '*outbox*_test*' -o \
       -name 'outbox.integration.test.*' -o -name '*outbox*.integration.*' \) \
    -not -path '*/node_modules/*' -not -path '*/target/*' \
    -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null || true)

  if [ -z "$OUTBOX_TEST_FILES" ]; then
    fail "Outbox code detected but no outbox integration test file found. " \
         "Required: *OutboxTest*, *outbox*_test.go, or outbox.integration.test.ts. " \
         "See docs/OUTBOX_PATTERN.md §Required Tests and " \
         "ci/templates/tests/OutboxIntegrationTestTemplate.java (or .go / .ts)."
  else
    echo "Found outbox test file(s):"
    echo "$OUTBOX_TEST_FILES" | sed 's/^/  /'

    # Check for relay/publish test
    RELAY_TEST=$(grep -l \
      'relay\|Relay\|publish\|Publish\|publishPending\|publishOutbox' \
      $OUTBOX_TEST_FILES 2>/dev/null || true)

    if [ -n "$RELAY_TEST" ]; then
      pass "Outbox: relay/publish test scenario found"
    else
      fail "Outbox test file(s) found but no relay or publish scenario detected. " \
           "Tests must verify the relay publishes unpublished outbox events. " \
           "See docs/OUTBOX_PATTERN.md §Required Tests."
    fi

    # Check for atomicity test (business write + outbox in same transaction)
    ATOMIC_TEST=$(grep -l \
      'atomic\|Atomic\|transaction\|Transaction\|rollback\|Rollback\|same.*tx\|sameTx' \
      $OUTBOX_TEST_FILES 2>/dev/null || true)

    if [ -n "$ATOMIC_TEST" ]; then
      pass "Outbox: atomicity test scenario found"
    else
      warn "No atomicity test detected. " \
           "Recommended: test that business write + outbox insert are atomic. " \
           "See docs/OUTBOX_PATTERN.md §Solution."
    fi
  fi

  echo ""
fi

if [ "${SAGA_DETECTED:-false}" = "false" ] && [ "${OUTBOX_DETECTED:-false}" = "false" ]; then
  warn "Neither SAGA_DETECTED nor OUTBOX_DETECTED — nothing to check."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Saga/outbox test check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Use templates in ci/templates/tests/ as a starting point."
  exit 1
else
  echo -e "${GREEN}✔ Saga/outbox test check: all required tests found.${NC}"
fi
