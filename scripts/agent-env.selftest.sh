#!/bin/bash
# agent-env.selftest.sh — Hermetic regression net for the per-machine agent
# environment: scripts/guard-env.sh and scripts/check-no-hardcoded-secrets.sh,
# plus the docs that describe the per-machine credential flow. Credentials now
# arrive via the per-machine direnv .envrc (spec 025) — the credential-loading
# behavior itself is covered by scripts/model-env.selftest.sh (AC-025-02-04 /
# AC-025-03-04); this file covers the structural guards around the credential
# files. Fixtures live in mktemp -d with trap cleanup; nothing here touches the
# real repo's config or git state.
#
# Self-trip constraint: this file lives under scripts/, which is in the
# hardcoded-secrets scan scope. Every fixture credential is constructed at
# runtime by string concatenation — the source of this file never contains a
# string that literally matches the check's patterns, and no loader-name or
# emit-flag string appears either (scripts/ is also in spec 025's purge scope).
#
# Usage:
#   bash scripts/agent-env.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/scripts/guard-env.sh"
SECRETS_CHECK="$ROOT/scripts/check-no-hardcoded-secrets.sh"
REAL_ENV="config/agent.local.env"
EXAMPLE_ENV="config/agent.local.env.example"

PASS_COUNT=0
FAIL_COUNT=0
RUN_RC=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# Runtime-built credential prefixes — never inlined, so this file cannot trip
# check-no-hardcoded-secrets.sh while it scans scripts/.
GHP="ghp""_"
GHPAT="github""_pat_"

# run_capture OUT ERR cmd... — captures stdout/stderr, sets RUN_RC
run_capture() {
  local out="$1" err="$2"
  shift 2
  if "$@" >"$out" 2>"$err"; then RUN_RC=0; else RUN_RC=$?; fi
}

# fixture_repo DIR — a scratch git repo with a config/ dir
fixture_repo() {
  mkdir -p "$1/config"
  git -C "$1" init -q
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== agent env template + gitignore =="

if [ -f "$ROOT/$EXAMPLE_ENV" ]; then
  ok "config/agent.local.env.example exists"
else
  bad "config/agent.local.env.example exists"
fi
# Tracked after the PR Opener commits it; before that, "trackable" is the
# pre-commit invariant: not gitignored and stageable with git add --dry-run.
if git -C "$ROOT" ls-files --error-unmatch -- "$EXAMPLE_ENV" >/dev/null 2>&1 \
   || { ! git -C "$ROOT" check-ignore -q -- "$EXAMPLE_ENV" \
        && git -C "$ROOT" add -n -- "$EXAMPLE_ENV" >/dev/null 2>&1; }; then
  ok "example is tracked (or committable pre-commit: not ignored, git add stages it)"
else
  bad "example is tracked (or committable pre-commit: not ignored, git add stages it)"
fi

placeholder_ok=1
prev_comment=0
if [ -f "$ROOT/$EXAMPLE_ENV" ]; then
  while IFS= read -r line; do
    case "$line" in
      '' | '#'*) prev_comment=1; continue ;;
    esac
    case "$line" in
      *=*)
        value="${line#*=}"
        case "$value" in
          '<'*'>') ;;
          *) placeholder_ok=0 ;;
        esac
        [ "$prev_comment" -eq 1 ] || placeholder_ok=0
        prev_comment=0
        ;;
    esac
  done < "$ROOT/$EXAMPLE_ENV"
else
  placeholder_ok=0
fi
if [ "$placeholder_ok" -eq 1 ]; then
  ok "every credential has a <...> placeholder with a comment directly above"
else
  bad "every credential has a <...> placeholder with a comment directly above"
fi

vars="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ROOT/$EXAMPLE_ENV" 2>/dev/null | sed -E 's/=.*//' || true)"
var_count="$(printf '%s\n' "$vars" | grep -c . || true)"
if [ "$var_count" -eq 2 ] && printf '%s\n' "$vars" | grep -qx 'GITHUB_TOKEN' \
   && printf '%s\n' "$vars" | grep -qx 'GH_TOKEN'; then
  ok "template enumerates exactly GITHUB_TOKEN and GH_TOKEN"
else
  bad "template enumerates exactly GITHUB_TOKEN and GH_TOKEN (got: $(printf '%s ' $vars))"
fi

# The header documents the direnv flow (spec 025): the gitignored .envrc loads
# this file via dotenv_if_exists after direnv allow; never commit the real file.
if grep -qi 'direnv' "$ROOT/$EXAMPLE_ENV" && grep -qi 'dotenv_if_exists' "$ROOT/$EXAMPLE_ENV" \
   && grep -qi 'never commit' "$ROOT/$EXAMPLE_ENV" && grep -qi 'fill' "$ROOT/$EXAMPLE_ENV"; then
  ok "header documents the direnv dotenv_if_exists flow and never-commit"
