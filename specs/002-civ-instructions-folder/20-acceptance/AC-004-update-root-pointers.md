# AC-004: Root pointers point at instructions, not the slimmed index

## AC-004-01 — `AGENTS.md` points at `00-pipeline-overview.md` for behavior
Given the root `AGENTS.md`
When the file is searched for behavioral pointers
Then every reference that needs the pipeline's role/stage mechanics
points at `.standards/instructions/00-pipeline-overview.md` (or a
stricter sibling)

## AC-004-02 — `AGENTS.md` keeps the slimmed-index link only for meta
Given the root `AGENTS.md`
When the file is read
Then any reference to `docs/SPEC_PIPELINE.md` is for meta-only content
(such as the pipeline's overall shape, archive-on-merge,
scenario-format conventions, model-configuration notes)
And the link is still a real file

## AC-004-03 — README references stay resolvable
Given the root `README.md`
When the file is searched for any `.standards/`, `instructions/`,
or `SPEC_PIPELINE.md` reference
Then each link still resolves to a real file or section
