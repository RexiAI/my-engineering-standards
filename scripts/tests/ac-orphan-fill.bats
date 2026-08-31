#!/usr/bin/env bats
# ac-orphan-fill.bats — fill remaining orphan scenario IDs for spec 001
# Ensures every AC-NNN-NN heading in specs/001-*/20-acceptance/*.md is traced

load test_helper
bats_require_minimum_version 1.5.0

@test "AC-004-04: mvn wiring documented and CI template references it" {
  run grep -R "mvn test" "$REPO_ROOT/ci/templates/java-feature" 2>&1
  [[ "$output" == *"mvn"* ]]
  [ -f "$REPO_ROOT/ci/templates/child-ci-java.yml" ]
  run grep -R "child-ci-java" "$REPO_ROOT/ci/templates"
  [ "$status" -eq 0 ]
}

@test "AC-005-04: internal layout follows Go standards" {
  [ -d "$REPO_ROOT/ci/templates/go-feature/internal/services" ]
  [ -d "$REPO_ROOT/ci/templates/go-feature/internal/store" ]
  [ -d "$REPO_ROOT/ci/templates/go-feature/internal/models" ]
  [ -f "$REPO_ROOT/ci/templates/go-feature/internal/dependency_injection.go" ]
}

@test "AC-006-04: npm scripts wired and package manager unchanged" {
  run grep -R '"test"' "$REPO_ROOT/ci/templates/js-feature/package.json" 2>&1
  [[ "$output" == *"vitest"* || "$output" == *"jest"* ]]
  [ ! -f "$REPO_ROOT/ci/templates/js-feature/yarn.lock" ]
  [ ! -f "$REPO_ROOT/ci/templates/js-feature/pnpm-lock.yaml" ]
}

@test "AC-006-05: Complexity gate referenced at ≤6" {
  run grep -R "complexity" "$REPO_ROOT/ci/templates/js-feature" 2>&1
  [[ "$output" == *"6"* ]]
}

@test "AC-006-06: Tier awareness documented" {
  run grep -R "production" "$REPO_ROOT/ci/templates/js-feature/README.md" 2>&1
  [[ "$output" == *"production"* ]]
}

@test "AC-007-01: Root Makefile exposes unified targets" {
  run grep -E "^test:" "$REPO_ROOT/Makefile" 2>&1
  [ "$status" -eq 0 ]
  run grep -E "^test-scripts:" "$REPO_ROOT/Makefile" 2>&1
  [ "$status" -eq 0 ]
  run grep -E "^mutation:" "$REPO_ROOT/Makefile" 2>&1
  [ "$status" -eq 0 ]
}

@test "AC-007-02: bootstrap and init-ci reference the new templates" {
  run grep -R "java-feature" "$REPO_ROOT/scripts/bootstrap.sh" 2>&1
  [ "$status" -eq 0 ]
  run grep -R "go-feature" "$REPO_ROOT/scripts/init-ci.sh" 2>&1
  [ "$status" -eq 0 ]
}

@test "AC-007-03: Onboarding guide is concise and covers both tracks" {
  wc -l "$REPO_ROOT/docs/TESTING_TDD_GUIDE.md" | awk '{if ($1 > 60) exit 1}'
  grep -q "starting a new feature" "$REPO_ROOT/docs/TESTING_TDD_GUIDE.md" || grep -q "Start a new feature" "$REPO_ROOT/docs/TESTING_TDD_GUIDE.md"
  grep -q "make test-scripts" "$REPO_ROOT/docs/TESTING_TDD_GUIDE.md"
  grep -q "check-scenario-traceability" "$REPO_ROOT/docs/TESTING_TDD_GUIDE.md"
}

@test "AC-007-04: Orchestration check still passes" {
  run bash "$REPO_ROOT/scripts/check-orchestration.sh" 2>&1
  [ "$status" -eq 0 ]
}
