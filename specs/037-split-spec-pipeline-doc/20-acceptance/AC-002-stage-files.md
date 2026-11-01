# AC-037-02: Per-stage files

## AC-037-02-01 — One file per stage agent
Given the split is complete
When `docs/spec-pipeline/` is listed
Then it contains specifier.md, ux.md, coder.md, refactorer.md, verifier.md, mutation-runner.md, pr-opener.md, deployer.md

## AC-037-02-02 — Every original section lands exactly once
Given the list of top-level `##` headings in `docs/SPEC_PIPELINE.md` at the base commit
When headings across the new index and `docs/spec-pipeline/*.md` are collected
Then each original heading appears in exactly one file

## AC-037-02-03 — Named sections in their owning stage file
Given the split is complete
When headings are located
Then "Scenario format" is in specifier.md, "Conformance tiers" and "Tooling by language" in coder.md, "Archive in the PR" in pr-opener.md, "Deploy verification loop (phase 3)" in deployer.md

## AC-037-02-04 — Stage file back-pointer
Given any stage file in `docs/spec-pipeline/`
When its first 5 lines are read
Then they reference `docs/SPEC_PIPELINE.md` and name the index sections the stage must read
