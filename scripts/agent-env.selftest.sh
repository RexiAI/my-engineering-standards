#!/bin/bash
# agent-env.selftest.sh — Hermetic regression net for the per-machine agent
# environment (spec 013): scripts/load-env.sh, scripts/guard-env.sh,
# and scripts/check-no-hardcoded-secrets.sh. Fixtures live in mktemp -d with
# trap cleanup; nothing here touches the real repo's config or git state.
#
# Covers (scenario traceability: the AC-013 IDs below are the tests for the
# 20-acceptance scenarios):
#   AC-013-01  committed config/agent.local.env.example template (placeholder +
#              comment per credential, exactly GITHUB_TOKEN + GH_TOKEN, header
#              states copy-fill-never-commit)
#   AC-013-02  real file gitignored; guard refuses a staged/tracked real file
#              (scratch repos); clean repo passes; self-ci wiring
#   AC-013-03  load-env.sh sources + exports; fails loudly when example present;
#              quiet no-op when both missing; never clobbers pre-set vars
#   AC-013-04  check-no-hardcoded-secrets.sh over agents/ commands/ scripts/
#              docs/ (fixture violations exit 1, clean dirs exit 0), self-ci wiring
#   AC-013-05  AGENTS.md documents the per-machine setup (copy/fill/never
#              commit, source load-env.sh, credentials, enforcement)
#   AC-013-06  agents read credentials via the loader, never literals (PR Opener
#              sources load-env.sh, orchestrator relies on the loaded shell)
#
# Self-trip constraint (Task 5): this file lives under scripts/, which is in
# the hardcoded-secrets scan scope. Every fixture credential is constructed at
# runtime by string concatenation — the source of this file never contains a
# string that literally matches the check's patterns.
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
LOADER="$ROOT/scripts/load-env.sh"
# (PowerShell twin removed — spec 013 no longer supports PowerShell)
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

# env_snapshot ROOT [KEY=VALUE ...] — sources the loader in a subshell with
# optional pre-set exports, then prints the loader-managed vars as VAR=value.
# The loader's exit status is propagated explicitly: errexit is suspended for
# functions invoked from an if-condition, so a non-zero source must be carried
# out by hand.
env_snapshot() {
  local root="$1"
  shift
  local preset=("${@+"$@"}")
  (
    local kv rc
    for kv in "${preset[@]}"; do export "$kv"; done
    # shellcheck disable=SC1090
    source "$LOADER" "$root"
    rc=$?
    printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:-}"
    printf 'GH_TOKEN=%s\n' "${GH_TOKEN:-}"
    printf 'EXTRA_VAR=%s\n' "${EXTRA_VAR:-}"
    exit "$rc"
  )
}

# fixture_repo DIR — a scratch git repo with a config/ dir
fixture_repo() {
  mkdir -p "$1/config"
  git -C "$1" init -q
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== AC-013-01 committed agent.local.env.example template =="

if [ -f "$ROOT/$EXAMPLE_ENV" ]; then
  ok "AC-013-01-01 config/agent.local.env.example exists"
else
  bad "AC-013-01-01 config/agent.local.env.example exists"
fi
# Tracked after the PR Opener commits it; before that, "trackable" is the
# pre-commit invariant: not gitignored and stageable with git add --dry-run.
if git -C "$ROOT" ls-files --error-unmatch -- "$EXAMPLE_ENV" >/dev/null 2>&1 \
   || { ! git -C "$ROOT" check-ignore -q -- "$EXAMPLE_ENV" \
        && git -C "$ROOT" add -n -- "$EXAMPLE_ENV" >/dev/null 2>&1; }; then
  ok "AC-013-01-01 example is tracked (or committable pre-commit: not ignored, git add stages it)"
else
  bad "AC-013-01-01 example is tracked (or committable pre-commit: not ignored, git add stages it)"
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
  ok "AC-013-01-02 every credential has a <...> placeholder with a comment directly above"
else
  bad "AC-013-01-02 every credential has a <...> placeholder with a comment directly above"
fi

vars="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ROOT/$EXAMPLE_ENV" 2>/dev/null | sed -E 's/=.*//' || true)"
var_count="$(printf '%s\n' "$vars" | grep -c . || true)"
if [ "$var_count" -eq 2 ] && printf '%s\n' "$vars" | grep -qx 'GITHUB_TOKEN' \
   && printf '%s\n' "$vars" | grep -qx 'GH_TOKEN'; then
  ok "AC-013-01-03 template enumerates exactly GITHUB_TOKEN and GH_TOKEN"
else
  bad "AC-013-01-03 template enumerates exactly GITHUB_TOKEN and GH_TOKEN (got: $(printf '%s ' $vars))"