else
  bad "header documents the direnv dotenv_if_exists flow and never-commit"
fi

if git -C "$ROOT" check-ignore -q -- "$REAL_ENV"; then
  ok "git check-ignore config/agent.local.env exits 0 (file absent on disk)"
else
  bad "git check-ignore config/agent.local.env exits 0"
fi
if git -C "$ROOT" check-ignore -q -- "$EXAMPLE_ENV"; then
  bad "example is NOT ignored (template stays trackable)"
else
  ok "example is NOT ignored (template stays trackable)"
fi

echo "== guard-env =="

# staged real file in a scratch repo -> guard --staged exits 1, names path
f22="$(mktemp -d "$TMP/guard-staged.XXXXXX")"
fixture_repo "$f22"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc" > "$f22/$REAL_ENV"
git -C "$f22" add "$REAL_ENV"
run_capture "$TMP/22o" "$TMP/22e" bash "$GUARD" --staged "$f22"
if [ "$RUN_RC" -eq 1 ] && grep -q "$REAL_ENV" "$TMP/22o"; then
  ok "staged real file: guard --staged exits 1 and names config/agent.local.env"
else
  bad "staged real file: guard --staged exits 1 and names the path (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/22o"))"
fi

# tracked (committed) real file in a scratch repo -> guard exits 1, names path
f23="$(mktemp -d "$TMP/guard-tracked.XXXXXX")"
fixture_repo "$f23"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc" > "$f23/$REAL_ENV"
git -C "$f23" add "$REAL_ENV"
git -C "$f23" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/23o" "$TMP/23e" bash "$GUARD" "$f23"
if [ "$RUN_RC" -eq 1 ] && grep -q "$REAL_ENV" "$TMP/23o"; then
  ok "tracked real file: guard (CI mode) exits 1 and names config/agent.local.env"
else
  bad "tracked real file: guard (CI mode) exits 1 and names the path (rc=$RUN_RC)"
fi

# clean scratch repo -> exit 0 + PASS line in both modes
f24="$(mktemp -d "$TMP/guard-clean.XXXXXX")"
fixture_repo "$f24"
run_capture "$TMP/24a" "$TMP/24ae" bash "$GUARD" --staged "$f24"
rc_staged="$RUN_RC"
run_capture "$TMP/24b" "$TMP/24be" bash "$GUARD" "$f24"
if [ "$rc_staged" -eq 0 ] && [ "$RUN_RC" -eq 0 ] \
   && grep -q 'PASS' "$TMP/24a" && grep -q 'PASS' "$TMP/24b"; then
  ok "clean scratch repo: guard exits 0 with a PASS line in both modes"
else
  bad "clean scratch repo: guard exits 0 with a PASS line in both modes (rc=$rc_staged/$RUN_RC)"
fi

echo "== check-no-hardcoded-secrets =="

# literal token prefix under a scanned dir -> exit 1, prints file:line
f41="$(mktemp -d "$TMP/secrets-prefix.XXXXXX")"
mkdir -p "$f41/agents"
printf '%s\n' "auth with ${GHP}abc123" > "$f41/agents/bad.txt"
run_capture "$TMP/41o" "$TMP/41e" bash "$SECRETS_CHECK" "$f41"
if [ "$RUN_RC" -eq 1 ] && grep -q 'agents/bad.txt' "$TMP/41o"; then
  ok "literal token prefix: exit 1, output prints the matching file"
else
  bad "literal token prefix: exit 1, output prints the file (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/41o"))"
fi

# secret-style assignment with a literal value -> exit 1
f42="$(mktemp -d "$TMP/secrets-assign.XXXXXX")"
mkdir -p "$f42/docs"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc123" > "$f42/docs/bad.txt"
run_capture "$TMP/42o" "$TMP/42e" bash "$SECRETS_CHECK" "$f42"
if [ "$RUN_RC" -eq 1 ] && grep -q 'docs/bad.txt' "$TMP/42o"; then
  ok "secret-style assignment: exit 1, output prints the matching file"
else
  bad "secret-style assignment: exit 1, output prints the file (rc=$RUN_RC)"
fi

# placeholders and variable references do not trip the check
f43="$(mktemp -d "$TMP/secrets-clean.XXXXXX")"
mkdir -p "$f43/agents" "$f43/commands" "$f43/scripts" "$f43/docs"
printf '%s\n' \
  'GITHUB_TOKEN=<your-github-personal-access-token>' \
  'export GH_TOKEN=${GITHUB_TOKEN}' \
  'API_KEY=PLACEHOLDER' \
  'API_KEY=YOUR_KEY_HERE' > "$f43/agents/ok.txt"
