#!/bin/bash
# lint-outbox-schema.sh — Validate outbox table migration files.
#
# Scans migration files for an outbox table definition and verifies:
#   1. Required columns exist: event_id, event_type, payload, aggregate_type,
#                              aggregate_id, created_at, published_at
#   2. Partial index on published_at IS NULL exists
#   3. A cleanup mechanism is defined (DELETE with TTL or scheduled job reference)
#
# Languages (ADR 0006 D3):
#   SQL / Rust sqlx / diesel  → *.sql migrations (CREATE TABLE ... outbox)
#   Java Flyway               → *.sql migrations
#   Python Alembic / SQLModel → *.py migrations (op.create_table('outbox', ...)
#                               or a `class Outbox` / __tablename__ = "outbox")
#   The required-column set and the partial-index requirement are IDENTICAL for
#   every language — extending coverage does not weaken them.
#
# Usage:
#   .standards/scripts/lint-outbox-schema.sh [MIGRATIONS_DIR]
#
# MIGRATIONS_DIR defaults to searching common migration paths:
#   src/main/resources/db/migration/   (Flyway/Java)
#   db/migrations/                     (Go)
#   migrations/                        (Node / Rust sqlx / diesel)
#   database/migrations/               (Node)
#   alembic/versions/ , versions/      (Python Alembic / SQLModel)
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

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; }

# ── Locate migration files ─────────────────────────────────────────────────────
SEARCH_DIRS=(
  "${1:-}"
  "src/main/resources/db/migration"
  "db/migrations"
  "migrations"
  "database/migrations"
  "prisma/migrations"
  "alembic/versions"
  "alembic"
  "versions"
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

# Find migration files containing an outbox table definition.
# SQL (*.sql): CREATE TABLE ... outbox — covers Java Flyway, Go, Node, and Rust
#   sqlx/diesel (both write plain .sql migrations).
OUTBOX_FILES_SQL=$(grep -rl --include="*.sql" 'CREATE TABLE.*outbox\|create table.*outbox' "$MIGRATION_DIR" 2>/dev/null || true)
# Python (*.py): Alembic op.create_table('outbox', ...) or a SQLModel/SQLAlchemy
#   declarative `class Outbox` / __tablename__ = "outbox". HOUSE CONVENTION per
#   ADR 0006 D3 — docs/OUTBOX_PATTERN.md §Database Schema shows the required
#   table but no Python ORM spelling.
OUTBOX_FILES_PY=$(grep -rlEi --include="*.py" 'create_table\(.*outbox|__tablename__.*outbox|class[[:space:]]+[A-Za-z_]*outbox' "$MIGRATION_DIR" 2>/dev/null || true)
OUTBOX_FILES=$(printf '%s\n%s\n' "$OUTBOX_FILES_SQL" "$OUTBOX_FILES_PY" | sed '/^[[:space:]]*$/d' | sort -u)

if [ -z "$OUTBOX_FILES" ]; then
  warn "No outbox table definition found in $MIGRATION_DIR. Skipping schema lint."
  warn "If outbox pattern is used, ensure a migration creates the 'outbox' table."
  exit 0
fi

echo "Found outbox migration(s): $OUTBOX_FILES"
echo ""

# ── Check 1: Required columns ──────────────────────────────────────────────────
# Isolate just the outbox CREATE TABLE statement block (from the matching
# "CREATE TABLE ... outbox ..." line to its closing "');'" line) so column
# names are only matched within that table's own definition, not anywhere
# else in the migration file (e.g. an unrelated table's columns).
REQUIRED_COLUMNS=(
  "event_id"
  "event_type"
  "payload"
  "aggregate_type"
  "aggregate_id"
  "created_at"
  "published_at"
)

extract_outbox_block() {
  awk 'BEGIN{IGNORECASE=1; inblock=0}
       !inblock && /create[ \t]+table/ && /outbox/ {inblock=1}
       inblock {print; if ($0 ~ /\);[ \t]*$/) {inblock=0}}' "$1"
}

