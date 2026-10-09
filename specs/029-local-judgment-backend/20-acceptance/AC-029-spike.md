# AC-029: Comparative hardware spike and report

## AC-029-01 — Spike report exists with required sections
Given the spec 029 pipeline has started
When Task 1 (spike) completes
Then `specs/029-local-judgment-backend/35-spike-report.md` exists
And the report contains a section for each candidate evaluated (Kev-4B, Kev-9B/8B, CLM path A, CLM path B, CLM path C)
And each evaluated candidate's section records: VRAM usage, p50 latency over ≥20 calls, accuracy on ≥10 ci-triage fixtures, accuracy on ≥10 spec-ux fixtures, confidence distribution, process count, startup time, model download size

## AC-029-02 — Spike declares winner and runner-up
Given the spike report exists
When the report is read
Then the report names exactly one winner with a stated rationale
And the report names exactly one runner-up with a stated rationale
And the winner is the first candidate in evaluation order that met all bar criteria

## AC-029-03 — Spike records recommended confidence threshold
Given the spike report exists
When the report is read
Then the report states a recommended `JUDGMENT_MIN_CONFIDENCE` value for the winning backend
And the report states the method used to derive it (e.g. "5th percentile of correct-answer confidence")
And the recommended value is a number between 0.0 and 1.0

## AC-029-04 — Spike records serving recipe for winner
Given the spike report exists
When the report is read
Then the report records the exact serving command for the winning recipe
And the report records the port number
And the report records the model identifier
And the report records the process count (1 for Kev, 2 for CLM)

## AC-029-05 — Spike records wire-compatibility result
Given the spike report exists
When the report is read
Then the report states whether `scripts/typed-judgment.sh` parses the winner's response with zero changes beyond the Task 2 backend switch
And if changes were needed, the report lists them

## AC-029-06 — Skipped candidates have recorded reasons
Given the spike report exists
And the winner was not the last candidate in evaluation order
When the report is read
Then each candidate after the winner has a one-line skip reason recorded
