# AC-036-03: Duplication check script

## AC-036-03-01 — Clean fixture passes
Given a fixture repo whose agents/*.md share no normalized line of 8+ words with docs/SPEC_PIPELINE.md
And all section references resolve
When scripts/check-agent-doc-duplication.sh <fixture> runs
Then it exits 0 and prints one OK line

## AC-036-03-02 — Verbatim duplicate flagged
Given a fixture where agents/x.md line 5 equals docs/SPEC_PIPELINE.md line 20 and has 8+ words
When the script runs
Then it exits 1
And prints "agents/x.md:5: duplicated from docs/SPEC_PIPELINE.md:20"

## AC-036-03-03 — Whitespace and list-marker differences still match
Given agents/x.md has "-   Do not   run stage-5 agents unless the Verifier passes" and the doc has "Do not run stage-5 agents unless the Verifier passes"
When the script runs
Then it exits 1 and reports the duplicate

## AC-036-03-04 — Below threshold ignored
Given the only shared normalized line has 7 words
When the script runs
Then it exits 0

## AC-036-03-05 — Exactly threshold flagged
Given the only shared normalized line has exactly 8 words
When the script runs
Then it exits 1

## AC-036-03-06 — Code blocks and headings excluded
Given the only shared 8+-word lines are inside fenced code blocks or are heading lines
When the script runs
Then it exits 0

## AC-036-03-07 — Unresolved section reference flagged
Given agents/x.md line 3 contains "docs/SPEC_PIPELINE.md §No Such Heading"
And the doc has no heading "No Such Heading"
When the script runs
Then it exits 1
And prints "agents/x.md:3: unresolved section reference §No Such Heading"

## AC-036-03-08 — Resolved ### reference accepted
Given agents/x.md references "docs/SPEC_PIPELINE.md §Never-list" and the doc has "### Never-list"
When the script runs
Then it exits 0

## AC-036-03-09 — Missing inputs
Given a fixture without docs/SPEC_PIPELINE.md or without agents/
When the script runs
Then it exits 2
