#!/usr/bin/env bats
# detect-saga-outbox.bats — characterization for scripts/detect-saga-outbox.sh
# Covers AC-002-01 (happy detects saga), AC-002-02 (negative), plus hermetic/trap

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "AC-002-01: detect-saga-outbox happy path detects saga file" {
  local repo="$TMPDIR_HELPER/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "test"
  mkdir -p "$repo/src"
  echo "// @SagaHandler" > "$repo/src/MySaga.java"
  echo "class MySaga { @SagaHandler void handle(){} }" >> "$repo/src/MySaga.java"
  git -C "$repo" add .
  git -C "$repo" commit -qm "init"
  run --separate-stderr bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/detect-saga-outbox.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED=true"* ]]
}

@test "detect-saga-outbox: sagaStep() in a JS/TS file sets SAGA_DETECTED=true" {
  local repo="$TMPDIR_HELPER/repo2"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "test"
  echo "sagaStep({ compensate: () => {}, timeout: 1000 })" > "$repo/app.ts"
  git -C "$repo" add .
  git -C "$repo" commit -qm "init"
  run --separate-stderr bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/detect-saga-outbox.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED=true"* ]]
}

@test "AC-002-02: detect-saga-outbox no-saga repo yields negative signal" {
  local repo="$TMPDIR_HELPER/emptyrepo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "test"
  echo "plain file" > "$repo/README.md"
  echo "no markers here" > "$repo/app.go"
  git -C "$repo" add .
  git -C "$repo" commit -qm "init"
  run --separate-stderr bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/detect-saga-outbox.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED=false"* ]]
  [[ "$output" == *"OUTBOX_DETECTED=false"* ]]
}

@test "detect-saga-outbox: run is hermetic — leaves scripts/ untouched" {
  before="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  local repo="$TMPDIR_HELPER/hermetic"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "test"
  touch "$repo/empty.txt"
  git -C "$repo" add .
  git -C "$repo" commit -qm "init" --allow-empty 2>&1 || true
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/detect-saga-outbox.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED="* ]]
  after="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  [ "$before" = "$after" ]
  [ -d "$TMPDIR_HELPER" ]
}
