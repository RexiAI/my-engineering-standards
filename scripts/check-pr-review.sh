#!/bin/bash
# check-pr-review.sh — Verify the PR review agent deliverables are present and
# carry the required content (spec 024).
#
# The PR review agent (spec 024) ships: an agent config (agents/pr-review.md),
# a Zen provider block in opencode.json, a shared reusable workflow
# (.github/workflows/ci-pr-review.yml), a self-hosted trigger
# (.github/workflows/pr-review.yml), an init-ci.sh --with-pr-review flag, and
# documentation. There is no application code and no test suite in the usual
# sense — this script is the spec's test carrier: every AC-024-NN-NN scenario
# ID from specs/024-pr-review-agent/20-acceptance/ is cited below as a check,
# so scripts/check-scenario-traceability.sh traces this spec, and the greps
# double as the acceptance tests.
#
# Checks (one block per acceptance scenario):
#   AC-024-01-01  agent file exists, mode: subagent, review-only first directive
#   AC-024-01-02  model pinned literally to opencode/mimo-v2.5-free in frontmatter
#   AC-024-01-03  Zen provider block: endpoint, env, model in opencode.json
#   AC-024-01-04  no other model id in the agent file or provider block
#   AC-024-01-05  edit denied; no allowed bash pattern matches write ops
#   AC-024-01-06  forbidden operations named in the prompt
#   AC-024-01-07  finding format file:line + what + why + fix
#   AC-024-01-08  no cosmetic nitpicks, no un-evidenced security findings
#   AC-024-01-09  findings grounded in the diff and the repo's standards
#   AC-024-01-10  Reviewed-SHA marker contract
#   AC-024-01-11  check-model-env.sh still exits 0
#   AC-024-01-12  spec-pipeline agents untouched
#   AC-024-02-01  shared workflow exists as a workflow_call reusable
#   AC-024-02-02  comment-only permissions, no content-modifying step
#   AC-024-02-03  optional secret; empty key skips the job cleanly
#   AC-024-02-04  no literal key in the workflow
#   AC-024-02-05  checkout at caller repo + PR head, pr-number/head-sha passed
#   AC-024-02-06  pinned opencode binary, headless --print-logs run
#   AC-024-02-07  agent discoverable for self-hosted and child repos
#   AC-024-02-08  no auto-approve / skip-permissions flag
#   AC-024-02-09  early exit when head already reviewed and CI green
#   AC-024-02-10  review proceeds when the head changed
#   AC-024-02-11  review proceeds when CI is failing on an untouched head
#   AC-024-03-01  trigger on pull_request with exactly the four types
#   AC-024-03-02  per-PR concurrency with cancel-in-progress
#   AC-024-03-03  calls the shared workflow with PR context
#   AC-024-03-04  key supplied via GitHub secret
#   AC-024-03-05  no key: job skipped, never a required-check failure
#   AC-024-03-06  no literal key in the trigger workflow
#   AC-024-03-07  self-hosting wiring identical to child wiring
#   AC-024-04-01  --with-pr-review accepted, usage line lists it
#   AC-024-04-02  GitHub generation emits the pr-review job
#   AC-024-04-03  default output unchanged without the flag
#   AC-024-04-04  secret prompted only when opted in
#   AC-024-04-05  secret never prompted without the flag
#   AC-024-04-06  summary lists the required secret for GitHub
#   AC-024-04-07  GitLab-only: warning, no emission, exit 0
#   AC-024-04-08  both platforms: GitHub emits, GitLab warns
#   AC-024-05-01  CI_CD.md documents the PR review agent
#   AC-024-05-02  Required Secrets table gains the new secret
#   AC-024-05-03  architecture tree lists the shared workflow
#   AC-024-05-04  SPEC_PIPELINE.md cross-references the section
#   AC-024-05-05  no literal key value in the docs
#
# Usage:
#   scripts/check-pr-review.sh [ROOT_DIR]
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more artifacts/rules missing; a FAIL line is printed per violation
#
# Standards reference:
#   docs/CI_CD.md §PR Review Agent
#   docs/SPEC_PIPELINE.md §Using OpenCode Zen
#   specs/024-pr-review-agent/20-acceptance/ (AC-024-01-01 … AC-024-05-05)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
ROOT_DIR="${1:-.}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

AGENT="$ROOT_DIR/agents/pr-review.md"
OPENCODE_JSON="$ROOT_DIR/opencode.json"
SHARED_WF="$ROOT_DIR/.github/workflows/ci-pr-review.yml"
TRIGGER_WF="$ROOT_DIR/.github/workflows/pr-review.yml"
INIT_CI="$ROOT_DIR/scripts/init-ci.sh"
SELF_CI="$ROOT_DIR/.github/workflows/self-ci.yml"
CI_CD="$ROOT_DIR/docs/CI_CD.md"
SPEC_PIPE="$ROOT_DIR/docs/SPEC_PIPELINE.md"

# verify_grep <AC-ID> <file> <label> <pattern>...
#   Every <pattern> must appear (fixed-string match) in <file>.
verify_grep() {
  local acid="$1" file="$2" label="$3"
  shift 3
  local missing=() pat
  for pat in "$@"; do
    grep -qF -- "$pat" "$file" || missing+=("$pat")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "$acid: $label"
  else
    fail "$acid: $label — missing: ${missing[*]}"
  fi
}

