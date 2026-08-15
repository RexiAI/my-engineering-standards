# AC-002: Slim `docs/SPEC_PIPELINE.md` to an index

## AC-002-01 — File opens with the redirect notice
Given `docs/SPEC_PIPELINE.md`
When the file is read
Then the first paragraph is "Behavioral rules now live under
`.standards/instructions/`. This document is an index."

## AC-002-02 — No duplicated rule text
Given `docs/SPEC_PIPELINE.md`
And given all `.standards/instructions/NN-*.md` files
When both are searched for the same paragraph text
Then no paragraph appears identically in both

## AC-002-03 — Human-review gate paragraph preserved verbatim
Given `docs/SPEC_PIPELINE.md`
When the file is read
Then it contains the "human-review gate" paragraph
And the paragraph text is preserved verbatim from the version before
this change

## AC-002-04 — Commit/push carve-out paragraph preserved verbatim
Given `docs/SPEC_PIPELINE.md`
When the file is read
Then it contains the "commit/push carve-out" paragraph
And the paragraph text is preserved verbatim from the version before
this change

## AC-002-05 — File still links from the README
Given the repository's `README.md`
When the file is searched for the string "SPEC_PIPELINE.md"
Then the link still resolves to a real file
And it points to the slimmed index, not to the
overlapping behavioral content
