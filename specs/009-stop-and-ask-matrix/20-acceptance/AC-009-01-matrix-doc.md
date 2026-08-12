# AC-009-01: Stop-and-Ask decision matrix present in docs/SPEC_PIPELINE.md

## AC-009-01-01 — Matrix section exists

Given the repo file `docs/SPEC_PIPELINE.md`
When the file is read
Then it contains a heading `## Stop-and-Ask decision matrix`

## AC-009-01-02 — Matrix declares itself authoritative

Given the section `## Stop-and-Ask decision matrix` in `docs/SPEC_PIPELINE.md`
When the section body is read
Then it states the matrix is authoritative for every pipeline agent and that
agents resolve listed conditions per the matrix, never by improvisation

## AC-009-01-03 — All 11 conditions have deterministic actions

Given the matrix table in `docs/SPEC_PIPELINE.md`
When every row is read
Then the conditions "Working tree dirty", "Repo not found after discovery",
"Spec artifacts not found", "Project type ambiguous",
"Version bump / git tag not requested", "A design gate blocks",
"Design gate WARN", "Out-of-scope finding",
"Acceptance criteria ambiguous", "Verifier verdict FAIL", and
"PR Opener precondition fails" are all present, each with a deterministic action

## AC-009-01-04 — No Confluence row

Given the matrix table in `docs/SPEC_PIPELINE.md`
When the table is scanned
Then no row references Confluence or a doc space or parent page

## AC-009-01-05 — Dirty working tree action is STOP and report

Given the matrix row for condition "Working tree dirty"
When the row's action is read
Then it is STOP and report, and it forbids stashing and auto-committing
