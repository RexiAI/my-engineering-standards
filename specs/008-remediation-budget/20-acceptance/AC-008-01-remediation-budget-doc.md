# AC-008-01: Remediation budget documented in docs/SPEC_PIPELINE.md

## AC-008-01-01 — Phase 1 documented with a max-3 budget (AC-001)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it contains a remediation-budget section that names a **Phase 1 — Pre-PR loop** covering the local gates and the design gates
And the section states the Verifier BLOCK hands back to Coder/Refactorer
And the section states the Phase 1 budget is **max 3**

## AC-008-01-02 — Phase 2 documented with an independent max-3 budget (AC-001)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it contains a **Phase 2 — Post-PR loop** covering the CI gates that run after the push
And the section states the Phase 2 budget is **max 3**
And the section states the Phase 2 counter is **independent of Phase 1**

## AC-008-01-03 — Budget exhaustion stops the pipeline and escalates to the human
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the section states that exhausting either budget stops the pipeline
And the section states the pipeline emits the failing gate IDs and the last evidence
And the section states the pipeline escalates to the human

## AC-008-01-04 — The forbidden phrasing appears verbatim (AC-003)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the section contains the exact string `re-run until green is forbidden phrasing`

## AC-008-01-05 — Scoped re-verification on BLOCK
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the section states that on a BLOCK the Verifier re-runs only the failing gates
And the section states the Verifier does not re-run the whole suite

## AC-008-01-06 — 30-report.md records phase and attempt count (AC-004)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the section states that `30-report.md` records which phase and attempt count each BLOCK was resolved at

## AC-008-01-07 — The section reconciles with the carve-out halt rule
Given `docs/SPEC_PIPELINE.md` is edited per task 1
And the existing "Commit and push carve-out" section says "Any gate failure halts the pipeline"
When the file is read
Then the two statements read consistently: a gate failure triggers remediation up to the cap
And the halt the carve-out describes is the post-exhaustion stop, not an immediate stop

## AC-008-01-08 — The section does not specify Phase 2 loop mechanics
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the remediation-budget section does not describe how CI status is queried or how failing CI logs are read
And no other section of the file is changed by task 1
