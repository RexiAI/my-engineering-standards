# AC-003: End-to-end + documentation

## AC-003-01 — PASS path pushes the branch
Given a fresh `spec/NNN-test-ship/` with a trivial feature that
satisfies all gates
When the user runs `/spec` then `/build` then `/ship`
Then the agent pushes the `spec/NNN-test-ship` branch

## AC-003-02 — BLOCK path halts with surfacing
Given a branch where the user introduces a failing scenario
When `/ship` is run
Then the agent halts
And the user sees the failing gate IDs and evidence in the response
And no push occurs

## AC-003-03 — Re-run after fix resumes PASS
Given the user removes the failing scenario
When `/ship` is run again
Then the gate-runner reports PASS
And the agent pushes the branch

## AC-003-04 — `README.md` documents `/ship`
Given the root `README.md`
When it is read
Then it contains a "Ship a feature" section
And it explains the `/spec` → `/build` → `/ship` flow

## AC-003-05 — Pipeline overview links to `/ship`
Given `.standards/instructions/00-pipeline-overview.md` (after
Phase A lands)
When it is read
Then it cross-links the `/ship` step
