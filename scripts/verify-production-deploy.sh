#!/bin/bash
# verify-production-deploy.sh — post-merge production deploy verification (spec 031).
#
# Verifies that the Vercel production deployment produced by the Git
# integration for the merged commit exists and answers a health check, then
# records the result on stdout (the CI log is the record — ponytail ceiling:
# no artifact file is written; upgrade path: a --report flag writing the
# evidence-block format of docs/SPEC_PIPELINE.md §Audit contract).
#
# Verdict semantics (docs/SPEC_PIPELINE.md §Production deploy verification
# (post-merge)):
#   - production deployment not found for the commit -> SKIP, exit 0
#   - no Vercel project linked to the repository     -> SKIP, exit 0
#   - Vercel Git integration not connected           -> SKIP, exit 0
#   - missing or invalid VERCEL_TOKEN                -> FAIL, exit non-zero
#     (a configuration defect is not a skip)
#   - health check non-2xx / transport failure       -> FAIL, exit non-zero
#
# Usage:
#   scripts/verify-production-deploy.sh [COMMIT_SHA]   (falls back to $GITHUB_SHA)
#
# Environment:
#   VERCEL_TOKEN / VERCEL_ORG_ID / VERCEL_PROJECT_ID  credential pattern
#       (config/agent.local.env.example; CI secrets for child repos)
#   VERCEL_API_BASE     defaults to https://api.vercel.com
#   VERCEL_HEALTH_PATH  path appended to the deployment URL, defaults to /
#   VERCEL_HTTP_TIMEOUT curl max-time seconds, defaults to 15
#
# Exit codes:
#   0 — verified (PASS) or legitimately skipped (SKIP with reason)
#   1 — auth error, API failure, or health-check failure (recorded as FAIL)
#   2 — usage error or missing tooling
set -euo pipefail

API_BASE="${VERCEL_API_BASE:-https://api.vercel.com}"

# ── helpers ──────────────────────────────────────────────────────────────────

record_skip() { echo "Result: SKIP — $*"; exit 0; }
record_fail() { echo "Result: FAIL — $*" >&2; exit 1; }

http_get() { # http_get <url> <body-file> — echo the HTTP status code (000 on transport error)
  local url="$1" out="$2" code
  code="$(curl -sS --max-time "${VERCEL_HTTP_TIMEOUT:-15}" -o "$out" -w '%{http_code}' \
    -H "Authorization: Bearer ${VERCEL_TOKEN:-}" "$url" || printf '000')"
  printf '%s' "$code"
}

team_suffix() { # team_suffix <first-separator> — teamId query when VERCEL_ORG_ID is set
  if [ -n "${VERCEL_ORG_ID:-}" ]; then printf '%steamId=%s' "$1" "$VERCEL_ORG_ID"; fi
}

is_2xx() { case "$1" in 2[0-9][0-9]) return 0 ;; *) return 1 ;; esac; }

# ── preflight ────────────────────────────────────────────────────────────────

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool is required" >&2; exit 2; }
done

SHA="${1:-${GITHUB_SHA:-}}"
[ -n "$SHA" ] || { echo "Usage: verify-production-deploy.sh [COMMIT_SHA] (or set GITHUB_SHA)" >&2; exit 2; }

# A missing token is a configuration defect (AC-031-40), checked before any
# skip-detection so it can never degrade into a silent skip.
[ -n "${VERCEL_TOKEN:-}" ] || \
  record_fail "authentication error: VERCEL_TOKEN is missing — configure the credential, this is not a skip"

# No project id at all: the repository has no Vercel lane linked (AC-031-39).
[ -n "${VERCEL_PROJECT_ID:-}" ] || \
  record_skip "No Vercel project linked to this repository"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# ── project lookup: linked? git-connected? authenticated? ────────────────────
proj_url="$API_BASE/v9/projects/$VERCEL_PROJECT_ID$(team_suffix '?')"
proj_code="$(http_get "$proj_url" "$WORK/project.json")"
case "$proj_code" in
  401|403) record_fail "authentication error: the Vercel API rejected VERCEL_TOKEN (HTTP $proj_code)" ;;
  404) record_skip "No Vercel project linked to this repository" ;;
esac
is_2xx "$proj_code" || record_fail "Vercel API error querying the project (HTTP $proj_code)"

if ! jq -e '.repository and (.repository | length > 0)' "$WORK/project.json" >/dev/null 2>&1; then
  record_skip "Vercel Git integration not connected"
fi

# ── production deployment for the merged commit ──────────────────────────────
dep_url="$API_BASE/v6/deployments?pid=$VERCEL_PROJECT_ID&target=production&limit=100$(team_suffix '&')"
dep_code="$(http_get "$dep_url" "$WORK/deployments.json")"
is_2xx "$dep_code" || record_fail "Vercel API error listing deployments (HTTP $dep_code)"

DPL_URL="$(jq -r --arg sha "$SHA" \
  '[.deployments[]? | select(.meta.githubCommitSha == $sha)] | .[0].url // empty' \
  "$WORK/deployments.json")"
[ -n "$DPL_URL" ] || record_skip "Production deployment not found for commit $SHA"

# ── health check + record ────────────────────────────────────────────────────
health_code="$(http_get "https://$DPL_URL${VERCEL_HEALTH_PATH:-/}" "$WORK/health.html")"
is_2xx "$health_code" || \
  record_fail "health check against https://$DPL_URL returned $health_code (expected 2xx)"

echo "Result: PASS — commit $SHA production deployment https://$DPL_URL health check HTTP $health_code at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
