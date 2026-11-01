#!/usr/bin/env bats
# ac-037-index-doc.bats — acceptance tests for spec 037 Task 1
# (specs/037-split-spec-pipeline-doc/20-acceptance/AC-037-01-index-doc.md).
# The index stays at docs/SPEC_PIPELINE.md so existing bare links resolve.

load test_helper
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"

@test "AC-037-01-01: index keeps the cross-cutting sections" {
  # The autopilot never-list is the `## Autopilot mode` section's Never-list
  # subsection; both must be reachable in the index.
  run grep -E '^## (Stages|Artifact layout|Stop-and-Ask decision matrix|Commit and push carve-out|Remediation budget|Autopilot mode|Stage files)$' "$DOC"
  [ "$status" -eq 0 ]
  for heading in "Stages" "Artifact layout" "Stop-and-Ask decision matrix" \
                 "Commit and push carve-out" "Remediation budget" "Autopilot mode" \
                 "Stage files"; do
    grep -qxF "## $heading" "$DOC" || { echo "missing index heading: $heading" >&2; return 1; }
  done
  # the autopilot never-list itself (refusals, not decisions) stays in the index
  grep -qxF '### Never-list' "$DOC"
  grep -qxF '### Hard stops' "$DOC"
}

@test "AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit" {
  # Snapshot of the rows at the 036-merged base commit (spec 037 split them
  # verbatim). Frozen here so the assertion survives the split landing on main.
  cat > "$BATS_TEST_TMPDIR/expected-rows" <<'ROWS'
| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery (wrong directory, `.standards/` submodule missing) | Ask for the absolute path once; never scaffold (no `git init`, no submodule creation) unprompted |
| Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`) | Tell the user to run `/spec` first; never create the artifacts yourself |
| Project type ambiguous (language stack / conformance tier undetectable) | Defer to the harness default (`mvp` tier; language per `language-specific/<lang>/SKILL.md`); ask only if interactive and unconfirmed |
| Version bump / git tag not requested | Off by default; never infer from SemVer or the diff; never create git tags — CI (Semantic Release) owns versioning |
| A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold) | Fix the code, never the threshold — gate config is off-limits to agents |
| Design gate WARN (not FAIL) | Record in the report; do not stop; flag to the Architect |
| Out-of-scope finding | Record it (Verifier: `25-verification.md`); do not fix; propose a follow-up spec |
| Acceptance criteria ambiguous | Resolve before delegating implementation — stop and ask one specific question |
| Verifier verdict FAIL | STOP the pipeline; relay the report; do not run stage-5 agents; do not fix it yourself |
| Deploy verification fails | Route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess |
| PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green) | STOP; commit nothing, push nothing |
ROWS
  awk '/^## Stop-and-Ask decision matrix$/{f=1;next} f && /^## /{exit} f' "$DOC" \
    | grep '^|' > "$BATS_TEST_TMPDIR/actual-rows"
  run diff -u "$BATS_TEST_TMPDIR/expected-rows" "$BATS_TEST_TMPDIR/actual-rows"
  [ "$status" -eq 0 ]
  # and no row was silently dropped
  [ "$(grep -c '^|' "$DOC" | head -1)" -ge 14 ]
}

@test "AC-037-01-03: index length is at most 250 lines" {
  local n
  n="$(awk 'END { print NR }' "$DOC")"
  [ "$n" -le 250 ]
}

@test "AC-037-01-04: every stage-file path in the Stage files table exists" {
  local listed
  listed="$(awk '/^## Stage files$/{f=1;next} f && /^## /{exit} f' "$DOC" \
    | grep -oP 'docs/spec-pipeline/[a-z-]+\.md' | sort -u)"
  [ -n "$listed" ]
  while IFS= read -r ref; do
    [ -f "$REPO_ROOT/$ref" ] || { echo "missing stage file: $ref" >&2; return 1; }
  done <<< "$listed"
}

@test "unit: index keeps the stage table rows 5a-5d" {
  for row in '| 5a | Mutation Runner |' '| 5b | PR Opener |' '| 5c | Deploy Verifier |' '| 5d | Archiver |'; do
    grep -qF "$row" "$DOC" || { echo "missing stage row: $row" >&2; return 1; }
  done
}
