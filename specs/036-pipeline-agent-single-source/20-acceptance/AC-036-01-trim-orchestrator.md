# AC-036-01: Trim agents/spec-pipeline.md to runtime procedure

## AC-036-01-01 — Frontmatter unchanged
Given agents/spec-pipeline.md before and after this change
When the frontmatter blocks are compared
Then they are byte-identical

## AC-036-01-02 — Stage order retained
Given the trimmed agents/spec-pipeline.md
When the /build section is read
Then it names spec-coder, spec-refactorer, spec-verifier, spec-mutation-runner, spec-pr-opener in that order

## AC-036-01-03 — /spec flow retained
Given the trimmed agents/spec-pipeline.md
When the /spec section is read
Then it delegates spec-specifier then spec-ux, relays BLOCKED, notes SKIPPED, and stops for human review

## AC-036-01-04 — Stop conditions retained
Given the trimmed agents/spec-pipeline.md
When it is searched for stop conditions
Then it states: no stage-5 agents unless Verifier PASS; no PR Opener unless Mutation Runner green; stop and relay when a stage cannot proceed; stop and escalate when the remediation budget is exhausted; on autopilot hard stop write the morning report and stop the queue

## AC-036-01-05 — Runtime actions retained
Given the trimmed agents/spec-pipeline.md
When it is searched
Then it contains scripts/judgment-preflight.sh and SPEC_LOOP_COUNT, SPEC_PHASE1_RETRIES, SPEC_PHASE2_RETRIES

## AC-036-01-06 — Never-list not restated
Given the trimmed agents/spec-pipeline.md
When it is searched for the never-list bullets ("no force-push", "no branch deletion", "no gate-threshold change", "no secret creation/rotation")
Then none is found
And a section reference "docs/SPEC_PIPELINE.md §Never-list" is present

## AC-036-01-07 — Doc rules referenced, not restated
Given the trimmed agents/spec-pipeline.md
When section references are listed
Then references exist for Remediation budget, Never-list, Commit and push carve-out, Autopilot mode, and Stop-and-Ask decision matrix
And the autopilot trigger definition (SPEC_AUTOPILOT=1 literal-token rule) is not restated

## AC-036-01-08 — File shrinks
Given the trimmed agents/spec-pipeline.md
When its lines are counted
Then the count is less than 140
