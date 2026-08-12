# AC-007-02: Verifier documents scoped re-verification for BLOCK fixes

## AC-007-02-01 — spec-verifier.md documents re-running only the failing gates on a BLOCK fix (AC-002)
Given `agents/spec-verifier.md` is the Verifier agent's instruction file
When a BLOCK (or FAIL) has been fixed
Then the Verifier re-runs only the gate(s) that blocked, not the whole suite
And the unchanged gates' prior results stand without being re-executed

## AC-007-02-02 — spec-verifier.md names the scoped flags available to the Verifier
Given task 3 adds `--gates` to `scripts/check-code-principles.sh`
And task 4 adds `--checks` to `scripts/check-scenario-traceability.sh`
When task 2 completes
Then `agents/spec-verifier.md` documents `--gates` for re-running only the failing design-principles category
And `agents/spec-verifier.md` documents `--checks` for re-running only the failing traceability check
And `agents/spec-verifier.md` states that a gate which is a single whole script is re-run whole — still scoped relative to the full suite

## AC-007-02-03 — A one-line fix must not re-run every scan
Given a BLOCK caused by a one-line defect in one gate
When the fix is made and the Verifier re-verifies
Then the Verifier re-runs only the failing gate, not the test suite or every scan
And the report reflects that the other gates were not re-executed

## AC-007-02-04 — The re-verification appends to the existing report instead of rewriting it
Given `specs/NNN-slug/25-verification.md` contains the prior full run for every gate
When a BLOCK fix triggers scoped re-verification
Then the re-run results are appended under the gate they belong to in the existing report
And the prior full run's content is preserved in the report
And the overall verdict reflects the re-run

## AC-007-02-05 — "Gate" means one of the Verifier's six checks
Given the Verifier runs checks 1 (traceability), 2 (test suite), 3 (complexity linter), 3.5 (design-principles), 4 (spot check), and 5 (no unaccounted behavior)
When scoped re-verification is invoked for a failing gate
Then only that check's commands are re-executed
And the scoped flags narrow a script-backed check further where the script supports it