fi
if grep -qiE 'Jira|Confluence|Jenkins|Bitbucket|kubeconfig' "$ROOT/$EXAMPLE_ENV"; then
  bad "AC-013-01-03 no Jira/Confluence/Jenkins/Bitbucket/kubeconfig credentials referenced"
else
  ok "AC-013-01-03 no Jira/Confluence/Jenkins/Bitbucket/kubeconfig credentials referenced"
fi

if grep -q "$EXAMPLE_ENV" "$ROOT/$EXAMPLE_ENV" && grep -qi 'copy' "$ROOT/$EXAMPLE_ENV" \
   && grep -qi 'never commit' "$ROOT/$EXAMPLE_ENV" && grep -qi 'fill' "$ROOT/$EXAMPLE_ENV"; then
  ok "AC-013-01-04 header documents copy -> fill -> never commit"
else
  bad "AC-013-01-04 header documents copy -> fill -> never commit"
fi

echo "== AC-013-02 gitignore + guard =="

if git -C "$ROOT" check-ignore -q -- "$REAL_ENV"; then
  ok "AC-013-02-01 git check-ignore config/agent.local.env exits 0 (file absent on disk)"
else
  bad "AC-013-02-01 git check-ignore config/agent.local.env exits 0"
fi
if git -C "$ROOT" check-ignore -q -- "$EXAMPLE_ENV"; then
  bad "AC-013-02-01 example is NOT ignored (template stays trackable)"
else
  ok "AC-013-02-01 example is NOT ignored (template stays trackable)"
fi

# 02-02: staged real file in a scratch repo -> guard --staged exits 1, names path
f22="$(mktemp -d "$TMP/guard-staged.XXXXXX")"
fixture_repo "$f22"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc" > "$f22/$REAL_ENV"
git -C "$f22" add "$REAL_ENV"
run_capture "$TMP/22o" "$TMP/22e" bash "$GUARD" --staged "$f22"
if [ "$RUN_RC" -eq 1 ] && grep -q "$REAL_ENV" "$TMP/22o"; then
  ok "AC-013-02-02 staged real file: guard --staged exits 1 and names config/agent.local.env"
else
  bad "AC-013-02-02 staged real file: guard --staged exits 1 and names the path (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/22o"))"
fi

# 02-03: tracked (committed) real file in a scratch repo -> guard exits 1, names path
f23="$(mktemp -d "$TMP/guard-tracked.XXXXXX")"
fixture_repo "$f23"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc" > "$f23/$REAL_ENV"
git -C "$f23" add "$REAL_ENV"
git -C "$f23" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/23o" "$TMP/23e" bash "$GUARD" "$f23"
if [ "$RUN_RC" -eq 1 ] && grep -q "$REAL_ENV" "$TMP/23o"; then
  ok "AC-013-02-03 tracked real file: guard (CI mode) exits 1 and names config/agent.local.env"
else
  bad "AC-013-02-03 tracked real file: guard (CI mode) exits 1 and names the path (rc=$RUN_RC)"
fi

# 02-04: clean scratch repo -> exit 0 + PASS line in both modes
f24="$(mktemp -d "$TMP/guard-clean.XXXXXX")"
fixture_repo "$f24"
run_capture "$TMP/24a" "$TMP/24ae" bash "$GUARD" --staged "$f24"
rc_staged="$RUN_RC"
run_capture "$TMP/24b" "$TMP/24be" bash "$GUARD" "$f24"
if [ "$rc_staged" -eq 0 ] && [ "$RUN_RC" -eq 0 ] \
   && grep -q 'PASS' "$TMP/24a" && grep -q 'PASS' "$TMP/24b"; then
  ok "AC-013-02-04 clean scratch repo: guard exits 0 with a PASS line in both modes"
else
  bad "AC-013-02-04 clean scratch repo: guard exits 0 with a PASS line in both modes (rc=$rc_staged/$RUN_RC)"
fi

# 02-05 / 04-04: self-ci wiring — one step runs the guard + check + selftest,
# no continue-on-error so a regression fails the job
ci="$ROOT/.github/workflows/self-ci.yml"
if grep -q 'bash scripts/guard-env.sh' "$ci" \
   && grep -q 'bash scripts/check-no-hardcoded-secrets.sh' "$ci" \
   && grep -q 'bash scripts/agent-env.selftest.sh' "$ci"; then
  ok "AC-013-02-05 self-ci validate job runs the guard, the secrets check, and the selftest"
else
  bad "AC-013-02-05 self-ci validate job runs the guard, the secrets check, and the selftest"
fi
if awk '
  /- name: Check agent env guard and hardcoded secrets/ { f=1 }
  f { print }
  f && /- name:/ && !/Check agent env guard and hardcoded secrets/ { exit }
' "$ci" | grep -q 'continue-on-error: true'; then
  bad "AC-013-02-05 no continue-on-error on the agent-env step — a regression must fail the job"