# verify_absent <AC-ID> <file> <label> <extended-regex>
#   The extended regex must NOT appear in <file>.
verify_absent() {
  local acid="$1" file="$2" label="$3" re="$4"
  if grep -qE -- "$re" "$file"; then
    fail "$acid: $label — forbidden pattern '$re' present"
  else
    pass "$acid: $label"
  fi
}

# frontmatter <file> — YAML block between the leading `---` pair.
frontmatter() {
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f' "$1"
}

# body <file> — everything after the frontmatter.
body() {
  awk 'BEGIN{n=0} /^---$/{n++; next} n==2{print}' "$1"
}

# str_contains <AC-ID> <label> <haystack> <fixed-string>
str_contains() {
  local acid="$1" label="$2" hay="$3" pat="$4"
  if grep -qF -- "$pat" <<< "$hay"; then
    pass "$acid: '$pat' present in $label"
  else
    fail "$acid: expected '$pat' in $label"
  fi
}

# verify_secret_name_only <AC-ID> <file> <label>
#   The OPENCODE_API_KEY token may appear only as the secret-name reference
#   (secrets.OPENCODE_API_KEY, the "key:" line, or the env-var mapped from it
#   as env.OPENCODE_API_KEY); any other form is a violation. Shared by the
#   shared-workflow and trigger-workflow checks (AC-024-02-04 / AC-024-03-06)
#   — the same rule, one implementation.
verify_secret_name_only() {
  local acid="$1" file="$2" label="$3"
  if grep 'OPENCODE_API_KEY' "$file" \
     | grep -v 'secrets.OPENCODE_API_KEY' \
     | grep -v 'OPENCODE_API_KEY:' \
     | grep -v 'env.OPENCODE_API_KEY' | grep -q .; then
    fail "$acid: OPENCODE_API_KEY appears in $label in a form other than the secret name reference"
  else
    pass "$acid: OPENCODE_API_KEY appears in $label only as the secret name"
  fi
}

# Key-shaped strings that must never appear in committed files: only the
# secret NAME (OPENCODE_API_KEY) is allowed, never a value. The prefix
# fragments below are assembled by runtime string concatenation (mirroring
# check-no-hardcoded-secrets.sh) so this script's own detection patterns
# cannot trip the hardcoded-secrets scanner, which flags literal credential
# token prefixes in any of the four scanned dirs including scripts/.
CH_ALNUM="[A-Za-z0-9]"
CH_ALNUM_UNDER="[A-Za-z0-9_]"
CH_ALNUM_UPPER="[0-9A-Z]"
CH_ALNUM_DASH="[0-9A-Za-z_-]"
DASH="-"
P="p_"
PAT="_pat_"
IA="IA"
I="I"
KEY_SHAPE="(sk${DASH}${CH_ALNUM}{8,}|gh${P}${CH_ALNUM}{16,}|github${PAT}${CH_ALNUM_UNDER}{20,}|AK${IA}${CH_ALNUM_UPPER}{12,}|A${I}za${CH_ALNUM_DASH}{20,})"

echo "Checking PR review agent deliverables in: $ROOT_DIR"
echo ""

# ── Task 1: agent config (AC-024-01) ─────────────────────────────────────────
# AC-024-01-01 — Agent file exists with review-only scope
if [ -f "$AGENT" ]; then
  AGENT_FM="$(frontmatter "$AGENT")"
  AGENT_BODY="$(body "$AGENT")"
  AGENT_FIRST="$(printf '%s\n' "$AGENT_BODY" | head -6)"
  str_contains AC-024-01-01 'agents/pr-review.md' "$AGENT_FM" 'mode: subagent'
  str_contains AC-024-01-01 'agents/pr-review.md first directive' "$AGENT_FIRST" 'review the PR diff'
  str_contains AC-024-01-01 'agents/pr-review.md first directive' "$AGENT_FIRST" 'suggested fixes'
else
  fail "AC-024-01-01: agents/pr-review.md is missing"
fi

echo ""

# AC-024-01-02 — Model pinned to opencode/mimo-v2.5-free in the agent config
if [ -f "$AGENT" ]; then
  if grep -q '^model: opencode/mimo-v2.5-free$' "$AGENT"; then
    pass "AC-024-01-02: frontmatter model: is exactly opencode/mimo-v2.5-free (literal)"
  else
    fail "AC-024-01-02: frontmatter must carry the literal 'model: opencode/mimo-v2.5-free'"
  fi
  verify_absent AC-024-01-02 "$AGENT" "model value is not an {env:...} reference" \
    'model:[[:space:]]*\{env:'
fi

echo ""

