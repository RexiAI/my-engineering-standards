#!/bin/bash
# check-post-pr-ci-loop.sh — Verify the phase-2 post-PR CI check-and-remediate
# loop is wired into the spec pipeline's prompts and docs (spec 014).
#
# Spec 014 is a prompts/docs-only spec: it edits agents/spec-*.md,
# commands/build.md, and docs/SPEC_PIPELINE.md, and adds no new agent and no new
# CI infrastructure. This script is the test carrier for its acceptance
# scenarios — every AC-014-* scenario ID below is asserted as file content, which
# is exactly what scripts/check-scenario-traceability.sh greps for. The repo has
# no JVM/Go/Node test stack; the shipped check script is the established carrier
# (same pattern as check-orchestration.sh).
#
# Checks, per task:
#   Task 1 (AC-014-01) — docs/SPEC_PIPELINE.md names the exact CI query, the
#     repo's Self CI workflow, the log read, the max-3 / independent-counter
#     bounds, the exhaustion escalation, and the 008 ordering dependency.
#   Task 2 (AC-014-02) — agents/spec-verifier.md runs the post-PR CI check and
#     records the verdict per check and per round in 25-verification.md.
#   Task 3 (AC-014-03) — agents/spec-coder.md and agents/spec-refactorer.md get
#     the bounded fix-from-CI-error mode.
#   Task 4 (AC-014-04) — commands/build.md and agents/spec-pipeline.md bound the
#     phase-2 loop (orchestrator-owned counter, max 3).
#   Task 5 (AC-014-05) — agents/spec-pr-opener.md gets the fix-round re-push mode.
#
# Note on the negative assertions: spec 008's budget policy bans "re-run until
# green" and any equivalent open-ended re-run instruction, and 014 extends that
# to the phase-2 loop. The banned phrase is therefore deliberately present in
# this script (as the grep pattern) but must be absent from the prompts/docs it
# checks — those files are the assertion targets, this script is not.
#
# Usage:
#   scripts/check-post-pr-ci-loop.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch
#   directory to check an isolated docs/ + agents/ + commands/ tree.
#
# Exit codes:
#   0 — every assertion holds
#   1 — at least one assertion failed; each prints FAIL <scenario-id>
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Post-PR CI check-and-remediate loop (phase 2) (spec 014)
set -euo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(dirname "$SCRIPT_DIR")"
fi
ROOT="$(cd "$ROOT" && pwd)"

DOCS="$ROOT/docs/SPEC_PIPELINE.md"
VERIFIER="$ROOT/agents/spec-verifier.md"
CODER="$ROOT/agents/spec-coder.md"
REFACTORER="$ROOT/agents/spec-refactorer.md"
BUILD="$ROOT/commands/build.md"
ORCH="$ROOT/agents/spec-pipeline.md"
OPENER="$ROOT/agents/spec-pr-opener.md"

DOCS_HEADING='## Post-PR CI check-and-remediate loop (phase 2)'

# Open-ended re-run phrasing banned by spec 008's budget policy and extended to
# the phase-2 loop by 014: "re-run until green" and any instruction to keep
# re-running until the checks pass.
BANNED='until green|until the checks pass|until all checks pass|until they pass'

FAILED=0

pass() { echo -e "\033[0;32mPASS\033[0m $*"; }
fail() { echo -e "\033[0;31mFAIL\033[0m $*"; FAILED=$((FAILED + 1)); }

# Extract a section: from the line exactly equal to <heading> to the next `## `.
section() { # section <file> <heading>
  local f="$1" h="$2"
  awk -v h="$h" '$0==h{f=1;next} /^## /{if(f)exit} f' "$f"
}

frontmatter() { # frontmatter <file>
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f' "$1"
}

