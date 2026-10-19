#!/usr/bin/env bats
# ac-031-docs-updates.bats — acceptance tests for spec 031 Task 10
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-docs-updates.md).

load test_helper
bats_require_minimum_version 1.5.0

OFFREF="$REPO_ROOT/docs/OFFICIAL_REFERENCES.md"
DEPLOY="$REPO_ROOT/docs/DEPLOYMENT.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-53 — version-pins table gains Vercel CLI 64.5.0 with source URL and Apache-2.0 licence" {
  run grep -F '| Vercel CLI |' "$OFFREF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"64.5.0"* ]]
  [[ "$output" == *"Apache-2.0"* ]]
  [[ "$output" == *"registry.npmjs.org/vercel"* ]]
  # licence table also records it
  run grep -F '| Vercel CLI |' "$OFFREF"
  [ "$(printf '%s\n' "$output" | grep -c 'Vercel CLI')" -ge 2 ]
}

@test "AC-031-54 — pages-consulted gains a Vercel CLI subsection" {
  grep -qF '### Vercel CLI' "$OFFREF"
  run awk '/^### Vercel CLI/,/^### [^V]/' "$OFFREF"
  [[ "$output" == *"registry.npmjs.org/vercel/64.5.0"* ]]
  [[ "$output" == *"vercel.com/docs/cli"* ]]
}

@test "AC-031-55 — DEPLOYMENT.md gains a Frontend: Vercel section with the required content" {
  grep -qxF '### Frontend: Vercel' "$DEPLOY"
  sec="$(awk '/^### Frontend: Vercel$/{f=1;next} /^### /{if(f)exit} f' "$DEPLOY" | tr '\n' ' ')"
  [[ "$sec" == *"Git integration"*"source of truth"* ]]
  [[ "$sec" == *"observation"* ]]
  [[ "$sec" == *"VERCEL_TOKEN"* ]]
  [[ "$sec" == *"VERCEL_ORG_ID"* ]]
  [[ "$sec" == *"VERCEL_PROJECT_ID"* ]]
  [[ "$sec" == *"GHCR"* ]]
  [[ "$sec" == *"never run"*"vercel deploy"* || "$sec" == *"prohibition"* ]]
  # alongside the existing backend sections
  grep -qxF '### Backend: Kamal + VPS' "$DEPLOY"
  grep -qxF '### Backend: Dokku + VPS' "$DEPLOY"
  grep -qxF '### Backend: Raw SSH + Docker Compose' "$DEPLOY"
}