# Python (Alembic/SQLModel) outbox block — HOUSE CONVENTION per ADR 0006 D3.
# Handles both migration spellings:
#   op.create_table('outbox', ...) closed by a lone ')' line, and
#   a declarative `class Outbox(...)` / __tablename__ = "outbox" body, which ends
#   at the next top-level (column-0) statement.
extract_outbox_block_py() {
  awk 'BEGIN{IGNORECASE=1; inblock=0; mode=""; started=0}
       !inblock && /create_table/ && /outbox/ {inblock=1; mode="call"}
       !inblock && ((/class[ \t]/ && /outbox/) || (/__tablename__/ && /outbox/)) {inblock=1; mode="class"}
       inblock {
         if (mode == "call") { print; if ($0 ~ /^[ \t]*\)/) {inblock=0} }
         else { if (started && $0 ~ /^[^ \t#]/) {inblock=0} else {print; started=1} }
       }' "$1"
}

# outbox_block_for <file> — dispatch on extension: Python uses the py extractor;
# everything else (*.sql, incl. Rust sqlx/diesel) uses the SQL extractor.
outbox_block_for() {
  case "$1" in
    *.py) extract_outbox_block_py "$1" ;;
    *)    extract_outbox_block "$1" ;;
  esac
}

# comment_prefix_re <file> — line-comment regex so a column name mentioned only
# in a comment does not satisfy the requirement. SQL '--', Python '#', Rust '//'.
comment_prefix_re() {
  case "$1" in
    *.py) printf '%s' '^[[:space:]]*#' ;;
    *.rs) printf '%s' '^[[:space:]]*//' ;;
    *)    printf '%s' '^[[:space:]]*--' ;;
  esac
}

for col in "${REQUIRED_COLUMNS[@]}"; do
  found=false
  for f in $OUTBOX_FILES; do
    cre=$(comment_prefix_re "$f")
    # Exclude comment lines to avoid matching column names mentioned in comments
    if outbox_block_for "$f" | grep -i "$col" | grep -qv "$cre"; then
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
# Pattern: CREATE INDEX ... WHERE published_at IS NULL (SQL / Rust sqlx / diesel)
# or Alembic op.create_index(..., postgresql_where=sa.text('published_at IS NULL')).
# The requirement is identical for every language — coverage is extended, not relaxed.
INDEX_FOUND=false
for f in $OUTBOX_FILES; do
  cre=$(comment_prefix_re "$f")
  # Exclude comment lines when checking for partial index
  if grep -i 'WHERE.*published_at.*IS NULL\|where.*published_at.*is null' "$f" \
     | grep -qv "$cre"; then
    INDEX_FOUND=true
    break
  fi
done
# Also check separate index migration files (*.sql or *.py) — exclude comment lines
INDEX_IN_SEPARATE=$(grep -rlE --include="*.sql" --include="*.py" 'published_at.*IS NULL|published_at.*is null' "$MIGRATION_DIR" 2>/dev/null \
  | while read -r f; do cre=$(comment_prefix_re "$f"); grep -i 'published_at.*IS NULL' "$f" | grep -v "$cre" | grep -q . && echo "$f"; done || true)
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

# Direct DELETE in a migration file (*.sql, or *.py via Alembic op.execute, or
# *.rs via an embedded sqlx/diesel DELETE)
for f in $(find "$MIGRATION_DIR" \( -name "*.sql" -o -name "*.py" -o -name "*.rs" \) 2>/dev/null); do
  if grep -qi 'DELETE.*outbox.*published_at\|delete.*from.*outbox.*where.*published' "$f"; then
    CLEANUP_FOUND=true
    break
  fi
done

# Scheduled cleanup in source code (Java @Scheduled, Go ticker, Node setInterval/
# cron, Python Celery/apscheduler, Rust tokio interval) — ADR 0006 D3 adds the
# *.py and *.rs includes; the DELETE ... outbox ... published_at pattern itself is
# the documented cleanup form (docs/OUTBOX_PATTERN.md §Cleanup) and is unchanged.
SOURCE_CLEANUP=$(grep -r \
  'DELETE.*outbox.*published_at\|outbox.*delete.*published\|published.*interval\|published_at.*INTERVAL' \
  --include="*.java" --include="*.go" --include="*.ts" --include="*.js" \
  --include="*.py" --include="*.rs" \
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
