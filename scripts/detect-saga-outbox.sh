#!/bin/bash
# detect-saga-outbox.sh — Detect whether changed files touch saga or outbox patterns.
#
# Outputs shell variable exports:
#   SAGA_DETECTED=true|false
#   OUTBOX_DETECTED=true|false
#
# Usage (source in CI to set variables for downstream gate scripts):
#   source .standards/scripts/detect-saga-outbox.sh
#
# Or as a standalone check that exports to GITHUB_ENV / GitLab dotenv artifact:
#   .standards/scripts/detect-saga-outbox.sh [--github-env | --gitlab-dotenv FILE]
#
# Standards reference: docs/SAGA_PATTERN.md, docs/OUTBOX_PATTERN.md
set -euo pipefail

# ── Detect changed files ───────────────────────────────────────────────────────
# In CI: use git diff against base branch. Locally: scan all tracked files.
if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || git ls-files)
else
  CHANGED_FILES=$(git ls-files)
fi

# ── Saga detection patterns ────────────────────────────────────────────────────
# Java:  @SagaHandler annotation, *.saga.* packages, SagaState, SagaOrchestrator
# Go:    *SagaHandler function suffix, SagaState struct
# Node:  sagaStep() call, SagaOrchestrator class
# Python/Rust (ADR 0006 D2): the PascalCase names above (SagaOrchestrator,
#   SagaState, SagaHandler) already match Rust types and Python classes, and the
#   snake_case names already match Python. The extra tokens below cover the
#   step-registration and compensation idioms ADR 0006 D3 keys on: Python
#   `saga_step`/`SagaStep` (decorator or class) and Rust `Compensable`
#   (`impl Compensable`). NOTE: `saga_step`/`Compensable` are HOUSE CONVENTIONS
#   chosen by ADR 0006 — docs/SAGA_PATTERN.md documents the timeout/compensation
#   *requirements* language-agnostically (its examples are Java) and mandates
#   neither token.
SAGA_PATTERNS=(
  '@SagaHandler'
  'SagaHandler'
  'SagaOrchestrator'
  'SagaStateStore'
  'SagaState'
  '/saga/'
  '\.saga\.'
  'sagaStep'
  'saga_handler'
  'saga_orchestrator'
  'saga_step'
  'SagaStep'
  'Compensable'
)

# ── Outbox detection patterns ──────────────────────────────────────────────────
# SQL:   CREATE TABLE outbox, INSERT INTO outbox
# Java:  OutboxRelay, OutboxRepository, OutboxEvent
# Go:    InsertOutbox, SaveOutbox, OutboxRelay
# Node:  outboxRepository, OutboxRelay
# Migrations: any file with 'outbox' in name
# Python/Rust (ADR 0006 D2): PascalCase Outbox* names already match Rust types
#   and Python classes; snake_case outbox_relay/outbox_repository already match
#   Python. The extra tokens add (a) the snake_case relay entry points
#   (publish_pending / publish_outbox / outbox_publisher) that Python and Rust
#   polling relays use, and (b) the Python ORM outbox-table creation spellings
#   (Alembic `op.create_table('outbox', ...)` and SQLModel/SQLAlchemy
#   `__tablename__ = "outbox"`), which the raw-SQL `CREATE TABLE outbox` token
#   does NOT match — without them an Alembic migration whose filename lacks
#   "outbox" would silently skip the gates (the defect-2 hazard). All are HOUSE
#   CONVENTIONS per ADR 0006 D3; docs/OUTBOX_PATTERN.md §Database Schema/§Outbox
#   Relay show plain SQL + a Java relay and mandate no Python/Rust token. Rust
#   sqlx/diesel migrations are plain .sql and were already covered by
#   `CREATE TABLE outbox`.
OUTBOX_PATTERNS=(
  'OutboxRelay'
  'OutboxRepository'
  'OutboxEvent'
  'OutboxPublisher'
  'outbox_relay'
  'outbox_repository'
  'outboxRepository'
  'outbox_publisher'
  'publish_pending'
  'publish_outbox'
  'InsertOutbox'
  'SaveOutbox'
  'CREATE TABLE outbox'
  'INSERT INTO outbox'
  'create_table.*outbox'
  '__tablename__.*outbox'
)

