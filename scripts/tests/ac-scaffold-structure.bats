#!/usr/bin/env bats
# ac-scaffold-structure.bats — Track A scaffold scenarios AC-004-01..03,
# AC-005-01..03, AC-006-01..03.
#
# Each test asserts a concrete file/content fact from ci/templates/<lang>-feature/,
# so deleting or gutting a scaffold file fails the test.

load test_helper
bats_require_minimum_version 1.5.0

JF="ci/templates/java-feature"
GF="ci/templates/go-feature"
SF="ci/templates/js-feature"

@test "AC-004-01: Java scaffold directory and pom fragment exist" {
  [ -d "$REPO_ROOT/$JF" ]
  [ -f "$REPO_ROOT/$JF/pom-fragment.xml" ]
  run grep -E 'junit|mockito|assertj|jqwik' "$REPO_ROOT/$JF/pom-fragment.xml"
  [ "$status" -eq 0 ]
}

@test "AC-004-02: Java layered skeleton mirrors ARCHITECTURE.md (controller/service/repository)" {
  run bash -c "ls -R '$REPO_ROOT/$JF/src/main/java' | tr 'A-Z' 'a-z'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"controller"* ]]
  [[ "$output" == *"service"* ]]
  [[ "$output" == *"repository"* ]]
}

@test "AC-004-03: Java sample acceptance test is traceable and Given/When/Then named" {
  run grep -rE 'AC_004_01' "$REPO_ROOT/$JF/src/test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"should"* ]]
}

@test "AC-005-01: Go scaffold directory and Makefile ci ladder exist" {
  [ -d "$REPO_ROOT/$GF" ]
  [ -f "$REPO_ROOT/$GF/Makefile" ]
  run cat "$REPO_ROOT/$GF/Makefile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ci-fast"* ]]
  [[ "$output" == *"ci-full"* ]]
}

@test "AC-005-02: Go test command matches the standards (-race -shuffle=on -count=1)" {
  run grep -E 'go test' "$REPO_ROOT/$GF/Makefile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-race"* ]]
  [[ "$output" == *"-shuffle=on"* ]]
  [[ "$output" == *"-count=1"* ]]
}

@test "AC-005-03: Go sample tests use stdlib testing and a testing/quick property test, not testify" {
  run bash -c "cat '$REPO_ROOT/$GF'/internal/services/*_test.go"
  [ "$status" -eq 0 ]
  [[ "$output" == *"testing/quick"* ]]
  [[ "$output" == *"TestAC_005_01"* ]]
  [[ "$output" != *"stretchr/testify"* ]]
}

@test "AC-006-01: JS scaffold directory and package wiring exist" {
  [ -d "$REPO_ROOT/$SF" ]
  [ -f "$REPO_ROOT/$SF/package.json" ]
  run cat "$REPO_ROOT/$SF/package.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vitest"* ]]
  [[ "$output" == *"fast-check"* ]]
}

@test "AC-006-02: JS sample acceptance test carries its AC id in the it() name" {
  run bash -c "grep -rE 'AC-006-01' '$REPO_ROOT/$SF'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"it("* ]]
}

@test "AC-006-03: Stryker mutation threshold 80 is configured in the JS scaffold" {
  [ -f "$REPO_ROOT/$SF/stryker.conf.json" ]
  run cat "$REPO_ROOT/$SF/stryker.conf.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"break\": 80"* ]]
}