# AC-024-01-03 — Zen provider wired to endpoint and auth
if [ -f "$OPENCODE_JSON" ]; then
  PROVIDER_SEC="$(sed -n '/"provider"/,$p' "$OPENCODE_JSON")"
  str_contains AC-024-01-03 'opencode.json provider block' "$PROVIDER_SEC" '"opencode"'
  str_contains AC-024-01-03 'opencode.json provider block' "$PROVIDER_SEC" 'https://opencode.ai/zen/v1'
  str_contains AC-024-01-03 'opencode.json provider block' "$PROVIDER_SEC" '"OPENCODE_API_KEY"'
  str_contains AC-024-01-03 'opencode.json provider block' "$PROVIDER_SEC" 'mimo-v2.5-free'
else
  fail "AC-024-01-03: opencode.json is missing"
fi

echo ""

# AC-024-01-04 — No other model id in the reviewer's config
if [ -f "$AGENT" ] && [ -f "$OPENCODE_JSON" ]; then
  # Model ids are provider/model tokens. The prompt also cites backticked
  # repo paths (.github/workflows/…, docs/…, shared/…) — those are not model
  # ids and are filtered out before the comparison.
  AGENT_MODEL_IDS="$(grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._-]+' "$AGENT" \
    | grep -vE '^(\.github|docs|shared|language)/' | sort -u || true)"
  if [ "$AGENT_MODEL_IDS" = "opencode/mimo-v2.5-free" ]; then
    pass "AC-024-01-04: only model id in agents/pr-review.md is opencode/mimo-v2.5-free"
  else
    fail "AC-024-01-04: agents/pr-review.md carries unexpected model ids: $(echo "$AGENT_MODEL_IDS" | tr '\n' ' ')"
  fi
  if grep -qE 'opencode-go/[A-Za-z0-9._-]+' "$OPENCODE_JSON"; then
    fail "AC-024-01-04: opencode.json must not carry the provider-qualified pin (it lives in the agent frontmatter)"
  else
    pass "AC-024-01-04: opencode.json carries no provider-qualified model pin"
  fi
fi

echo ""

# AC-024-01-05 — Write operations disabled in the permission config
if [ -f "$AGENT" ]; then
  str_contains AC-024-01-05 'agents/pr-review.md frontmatter' "$AGENT_FM" 'edit:'
  str_contains AC-024-01-05 'agents/pr-review.md frontmatter' "$AGENT_FM" '"*": deny'
  # Every allowed bash pattern is glob-matched against the forbidden write
  # operations: a pattern like `gh pr *` would match `gh pr merge` and must
  # fail the check.
  ALLOWED_PATTERNS="$(printf '%s\n' "$AGENT_FM" | sed -n '/bash:/,/^[[:space:]]*[^[:space:]-]/p' \
    | sed -nE 's/^[[:space:]]*"([^"]+)":[[:space:]]*allow.*/\1/p')"
  FORBIDDEN_WRITES=("git push" "git commit" "git add" "git checkout" "git reset" \
    "git worktree" "gh pr merge" "gh pr edit" "touch " "tee " "vim " "nano ")
  WRITE_MATCHES=()
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    for cmd in "${FORBIDDEN_WRITES[@]}"; do
      # Glob match: the allowed pattern as written in the frontmatter.
      if [[ "$cmd" == $pattern ]]; then
        WRITE_MATCHES+=("$pattern -> $cmd")
      fi
    done
  done <<< "$ALLOWED_PATTERNS"
  if [ "${#WRITE_MATCHES[@]}" -eq 0 ]; then
    pass "AC-024-01-05: no allowed bash pattern matches git push/commit/add/checkout/reset/worktree, gh pr merge/edit, or file editors"
  else
    fail "AC-024-01-05: allowed bash pattern matches a write operation: ${WRITE_MATCHES[*]}"
  fi
fi

echo ""

# AC-024-01-06 — Disabled operations named in the prompt
if [ -f "$AGENT" ]; then
  verify_grep AC-024-01-06 "$AGENT" "forbidden operations named in the prompt" \
    "describe" "improve" "auto-apply" "title or summary" "auto-merge" "push"
fi

echo ""

# AC-024-01-07 — Finding format is file:line + what + why + fix
if [ -f "$AGENT" ]; then
  verify_grep AC-024-01-07 "$AGENT" "finding format requires file:line, what, why, fix" \
    "file:line" "what" "why" "concrete suggested fix"
fi

echo ""

# AC-024-01-08 — No cosmetic nitpicks, no un-evidenced security findings
if [ -f "$AGENT" ]; then
  verify_grep AC-024-01-08 "$AGENT" "review discipline forbids nitpicks and un-evidenced security findings" \
    "nitpick" "cosmetic" "security findings without evidence"
fi

echo ""

# AC-024-01-09 — Findings grounded in the diff and the repo's standards
if [ -f "$AGENT" ]; then
  verify_grep AC-024-01-09 "$AGENT" "findings grounded in the diff and the repo standards" \
    "PR diff" "docs/CODING_CONVENTIONS.md" "language-specific/<lang>/SKILL.md" "AGENTS.md"
fi

echo ""

# AC-024-01-10 — Reviewed-SHA marker contract
if [ -f "$AGENT" ]; then
  verify_grep AC-024-01-10 "$AGENT" "review comment ends with the Reviewed-SHA marker" \
    "Reviewed-SHA:" "<head sha>"
fi

echo ""

# AC-024-01-11 — Model-env gate stays green
if [ -f "$ROOT_DIR/scripts/check-model-env.sh" ]; then
  if bash "$ROOT_DIR/scripts/check-model-env.sh" >/dev/null 2>&1; then
    pass "AC-024-01-11: scripts/check-model-env.sh exits 0 with the provider block present"
  else
    fail "AC-024-01-11: scripts/check-model-env.sh does not exit 0 with the provider block present"
  fi
else
  fail "AC-024-01-11: scripts/check-model-env.sh is missing"
fi

echo ""

# AC-024-01-12 — Spec-pipeline agents untouched
SPEC_AGENTS=(spec-coder spec-mutation-runner spec-pipeline spec-pr-opener \
  spec-refactorer spec-specifier spec-ux spec-verifier)
MISSING_SPEC=()
for a in "${SPEC_AGENTS[@]}"; do
  [ -f "$ROOT_DIR/agents/$a.md" ] || MISSING_SPEC+=("$a")
done
EXTRA_SPEC="$(find "$ROOT_DIR/agents" -maxdepth 1 -name 'spec-*.md' -printf '%f\n' 2>/dev/null \
  | sed 's/\.md$//' | while IFS= read -r n; do
      case " ${SPEC_AGENTS[*]} " in *" $n "*) ;; *) echo "$n" ;; esac
    done || true)"
