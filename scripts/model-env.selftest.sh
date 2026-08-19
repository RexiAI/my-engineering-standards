#!/bin/bash
# model-env.selftest.sh — Hermetic regression net for load-model-env.sh and
# check-model-env.sh. No opencode binary needed; fixtures live in mktemp -d
# with trap cleanup. The runtime half is model-env.runtime-check.sh.
#
# Covers (scenario traceability: AC-020 IDs below are the tests for the
# 20-acceptance scenarios):
#   AC-020-01  real repo: opencode.json env references, no literals, valid JSON
#   AC-020-02  real repo: committed example tracked, 8 vars, comments, header
#   AC-020-03  real repo: gitignore — real file ignored, example not
#   AC-020-04  loader precedence: env > local file > example, fail-loudly
#   AC-020-05  check script branches: literal id, clean, missing/extra var,
#              tracked real file
#   AC-020-06  both scripts exist + structure, self-ci wiring
#   AC-020-07  real repo: docs describe the one-time-setup flow
#
# Self-trip constraint: every fixture model id is constructed at runtime
# (string concatenation), never inlined as a literal — so the fixtures cannot
# trip check-model-env.sh or a hardcoded-secret-style scan.
#
# Usage:
#   bash scripts/model-env.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="$ROOT/scripts/load-model-env.sh"
CHECK="$ROOT/scripts/check-model-env.sh"
RUNTIME_CHECK="$ROOT/scripts/model-env.runtime-check.sh"

# Shared roster (MODEL_ENV_VARS, MODEL_ENV_PLUS_AGENTS, model_env_var_for_agent).
# shellcheck disable=SC1091
source "$ROOT/scripts/model-env.vars.sh"

# The selftest's own copy of the var names: loader_snapshot references it AFTER
# sourcing the loader, which unsets its internal MODEL_ENV_VARS — a distinct
# name keeps the snapshot loop immune to the loader's zero-trace cleanup.
ALL_VARS=("${MODEL_ENV_VARS[@]}")

PASS_COUNT=0
FAIL_COUNT=0
RUN_RC=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# Runtime-built model ids (no inline literal model-id values anywhere below).
provider="opencode-""go"
DEFAULT_FAST="$provider/""deepseek-v4-flash"
DEFAULT_PLUS="$provider/""qwen3.7-plus"

# run_capture OUT ERR cmd... — captures stdout/stderr, sets RUN_RC
run_capture() {
  local out="$1" err="$2"
  shift 2
  if "$@" >"$out" 2>"$err"; then RUN_RC=0; else RUN_RC=$?; fi
}

# loader_snapshot ROOT [KEY=VALUE ...] — sources the loader in a subshell with
# all 8 vars unset first (optional pre-set KEY=VALUEs re-exported before), then
# prints every resolved var as VAR=value. Non-zero exit propagates.
loader_snapshot() {
  local root="$1"
  shift
  local preset=("${@+"$@"}")
  (
    local v kv
    for v in "${ALL_VARS[@]}"; do unset "$v"; done
    for kv in "${preset[@]}"; do export "$kv"; done
    # shellcheck disable=SC1090
    source "$LOADER" "$root"
    for v in "${ALL_VARS[@]}"; do printf '%s=%s\n' "$v" "${!v}"; done
  )
}

# write_refs_opencode ROOT — fixture opencode.json with 8 {env:...} references
write_refs_opencode() {
  mkdir -p "$1/config"
  cat > "$1/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "spec-specifier": { "model": "{env:SPEC_SPECIFIER_MODEL}" },
    "spec-ux": { "model": "{env:SPEC_UX_MODEL}" },
    "spec-verifier": { "model": "{env:SPEC_VERIFIER_MODEL}" },
    "spec-mutation-runner": { "model": "{env:SPEC_MUTATION_RUNNER_MODEL}" },
    "spec-pr-opener": { "model": "{env:SPEC_PR_OPENER_MODEL}" },
    "spec-coder": { "model": "{env:SPEC_CODER_MODEL}" },
    "spec-refactorer": { "model": "{env:SPEC_REFACTORER_MODEL}" },
    "spec-pipeline": { "model": "{env:SPEC_PIPELINE_MODEL}" }
  }
}
EOF
}