run_capture "$TMP/43o" "$TMP/43e" bash "$SECRETS_CHECK" "$f43"
if [ "$RUN_RC" -eq 0 ]; then
  ok "placeholders and variable references are not flagged"
else
  bad "placeholders and variable references are not flagged (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/43o"))"
fi

# real scanned dirs must be clean (scripts/ scan includes this file)
run_capture "$TMP/43r" "$TMP/43re" bash "$SECRETS_CHECK"
if [ "$RUN_RC" -eq 0 ]; then
  ok "real scanned dirs (agents/ commands/ scripts/ docs/) are clean — the selftest itself trips nothing"
else
  bad "real scanned dirs (agents/ commands/ scripts/ docs/) are clean (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/43r"))"
fi

echo "== self-ci wiring =="

ci="$ROOT/.github/workflows/self-ci.yml"
if grep -q 'bash scripts/guard-env.sh' "$ci" \
   && grep -q 'bash scripts/check-no-hardcoded-secrets.sh' "$ci" \
   && grep -q 'bash scripts/agent-env.selftest.sh' "$ci"; then
  ok "self-ci validate job runs the guard, the secrets check, and the selftest"
else
  bad "self-ci validate job runs the guard, the secrets check, and the selftest"
fi
if awk '
  /- name: Check agent env guard and hardcoded secrets/ { f=1 }
  f { print }
  f && /- name:/ && !/Check agent env guard and hardcoded secrets/ { exit }
' "$ci" | grep -q 'continue-on-error: true'; then
  bad "no continue-on-error on the agent-env step — a regression must fail the job"
else
  ok "no continue-on-error on the agent-env step — a regression must fail the job"
fi

echo "== docs + agent cross-references (spec 025 dotenv flow) =="

# AGENTS.md documents the per-machine direnv credential flow and the guards.
if grep -qi 'per-machine agent environment' "$ROOT/AGENTS.md" \
   && grep -q 'cp config/agent.local.env.example config/agent.local.env' "$ROOT/AGENTS.md" \
   && grep -qi 'direnv allow' "$ROOT/AGENTS.md" \
   && grep -qi 'never commit' "$ROOT/AGENTS.md"; then
  ok "AGENTS.md documents copy -> fill -> never commit and the direnv .envrc flow"
else
  bad "AGENTS.md documents copy -> fill -> never commit and the direnv .envrc flow"
fi

if grep -q 'GITHUB_TOKEN' "$ROOT/AGENTS.md" && grep -q 'GH_TOKEN' "$ROOT/AGENTS.md" \
   && grep -q 'scripts/guard-env.sh' "$ROOT/AGENTS.md" \
   && grep -q 'scripts/check-no-hardcoded-secrets.sh' "$ROOT/AGENTS.md"; then
  ok "AGENTS.md names the credentials and the enforcement scripts"
else
  bad "AGENTS.md names the credentials and the enforcement scripts"
fi

# PR Opener: presence check, never literals, no env script to source.
pr_opener="$ROOT/agents/spec-pr-opener.md"
if grep -q 'GITHUB_TOKEN' "$pr_opener" \
   && grep -q 'GH_TOKEN' "$pr_opener" \
   && grep -q 'non-empty' "$pr_opener" \
   && grep -q 'dotenv_if_exists' "$pr_opener" \
   && ! grep -qE "$GHP|$GHPAT" "$pr_opener"; then
  ok "PR Opener verifies credential presence via the direnv flow and uses env vars, never literals"
else
  bad "PR Opener verifies credential presence via the direnv flow and uses env vars, never literals"
fi

# Orchestrator: the running shell is direnv-loaded; no per-agent sourcing.
pipeline="$ROOT/agents/spec-pipeline.md"
if grep -q 'dotenv_if_exists' "$pipeline" && grep -qi 'AGENTS.md' "$pipeline" \
   && ! grep -qE "$GHP|$GHPAT" "$pipeline"; then
  ok "orchestrator documents that the direnv-loaded shell already has the env loaded"
else
  bad "orchestrator documents that the direnv-loaded shell already has the env loaded"
fi

# no literal credential value in any agent or command file
if ! grep -rqE "$GHP|$GHPAT" "$ROOT/agents" "$ROOT/commands" \
   && ! grep -rqE '^(export[[:space:]]+)?[A-Z0-9_]+(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL)=[^${<"]' "$ROOT/agents" "$ROOT/commands"; then
  ok "no literal credential value in agents/ or commands/"
else
  bad "no literal credential value in agents/ or commands/"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ agent-env.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ agent-env.selftest: all cases pass.${NC}"