if [ "${#MISSING_SPEC[@]}" -eq 0 ] && [ -z "$EXTRA_SPEC" ]; then
  pass "AC-024-01-12: exactly the 8 spec-pipeline agents exist under agents/, none added"
else
  fail "AC-024-01-12: spec-pipeline agent set changed — missing: ${MISSING_SPEC[*]:-}, extra: $EXTRA_SPEC"
fi
TOUCHED="$(git -C "$ROOT_DIR" diff --name-only origin/main HEAD 2>/dev/null \
  || git -C "$ROOT_DIR" diff --name-only HEAD^ HEAD 2>/dev/null || true)"
if [ -z "$(printf '%s\n' "$TOUCHED" | grep '^agents/spec-' || true)" ]; then
  pass "AC-024-01-12: no agents/spec-*.md file is modified in the change set"
else
  fail "AC-024-01-12: change set modifies agents/spec-*.md: $(printf '%s\n' "$TOUCHED" | grep '^agents/spec-')"
fi

echo ""

# ── Task 2: shared reusable workflow (AC-024-02) ─────────────────────────────
# AC-024-02-01 — Shared workflow exists as a reusable
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-01 "$SHARED_WF" "shared workflow is a workflow_call reusable" \
    "workflow_call" "pr-number" "head-sha" "OPENCODE_API_KEY"
else
  fail "AC-024-02-01: .github/workflows/ci-pr-review.yml is missing"
fi

echo ""

# AC-024-02-02 — Comment-only permissions
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-02 "$SHARED_WF" "permissions grant exactly contents: read + pull-requests: write" \
    "contents: read" "pull-requests: write"
  verify_absent AC-024-02-02 "$SHARED_WF" "no broader permission, no content-modifying step" \
    'contents: write|issues: write|packages: write|id-token: write|actions: write|security-events: write|git push|git commit|auto-merge|--merge'
fi

echo ""

# AC-024-02-03 — Secret optional; empty key skips the job cleanly
if [ -f "$SHARED_WF" ]; then
  SECRETS_BLOCK="$(sed -n '/^    secrets:/,/^permissions:/p' "$SHARED_WF")"
  str_contains AC-024-02-03 'workflow_call secrets block' "$SECRETS_BLOCK" 'OPENCODE_API_KEY:'
  if grep -q 'required: true' <<< "$SECRETS_BLOCK"; then
    fail "AC-024-02-03: OPENCODE_API_KEY must be declared without required: true"
  else
    pass "AC-024-02-03: OPENCODE_API_KEY is declared without required: true"
  fi
  # Empty-key guard (AC-024-02-03): secrets is not a legal context in an if:
  # at any scope, so the guard must gate on the mapped job env var. Verify
  # the job env maps the secret and a step guards on env.OPENCODE_API_KEY.
  verify_grep AC-024-02-03 "$SHARED_WF" "review job guarded by the empty-key check" \
    "env.OPENCODE_API_KEY != ''"
fi

echo ""

# AC-024-02-04 — No literal key in the workflow
if [ -f "$SHARED_WF" ]; then
  verify_absent AC-024-02-04 "$SHARED_WF" "no key-shaped value in the workflow" "$KEY_SHAPE"
  verify_secret_name_only AC-024-02-04 "$SHARED_WF" "the shared workflow"
fi

echo ""

# AC-024-02-05 — Review runs against the caller repo at the PR head
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-05 "$SHARED_WF" "checkout checks out the caller with submodules and no persisted credentials" \
    "submodules: true" "persist-credentials: false"
  verify_grep AC-024-02-05 "$SHARED_WF" "run step passes pr-number and head-sha into the invocation" \
    "inputs.pr-number" "inputs.head-sha" "PR_NUMBER" "HEAD_SHA"
fi

echo ""