# write_example ROOT FAST PLUS — fixture example defining all 8 vars
write_example() {
  mkdir -p "$1/config"
  {
    printf 'SPEC_SPECIFIER_MODEL=%s\n' "$2"
    printf 'SPEC_UX_MODEL=%s\n' "$2"
    printf 'SPEC_VERIFIER_MODEL=%s\n' "$3"
    printf 'SPEC_MUTATION_RUNNER_MODEL=%s\n' "$3"
    printf 'SPEC_PR_OPENER_MODEL=%s\n' "$3"
    printf 'SPEC_CODER_MODEL=%s\n' "$2"
    printf 'SPEC_REFACTORER_MODEL=%s\n' "$2"
    printf 'SPEC_PIPELINE_MODEL=%s\n' "$2"
  } > "$1/config/model.local.env.example"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== AC-020-01 opencode.json env references =="

if python3 -m json.tool "$ROOT/opencode.json" >/dev/null 2>&1; then
  ok "AC-020-01-01 opencode.json parses as valid JSON"
else
  bad "AC-020-01-01 opencode.json parses as valid JSON"
fi
run_capture "$TMP/o" "$TMP/e" bash "$CHECK" "$ROOT"
if [ "$RUN_RC" -eq 0 ]; then
  ok "AC-020-01-01 check-model-env passes on the real repo (all 8 agents, {env:SPEC_*_MODEL} only, no literal model id)"
else
  bad "AC-020-01-01 check-model-env passes on the real repo (rc=$RUN_RC): $(tr '\n' ' ' < "$TMP/o")"
fi
# The pr-review agent (spec 024) is the one deliberate exception to "shipped
# agents ship without model:": its frontmatter carries a literal
# `model: opencode-go/kimi-k3` pin (AC-024-01-02) that must NOT be an
# {env:...} reference, and it lives in the agent file, not in opencode.json
# (which check-model-env.sh's env-reference rule governs). Every other shipped
# agent must still ship without a model: key — a second pinned agent would
# silently beat its {env:...} reference and break the per-machine override.
if grep -rqE '^model:[[:space:]]' "$ROOT/agents" --exclude='pr-review.md' 2>/dev/null; then
  bad "AC-020-01-01 every shipped agent except agents/pr-review.md ships without a model: key (agent-file model would beat the {env:...} reference)"
else
  ok "AC-020-01-01 every shipped agent except agents/pr-review.md ships without a model: key"
fi
if [ -f "$ROOT/agents/pr-review.md" ] \
   && grep -q '^model: opencode-go/kimi-k3$' "$ROOT/agents/pr-review.md"; then
  ok "AC-020-01-01 the pr-review agent carries the deliberate literal model: pin opencode-go/kimi-k3 (spec 024)"
else
  bad "AC-020-01-01 the pr-review agent must carry the literal model: pin opencode-go/kimi-k3"
fi

echo "== AC-020-02 committed example template =="

if [ -f "$ROOT/config/model.local.env.example" ]; then
  ok "AC-020-02-01 config/model.local.env.example exists"
else
  bad "AC-020-02-01 config/model.local.env.example exists"
fi
# Tracked after the PR Opener commits it; before that, "trackable" is the
# pre-commit invariant: not gitignored and stageable with git add --dry-run.
if git -C "$ROOT" ls-files --error-unmatch -- config/model.local.env.example >/dev/null 2>&1 \
   || { ! git -C "$ROOT" check-ignore -q -- config/model.local.env.example \
        && git -C "$ROOT" add -n -- config/model.local.env.example >/dev/null 2>&1; }; then
  ok "AC-020-02-01 example is tracked (or committable pre-commit: not ignored, git add stages it)"
else
  bad "AC-020-02-01 example is tracked (or committable pre-commit: not ignored, git add stages it)"
fi

example_vars="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ROOT/config/model.local.env.example" | sed -E 's/=.*//')"
example_count="$(printf '%s\n' "$example_vars" | grep -c . || true)"
if [ "$example_count" -eq 8 ] && [ "$(printf '%s\n' "$example_vars" | sort -u | wc -l | tr -d ' ')" -eq 8 ]; then
  ok "AC-020-02-02 exactly 8 unique SPEC_*_MODEL vars in example, no duplicates"
else
  bad "AC-020-02-02 exactly 8 unique SPEC_*_MODEL vars in example (got $example_count)"
fi

# The "plus"-tier vars, derived from the shared roster so the default split
# lives in one place (model-env.vars.sh).
plus_vars="$(for a in "${MODEL_ENV_PLUS_AGENTS[@]}"; do model_env_var_for_agent "$a"; done | tr '\n' ' ')"
defaults_ok=1
while IFS= read -r line; do
  v="${line%%=*}"
  val="${line#*=}"
  case " $plus_vars " in
    *" $v "*)
      [ "$val" = "$DEFAULT_PLUS" ] || defaults_ok=0 ;;
    *)
      [ "$val" = "$DEFAULT_FAST" ] || defaults_ok=0 ;;
  esac
