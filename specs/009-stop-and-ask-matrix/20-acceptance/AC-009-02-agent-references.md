# AC-009-02: Every pipeline agent references the matrix as authoritative

## AC-009-02-01 — All 8 agents reference the matrix section

Given the 8 pipeline agent files:
`agents/spec-pipeline.md`, `agents/spec-specifier.md`, `agents/spec-ux.md`,
`agents/spec-coder.md`, `agents/spec-refactorer.md`, `agents/spec-verifier.md`,
`agents/spec-mutation-runner.md`, and `agents/spec-pr-opener.md`

When each file is read
Then each contains the exact section title `Stop-and-Ask decision matrix`

## AC-009-02-02 — Each reference states the matrix is authoritative

Given each of the 8 pipeline agent files
When the file's reference to the matrix is read
Then it states the matrix is authoritative for that agent — the agent resolves
the listed conditions per the matrix, never by improvisation

## AC-009-02-03 — No other pipeline-touching file is required to change

Given the repo after this spec's implementation
When git status of `agents/` is inspected
Then the only changed agent files are the 8 listed in AC-009-02-01
