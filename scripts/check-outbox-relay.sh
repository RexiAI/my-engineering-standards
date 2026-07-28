#!/bin/bash
# check-outbox-relay.sh — Verify outbox relay component and consumer deduplication exist.
#
# Checks:
#   1. Relay component exists (polling @Scheduled / Debezium config / Go ticker / Node cron)
#   2. Consumer deduplication logic exists in event handler code
#
# Usage:
#   .standards/scripts/check-outbox-relay.sh [SOURCE_DIR]
#
# SOURCE_DIR defaults to current directory.
#
# Exit codes:
#   0 — all checks pass
#   1 — violations found
#
# Standards reference:
#   docs/OUTBOX_PATTERN.md §Outbox Relay
#   docs/OUTBOX_PATTERN.md §Idempotent Event Processing
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

echo "Checking outbox relay and consumer dedup in: $SOURCE_DIR"
echo ""

# ── Check 1: Relay component exists ───────────────────────────────────────────
# Java:  class/method named *OutboxRelay* or *OutboxPublisher*, @Scheduled annotation
#        co-located with outbox query (SELECT ... WHERE published_at IS NULL)
# Go:    function/ticker doing outbox polling
# Node:  class *OutboxRelay* with scheduled/cron invocation
# Debezium: debezium connector config file

RELAY_FOUND=false

# Java: @Scheduled on a method that queries outbox
JAVA_RELAY=$(grep -r '@Scheduled' \
  --include="*.java" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
  grep -i 'outbox\|relay\|publish' || true)
[ -n "$JAVA_RELAY" ] && RELAY_FOUND=true

# Java: class named *OutboxRelay* or *OutboxPublisher*
JAVA_CLASS=$(grep -r 'class.*OutboxRelay\|class.*OutboxPublisher' \
  --include="*.java" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)
[ -n "$JAVA_CLASS" ] && RELAY_FOUND=true

# Go: goroutine/ticker for outbox polling
GO_RELAY=$(grep -r 'OutboxRelay\|outbox.*ticker\|publishPending\|publishOutbox\|time\.NewTicker' \
  --include="*.go" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null | \
  grep -i 'outbox\|relay\|publish' || true)
[ -n "$GO_RELAY" ] && RELAY_FOUND=true

# Node: OutboxRelay class or cron/setInterval for outbox
NODE_RELAY=$(grep -r 'OutboxRelay\|outboxRelay\|publishPending\|publishOutbox' \
  --include="*.ts" --include="*.js" $GREP_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)
[ -n "$NODE_RELAY" ] && RELAY_FOUND=true

# Debezium or CDC connector config
CDC_CONFIG=$(find "$SOURCE_DIR" \
  -name 'debezium*.json' -o -name 'debezium*.yml' -o \
  -name '*cdc*.json' -o -name '*connector*.json' 2>/dev/null | head -1 || true)
[ -n "$CDC_CONFIG" ] && RELAY_FOUND=true

if $RELAY_FOUND; then
  pass "Outbox relay component found"
else
  fail "No outbox relay component detected. " \
       "A relay is required to publish events from the outbox table to the broker. " \
       "Implement *OutboxRelay with @Scheduled (Java), a ticker (Go), or a cron job (Node). " \
       "See docs/OUTBOX_PATTERN.md §Outbox Relay."
fi

echo ""

# ── Check 2: Consumer deduplication ───────────────────────────────────────────
# Java:  dedupStore.alreadyProcessed / dedupStore.markProcessed / Redis SETNX
# Go:    dedupStore.AlreadyProcessed / dedupStore.MarkProcessed / redis.SetNX
# Node:  dedupStore.alreadyProcessed / dedupStore.markProcessed / redis.setNX
#
# Must be found in PRODUCTION code — test files legitimately reference dedup
# calls (mocks/assertions) without that proving production code implements it.
DEDUP_TEST_EXCLUDES="$GREP_EXCLUDES \
  --exclude-dir=src/test --exclude-dir=test --exclude-dir=tests \
  --exclude-dir=__tests__ \
  --exclude=*Test.java --exclude=*_test.go --exclude=*.test.ts --exclude=*.test.js \
  --exclude=*.spec.ts --exclude=*.spec.js"

DEDUP_FOUND=false

# Java
JAVA_DEDUP=$(grep -r 'alreadyProcessed\|markProcessed\|SETNX\|setIfAbsent\|DedupStore\|DeduplicationStore' \
  --include="*.java" $DEDUP_TEST_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)
[ -n "$JAVA_DEDUP" ] && DEDUP_FOUND=true

# Go
GO_DEDUP=$(grep -r 'AlreadyProcessed\|MarkProcessed\|SetNX\|DedupStore\|DeduplicationStore' \
  --include="*.go" $DEDUP_TEST_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)
[ -n "$GO_DEDUP" ] && DEDUP_FOUND=true

# Node/TS
NODE_DEDUP=$(grep -r 'alreadyProcessed\|markProcessed\|setNX\|dedupStore\|deduplicationStore\|DedupStore' \
  --include="*.ts" --include="*.js" $DEDUP_TEST_EXCLUDES "$SOURCE_DIR" 2>/dev/null || true)
[ -n "$NODE_DEDUP" ] && DEDUP_FOUND=true

if $DEDUP_FOUND; then
  pass "Consumer deduplication logic found"
else
  fail "No consumer deduplication logic detected. " \
       "The outbox relay may re-publish events after a crash. " \
       "Consumers must check dedupStore.alreadyProcessed(eventId) before processing. " \
       "See docs/OUTBOX_PATTERN.md §Idempotent Event Processing."
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Outbox relay check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/OUTBOX_PATTERN.md §Outbox Relay, §Idempotent Event Processing"
  exit 1
else
  echo -e "${GREEN}✔ Outbox relay check: all checks passed.${NC}"
fi
