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
)

# ── Outbox detection patterns ──────────────────────────────────────────────────
# SQL:   CREATE TABLE outbox, INSERT INTO outbox
# Java:  OutboxRelay, OutboxRepository, OutboxEvent
# Go:    InsertOutbox, SaveOutbox, OutboxRelay
# Node:  outboxRepository, OutboxRelay
# Migrations: any file with 'outbox' in name
OUTBOX_PATTERNS=(
  'OutboxRelay'
  'OutboxRepository'
  'OutboxEvent'
  'OutboxPublisher'
  'outbox_relay'
  'outbox_repository'
  'outboxRepository'
  'InsertOutbox'
  'SaveOutbox'
  'CREATE TABLE outbox'
  'INSERT INTO outbox'
)

# ── Scan logic ────────────────────────────────────────────────────────────────
SAGA_DETECTED=false
OUTBOX_DETECTED=false

# Also check migration file names for outbox — restrict to code/migration extensions only
for f in $CHANGED_FILES; do
  case "$f" in
    *.java|*.go|*.ts|*.js|*.sql|*.xml)
      if echo "$f" | grep -qi 'outbox'; then
        OUTBOX_DETECTED=true
        break
      fi
      ;;
  esac
done

# Scan file contents for patterns (limit to code + migration files)
CODE_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(java|go|ts|js|sql|xml)$' || true)

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