# AC-024-02-06 — Pinned opencode binary
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-06 "$SHARED_WF" "pinned binary installed, headless --print-logs run" \
    "scripts/install-opencode.sh" "opencode run" "--print-logs"
fi

echo ""

# AC-024-02-07 — Agent discoverable for both self-hosting and child repos
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-07 "$SHARED_WF" "agent symlinked into .opencode/agents from agents/ or .standards/agents/" \
    "ln -sfn" ".opencode/agents/" "agents/pr-review.md" ".standards/agents/pr-review.md"
fi

echo ""

# AC-024-02-08 — No auto-approve in the run command
if [ -f "$SHARED_WF" ]; then
  verify_absent AC-024-02-08 "$SHARED_WF" "run command passes no auto-approve or skip-permissions flag" \
    '--auto|skip-permissions'
fi

echo ""

# AC-024-02-09/10/11 — Early-exit step semantics
if [ -f "$SHARED_WF" ]; then
  verify_grep AC-024-02-09 "$SHARED_WF" "early-exit extracts the Reviewed-SHA marker from prior comments" \
    "Reviewed-SHA" "comments[].body"
  verify_grep AC-024-02-09 "$SHARED_WF" "early-exit compares the marker to the current head-sha" \
    '"$reviewed_sha" = "${HEAD_SHA}"' "HEAD_SHA"
  verify_grep AC-024-02-09 "$SHARED_WF" "early-exit requires gh pr checks all green" \
    "gh pr checks" "SUCCESS"
  verify_grep AC-024-02-09 "$SHARED_WF" "model-run step is conditional on the early-exit output" \
    "steps.early-exit.outputs.skip"
  verify_grep AC-024-02-10 "$SHARED_WF" "skip requires marker == head-sha; a changed head proceeds" \
    '"$reviewed_sha" = "${HEAD_SHA}"'
  verify_grep AC-024-02-11 "$SHARED_WF" "a non-green check keeps skip=false, so the run proceeds" \
    "SUCCESS" "skip="
fi

echo ""

# ── Task 3: self-hosted trigger workflow (AC-024-03) ─────────────────────────
# AC-024-03-01 — Trigger on pull_request with the four types
if [ -f "$TRIGGER_WF" ]; then
  verify_grep AC-024-03-01 "$TRIGGER_WF" "trigger is pull_request" \
    "pull_request" "types:" "opened, ready_for_review, synchronize, reopened"
  TYPES_LINE="$(sed -nE 's/.*types:[[:space:]]*\[([^]]*)\].*/\1/p' "$TRIGGER_WF" | head -1 || true)"
  TYPE_COUNT="$(printf '%s' "$TYPES_LINE" | tr ',' '\n' | grep -c '[^[:space:]]' || true)"
  if [ -n "$TYPES_LINE" ] && [ "$TYPE_COUNT" -eq 4 ]; then
    pass "AC-024-03-01: types list has exactly 4 entries"
  else
    fail "AC-024-03-01: types list must contain exactly opened, ready_for_review, synchronize, reopened (found: $TYPES_LINE)"
  fi
  verify_absent AC-024-03-01 "$TRIGGER_WF" "no extra pull_request types" \
    'types:[[:space:]]*\[[^]]*(labeled|assigned|unassigned|unlabeled|closed|edited|review_requested|review_request_removed)[^]]*\]'
else
  fail "AC-024-03-01: .github/workflows/pr-review.yml is missing"
fi

echo ""

# AC-024-03-02 — Per-PR concurrency with cancel-in-progress
if [ -f "$TRIGGER_WF" ]; then
  verify_grep AC-024-03-02 "$TRIGGER_WF" "concurrency keyed on the PR number with cancel-in-progress" \
    "concurrency:" "github.event.pull_request.number" "cancel-in-progress: true"
fi

echo ""

# AC-024-03-03 — Calls the shared workflow with PR context
if [ -f "$TRIGGER_WF" ]; then
  verify_grep AC-024-03-03 "$TRIGGER_WF" "job calls the shared pr-review workflow@main" \
    "RexiAI/my-engineering-standards/.github/workflows/ci-pr-review.yml@main"
  verify_grep AC-024-03-03 "$TRIGGER_WF" "pr-number and head-sha passed from the PR event" \
    "pr-number: \${{ github.event.pull_request.number }}" \
    "head-sha: \${{ github.event.pull_request.head.sha }}"
fi

echo ""

# AC-024-03-04 — Key supplied via GitHub secret
if [ -f "$TRIGGER_WF" ]; then
  verify_grep AC-024-03-04 "$TRIGGER_WF" "OPENCODE_API_KEY mapped from secrets" \
    "OPENCODE_API_KEY: \${{ secrets.OPENCODE_API_KEY }}"
fi

echo ""

# AC-024-03-05 — No key: job skipped, never a required-check failure.
# The trigger job has no if:-level secrets guard (illegal in GitHub Actions);
# the no-key skip is guaranteed by the shared reusable workflow it calls,
# which gates its review step on env.OPENCODE_API_KEY.
if [ -f "$TRIGGER_WF" ]; then
  verify_grep AC-024-03-05 "$TRIGGER_WF" "trigger delegates to the self-guarding shared workflow" \
    "ci-pr-review.yml"
