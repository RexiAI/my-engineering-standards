#!/bin/bash
# check-agent-doc-duplication.selftest.sh — acceptance tests for spec 036
# (specs/036-pipeline-agent-single-source/20-acceptance/). Hermetic: fixtures
# live in mktemp -d and are removed on exit. Scenario IDs are greppable below.
#
# Usage:   bash scripts/check-agent-doc-duplication.selftest.sh
# Exit:    0 every case passes, 1 at least one failed
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-agent-doc-duplication.sh"
ORCH_CHECK="$ROOT/scripts/check-orchestration.sh"
AGENT="$ROOT/agents/spec-pipeline.md"
DOC="$ROOT/docs/SPEC_PIPELINE.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL $1"; }
check() { # check <id> <cmd...>
  local id="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$id"; else bad "$id"; fi
}

# fixture <name> <doc-content> <agent-content> → prints fixture root
fixture() {
  local d="$TMP/$1"
  mkdir -p "$d/docs" "$d/agents"
  printf '%s\n' "$2" > "$d/docs/SPEC_PIPELINE.md"
  printf '%s\n' "$3" > "$d/agents/x.md"
  echo "$d"
}
# run_check <root> → sets RC and OUT
run_check() { set +e; OUT="$(bash "$CHECK" "$1" 2>&1)"; RC=$?; set -e; }

# 20 doc lines so a duplicate can sit on doc line 20
doc_lines() { local i; for i in $(seq 1 19); do echo "filler $i"; done; echo "$1"; }

# ── AC-036-01 — trimmed orchestrator ─────────────────────────────────────────────
has() { grep -qF -- "$2" "$1"; }
check "AC-036-01-01 frontmatter byte-identical to HEAD" bash -c \
  "cmp <(awk 'NR==1||!e{print} /^---\$/&&NR>1{e=1}' '$AGENT') \
       <(git -C '$ROOT' show HEAD:agents/spec-pipeline.md | awk 'NR==1||!e{print} /^---\$/&&NR>1{e=1}')"
check "AC-036-01-02 /build stage order" bash -c \
  "tr '\n' ' ' < '$AGENT' | grep -qP 'spec-coder.*spec-refactorer.*spec-verifier.*spec-mutation-runner.*spec-pr-opener'"
check "AC-036-01-03 /spec flow" bash -c \
  "tr '\n' ' ' < '$AGENT' | grep -qP 'spec-specifier.*spec-ux' && grep -q BLOCKED '$AGENT' && grep -q SKIPPED '$AGENT' && grep -q 'human review' '$AGENT'"
check "AC-036-01-04 stop conditions" bash -c \
  "grep -q \"unless\" '$AGENT' && grep -q \"Verifier's verdict is PASS\" '$AGENT' && grep -q 'do not run the PR Opener' '$AGENT' \
   && grep -q 'cannot proceed' '$AGENT' && grep -q 'budget is exhausted' '$AGENT' && grep -q 'escalate to the human' '$AGENT' \
   && grep -q 'first hard stop' '$AGENT' && grep -q 'morning report' '$AGENT' && grep -q 'stop the queue' '$AGENT'"
check "AC-036-01-05 runtime actions" bash -c \
  "grep -q 'scripts/judgment-preflight.sh' '$AGENT' && grep -q SPEC_LOOP_COUNT '$AGENT' && grep -q SPEC_PHASE1_RETRIES '$AGENT' && grep -q SPEC_PHASE2_RETRIES '$AGENT'"
check "AC-036-01-06 never-list not restated" bash -c \
  "! grep -qE 'no force-push|no branch deletion|no gate-threshold change|no secret creation/rotation' '$AGENT' \
   && grep -qF 'docs/SPEC_PIPELINE.md §Never-list' '$AGENT'"
check "AC-036-01-07 section references, no trigger restatement" bash -c \
  "for h in 'Remediation budget' 'Never-list' 'Commit and push carve-out' 'Autopilot mode' 'Stop-and-Ask decision matrix'; do
     grep -qF \"docs/SPEC_PIPELINE.md §\$h\" '$AGENT' || exit 1; done; ! grep -q 'SPEC_AUTOPILOT=1' '$AGENT'"
check "AC-036-01-08 under 140 lines" bash -c "[ \$(wc -l < '$AGENT') -lt 140 ]"

# ── AC-036-02 — rules present in the doc ────────────────────────────────────────
check "AC-036-02-01 phase-1 and phase-2 max 3" bash -c \
  "tr '\\n' ' ' < '$DOC' | grep -qF 'Phase 1 budget is **max 3**' && tr '\\n' ' ' < '$DOC' | grep -qF 'independent of **Phase 1**'"
check "AC-036-02-02 never-list complete" bash -c \
  "s=\$(awk '/^### Never-list/{f=1;next} /^##/{f=0} f' '$DOC');
   for i in 'no merge' 'no git tag' 'no push to \`main\`/\`master\`' 'no force-push' 'no branch deletion' \
            'no gate-threshold change' 'no secret creation/rotation' 'no writes outside the target repo' \
            'no \`git init\`/submodule scaffolding'; do grep -qF -- \"\$i\" <<<\"\$s\" || exit 1; done"
check "AC-036-02-03 carve-out and autopilot trigger" bash -c \
  "grep -qF 'spec/NNN-slug' '$DOC' && grep -qF '30-report.md' '$DOC' && grep -qF 'SPEC_AUTOPILOT=1' '$DOC' && grep -qF 'token \`autopilot\`' '$DOC'"