done <<< "$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ROOT/config/model.local.env.example")"
if [ "$defaults_ok" -eq 1 ]; then
  ok "AC-020-02-02 every var's value is the current committed default"
else
  bad "AC-020-02-02 every var's value is the current committed default"
fi

if awk 'BEGIN{b=0} /^[A-Za-z_][A-Za-z0-9_]*=/ { if (prev !~ /^[[:space:]]*#/) { b=1 } } { prev=$0 } END{exit b}' "$ROOT/config/model.local.env.example"; then
  ok "AC-020-02-03 a comment line sits directly above every var"
else
  bad "AC-020-02-03 a comment line sits directly above every var"
fi

header="$ROOT/config/model.local.env.example"
if grep -q 'load-model-env.sh' "$header" && grep -q 'config/model.local.env' "$header" \
   && grep -qi 'restart' "$header" && grep -qi 'never commit' "$header" \
   && grep -qi 'shell profile' "$header"; then
  ok "AC-020-02-04 header documents profile wiring, optional copy, restart, never commit"
else
  bad "AC-020-02-04 header documents profile wiring, optional copy, restart, never commit"
fi

echo "== AC-020-03 gitignore =="

if git -C "$ROOT" check-ignore -q -- config/model.local.env; then
  ok "AC-020-03-01 git check-ignore config/model.local.env exits 0 (file absent on disk)"
else
  bad "AC-020-03-01 git check-ignore config/model.local.env exits 0"
fi
if git -C "$ROOT" check-ignore -q -- config/model.local.env.example; then
  bad "AC-020-03-02 git check-ignore config/model.local.env.example is non-zero (example not ignored)"
else
  ok "AC-020-03-02 git check-ignore config/model.local.env.example is non-zero (example stays trackable)"
fi

echo "== AC-020-04 / AC-020-06-02 loader precedence (fixtures) =="

f4a="$(mktemp -d "$TMP/loader-a.XXXXXX")"
write_example "$f4a" "$DEFAULT_FAST" "$DEFAULT_PLUS"
snap="$(loader_snapshot "$f4a")"
if [ $? -eq 0 ] && printf '%s\n' "$snap" | grep -qx "SPEC_SPECIFIER_MODEL=$DEFAULT_FAST" \
   && printf '%s\n' "$snap" | grep -qx "SPEC_VERIFIER_MODEL=$DEFAULT_PLUS" \
   && [ "$(printf '%s\n' "$snap" | grep -c .)" -eq 8 ]; then
  ok "AC-020-04-01 no local file: all 8 vars exported to example defaults, exit 0"
else
  bad "AC-020-04-01 no local file: all 8 vars exported to example defaults, exit 0"
fi

f4b="$(mktemp -d "$TMP/loader-b.XXXXXX")"
write_example "$f4b" "$DEFAULT_FAST" "$DEFAULT_PLUS"
local_custom="$provider/""custom""$RANDOM"
local_other="$provider/""other""$RANDOM"
printf 'SPEC_SPECIFIER_MODEL=%s\nSPEC_UX_MODEL=%s\n' "$local_custom" "$local_other" > "$f4b/config/model.local.env"
snap="$(loader_snapshot "$f4b")"
if printf '%s\n' "$snap" | grep -qx "SPEC_SPECIFIER_MODEL=$local_custom" \
   && printf '%s\n' "$snap" | grep -qx "SPEC_UX_MODEL=$local_other" \
   && printf '%s\n' "$snap" | grep -qx "SPEC_VERIFIER_MODEL=$DEFAULT_PLUS" \
   && [ "$(printf '%s\n' "$snap" | grep -c .)" -eq 8 ]; then
  ok "AC-020-04-02 partial local file: defined vars override, missing vars fall back to example defaults"
else
  bad "AC-020-04-02 partial local file: defined vars override, missing vars fall back to example defaults"
fi

f4c="$(mktemp -d "$TMP/loader-c.XXXXXX")"
write_example "$f4c" "$DEFAULT_FAST" "$DEFAULT_PLUS"
process_win="$provider/""process-env-win""$RANDOM"
printf 'SPEC_SPECIFIER_MODEL=%s\n' "$provider/""file-value""$RANDOM" > "$f4c/config/model.local.env"
snap="$(loader_snapshot "$f4c" "SPEC_SPECIFIER_MODEL=$process_win")"
if printf '%s\n' "$snap" | grep -qx "SPEC_SPECIFIER_MODEL=$process_win"; then
  ok "AC-020-04-03 pre-existing exported var is never clobbered (process env wins over local file)"
