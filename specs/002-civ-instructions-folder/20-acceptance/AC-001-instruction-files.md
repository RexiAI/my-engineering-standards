# AC-001: Author the nine instruction files

## AC-001-01 — `.standards/instructions/` exists with all nine files
Given this repository's working tree
When `.standards/instructions/` is listed
Then it contains exactly nine files: `00-pipeline-overview.md`,
`01-specify.md`, `02-design.md`, `03-implement.md`, `04-refactor.md`,
`05-verify.md`, `06-architect.md`, `07-archive.md`,
`99-validation-checklist.md`
And no other files exist in that directory

## AC-001-02 — Each file has YAML frontmatter with `description:`
Given any file in `.standards/instructions/`
When the file is read
Then its first line is `---` (frontmatter start)
And its frontmatter contains a `description:` key

## AC-001-03 — Step files declare `applyTo` matching their stage's edit surface
Given any of `02-design.md`, `03-implement.md`, `04-refactor.md`,
`05-verify.md`, `06-architect.md`, `07-archive.md`, `99-validation-checklist.md`
When the file is read
Then its YAML frontmatter contains an `applyTo:` key

## AC-001-04 — `02-design.md` `applyTo` matches frontend file extensions
Given `.standards/instructions/02-design.md`
When the file is read
Then its `applyTo` glob matches `**/*.{tsx,jsx,vue,svelte,css,scss,swift,kt}`
And the glob does not include backend extensions
(`java`, `go`, `py`, `rb`, `php`)

## AC-001-05 — `03-implement.md` covers the Coder's edit surface
Given `.standards/instructions/03-implement.md`
When the file is read
Then its `applyTo` glob matches `src/**`, `tests/**`, or `lib/**`

## AC-001-06 — `00-pipeline-overview.md` faithfully restates the pipeline shape
Given `docs/SPEC_PIPELINE.md §Stages` content
And given `.standards/instructions/00-pipeline-overview.md`
When the two are compared
Then every row in `docs/SPEC_PIPELINE.md §Stages`'s stage table has a
matching section in `00-pipeline-overview.md`
And no new rows were invented
And no existing rows were dropped
