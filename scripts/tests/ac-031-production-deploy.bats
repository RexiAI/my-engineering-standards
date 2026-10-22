#!/usr/bin/env bats
# ac-031-production-deploy.bats — acceptance tests for spec 031 Task 7
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-production-deploy.md).
# Hermetic: a stub `curl` earlier on PATH answers the Vercel API; no network,
# no real token (same discipline as typed-judgment.bats offline cases).

load test_helper
bats_require_minimum_version 1.5.0

SCRIPT="$REPO_ROOT/scripts/verify-production-deploy.sh"
WF="$REPO_ROOT/.github/workflows/ci-vercel-production-verify.yml"

# stub_setup — fake curl answering from canned files in $TMPDIR_HELPER/canned
stub_setup() {
  mkdir -p "$TMPDIR_HELPER/bin" "$TMPDIR_HELPER/canned"
  cat > "$TMPDIR_HELPER/bin/curl" <<'STUB'
#!/bin/bash
# canned: $CANNED/<slug>.<key>; slug derived from the URL by the test's env
args="$*"; url=""
for a in "$@"; do case "$a" in http*) url="$a";; esac; done
out=""; o_next=0
for a in "$@"; do
  if [ "$o_next" = 1 ]; then out="$a"; o_next=0; else case "$a" in -o) o_next=1;; esac; fi
done
code="$(cat "$CANNED/code" 2>/dev/null || echo 000)"
body="$(cat "$CANNED/body" 2>/dev/null || true)"
case "$url" in
  */v9/projects/*) cp "$CANNED/proj.json" "$out" 2>/dev/null || true; printf '%s' "$(cat "$CANNED/proj.code" 2>/dev/null || echo 200)" ;;
  */v6/deployments*) cp "$CANNED/deploy.json" "$out" 2>/dev/null || true; printf '%s' "$(cat "$CANNED/deploy.code" 2>/dev/null || echo 200)" ;;
  *) [ -n "$out" ] && cp "$CANNED/health.body" "$out" 2>/dev/null || true; printf '%s' "$(cat "$CANNED/health.code" 2>/dev/null || echo 200)" ;;
esac
STUB
  chmod +x "$TMPDIR_HELPER/bin/curl"
  printf '{"repository":{"repo":"acme/app"},"id":"prj_1"}' > "$TMPDIR_HELPER/canned/proj.json"
  printf '200' > "$TMPDIR_HELPER/canned/proj.code"
  printf '{"deployments":[{"id":"dpl_1","url":"acme-app.pages.vercel.app","target":"production","readyState":"READY","meta":{"githubCommitSha":"deadbeef123"}}]}' > "$TMPDIR_HELPER/canned/deploy.json"
  printf '200' > "$TMPDIR_HELPER/canned/deploy.code"
  printf 'ok' > "$TMPDIR_HELPER/canned/health.body"
  printf '200' > "$TMPDIR_HELPER/canned/health.code"
  export CANNED="$TMPDIR_HELPER/canned"
  export PATH="$TMPDIR_HELPER/bin:$PATH"
  export VERCEL_TOKEN=fake-token VERCEL_ORG_ID=team_1 VERCEL_PROJECT_ID=prj_1
}

setup() { setup_tmpdir; stub_setup; }
teardown() { teardown_tmpdir; }

@test "AC-031-37 — post-merge verification queries the Vercel API for the merged commit, runs the health check, records the result" {
  run bash "$SCRIPT" deadbeef123
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
  [[ "$output" == *"deadbeef123"* ]]
  [[ "$output" == *"acme-app.pages.vercel.app"* ]]
}

@test "AC-031-38 — production deployment not found for the commit: skip with reason, exit 0" {
  printf '{"deployments":[]}' > "$CANNED/deploy.json"
  run bash "$SCRIPT" cafebabe999
  [ "$status" -eq 0 ]
  [[ "$output" == *"Production deployment not found for commit cafebabe999"* ]]
}

@test "AC-031-39 — repo with no Vercel project: skip with reason, exit 0" {
  run env -u VERCEL_PROJECT_ID VERCEL_TOKEN=fake-token bash "$SCRIPT" deadbeef123
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Vercel project linked to this repository"* ]]
  # API-side variant: project lookup 404
  printf '404' > "$CANNED/proj.code"
  run bash "$SCRIPT" deadbeef123
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Vercel project linked to this repository"* ]]
}

@test "AC-031-40 — missing or invalid VERCEL_TOKEN: record failure with the auth error, exit non-zero (not a skip)" {
  run env -u VERCEL_TOKEN VERCEL_ORG_ID=team_1 VERCEL_PROJECT_ID=prj_1 bash "$SCRIPT" deadbeef123
  [ "$status" -ne 0 ]
  [[ "$output" == *"authentication error"* ]]
  printf '401' > "$CANNED/proj.code"
  run bash "$SCRIPT" deadbeef123
  [ "$status" -ne 0 ]
  [[ "$output" == *"authentication error"* ]]
}

@test "AC-031-41 — Vercel Git integration not connected: skip with reason, exit 0" {
  printf '{"id":"prj_1"}' > "$CANNED/proj.json"
  run bash "$SCRIPT" deadbeef123
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vercel Git integration not connected"* ]]
}

@test "unit — missing commit sha and missing sha fallback is a usage error (exit 2)" {
  run env -u GITHUB_SHA bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "unit — health check failure records FAIL and exits non-zero" {
  printf '503' > "$CANNED/health.code"
  run bash "$SCRIPT" deadbeef123
  [ "$status" -ne 0 ]
  [[ "$output" == *"health check"* ]]
  [[ "$output" == *"503"* ]]
}

@test "unit — post-merge workflow template exists, calls the verify script, and is main-push scoped" {
  [ -f "$WF" ]
  grep -qF 'verify-production-deploy.sh' "$WF"
  grep -qF 'VERCEL_TOKEN' "$WF"
  grep -qF 'refs/heads/main' "$WF"
}

@test "unit — SPEC_PIPELINE.md carries the production-verification section (rewritten after-merge contract)" {
  grep -qF '## Production deploy verification (post-merge)' "$REPO_ROOT/docs/SPEC_PIPELINE.md"
}