# NOTE: here-strings, not pipes — with `set -o pipefail`, `grep -q` exits on an
# early match, the upstream `printf` gets SIGPIPE, and the pipeline then reports
# failure for a pattern that IS present (a real flake this script hit).
str_contains() { # str_contains <id> <label> <haystack> <literal>
  local id="$1" label="$2" hay="$3" pat="$4"
  if grep -qF -- "$pat" <<< "$hay"; then
    pass "$id — '$pat' present in $label"
  else
    fail "$id — expected '$pat' in $label"
  fi
}

str_absent() { # str_absent <id> <label> <haystack> <extended-regex>
  local id="$1" label="$2" hay="$3" re="$4"
  if grep -qE -- "$re" <<< "$hay"; then
    fail "$id — forbidden pattern '$re' present in $label"
  else
    pass "$id — no '$re' in $label"
  fi
}

# File variants delegate to the string variants; the relative path is the label.
contains() { # contains <id> <file> <literal>
  local id="$1" f="$2" pat="$3"
  str_contains "$id" "${f#"$ROOT"/}" "$(cat "$f")" "$pat"
}

absent() { # absent <id> <file> <extended-regex>
  local id="$1" f="$2" re="$3"
  str_absent "$id" "${f#"$ROOT"/}" "$(cat "$f")" "$re"
}

# ── Task 1 — docs/SPEC_PIPELINE.md (AC-014-01) ───────────────────────────────
DOCS_P2="$(section "$DOCS" "$DOCS_HEADING")"

echo "Task 1 — docs/SPEC_PIPELINE.md post-PR CI loop documentation..."
# AC-014-01-01 — the exact CI query is named, and the bucket field is the
# PASS/FAIL parse rule
str_contains AC-014-01-01 "$DOCS_HEADING" "$DOCS_P2" \
  'gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link'
str_contains AC-014-01-01 "$DOCS_HEADING" "$DOCS_P2" 'PASS/FAIL parse rule'
# AC-014-01-02 — the CI platform and workflow are grounded in this repo
str_contains AC-014-01-02 "$DOCS_HEADING" "$DOCS_P2" 'GitHub Actions'
str_contains AC-014-01-02 "$DOCS_HEADING" "$DOCS_P2" 'Self CI'
str_contains AC-014-01-02 "$DOCS_HEADING" "$DOCS_P2" '.github/workflows/self-ci.yml'
str_absent  AC-014-01-02 "$DOCS_HEADING" "$DOCS_P2" \
  'GitLab|CircleCI|Travis|Jenkins|Azure Pipelines|Bitbucket|GitHub Enterprise'
# AC-014-01-03 — pending checks are polled, not misread
str_contains AC-014-01-03 "$DOCS_HEADING" "$DOCS_P2" 'gh pr checks --watch'
str_contains AC-014-01-03 "$DOCS_HEADING" "$DOCS_P2" 'neither a pass nor a fail'
# AC-014-01-04 — failing check IDs and log read are named
str_contains AC-014-01-04 "$DOCS_HEADING" "$DOCS_P2" \
  'gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs'
str_contains AC-014-01-04 "$DOCS_HEADING" "$DOCS_P2" \
  'gh run list --branch spec/NNN-slug --workflow "Self CI"'
str_contains AC-014-01-04 "$DOCS_HEADING" "$DOCS_P2" 'gh run view <RUN-ID> --log-failed'
str_contains AC-014-01-04 "$DOCS_HEADING" "$DOCS_P2" '25-verification.md'
# AC-014-01-05 — max 3 rounds, independent of Phase 1, each re-push re-triggers CI
str_contains AC-014-01-05 "$DOCS_HEADING" "$DOCS_P2" 'at most 3'
str_contains AC-014-01-05 "$DOCS_HEADING" "$DOCS_P2" 'independent of Phase 1'
str_contains AC-014-01-05 "$DOCS_HEADING" "$DOCS_P2" 're-triggers CI'
# AC-014-01-06 — exhaustion escalates to the human, never a silent green
str_contains AC-014-01-06 "$DOCS_HEADING" "$DOCS_P2" 'escalates to the human'
str_contains AC-014-01-06 "$DOCS_HEADING" "$DOCS_P2" 'failing check IDs'
str_contains AC-014-01-06 "$DOCS_HEADING" "$DOCS_P2" 'last log evidence'
str_contains AC-014-01-06 "$DOCS_HEADING" "$DOCS_P2" 'silent green'
# AC-014-01-07 — per-check and per-round outcome recorded in 25-verification.md
str_contains AC-014-01-07 "$DOCS_HEADING" "$DOCS_P2" 'per check and per round'
# AC-014-01-08 — no open-ended re-run phrasing
str_absent  AC-014-01-08 "$DOCS_HEADING" "$DOCS_P2" "$BANNED"
# AC-014-01-09 — ordering dependency on 008 is stated
str_contains AC-014-01-09 "$DOCS_HEADING" "$DOCS_P2" 'spec 008'
str_contains AC-014-01-09 "$DOCS_HEADING" "$DOCS_P2" 'only once'

