# AC-010-01: docs/GOVERNANCE.md exists with the three required sections

## AC-010-01-01 — The governance document exists

Given the standards repo root
When the filesystem is scanned
Then a file `docs/GOVERNANCE.md` exists

## AC-010-01-02 — The document contains exactly the three required headings

Given `docs/GOVERNANCE.md`
When the top-level headings are read
Then it contains `## Trust Tiers`
And it contains `## Model-Assignment Discipline`
And it contains `## ADR Requirement`
And no other top-level `##` heading exists in the file

## AC-010-01-03 — The three sections appear in the required order

Given `docs/GOVERNANCE.md`
When the top-level headings are read in file order
Then `## Trust Tiers` appears before `## Model-Assignment Discipline`
And `## Model-Assignment Discipline` appears before `## ADR Requirement`

## AC-010-01-04 — The document declares the governance/operations split

Given `docs/GOVERNANCE.md`
When the opening paragraph is read
Then it states governance is separated from operations
And it points to `docs/SPEC_PIPELINE.md` as the operational home for pipeline mechanics