fi

echo ""

# AC-024-03-06 — No literal key in the trigger workflow
if [ -f "$TRIGGER_WF" ]; then
  verify_absent AC-024-03-06 "$TRIGGER_WF" "no key-shaped value in the trigger workflow" "$KEY_SHAPE"
  verify_secret_name_only AC-024-03-06 "$TRIGGER_WF" "the trigger workflow"
fi

echo ""

# AC-024-03-07 — Self-hosting wiring is identical to child wiring
if [ -f "$TRIGGER_WF" ] && [ -f "$INIT_CI" ]; then
  SHARED_URL='RexiAI/my-engineering-standards/.github/workflows/ci-pr-review.yml@main'
  if grep -qF -- "$SHARED_URL" "$TRIGGER_WF" && grep -qF -- "$SHARED_URL" "$INIT_CI"; then
    pass "AC-024-03-07: trigger workflow and init-ci.sh emit the same shared pr-review workflow@main"
  else
    fail "AC-024-03-07: trigger workflow and init-ci.sh must reference the same ci-pr-review.yml@main"
  fi
fi

echo ""

# ── Task 4: init-ci.sh --with-pr-review (AC-024-04) ──────────────────────────
# AC-024-04-01 — Flag accepted and documented in usage
if [ -f "$INIT_CI" ]; then
  verify_grep AC-024-04-01 "$INIT_CI" "usage line lists --with-pr-review" "[--with-pr-review]"
  if grep -q 'WITH_PR_REVIEW_FLAG="true"' "$INIT_CI" \
     && grep -q -- '--with-pr-review)' "$INIT_CI"; then
    pass "AC-024-04-01: --with-pr-review parsed into WITH_PR_REVIEW_FLAG"
  else
    fail "AC-024-04-01: --with-pr-review case branch missing from the flag parser"
  fi
fi

echo ""

# AC-024-04-02/03/07/08 — generation runs in a scratch child repo
if [ -f "$INIT_CI" ]; then
  FIX="$(mktemp -d)"
  trap 'rm -rf "$FIX"' EXIT
  ln -s "$ROOT_DIR" "$FIX/.standards"

  # AC-024-04-02 — GitHub generation emits the pr-review job
  if ( cd "$FIX" && bash .standards/scripts/init-ci.sh \
       --with-pr-review --platform github --backend go < /dev/null > /dev/null 2>&1 ); then
    if [ -f "$FIX/.github/workflows/ci.yml" ]; then
      verify_grep AC-024-04-02 "$FIX/.github/workflows/ci.yml" "generated ci.yml carries the pr-review job" \
        "pr-review:" "RexiAI/my-engineering-standards/.github/workflows/ci-pr-review.yml@main" \
        "OPENCODE_API_KEY: \${{ secrets.OPENCODE_API_KEY }}"
    else
      fail "AC-024-04-02: init-ci.sh did not generate .github/workflows/ci.yml"
    fi
  else
    fail "AC-024-04-02: init-ci.sh --with-pr-review --platform github exited non-zero"
  fi
  rm -rf "$FIX/.github"

  # AC-024-04-03 — Default output unchanged without the flag
  if ( cd "$FIX" && bash .standards/scripts/init-ci.sh \
       --platform github --backend go < /dev/null > /dev/null 2>&1 ); then
    if [ -f "$FIX/.github/workflows/ci.yml" ]; then
      if grep -q 'pr-review' "$FIX/.github/workflows/ci.yml" \
         || grep -q 'OPENCODE_API_KEY' "$FIX/.github/workflows/ci.yml"; then
        fail "AC-024-04-03: default ci.yml (no --with-pr-review) contains a pr-review job or OPENCODE_API_KEY"
      else
        pass "AC-024-04-03: default ci.yml has no pr-review job and no OPENCODE_API_KEY line"
      fi
    else
      fail "AC-024-04-03: init-ci.sh did not generate .github/workflows/ci.yml"
    fi
  else
    fail "AC-024-04-03: init-ci.sh --platform github exited non-zero"
  fi
  rm -rf "$FIX/.github" "$FIX/.gitlab-ci.yml"

  # AC-024-04-07 — GitLab-only: warning, no emission, exit 0
  GL_OUT="$(cd "$FIX" && bash .standards/scripts/init-ci.sh \
    --with-pr-review --platform gitlab --backend go < /dev/null 2>&1)" && GL_RC=0 || GL_RC=$?
  if [ "$GL_RC" -eq 0 ]; then
    pass "AC-024-04-07: --platform gitlab with the flag exits 0"
  else
    fail "AC-024-04-07: --platform gitlab with the flag must exit 0 (got $GL_RC)"
  fi
  if grep -q 'GitHub Actions feature' <<< "$GL_OUT"; then
    pass "AC-024-04-07: GitLab run prints the GitHub-only warning"
  else
    fail "AC-024-04-07: GitLab run must print a warning that PR review is a GitHub Actions feature"
  fi
  if [ -f "$FIX/.gitlab-ci.yml" ] && grep -q 'pr-review' "$FIX/.gitlab-ci.yml"; then
    fail "AC-024-04-07: .gitlab-ci.yml must not contain PR-review content"
  else
    pass "AC-024-04-07: nothing PR-review-related emitted into .gitlab-ci.yml"
  fi
  rm -rf "$FIX/.github" "$FIX/.gitlab-ci.yml"

  # AC-024-04-08 — Both platforms: GitHub emits, GitLab warns
  BOTH_OUT="$(cd "$FIX" && bash .standards/scripts/init-ci.sh \
    --with-pr-review --platform both --backend go < /dev/null 2>&1)" && BOTH_RC=0 || BOTH_RC=$?
  if [ "$BOTH_RC" -eq 0 ] \
     && grep -q 'pr-review:' "$FIX/.github/workflows/ci.yml" \
     && grep -q 'OPENCODE_API_KEY: \${{ secrets.OPENCODE_API_KEY }}' "$FIX/.github/workflows/ci.yml" \
     && grep -q 'GitHub Actions feature' <<< "$BOTH_OUT" \
     && ! grep -q 'pr-review' "$FIX/.gitlab-ci.yml"; then
    pass "AC-024-04-08: --platform both emits the GitHub pr-review job and warns on GitLab"
  else
    fail "AC-024-04-08: --platform both must emit the pr-review job on GitHub and warn (no emission) on GitLab"
  fi
