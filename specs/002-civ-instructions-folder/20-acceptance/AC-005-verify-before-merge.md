# AC-005: Verification before merge

## AC-005-01 — Traceability check passes
Given a `spec/NNN-*/` working spec on the branch
When `bash scripts/check-scenario-traceability.sh` is run
Then it exits `0`

## AC-005-02 — No duplicated rule text between `docs/` and `.standards/`
Given the repository's working tree
When `grep -F` is run for representative rule text against both
`docs/SPEC_PIPELINE.md` and `.standards/instructions/*.md`
Then no matches appear identically in both directories

## AC-005-03 — Draft PR is opened and CI is green
Given this change is committed on a `spec/002-civ-instructions-folder`
branch
When the branch is pushed and a draft PR is opened
Then the PR's CI run is green
