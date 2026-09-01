#!/usr/bin/env bats
# ac-001-harness.bats — harness foundation acceptance (AC-001-01..06)

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "AC-001-01: Harness runs a passing bats test (TAP ok)" {
  mkdir -p "$TMPDIR_HELPER/bats-passing"
  cat > "$TMPDIR_HELPER/bats-passing/passing.bats" <<'EOF'
#!/usr/bin/env bats
@test "passing" { true; }
EOF
  run --separate-stderr bats --tap "$TMPDIR_HELPER/bats-passing/passing.bats"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok 1"* ]]
}

@test "AC-001-02: Failing bats test fails the target (not ok)" {
  mkdir -p "$TMPDIR_HELPER/bats-failing"
  cat > "$TMPDIR_HELPER/bats-failing/failing.bats" <<'EOF'
#!/usr/bin/env bats
@test "failing" { false; }
EOF
  run --separate-stderr bats --tap "$TMPDIR_HELPER/bats-failing/failing.bats"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not ok"* ]]
}

@test "AC-001-03: Helper safely sources shared libs (json_escape, json_array)" {
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/tests/test_helper.bash' && type json_escape && type json_array"
  [ "$status" -eq 0 ]
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/tests/test_helper.bash'; source '$REPO_ROOT/scripts/tests/test_helper.bash' && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "AC-001-04: Missing bats binary yields actionable error via make test-scripts" {
  run --separate-stderr bash -c "PATH=/usr/bin:/bin make -C '$REPO_ROOT' test-scripts 2>&1 || true"
  [[ "$output$stderr" == *"bats"* ]]
  [[ "$output$stderr" == *"install hint"* || "$output$stderr" == *"bats-core"* || "$output$stderr" == *"not found"* ]]
}

@test "AC-001-05: No secrets in harness or fixtures" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"scripts/tests/"* ]]
}

@test "AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)" {
  run --separate-stderr grep -E "make test-scripts|bats scripts/tests" "$REPO_ROOT/.github/workflows/self-ci.yml"
  [ "$status" -eq 0 ]
  run bash -c "grep -A5 'make test-scripts\|bats scripts/tests' '$REPO_ROOT/.github/workflows/self-ci.yml' | grep -q 'continue-on-error: true' && echo found || echo notfound"
  [[ "$output" == *"notfound"* ]]
}
