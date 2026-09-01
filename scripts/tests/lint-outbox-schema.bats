#!/usr/bin/env bats
# lint-outbox-schema.bats — characterization tests for scripts/lint-outbox-schema.sh
# Contract: 0 when no migrations or the schema is complete; 1 when an outbox
# table is present but required columns / partial index / cleanup are missing.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "lint-outbox-schema: tree with no outbox table warns and exits 0" {
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No outbox table definition found"* ]]
  [[ "$output" == *"Skipping schema lint"* ]]
}

@test "lint-outbox-schema: outbox table missing required columns exits 1 with a violation count" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  printf 'CREATE TABLE outbox_events (id UUID PRIMARY KEY);\n' > "$TMPDIR_HELPER/migrations/001_outbox.sql"
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Outbox schema lint"* ]]
  [[ "$output" == *"violation(s)"* ]]
  [[ "$output" == *"docs/OUTBOX_PATTERN.md"* ]]
}

@test "lint-outbox-schema: full outbox schema passes columns, partial index and cleanup" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/001_outbox.sql" <<'SQL'
CREATE TABLE outbox_events (
  event_id UUID PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ
);
CREATE INDEX idx_outbox_unpublished ON outbox_events (created_at) WHERE published_at IS NULL;
DELETE FROM outbox_events WHERE published_at < now() - INTERVAL '7 days';
SQL
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Partial index on 'published_at IS NULL' found"* ]]
  [[ "$output" == *"Outbox cleanup mechanism"* ]]
}