# ── Task 2 — agents/spec-verifier.md (AC-014-02) ─────────────────────────────
VERIFIER_FM="$(frontmatter "$VERIFIER")"

echo "Task 2 — agents/spec-verifier.md post-PR CI check..."
# AC-014-02-01 — the Verifier runs the real CI query and records PASS/FAIL
contains AC-014-02-01 "$VERIFIER" \
  'gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link'
contains AC-014-02-01 "$VERIFIER" 'PASS/FAIL per check'
contains AC-014-02-01 "$VERIFIER" 'bucket'
# AC-014-02-02 — pending checks are polled to terminal, never a pass or a fail
contains AC-014-02-02 "$VERIFIER" '--watch'
contains AC-014-02-02 "$VERIFIER" 'neither a pass nor a fail'
# AC-014-02-03 — on FAIL the Verifier captures check IDs and reads the logs
contains AC-014-02-03 "$VERIFIER" \
  'gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs'
contains AC-014-02-03 "$VERIFIER" 'conclusion == "failure"'
contains AC-014-02-03 "$VERIFIER" \
  'gh run list --branch spec/NNN-slug --workflow "Self CI"'
contains AC-014-02-03 "$VERIFIER" 'gh run view <RUN-ID> --log-failed'
contains AC-014-02-03 "$VERIFIER" 'failure reason'
# AC-014-02-04 — Post-PR CI check section records per-check, per-round detail
contains AC-014-02-04 "$VERIFIER" 'Post-PR CI check'
contains AC-014-02-04 "$VERIFIER" 'round index'
contains AC-014-02-04 "$VERIFIER" 'log excerpt'
# AC-014-02-05 — diagnosis handed to the orchestrator; scoped re-check on re-trigger
contains AC-014-02-05 "$VERIFIER" 'Hand the diagnosis back to the orchestrator'
contains AC-014-02-05 "$VERIFIER" 'previously-failing checks'
# AC-014-02-06 — frontmatter and permissions are unchanged
str_contains AC-014-02-06 'spec-verifier.md frontmatter' "$VERIFIER_FM" \
  '"specs/*/25-verification.md": allow'
str_contains AC-014-02-06 'spec-verifier.md frontmatter' "$VERIFIER_FM" \
  '"git commit*": deny'
str_contains AC-014-02-06 'spec-verifier.md frontmatter' "$VERIFIER_FM" \
  '"git push*": deny'
# AC-014-02-07 — no open-ended re-run phrasing is added
absent AC-014-02-07 "$VERIFIER" "$BANNED"

# ── Task 3 — fixers: agents/spec-coder.md + agents/spec-refactorer.md (AC-014-03) ──
CODER_FM="$(frontmatter "$CODER")"
REFACTORER_FM="$(frontmatter "$REFACTORER")"