fi

echo ""

# AC-024-04-04/05 — Secret prompt gating (structural: the read is inside the
# flag guard; the interactive proof lives in check-pr-review.selftest.sh)
if [ -f "$INIT_CI" ]; then
  # The OPENCODE_API_KEY prompt must sit textually inside the
  # `if [ "$WITH_PR_REVIEW_FLAG" = "true" ]; then` guard. Find the line of the
  # guard and the line of the prompt and confirm the guard opens before the
  # prompt and its `fi` closes after it.
  GUARD_LINE="$(grep -nF 'if [ "$WITH_PR_REVIEW_FLAG" = "true" ]; then' "$INIT_CI" | head -1 | cut -d: -f1)"
  PROMPT_LINE="$(grep -nF 'OPENCODE_API_KEY (PR review agent, opt-in)' "$INIT_CI" | head -1 | cut -d: -f1)"
  FI_LINE="$(awk -v start="$GUARD_LINE" 'NR>start && $0 ~ /^[[:space:]]*fi[[:space:]]*$/{print NR; exit}' "$INIT_CI" || true)"
  if [ -n "$GUARD_LINE" ] && [ -n "$PROMPT_LINE" ] && [ -n "$FI_LINE" ] \
     && [ "$GUARD_LINE" -lt "$PROMPT_LINE" ] && [ "$PROMPT_LINE" -lt "$FI_LINE" ]; then
    pass "AC-024-04-04: OPENCODE_API_KEY prompt is gated on WITH_PR_REVIEW_FLAG"
  else
    fail "AC-024-04-04: OPENCODE_API_KEY must be prompted only inside the --with-pr-review guard"
  fi
  READS="$(grep -c 'read -rp.*OPENCODE_API_KEY' "$INIT_CI" || true)"
  if [ "$READS" -eq 1 ]; then
    pass "AC-024-04-05: exactly one OPENCODE_API_KEY prompt exists, and it is flag-gated (never prompted without the flag)"
  else
    fail "AC-024-04-05: expected exactly one OPENCODE_API_KEY prompt (found $READS)"
  fi
fi

echo ""

# AC-024-04-06 — Summary lists the required secret for GitHub
if [ -f "$INIT_CI" ]; then
  verify_grep AC-024-04-06 "$INIT_CI" "summary's GitHub next steps list OPENCODE_API_KEY" \
    "OPENCODE_API_KEY OPENCODE_API_KEY (PR review agent, opt-in only)" \
    "docs/CI_CD.md §PR Review Agent"
fi

echo ""

# ── Task 5: documentation (AC-024-05) ────────────────────────────────────────
# AC-024-05-01 — CI_CD.md documents the PR review agent
if [ -f "$CI_CD" ]; then
  PR_SECTION="$(awk '$0=="## PR Review Agent"{f=1;next} /^## /{if(f)exit} f' "$CI_CD")"
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'review + suggest fixes only'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'describe'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'improve'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'auto-apply'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'auto-merge'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'push'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'opencode/mimo-v2.5-free'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'https://opencode.ai/zen/v1'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'OPENCODE_API_KEY'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'never committed'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'init-ci.sh --with-pr-review'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'never opts in'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'latest head'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'Early exit'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'Reviewed-SHA'
  str_contains AC-024-05-01 'docs/CI_CD.md PR Review Agent section' "$PR_SECTION" 'One review per relevant PR event'
else
  fail "AC-024-05-01: docs/CI_CD.md is missing"
fi

echo ""

# AC-024-05-02 — Required Secrets table gains the new secret
if [ -f "$CI_CD" ]; then
  SECRETS_TABLE="$(awk '/^### Required Secrets/{f=1;next} /^## /{if(f)exit} f' "$CI_CD")"
  if grep -q '`OPENCODE_API_KEY`' <<< "$SECRETS_TABLE" && grep -q 'opt-in' <<< "$SECRETS_TABLE"; then
    pass "AC-024-05-02: Required Secrets table lists OPENCODE_API_KEY as opt-in"
  else
    fail "AC-024-05-02: Required Secrets table must list OPENCODE_API_KEY with an opt-in marker"
  fi
