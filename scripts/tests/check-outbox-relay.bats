#!/usr/bin/env bats
# check-outbox-relay.bats — characterization tests for scripts/check-outbox-relay.sh
#
# Both tests are discriminating: replacing the script with `exit 0` fails the
# empty-tree test; deleting its clean line fails the happy-path test.
# No AC prefix — these cover script behavior beyond the archived AC-001..007
# scenario list (see scripts/tests/README.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-outbox-relay: clean repo exits 0 and prints its documented clean line" {
  run bash "$REPO_ROOT/scripts/check-outbox-relay.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Outbox relay check: all checks passed"* ]]
}

@test "check-outbox-relay: empty tree exits 1 and names the missing artifact" {
  run bash "$REPO_ROOT/scripts/check-outbox-relay.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No outbox relay component detected"* ]]
}

# ── ADR 0006 D3: Python and Rust relay + consumer-dedup detection ──────────────
# The relay entry-point names (OutboxRelay/publish_pending) and dedup method names
# (already_processed/mark_processed) are HOUSE CONVENTIONS mirroring the Node
# idiom; docs/OUTBOX_PATTERN.md §Outbox Relay / §Idempotent Event Processing
# mandate the behaviour with a Java example, not a Python/Rust spelling.

@test "check-outbox-relay: Python relay + dedup exits 0" {
  mkdir -p "$TMPDIR_HELPER/app"
  cat > "$TMPDIR_HELPER/app/outbox_relay.py" <<'PY'
class OutboxRelay:
    async def publish_pending(self, dedup_store):
        if dedup_store.already_processed(eid):
            return
        dedup_store.mark_processed(eid)
PY
  run bash "$REPO_ROOT/scripts/check-outbox-relay.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Outbox relay component found"* ]]
  [[ "$output" == *"Consumer deduplication logic found"* ]]
}

@test "check-outbox-relay: Rust relay + dedup exits 0" {
  mkdir -p "$TMPDIR_HELPER/src"
  cat > "$TMPDIR_HELPER/src/outbox_relay.rs" <<'RS'
pub struct OutboxRelay;
impl OutboxRelay {
    pub async fn publish_pending(&self, dedup: &DedupStore) {
        if dedup.already_processed(id) { return; }
        dedup.mark_processed(id);
    }
}
RS
  run bash "$REPO_ROOT/scripts/check-outbox-relay.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Outbox relay component found"* ]]
  [[ "$output" == *"Consumer deduplication logic found"* ]]
}

@test "check-outbox-relay: Python outbox repo without a relay exits 1" {
  mkdir -p "$TMPDIR_HELPER/app"
  printf 'def write_order():\n    pass\n' > "$TMPDIR_HELPER/app/orders.py"
  run bash "$REPO_ROOT/scripts/check-outbox-relay.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No outbox relay component detected"* ]]
}