echo "Task 3 — bounded fix-from-CI-error mode in the fixer prompts..."
# AC-014-03-01 — Coder fixes only the diagnosed failing check
contains AC-014-03-01 "$CODER" 're-invoked'
contains AC-014-03-01 "$CODER" 'CI failure'
contains AC-014-03-01 "$CODER" '25-verification.md'
contains AC-014-03-01 "$CODER" 'failing check'
# AC-014-03-02 — Coder's re-fix is bounded by the orchestrator's counter
contains AC-014-03-02 "$CODER" 'orchestrator'
contains AC-014-03-02 "$CODER" 'capped at 3'
contains AC-014-03-02 "$CODER" 're-fix endlessly'
# AC-014-03-03 — Refactorer gets the same bounded rule
contains AC-014-03-03 "$REFACTORER" 'structural'
contains AC-014-03-03 "$REFACTORER" 'complexity'
contains AC-014-03-03 "$REFACTORER" 'orchestrator'
contains AC-014-03-03 "$REFACTORER" 'capped at 3'
# AC-014-03-04 — fixers never push; the re-push is the PR Opener's job
str_contains AC-014-03-04 'spec-coder.md frontmatter' "$CODER_FM" '"git push*": deny'
str_contains AC-014-03-04 'spec-refactorer.md frontmatter' "$REFACTORER_FM" '"git push*": deny'
contains AC-014-03-04 "$CODER" 'the re-push is the PR Opener'
contains AC-014-03-04 "$REFACTORER" 'the re-push is the PR Opener'
# AC-014-03-05 — information barriers are unchanged
contains AC-014-03-05 "$CODER" 'must not read `00-informal.md`'
contains AC-014-03-05 "$REFACTORER" 'must not read anything under'
contains AC-014-03-05 "$REFACTORER" '`specs/**`'
# AC-014-03-06 — no open-ended re-run phrasing is added
absent AC-014-03-06 "$CODER" "$BANNED"
absent AC-014-03-06 "$REFACTORER" "$BANNED"

# ── Task 4 — commands/build.md + agents/spec-pipeline.md (AC-014-04) ─────────
echo "Task 4 — bounded phase-2 loop in the orchestrator and /build command..."
# AC-014-04-01 — commands/build.md describes a bounded post-PR CI loop
contains AC-014-04-01 "$BUILD" 'PR URL'
contains AC-014-04-01 "$BUILD" 'post-PR CI check'
contains AC-014-04-01 "$BUILD" 'spec-coder'
contains AC-014-04-01 "$BUILD" 'spec-refactorer'
contains AC-014-04-01 "$BUILD" 'spec-pr-opener'
contains AC-014-04-01 "$BUILD" 'at most 3'
# AC-014-04-02 — agents/spec-pipeline.md describes the same bounded loop
contains AC-014-04-02 "$ORCH" 'phase-2 loop'
contains AC-014-04-02 "$ORCH" 're-push'
contains AC-014-04-02 "$ORCH" 'spec-coder'
contains AC-014-04-02 "$ORCH" 'spec-refactorer'
contains AC-014-04-02 "$ORCH" 'behavior'
contains AC-014-04-02 "$ORCH" 'structural'
# AC-014-04-03 — counter independent of Phase 1, max 3, referencing spec 008
contains AC-014-04-03 "$BUILD" 'independent of Phase 1'
contains AC-014-04-03 "$ORCH" 'independent of Phase 1'
contains AC-014-04-03 "$BUILD" 'max 3'
contains AC-014-04-03 "$ORCH" 'max 3'
contains AC-014-04-03 "$BUILD" 'spec 008'
contains AC-014-04-03 "$ORCH" 'spec 008'
# AC-014-04-04 — exhaustion stops the pipeline with the escalation payload
contains AC-014-04-04 "$BUILD" '3rd FAIL'
contains AC-014-04-04 "$ORCH" '3rd FAIL'
contains AC-014-04-04 "$BUILD" 'verbatim'
contains AC-014-04-04 "$ORCH" 'verbatim'
contains AC-014-04-04 "$BUILD" 'no 4th round'
contains AC-014-04-04 "$ORCH" 'no 4th round'
contains AC-014-04-04 "$BUILD" 'escalate to the human'
contains AC-014-04-04 "$ORCH" 'escalate to the human'
# AC-014-04-05 — never a silent green; outcome recorded in 25-verification.md
contains AC-014-04-05 "$BUILD" 'never reported as green'
contains AC-014-04-05 "$ORCH" 'never reported as green'
contains AC-014-04-05 "$BUILD" '25-verification.md'
contains AC-014-04-05 "$ORCH" '25-verification.md'
# AC-014-04-06 — each re-push re-triggers CI; the re-check waits for the run
contains AC-014-04-06 "$BUILD" 'Self CI'
contains AC-014-04-06 "$ORCH" 'Self CI'
contains AC-014-04-06 "$BUILD" 'waits for the re-triggered run'
contains AC-014-04-06 "$ORCH" 'waits for the re-triggered run'
# AC-014-04-07 — the orchestrator stays out of the mechanics
absent AC-014-04-07 "$BUILD" 'gh pr checks'
absent AC-014-04-07 "$ORCH" 'gh pr checks'
absent AC-014-04-07 "$BUILD" 'git (commit|push)'
absent AC-014-04-07 "$ORCH" 'git (commit|push)'
# AC-014-04-08 — no open-ended re-run phrasing in the loop
absent AC-014-04-08 "$BUILD" "$BANNED"
absent AC-014-04-08 "$ORCH" "$BANNED"
# AC-014-04-09 — no new infrastructure: every cited agent resolves, no new
# script or workflow references
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  if [ -f "$ROOT/agents/$tok.md" ]; then
    pass "AC-014-04-09 — agent '$tok' cited in build.md/spec-pipeline.md resolves"
  else
    fail "AC-014-04-09 — agent '$tok' cited but agents/$tok.md does not exist"
  fi
