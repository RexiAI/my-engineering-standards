# AC-008-02: Verifier encodes the budget and scoped re-verification

## AC-008-02-01 — Verifier stops relaying BLOCKs after 3 (AC-002)
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it states the Verifier stops relaying BLOCKs after **3** per phase
And it states the Verifier must not expect or accept a 4th re-verification of the same BLOCK

## AC-008-02-02 — Re-trigger means scoped re-verification, not the whole suite
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it instructs the Verifier, on a re-trigger, to read its prior `25-verification.md`
And it instructs the Verifier to re-run only the gates that previously failed
And it instructs the Verifier to record per-gate results for just those gates, not to re-run the full suite

## AC-008-02-03 — Re-verification attempt index and phase are recorded
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it requires the Verifier to record the re-verification attempt index and the phase in `25-verification.md` on every re-verification

## AC-008-02-04 — Final BLOCK report carries the escalation payload
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then its "On failure" section still says the Verifier does not fix anything itself
And it instructs the final BLOCK report to name the failing gate IDs and the last evidence
And it instructs the final BLOCK report to state that the phase budget is exhausted

## AC-008-02-05 — Frontmatter and permissions are unchanged
Given `agents/spec-verifier.md` is edited per task 2
When the prompt's frontmatter is read
Then it still allows edits only to `specs/*/25-verification.md`
And it still denies commits and pushes

## AC-008-02-06 — No open-ended re-run phrasing is added
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it does not contain `re-run until green`
And it does not contain any equivalent instruction to re-verify without a stated cap