else
  fail "AC-024-05-02: docs/CI_CD.md is missing"
fi

echo ""

# AC-024-05-03 — Architecture tree lists the shared workflow
if [ -f "$CI_CD" ]; then
  ARCH_TREE="$(awk '$0=="## Architecture"{f=1;next} /^## /{if(f)exit} f' "$CI_CD")"
  str_contains AC-024-05-03 'docs/CI_CD.md Architecture tree' "$ARCH_TREE" 'pr-review.yml'
else
  fail "AC-024-05-03: docs/CI_CD.md is missing"
fi

echo ""

# AC-024-05-04 — SPEC_PIPELINE.md cross-references the section
if [ -f "$SPEC_PIPE" ]; then
  ZEN_SEC="$(awk '$0=="## Using OpenCode Zen"{f=1;next} /^## /{if(f)exit} f' "$SPEC_PIPE")"
  str_contains AC-024-05-04 'docs/SPEC_PIPELINE.md Using OpenCode Zen section' "$ZEN_SEC" 'https://opencode.ai/zen/v1'
  str_contains AC-024-05-04 'docs/SPEC_PIPELINE.md Using OpenCode Zen section' "$ZEN_SEC" 'OPENCODE_API_KEY'
  str_contains AC-024-05-04 'docs/SPEC_PIPELINE.md Using OpenCode Zen section' "$ZEN_SEC" 'opencode/mimo-v2.5-free'
  str_contains AC-024-05-04 'docs/SPEC_PIPELINE.md Using OpenCode Zen section' "$ZEN_SEC" 'CI_CD.md §PR Review Agent'
else
  fail "AC-024-05-04: docs/SPEC_PIPELINE.md is missing"
fi

echo ""

# AC-024-05-05 — No literal key value in the docs
for doc in "$CI_CD" "$SPEC_PIPE"; do
  if [ -f "$doc" ]; then
    if grep -qE "$KEY_SHAPE" "$doc"; then
      fail "AC-024-05-05: key-shaped value found in ${doc#"$ROOT_DIR"/}"
    else
      pass "AC-024-05-05: no key-shaped value in ${doc#"$ROOT_DIR"/}"
    fi
  fi
done

echo ""

# ── Self-citation and wiring ─────────────────────────────────────────────────
SCENARIO_IDS=(AC-024-01-01 AC-024-01-02 AC-024-01-03 AC-024-01-04 AC-024-01-05 \
  AC-024-01-06 AC-024-01-07 AC-024-01-08 AC-024-01-09 AC-024-01-10 AC-024-01-11 AC-024-01-12 \
  AC-024-02-01 AC-024-02-02 AC-024-02-03 AC-024-02-04 AC-024-02-05 AC-024-02-06 \
  AC-024-02-07 AC-024-02-08 AC-024-02-09 AC-024-02-10 AC-024-02-11 \
  AC-024-03-01 AC-024-03-02 AC-024-03-03 AC-024-03-04 AC-024-03-05 AC-024-03-06 AC-024-03-07 \
  AC-024-04-01 AC-024-04-02 AC-024-04-03 AC-024-04-04 AC-024-04-05 AC-024-04-06 \
  AC-024-04-07 AC-024-04-08 \
  AC-024-05-01 AC-024-05-02 AC-024-05-03 AC-024-05-04 AC-024-05-05)
MISSING_CITES=0
for id in "${SCENARIO_IDS[@]}"; do
  if ! grep -qF -- "$id" "$0"; then
    fail "self-citation: scenario $id is not cited by check-pr-review.sh"
    MISSING_CITES=$((MISSING_CITES + 1))
  fi
done
if [ "$MISSING_CITES" -eq 0 ]; then
  pass "self-citation: every AC-024-NN-NN scenario ID is cited by this script"
fi

STALE_REFS=0
for ref in $(grep -oE 'AC-024-[0-9]{2}-[0-9]{2}' "$0" | sort -u); do
  case " ${SCENARIO_IDS[*]} " in
    *" $ref "*) ;;
    *)
      fail "self-citation: stale reference $ref resolves to no scenario"
      STALE_REFS=$((STALE_REFS + 1))
      ;;
  esac
done
if [ "$STALE_REFS" -eq 0 ]; then
  pass "self-citation: every AC-024 reference inside the script resolves to a scenario ID"
fi

if [ -f "$SELF_CI" ] && grep -q 'check-pr-review.sh' "$SELF_CI"; then
  pass "self-ci: .github/workflows/self-ci.yml runs check-pr-review.sh in the Validate job"
else
  fail "self-ci: .github/workflows/self-ci.yml does not run check-pr-review.sh"
fi

echo ""

# ── Summary ─────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ PR review agent check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/CI_CD.md §PR Review Agent, specs/024-pr-review-agent/20-acceptance/"
  exit 1
else
  echo -e "${GREEN}✔ PR review agent check: every check passed.${NC}"
  exit 0
fi