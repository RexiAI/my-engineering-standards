# AC-037-01: Index doc

## AC-037-01-01 — Index keeps cross-cutting sections
Given the split is complete
When `docs/SPEC_PIPELINE.md` headings are listed
Then it contains headings for Stages, Artifact layout, Stop-and-Ask decision matrix, Commit and push carve-out, Remediation budget, Autopilot mode never-list, and Stage files

## AC-037-01-02 — Stop-and-Ask rows unchanged
Given the Stop-and-Ask table rows at the base commit
When compared with the rows in the new index
Then they are byte-identical

## AC-037-01-03 — Index length cap
Given the split is complete
When `wc -l docs/SPEC_PIPELINE.md` runs
Then the count is ≤ 250

## AC-037-01-04 — Stage files table resolves
Given the "Stage files" table in the index
When each listed `docs/spec-pipeline/<stage>.md` path is checked
Then every path exists
