#!/bin/bash
# lint-outbox-schema.sh — Validate outbox table SQL migration files.
#
# Scans SQL migration files for outbox table definition and verifies:
#   1. Required columns exist: event_id, event_type, payload, aggregate_type,
#                              aggregate_id, created_at, published_at
#   2. Partial index on published_at IS NULL exists
#   3. A cleanup mechanism is defined (DELETE with TTL or scheduled job reference)
#
# Usage:
#   .standards/scripts/lint-outbox-schema.sh [MIGRATIONS_DIR]
#
# MIGRATIONS_DIR defaults to searching common migration paths:
#   src/main/resources/db/migration/   (Flyway/Java)
#   db/migrations/                     (Go)
#   migrations/                        (Node)
#   database/migrations/               (Node)
#
# Exit codes:
#   0 — all checks pass
#   1 — violations found
#
# Standards reference: docs/OUTBOX_PATTERN.md §Database Schema
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VIOLATIONS=0

fail() { echo -e "${RED}FAIL${NC} $1"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $1"; }
warn() { echo -e "${YELLOW}WARN${NC} $1"; }

# ── Locate migration files ─────────────────────────────────────────────────────
SEARCH_DIRS=(
  "${1:-}"
  "src/main/resources/db/migration"
  "db/migrations"
  "migrations"
  "database/migrations"
  "prisma/migrations"
)

MIGRATION_DIR=""
for dir in "${SEARCH_DIRS[@]}"; do
  [ -z "$dir" ] && continue
  if [ -d "$dir" ]; then
    MIGRATION_DIR="$dir"
    break
  fi
done

if [ -z "$MIGRATION_DIR" ]; then
  # If OUTBOX_DETECTED is set (called from CI gate), a missing migration dir is a real problem.
  if [ "${OUTBOX_DETECTED:-false}" = "true" ]; then
    fail "Outbox pattern detected but no migration directory found. " \
         "Create outbox table migration in one of: " \
         "src/main/resources/db/migration, db/migrations, migrations, database/migrations, prisma/migrations"
    echo -e "${RED}✘ Outbox schema lint: $VIOLATIONS violation(s). Fix before merging.${NC}"
    exit 1
  fi
  warn "No migration directory found. Skipping outbox schema lint."
  warn "Expected one of: src/main/resources/db/migration, db/migrations, migrations, database/migrations"
  exit 0
fi

echo "Scanning migrations in: $MIGRATION_DIR"

# Find SQL files containing outbox table definitions
OUTBOX_FILES=$(grep -rl --include="*.sql" 'CREATE TABLE.*outbox\|create table.*outbox' "$MIGRATION_DIR" 2>/dev/null || true)

if [ -z "$OUTBOX_FILES" ]; then
  warn "No outbox table definition found in $MIGRATION_DIR. Skipping schema lint."
  warn "If outbox pattern is used, ensure a migration creates the 'outbox' table."
  exit 0
fi

echo "Found outbox migration(s): $OUTBOX_FILES"
echo ""

# ── Check 1: Required columns ──────────────────────────────────────────────────
REQUIRED_COLUMNS=(
  "event_id"
  "event_type"
  "payload"
  "aggregate_type"
  "aggregate_id"
  "created_at"
  "published_at"
)

for col in "${REQUIRED_COLUMNS[@]}"; do
  found=false
  for f in $OUTBOX_FILES; do
    # Exclude SQL comment lines (-- ...) to avoid matching column names mentioned in comments
    if grep -i "$col" "$f" | grep -qv '^\s*--'; then
      found=true
      break
    fi
  done
  if $found; then
    pass "Column '$col' present in outbox schema"
  else
    fail "Column '$col' missing from outbox table. Required by docs/OUTBOX_PATTERN.md §Database Schema."
  fi
done

echo ""

# ── Check 2: Partial index on published_at IS NULL ────────────────────────────
# Pattern: CREATE INDEX ... WHERE published_at IS NULL
INDEX_FOUND=false
for f in $OUTBOX_FILES; do
  # Exclude SQL comment lines when checking for partial index
  if grep -i 'WHERE.*published_at.*IS NULL\|where.*published_at.*is null' "$f" \
     | grep -qv '^\s*--'; then
    INDEX_FOUND=true
    break
  fi
done
# Also check separate index migration files — exclude comment lines
INDEX_IN_SEPARATE=$(grep -rl --include="*.sql" 'published_at.*IS NULL\|published_at.*is null' "$MIGRATION_DIR" 2>/dev/null \
  | while read -r f; do grep -i 'published_at.*IS NULL' "$f" | grep -v '^\s*--' | grep -q . && echo "$f"; done || true)
[ -n "$INDEX_IN_SEPARATE" ] && INDEX_FOUND=true

if $INDEX_FOUND; then
  pass "Partial index on 'published_at IS NULL' found"
else
  fail "No partial index on 'published_at IS NULL' found. " \
       "Required for relay performance. See docs/OUTBOX_PATTERN.md §Database Schema."
fi

echo ""

# ── Check 3: Cleanup / TTL mechanism ──────────────────────────────────────────
# Look for: DELETE from outbox with date/interval condition, or a scheduled cleanup reference
CLEANUP_FOUND=false

# Direct DELETE in migration or app code
for f in $(find "$MIGRATION_DIR" -name "*.sql" 2>/dev/null); do
  if grep -qi 'DELETE.*outbox.*published_at\|delete.*from.*outbox.*where.*published' "$f"; then
    CLEANUP_FOUND=true
    break
  fi
done

# Scheduled cleanup in source code (Java @Scheduled, Go ticker, Node setInterval/cron)
SOURCE_CLEANUP=$(grep -r \
  'DELETE.*outbox.*published_at\|outbox.*delete.*published\|published.*interval\|published_at.*INTERVAL' \
  --include="*.java" --include="*.go" --include="*.ts" --include="*.js" \
  . 2>/dev/null | grep -v 'node_modules\|target\|vendor\|\.git' || true)

[ -n "$SOURCE_CLEANUP" ] && CLEANUP_FOUND=true

if $CLEANUP_FOUND; then
  pass "Outbox cleanup mechanism (DELETE + TTL) found"
else
  fail "No outbox cleanup mechanism found. " \
       "Published rows must be deleted after TTL to prevent table bloat. " \
       "See docs/OUTBOX_PATTERN.md §Cleanup: " \
       "'DELETE FROM outbox WHERE published_at < NOW() - INTERVAL ''7 days'';'"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Outbox schema lint: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/OUTBOX_PATTERN.md §Database Schema"
  exit 1
else
  echo -e "${GREEN}✔ Outbox schema lint: all checks passed.${NC}"
fi