else
  ok "AC-013-02-05 no continue-on-error on the agent-env step — a regression must fail the job"
fi

echo "== AC-013-03 load-env.sh loader =="

# 03-01: example present, real missing -> exit 1, stderr names path + copy step
f31="$(mktemp -d "$TMP/loader-example.XXXXXX")"
mkdir -p "$f31/config"
printf 'GITHUB_TOKEN=%s\nGH_TOKEN=%s\n' '<your-github-personal-access-token>' '<your-github-personal-access-token>' > "$f31/$EXAMPLE_ENV"
run_capture "$TMP/31o" "$TMP/31e" env_snapshot "$f31"
if [ "$RUN_RC" -eq 1 ] && grep -q "$REAL_ENV" "$TMP/31e" \
   && grep -q 'cp config/agent.local.env.example config/agent.local.env' "$TMP/31e"; then
  ok "AC-013-03-01 example-only: exit 1, stderr names the missing file and the copy-fill step"
else
  bad "AC-013-03-01 example-only: exit 1, stderr names the missing file and the copy step (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/31e"))"
fi

# 03-02: real file present -> every variable exported with the file's value
f32="$(mktemp -d "$TMP/loader-real.XXXXXX")"
mkdir -p "$f32/config"
val1="rt-""$RANDOM"
val2="rt-""$RANDOM"
printf 'GITHUB_TOKEN=%s\nGH_TOKEN=%s\nEXTRA_VAR=hello\n' "$val1" "$val2" > "$f32/$REAL_ENV"
snap="$(env_snapshot "$f32")"
if printf '%s\n' "$snap" | grep -qx "GITHUB_TOKEN=$val1" \
   && printf '%s\n' "$snap" | grep -qx "GH_TOKEN=$val2" \
   && printf '%s\n' "$snap" | grep -qx 'EXTRA_VAR=hello'; then
  ok "AC-013-03-02 real file present: every variable is exported with the file's value"
else
  bad "AC-013-03-02 real file present: every variable is exported (got: $(printf '%s ' $snap))"
fi

# 03-03: both missing -> exit 0, nothing on stderr
f33="$(mktemp -d "$TMP/loader-none.XXXXXX")"
run_capture "$TMP/33o" "$TMP/33e" env_snapshot "$f33"
if [ "$RUN_RC" -eq 0 ] && [ ! -s "$TMP/33e" ]; then
  ok "AC-013-03-03 both files missing: exit 0, nothing on stderr"
else
  bad "AC-013-03-03 both files missing: exit 0, nothing on stderr (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/33e"))"
fi

# 03-04: pre-set exported var is never clobbered
f34="$(mktemp -d "$TMP/loader-noclobber.XXXXXX")"
mkdir -p "$f34/config"
printf 'GITHUB_TOKEN=%s\n' "file-value""$RANDOM" > "$f34/$REAL_ENV"
snap="$(env_snapshot "$f34" "GITHUB_TOKEN=already-set")"
if printf '%s\n' "$snap" | grep -qx 'GITHUB_TOKEN=already-set'; then
  ok "AC-013-03-04 pre-existing exported GITHUB_TOKEN wins over the file value"
else
  bad "AC-013-03-04 pre-existing exported GITHUB_TOKEN wins over the file value (got: $(printf '%s ' $snap))"
fi

echo "== AC-013-04 check-no-hardcoded-secrets =="

# 04-01: literal token prefix under a scanned dir -> exit 1, prints file:line
f41="$(mktemp -d "$TMP/secrets-prefix.XXXXXX")"
mkdir -p "$f41/agents"
printf '%s\n' "auth with ${GHP}abc123" > "$f41/agents/bad.txt"
run_capture "$TMP/41o" "$TMP/41e" bash "$SECRETS_CHECK" "$f41"
if [ "$RUN_RC" -eq 1 ] && grep -q 'agents/bad.txt' "$TMP/41o"; then
  ok "AC-013-04-01 literal token prefix: exit 1, output prints the matching file"
else
  bad "AC-013-04-01 literal token prefix: exit 1, output prints the file (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/41o"))"
fi

# 04-02: secret-style assignment with a literal value -> exit 1
f42="$(mktemp -d "$TMP/secrets-assign.XXXXXX")"
mkdir -p "$f42/docs"
printf 'GITHUB_TOKEN=%s\n' "${GHP}abc123" > "$f42/docs/bad.txt"
run_capture "$TMP/42o" "$TMP/42e" bash "$SECRETS_CHECK" "$f42"
if [ "$RUN_RC" -eq 1 ] && grep -q 'docs/bad.txt' "$TMP/42o"; then
  ok "AC-013-04-02 secret-style assignment: exit 1, output prints the matching file"