done < <(grep -hoP '`\Kspec-[a-z][a-z0-9-]*' "$BUILD" "$ORCH" 2>/dev/null | sort -u || true)
absent AC-014-04-09 "$BUILD" 'scripts/'
absent AC-014-04-09 "$ORCH" 'scripts/'
absent AC-014-04-09 "$BUILD" '\.github/workflows'
absent AC-014-04-09 "$ORCH" '\.github/workflows'

# ── Task 5 — agents/spec-pr-opener.md (AC-014-05) ────────────────────────────
OPENER_FM="$(frontmatter "$OPENER")"

echo "Task 5 — fix-round re-push mode in the PR Opener prompt..."
# AC-014-05-01 — fix-round re-push mode: conventional commit on the existing branch
contains AC-014-05-01 "$OPENER" 'fix round'
contains AC-014-05-01 "$OPENER" 'conventional commit'
contains AC-014-05-01 "$OPENER" 'failing check ID'
contains AC-014-05-01 "$OPENER" 'existing `spec/NNN-slug` branch'
# AC-014-05-02 — no second PR is opened; the existing PR is confirmed
contains AC-014-05-02 "$OPENER" 'do not open a new PR'
contains AC-014-05-02 "$OPENER" 'gh pr view'
# AC-014-05-03 — the re-push re-triggers the Self CI workflow
contains AC-014-05-03 "$OPENER" 're-triggers the Self CI'
# AC-014-05-04 — initial-open and safety rules are unchanged
contains AC-014-05-04 "$OPENER" '30-report.md'
contains AC-014-05-04 "$OPENER" 'main`/`master'
contains AC-014-05-04 "$OPENER" 'Never create git version tags'
# AC-014-05-05 — frontmatter is unchanged; git push*: ask still permits the re-push
str_contains AC-014-05-05 'spec-pr-opener.md frontmatter' "$OPENER_FM" '"git push*": ask'
# AC-014-05-06 — no open-ended re-run phrasing is added
absent AC-014-05-06 "$OPENER" "$BANNED"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "Post-PR CI loop check: all assertions hold."
  exit 0
else
  echo "$FAILED assertion(s) failed!"
  exit 1
fi