# ── Scan logic ────────────────────────────────────────────────────────────────
SAGA_DETECTED=false
OUTBOX_DETECTED=false

# Also check migration file names for outbox — restrict to code/migration extensions only
# ADR 0006 D2: `.py` (Alembic/SQLModel migrations) and `.rs` (Rust sources /
# sqlx migrations embedded via query! macros) join the existing set. sqlx and
# diesel migrations are `.sql` and were already covered.
for f in $CHANGED_FILES; do
  case "$f" in
    *.java|*.go|*.ts|*.js|*.sql|*.xml|*.py|*.rs)
      if echo "$f" | grep -qi 'outbox'; then
        OUTBOX_DETECTED=true
        break
      fi
      ;;
  esac
done

# Scan file contents for patterns (limit to code + migration files)
# ADR 0006 D2: `.py` and `.rs` added so Python/Rust saga+outbox code is scanned
# in the primary pass rather than only via the full-tree fallback below.
CODE_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(java|go|ts|js|sql|xml|py|rs)$' || true)

if [ -n "$CODE_FILES" ]; then
  # Build array of files that actually exist on disk
  EXISTING_CODE_FILES=()
  while IFS= read -r f; do
    [ -f "$f" ] && EXISTING_CODE_FILES+=("$f")
  done <<< "$CODE_FILES"

  if [ ${#EXISTING_CODE_FILES[@]} -gt 0 ]; then
    for pattern in "${SAGA_PATTERNS[@]}"; do
      # Check file contents directly
      if grep -ql "$pattern" "${EXISTING_CODE_FILES[@]}" 2>/dev/null; then
        SAGA_DETECTED=true
        break
      fi
      # Also grep diff (catches deletions / context lines)
      if git diff HEAD~1 HEAD -- "${EXISTING_CODE_FILES[@]}" 2>/dev/null | grep -q "$pattern"; then
        SAGA_DETECTED=true
        break
      fi
    done

    for pattern in "${OUTBOX_PATTERNS[@]}"; do
      if grep -ql "$pattern" "${EXISTING_CODE_FILES[@]}" 2>/dev/null; then
        OUTBOX_DETECTED=true
        break
      fi
      if git diff HEAD~1 HEAD -- "${EXISTING_CODE_FILES[@]}" 2>/dev/null | grep -q "$pattern"; then
        OUTBOX_DETECTED=true
        break
      fi
    done
  fi
fi

# ── Fallback: scan full codebase for existing saga/outbox usage ───────────────
# If base comparison unavailable, scan full tracked files.
if [ "$SAGA_DETECTED" = false ] && [ "$OUTBOX_DETECTED" = false ]; then
  for f in $CHANGED_FILES; do
    [ -f "$f" ] || continue
    for pattern in "${SAGA_PATTERNS[@]}"; do
      if grep -q "$pattern" "$f" 2>/dev/null; then
        SAGA_DETECTED=true
        break 2
      fi
    done
  done
  for f in $CHANGED_FILES; do
    [ -f "$f" ] || continue
    for pattern in "${OUTBOX_PATTERNS[@]}"; do
      if grep -q "$pattern" "$f" 2>/dev/null; then
        OUTBOX_DETECTED=true
        break 2
      fi
    done
  done
fi

# ── Export / report ───────────────────────────────────────────────────────────
export SAGA_DETECTED
export OUTBOX_DETECTED

echo "SAGA_DETECTED=${SAGA_DETECTED}"
echo "OUTBOX_DETECTED=${OUTBOX_DETECTED}"

# GitHub Actions: write to GITHUB_ENV
if [ "${1:-}" = "--github-env" ] && [ -n "${GITHUB_ENV:-}" ]; then
  echo "SAGA_DETECTED=${SAGA_DETECTED}" >> "$GITHUB_ENV"
  echo "OUTBOX_DETECTED=${OUTBOX_DETECTED}" >> "$GITHUB_ENV"
fi

# GitLab: write to dotenv artifact file for downstream jobs
if [ "${1:-}" = "--gitlab-dotenv" ] && [ -n "${2:-}" ]; then
  echo "SAGA_DETECTED=${SAGA_DETECTED}" > "$2"
  echo "OUTBOX_DETECTED=${OUTBOX_DETECTED}" >> "$2"
fi
