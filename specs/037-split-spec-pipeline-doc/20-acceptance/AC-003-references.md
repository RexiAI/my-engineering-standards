# AC-037-03: Reference rewrite

## AC-037-03-01 — Moved-section references repointed
Given a reference `docs/SPEC_PIPELINE.md §X` where section X moved to `docs/spec-pipeline/f.md`
When `agents/ commands/ AGENTS.md docs/ scripts/ skills/` are grepped
Then no reference `docs/SPEC_PIPELINE.md §X` remains and `docs/spec-pipeline/f.md §X` is used instead

## AC-037-03-02 — Index-section references unchanged
Given a reference `docs/SPEC_PIPELINE.md §Remediation budget`
When the rewrite is applied
Then the reference still points at `docs/SPEC_PIPELINE.md`

## AC-037-03-03 — Agents read only their slice
Given each `agents/spec-*.md` stage agent
When its reading instructions are inspected
Then it names its own `docs/spec-pipeline/<stage>.md` and specific index sections, and contains no instruction to read all of `docs/SPEC_PIPELINE.md`
