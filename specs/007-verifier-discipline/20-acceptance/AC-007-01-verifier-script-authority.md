# AC-007-01: Verifier states script-is-authority and missing-script = BLOCK verbatim

## AC-007-01-01 — spec-verifier.md contains the script-is-authority rule verbatim (AC-001)
Given `agents/spec-verifier.md` is the Verifier agent's instruction file
When task 1 completes
Then `agents/spec-verifier.md` contains, as a contiguous passage, exactly this text:
The script is the authority. The Verifier's verdict is a transcription of the gate script's exit code and JSON, never a judgment that overrides it. If its own reading of a diff disagrees with a deterministic gate, the gate wins.

## AC-007-01-02 — spec-verifier.md contains the missing/errored-script = BLOCK rule verbatim (AC-001)
Given `agents/spec-verifier.md` is the Verifier agent's instruction file
When task 1 completes
Then `agents/spec-verifier.md` contains, as a contiguous passage, exactly this text:
A missing/errored script is a BLOCK, not a pass. If check-code-principles.sh or check-scenario-traceability.sh fails to run (missing file, jq absent, non-zero for a reason other than a finding), the Verifier reports a tooling failure — it must not mark the gate green by reasoning about what the script "would have" checked.

## AC-007-01-03 — The report section defines PASS, FAIL, and BLOCK
Given `agents/spec-verifier.md`'s report section currently defines PASS and FAIL verdicts
When task 1 adds the missing-script rule
Then the report section defines a third verdict BLOCK for a gate that could not run or exited non-zero for a reason other than a finding
And the report section states that both FAIL and BLOCK stop the pipeline
And the report section states that a BLOCK report line names the tooling failure explicitly

## AC-007-01-04 — Verdict transcription comes from the gate, not the Verifier's reading
Given a deterministic gate such as `scripts/check-code-principles.sh`
When the Verifier's own reading of a diff disagrees with the gate's exit code or output
Then the report transcribes the gate's exit code and output as the verdict
And the gate wins over the Verifier's own reading

## AC-007-01-05 — Checks 1-5 and their order are unchanged
Given `agents/spec-verifier.md` defines checks 1, 2, 3, 3.5, 4, and 5 in order
When task 1 adds the two rules and the BLOCK verdict
Then checks 1, 2, 3, 3.5, 4, and 5 keep their current order, commands, and semantics
And no check is removed, renumbered, or given new execution behavior
