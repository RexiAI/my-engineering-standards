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

# ── ADR 0006 D3: Python (Alembic/SQLModel) and Rust (sqlx/diesel) outbox schema ─
# The required-column set and the partial-index requirement are IDENTICAL to the
# SQL/Java/Go/Node path — these tests prove coverage was extended, not weakened.
# Alembic's op.create_table / postgresql_where spelling is a HOUSE CONVENTION the
# docs do not mandate (docs/OUTBOX_PATTERN.md §Database Schema shows plain SQL).

@test "lint-outbox-schema: Python Alembic outbox migration with all columns + partial index passes" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/0001_create_outbox.py" <<'PY'
from alembic import op
import sqlalchemy as sa

def upgrade():
    op.create_table('outbox',
        sa.Column('event_id', sa.UUID(), nullable=False),
        sa.Column('event_type', sa.String(), nullable=False),
        sa.Column('payload', sa.JSON(), nullable=False),
        sa.Column('aggregate_type', sa.String(), nullable=False),
        sa.Column('aggregate_id', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('published_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('event_id')
    )
    op.create_index('ix_outbox_unpublished', 'outbox', ['created_at'],
                    postgresql_where=sa.text('published_at IS NULL'))
    op.execute("DELETE FROM outbox WHERE published_at < NOW() - INTERVAL '7 days'")
PY
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Column 'aggregate_type' present"* ]]
  [[ "$output" == *"Partial index on 'published_at IS NULL' found"* ]]
  [[ "$output" == *"all checks passed"* ]]
}

@test "lint-outbox-schema: Python Alembic outbox migration missing a column and the partial index exits 1" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/0001_create_outbox.py" <<'PY'
from alembic import op
import sqlalchemy as sa

def upgrade():
    op.create_table('outbox',
        sa.Column('event_id', sa.UUID(), nullable=False),
        sa.Column('payload', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False)
    )
PY
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aggregate_type' missing"* ]]
  [[ "$output" == *"No partial index on 'published_at IS NULL' found"* ]]
}

@test "lint-outbox-schema: Rust sqlx outbox migration with all columns + partial index passes" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/20240101_create_outbox.sql" <<'SQL'
CREATE TABLE outbox (
    event_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);
CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;
DELETE FROM outbox WHERE published_at < now() - INTERVAL '7 days';
SQL
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Column 'payload' present"* ]]
  [[ "$output" == *"Partial index on 'published_at IS NULL' found"* ]]
  [[ "$output" == *"all checks passed"* ]]
}

@test "lint-outbox-schema: Rust sqlx outbox migration missing the partial index exits 1" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/20240101_create_outbox.sql" <<'SQL'
CREATE TABLE outbox (
    event_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);
DELETE FROM outbox WHERE published_at < now() - INTERVAL '7 days';
SQL
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Column 'event_id' present"* ]]
  [[ "$output" == *"No partial index on 'published_at IS NULL' found"* ]]
}

@test "lint-outbox-schema: Rust sqlx outbox migration missing a required column exits 1" {
  mkdir -p "$TMPDIR_HELPER/migrations"
  cat > "$TMPDIR_HELPER/migrations/20240101_create_outbox.sql" <<'SQL'
CREATE TABLE outbox (
    event_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);
CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;
DELETE FROM outbox WHERE published_at < now() - INTERVAL '7 days';
SQL
  run bash "$REPO_ROOT/scripts/lint-outbox-schema.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"payload' missing"* ]]
  [[ "$output" == *"Partial index on 'published_at IS NULL' found"* ]]
}