else
  bad "AC-013-04-02 secret-style assignment: exit 1, output prints the file (rc=$RUN_RC)"
fi

# 04-03: placeholders and variable references do not trip the check
f43="$(mktemp -d "$TMP/secrets-clean.XXXXXX")"
mkdir -p "$f43/agents" "$f43/commands" "$f43/scripts" "$f43/docs"
printf '%s\n' \
  'GITHUB_TOKEN=<your-github-personal-access-token>' \
  'export GH_TOKEN=${GITHUB_TOKEN}' \
  'API_KEY=PLACEHOLDER' \
  'API_KEY=YOUR_KEY_HERE' > "$f43/agents/ok.txt"
run_capture "$TMP/43o" "$TMP/43e" bash "$SECRETS_CHECK" "$f43"
if [ "$RUN_RC" -eq 0 ]; then
  ok "AC-013-04-03 placeholders and variable references are not flagged"
else
  bad "AC-013-04-03 placeholders and variable references are not flagged (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/43o"))"
fi

# 04-04: real scanned dirs must be clean (scripts/ scan includes this file)
run_capture "$TMP/43r" "$TMP/43re" bash "$SECRETS_CHECK"
if [ "$RUN_RC" -eq 0 ]; then
  ok "AC-013-04-04 real scanned dirs (agents/ commands/ scripts/ docs/) are clean — the selftest itself trips nothing"
else
  bad "AC-013-04-04 real scanned dirs (agents/ commands/ scripts/ docs/) are clean (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/43r"))"
fi

# 04-05: the check runs in self-ci without continue-on-error (asserted by the
# AC-013-02-05 wiring check above, which covers this scenario's step)
if grep -q 'bash scripts/check-no-hardcoded-secrets.sh' "$ci"; then
  ok "AC-013-04-05 the secrets check runs in the self-ci validate job"
else
  bad "AC-013-04-05 the secrets check runs in the self-ci validate job"
fi

echo "== AC-013-05 per-machine setup documented =="

if grep -qi 'per-machine agent environment' "$ROOT/AGENTS.md" \
   && grep -q 'cp config/agent.local.env.example config/agent.local.env' "$ROOT/AGENTS.md" \
   && grep -q 'scripts/load-env.sh' "$ROOT/AGENTS.md" \
   && grep -qi 'never commit' "$ROOT/AGENTS.md"; then
  ok "AC-013-05-01 AGENTS.md documents copy -> fill -> never commit and sourcing load-env.sh"
else
  bad "AC-013-05-01 AGENTS.md documents copy -> fill -> never commit and sourcing load-env.sh"
fi

if grep -q 'GITHUB_TOKEN' "$ROOT/AGENTS.md" && grep -q 'GH_TOKEN' "$ROOT/AGENTS.md" \
   && grep -q 'scripts/guard-env.sh' "$ROOT/AGENTS.md" \
   && grep -q 'scripts/check-no-hardcoded-secrets.sh' "$ROOT/AGENTS.md"; then
  ok "AC-013-05-02 AGENTS.md names the credentials and the enforcement scripts"
else
  bad "AC-013-05-02 AGENTS.md names the credentials and the enforcement scripts"
fi

echo "== AC-013-06 agent cross-references =="

pr_opener="$ROOT/agents/spec-pr-opener.md"
if grep -q 'scripts/load-env.sh' "$pr_opener" \
   && grep -qE '\$(GITHUB_TOKEN|GH_TOKEN)' "$pr_opener" \
   && ! grep -qE "$GHP|$GHPAT" "$pr_opener"; then
  ok "AC-013-06-01 PR Opener sources the loader and uses env vars, never literals"
else
  bad "AC-013-06-01 PR Opener sources the loader and uses env vars, never literals"
fi

pipeline="$ROOT/agents/spec-pipeline.md"
if grep -q 'load-env.sh' "$pipeline" && grep -qi 'AGENTS.md' "$pipeline"; then
  ok "AC-013-06-02 orchestrator documents that the running shell already has the env loaded"
else
  bad "AC-013-06-02 orchestrator documents that the running shell already has the env loaded"
fi

# 06-03: no literal credential value in any agent or command file (agents/ and
# commands/ are in the AC-013-04 scan scope; assert them directly too)
if ! grep -rqE "$GHP|$GHPAT" "$ROOT/agents" "$ROOT/commands" \
   && ! grep -rqE '^(export[[:space:]]+)?[A-Z0-9_]+(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL)=[^${<"]' "$ROOT/agents" "$ROOT/commands"; then
  ok "AC-013-06-03 no literal credential value in agents/ or commands/"
else
  bad "AC-013-06-03 no literal credential value in agents/ or commands/"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ agent-env.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ agent-env.selftest: all cases pass.${NC}"
