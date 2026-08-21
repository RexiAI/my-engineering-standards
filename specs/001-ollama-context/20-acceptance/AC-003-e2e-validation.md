# AC-003: End-to-end validation on the local model

## AC-003-01 — A real stage runs on the local model
Given the ollama service runs with the Task 2 override applied
When scripts/validate-ollama-e2e.sh is run
Then it invokes opencode run targeting the spec-specifier agent with SPEC_SPECIFIER_MODEL=ollama/qwen3.8:27b exported for the run
And the invocation completes with exit code 0

## AC-003-02 — No "no user query found" errors in the run's log slice
Given a completed e2e run whose start timestamp was recorded before the opencode invocation
When the log slice [run start, now] of ~/.local/share/opencode/log/opencode.log is searched for "no user query found" with modelID=qwen3.8:27b
Then zero occurrences are found
And the script exits 0

## AC-003-03 — Thread is retained across turns
Given an e2e run whose turn-1 prompt embeds a unique marker token
And whose turn-2 follow-up asks for that marker
When the turn-2 final answer is inspected
Then it contains the marker token
And the script exits 0

## AC-003-04 — Decision line is emitted for the fallback wiring
Given a completed e2e run with --out <file>
When the script output is inspected
Then stdout and <file> carry LOCAL_STAGES=<space-separated agent ids> and CLOUD_FALLBACK_STAGES=<space-separated agent ids>
And every one of the eight stage agents appears in exactly one of the two lists

## AC-003-05 — A failing stage is recorded as cloud fallback
Given an e2e run in which a stage produces a non-zero exit, or a "no user query found" error in its log slice, or a context-overflow error in its session
When the decision line is emitted
Then that stage is listed in CLOUD_FALLBACK_STAGES and absent from LOCAL_STAGES

## AC-003-06 — Tooling failure exits 2
Given opencode is not available
Or the log file ~/.local/share/opencode/log/opencode.log is unreadable
When scripts/validate-ollama-e2e.sh is run
Then it exits 2 with a message naming the failure