else
  bad "AC-020-04-03 pre-existing exported var is never clobbered (process env wins over local file)"
fi

f4d="$(mktemp -d "$TMP/loader-d.XXXXXX")"
run_capture "$TMP/dout" "$TMP/derr" loader_snapshot "$f4d"
if [ "$RUN_RC" -eq 1 ] && grep -qE 'SPEC_[A-Z_]+_MODEL' "$TMP/derr"; then
  ok "AC-020-04-04 var resolvable from no source: exit 1, stderr names the var"
else
  bad "AC-020-04-04 var resolvable from no source: exit 1, stderr names the var (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/derr"))"
fi

# AC-020-04-05 / AC-020-06-02: cwd independence — run from a foreign cwd with
# no positional arg; the loader derives the repo root from its own location.
( cd "$TMP" && unset "${MODEL_ENV_VARS[@]}" && source "$LOADER" && rc=$? && \
  [ "$rc" -eq 0 ] && [ -n "${SPEC_SPECIFIER_MODEL:-}" ] && [ -n "${SPEC_PIPELINE_MODEL:-}" ] ) \
  && ok "AC-020-04-05 runs from any cwd without a positional arg, non-interactively, defaults to repo root" \
  || bad "AC-020-04-05 runs from any cwd without a positional arg, non-interactively, defaults to repo root"

echo "== AC-020-05 / AC-020-06-03 check script branches (fixtures) =="

f5a="$(mktemp -d "$TMP/check-a.XXXXXX")"
bad_model="$provider/""literal-model""$RANDOM"
mkdir -p "$f5a/config"
cat > "$f5a/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "agent": {
    "spec-coder": { "model": "$bad_model" }
  }
}
EOF
run_capture "$TMP/aout" "$TMP/aerr" bash "$CHECK" "$f5a"
if [ "$RUN_RC" -eq 1 ] && grep -q 'spec-coder' "$TMP/aout"; then
  ok "AC-020-05-01 literal model id in opencode.json: exit 1, output names the offending agent (spec-coder)"
else
  bad "AC-020-05-01 literal model id in opencode.json: exit 1, output names spec-coder (rc=$RUN_RC)"
fi

f5b="$(mktemp -d "$TMP/check-b.XXXXXX")"
write_refs_opencode "$f5b"
write_example "$f5b" "$DEFAULT_FAST" "$DEFAULT_PLUS"
git -C "$f5b" init -q
git -C "$f5b" add opencode.json config/model.local.env.example
git -C "$f5b" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/bout" "$TMP/berr" bash "$CHECK" "$f5b"
if [ "$RUN_RC" -eq 0 ] && grep -q 'PASS' "$TMP/bout"; then
  ok "AC-020-05-02 all env references + example wired + no tracked real file: exit 0 with PASS line"
else
  bad "AC-020-05-02 all env references + example wired + no tracked real file: exit 0 with PASS line (rc=$RUN_RC)"
fi

f5c="$(mktemp -d "$TMP/check-c.XXXXXX")"
write_refs_opencode "$f5c"
write_example "$f5c" "$DEFAULT_FAST" "$DEFAULT_PLUS"
printf 'SPEC_CODER_MODEL=%s\n' "$provider/""tracked""$RANDOM" > "$f5c/config/model.local.env"
git -C "$f5c" init -q
git -C "$f5c" add opencode.json config/model.local.env.example config/model.local.env
git -C "$f5c" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/cout" "$TMP/cerr" bash "$CHECK" "$f5c"
if [ "$RUN_RC" -eq 1 ] && grep -q 'config/model.local.env' "$TMP/cout"; then
  ok "AC-020-05-03 tracked real env file: exit 1, output names the offending path"
else
  bad "AC-020-05-03 tracked real env file: exit 1, output names the offending path (rc=$RUN_RC)"
fi

f5d="$(mktemp -d "$TMP/check-d.XXXXXX")"
write_refs_opencode "$f5d"
write_example "$f5d" "$DEFAULT_FAST" "$DEFAULT_PLUS"
grep -v '^SPEC_CODER_MODEL=' "$f5d/config/model.local.env.example" > "$f5d/config/model.local.env.example.tmp"
mv "$f5d/config/model.local.env.example.tmp" "$f5d/config/model.local.env.example"
run_capture "$TMP/dout" "$TMP/derr" bash "$CHECK" "$f5d"
if [ "$RUN_RC" -eq 1 ] && grep -q 'SPEC_CODER_MODEL' "$TMP/dout"; then
  ok "AC-020-05-04 reference with no example default: exit 1, output names SPEC_CODER_MODEL"
