# AC-003: Agent specs are pointer-only

## AC-003-01 — Each spec has exactly one pointer line
Given any of `agents/spec-specifier.md`, `agents/spec-ux.md`,
`agents/spec-coder.md`, `agents/spec-refactorer.md`,
`agents/spec-verifier.md`, `agents/spec-architect.md`,
`agents/spec-pipeline.md`
When the file is searched for the string
".standards/instructions/"
Then exactly one line in the file matches

## AC-003-02 — Specifier points at `01-specify.md`
Given `agents/spec-specifier.md`
When the file is read
Then the pointer line references
`.standards/instructions/01-specify.md`

## AC-003-03 — Coder points at `03-implement.md`
Given `agents/spec-coder.md`
When the file is read
Then the pointer line references
`.standards/instructions/03-implement.md`

## AC-003-04 — Verifier points at `05-verify.md`
Given `agents/spec-verifier.md`
When the file is read
Then the pointer line references
`.standards/instructions/05-verify.md`

## AC-003-05 — No restated rules in agent specs
Given any of the seven `agents/spec-*.md` files
When the file is searched for known rule strings
(layer-order lists, retry budgets, gate catalogs, hand-off JSON
examples)
Then none of them appear in the agent spec