# ── AC-036-03 — duplication check ───────────────────────────────────────────────
DUP8="Do not run stage-5 agents unless the Verifier passes"

d="$(fixture clean "$(doc_lines '### Never-list')" 'See docs/SPEC_PIPELINE.md §Never-list for refusals today.')"
run_check "$d"
if [ "$RC" -eq 0 ] && [ "$(wc -l <<<"$OUT")" -eq 1 ] && grep -q '^OK' <<<"$OUT"; then ok "AC-036-03-01 clean fixture passes"; else bad "AC-036-03-01 clean fixture passes ($RC: $OUT)"; fi

d="$(fixture dup "$(doc_lines "$DUP8")" "$(printf 'a\nb\nc\nd\n%s' "$DUP8")")"
run_check "$d"
if [ "$RC" -eq 1 ] && grep -qxF 'agents/x.md:5: duplicated from docs/SPEC_PIPELINE.md:20' <<<"$OUT"; then ok "AC-036-03-02 verbatim duplicate flagged"; else bad "AC-036-03-02 ($RC: $OUT)"; fi

d="$(fixture ws "$DUP8" '-   Do not   run stage-5 agents unless the Verifier passes')"
run_check "$d"
if [ "$RC" -eq 1 ] && grep -q 'duplicated from' <<<"$OUT"; then ok "AC-036-03-03 whitespace/list-marker normalized"; else bad "AC-036-03-03 ($RC: $OUT)"; fi

d="$(fixture seven "one two three four five six seven" "* one two three four five six seven")"
run_check "$d"
if [ "$RC" -eq 0 ]; then ok "AC-036-03-04 below threshold ignored"; else bad "AC-036-03-04 ($RC: $OUT)"; fi

d="$(fixture eight "one two three four five six seven eight" "1. one two three four five six seven eight")"
run_check "$d"
if [ "$RC" -eq 1 ]; then ok "AC-036-03-05 exactly threshold flagged"; else bad "AC-036-03-05 ($RC: $OUT)"; fi

d="$(fixture fence "$(printf '## %s\n```\n%s\n```' "$DUP8" "one two three four five six seven eight")" \
                   "$(printf '## %s\n```\n%s\n```' "$DUP8" "one two three four five six seven eight")")"
run_check "$d"
if [ "$RC" -eq 0 ]; then ok "AC-036-03-06 code blocks and headings excluded"; else bad "AC-036-03-06 ($RC: $OUT)"; fi

d="$(fixture unres "## Real" "$(printf 'a\nb\nsee "docs/SPEC_PIPELINE.md §No Such Heading"')")"
run_check "$d"
if [ "$RC" -eq 1 ] && grep -qxF 'agents/x.md:3: unresolved section reference §No Such Heading' <<<"$OUT"; then ok "AC-036-03-07 unresolved reference flagged"; else bad "AC-036-03-07 ($RC: $OUT)"; fi

d="$(fixture h3 "### Never-list" 'Refusals: `docs/SPEC_PIPELINE.md §Never-list`.')"
run_check "$d"
if [ "$RC" -eq 0 ]; then ok "AC-036-03-08 ### reference resolves"; else bad "AC-036-03-08 ($RC: $OUT)"; fi

mkdir -p "$TMP/nodoc/agents" "$TMP/noagents/docs"; echo x > "$TMP/noagents/docs/SPEC_PIPELINE.md"
rc1=0; bash "$CHECK" "$TMP/nodoc" >/dev/null 2>&1 || rc1=$?
rc2=0; bash "$CHECK" "$TMP/noagents" >/dev/null 2>&1 || rc2=$?
if [ "$rc1" -eq 2 ] && [ "$rc2" -eq 2 ]; then ok "AC-036-03-09 missing inputs exit 2"; else bad "AC-036-03-09 ($rc1/$rc2)"; fi

# unit: a reference whose heading has a parenthesised suffix resolves by longest match
d="$(fixture paren "$(printf '## Loop\n## Loop (phase 2)')" '`docs/SPEC_PIPELINE.md §Loop (phase 2)` — x')"
run_check "$d"
if [ "$RC" -eq 0 ]; then ok "unit: longest heading match"; else bad "unit: longest heading match ($RC: $OUT)"; fi
# unit: prefix of a longer word is not a match
d="$(fixture prefix "## Audit" 'see docs/SPEC_PIPELINE.md §Auditing now')"
run_check "$d"
if [ "$RC" -eq 1 ]; then ok "unit: word-boundary on heading match"; else bad "unit: word-boundary ($RC: $OUT)"; fi
# unit: too many args → usage error
rc=0; bash "$CHECK" a b >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then ok "unit: usage error exit 2"; else bad "unit: usage error ($rc)"; fi

# ── AC-036-04 — wiring ──────────────────────────────────────────────────────────
rc=0; (cd "$ROOT" && bash "$CHECK" >/dev/null 2>&1) || rc=$?
if [ "$rc" -eq 0 ]; then ok "AC-036-04-01 repo passes the new check"; else bad "AC-036-04-01 ($rc)"; fi

d="$(fixture orch "$DUP8" "$DUP8")"
rc=0; bash "$ORCH_CHECK" "$d" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then ok "AC-036-04-02 check-orchestration propagates failure"; else bad "AC-036-04-02 ($rc)"; fi

rc=0; bash "$ORCH_CHECK" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then ok "AC-036-04-03 check-orchestration green on repo"; else bad "AC-036-04-03 ($rc)"; fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