else
  bad "AC-020-05-04 reference with no example default: exit 1, output names SPEC_CODER_MODEL (rc=$RUN_RC)"
fi

f5e="$(mktemp -d "$TMP/check-e.XXXXXX")"
write_refs_opencode "$f5e"
write_example "$f5e" "$DEFAULT_FAST" "$DEFAULT_PLUS"
printf 'SPEC_UNUSED_MODEL=%s\n' "$provider/""unused""$RANDOM" >> "$f5e/config/model.local.env.example"
run_capture "$TMP/eout" "$TMP/eerr" bash "$CHECK" "$f5e"
if [ "$RUN_RC" -eq 1 ] && grep -q 'SPEC_UNUSED_MODEL' "$TMP/eout"; then
  ok "AC-020-05-05 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL"
else
  bad "AC-020-05-05 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL (rc=$RUN_RC)"
fi

echo "== AC-020-06 scripts + self-ci wiring =="

for script in "$LOADER" "$CHECK" "$RUNTIME_CHECK"; do
  if [ -f "$script" ] && [ "$(head -1 "$script")" = '#!/bin/bash' ] \
     && grep -q 'set -euo pipefail' "$script"; then
    ok "AC-020-06-01 $(basename "$script") exists, bash, set -euo pipefail"
  else
    bad "AC-020-06-01 $(basename "$script") exists, bash, set -euo pipefail"
  fi
done
for script in "$RUNTIME_CHECK"; do
  if grep -q 'mktemp -d' "$script" && grep -q 'trap ' "$script"; then
    ok "AC-020-06-01 $(basename "$script") builds fixtures in mktemp -d with trap cleanup"
  else
    bad "AC-020-06-01 $(basename "$script") builds fixtures in mktemp -d with trap cleanup"
  fi
done

ci="$ROOT/.github/workflows/self-ci.yml"
if grep -q 'https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz' "$ci" \
   && grep -q 'bash scripts/check-model-env.sh' "$ci" \
   && grep -q 'bash scripts/model-env.selftest.sh' "$ci" \
   && grep -q 'bash scripts/model-env.runtime-check.sh' "$ci"; then
  ok "AC-020-06-05 self-ci validate job downloads the pinned opencode tarball and runs all three scripts"
else
  bad "AC-020-06-05 self-ci validate job downloads the pinned opencode tarball and runs all three scripts"
fi
if awk '
  /- name: Install pinned opencode/ { f=1 }
  f { print }
  f && /- name:/ && !/Install pinned opencode/ { exit }
' "$ci" | grep -q 'continue-on-error: true'; then
  bad "AC-020-06-05 no continue-on-error on the model-env step — a regression must fail the job"
else
  ok "AC-020-06-05 no continue-on-error on the model-env step — a regression must fail the job"
fi

echo "== AC-020-07 docs describe the one-time-setup flow =="

pipe="$ROOT/docs/SPEC_PIPELINE.md"
if grep -q 'load-model-env.sh' "$pipe" && grep -q 'config/model.local.env' "$pipe" \
   && grep -qi 'restart' "$pipe" && grep -qi 'no commit' "$pipe" \
   && grep -q 'check-model-env.sh' "$pipe" && grep -q 'pinned' "$pipe"; then
  ok "AC-020-07-01 SPEC_PIPELINE.md documents profile wiring, copy→fill→restart, no commit, precedence, enforcement"
else
  bad "AC-020-07-01 SPEC_PIPELINE.md documents profile wiring, copy→fill→restart, no commit, precedence, enforcement"
fi

if grep -q 'config/model.local.env' "$ROOT/AGENTS.md" && grep -q 'load-model-env.sh' "$ROOT/AGENTS.md" \
   && grep -qi 'restart' "$ROOT/AGENTS.md"; then
  ok "AC-020-07-02 AGENTS.md model table points at config/model.local.env via load-model-env.sh, restart not commit"
else
  bad "AC-020-07-02 AGENTS.md model table points at config/model.local.env via load-model-env.sh, restart not commit"
fi

if grep -q 'check-model-env.sh' "$pipe" && grep -q 'runtime-check' "$pipe"; then
  ok "AC-020-07-03 SPEC_PIPELINE.md cites check-model-env.sh and the self-ci pinned-binary runtime check"
else
  bad "AC-020-07-03 SPEC_PIPELINE.md cites check-model-env.sh and the self-ci pinned-binary runtime check"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ model-env.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ model-env.selftest: all cases pass.${NC}"
