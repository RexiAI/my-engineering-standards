# AC-001: Empirical context benchmark harness

## AC-001-01 — Full sweep over the default context values
Given a running ollama server with qwen3.8:27b available
And no arguments other than --out pointing at a writable path
When scripts/benchmark-ollama-context.sh --out <file> is run
Then the script exits 0
And <file> is a CSV with one header row, four data rows (one per num_ctx 16384, 32768, 49152, 65536), and one summary line

## AC-001-02 — Report columns are complete
Given a completed benchmark run with output file <file>
When the data rows of <file> are inspected
Then each row records num_ctx, size_vram_gib, tokens_per_sec, prompt_tokens, context_loaded, and probe_result
And size_vram_gib is derived from the ollama /api/ps size_vram for the loaded model converted to GiB
And the thread-retention probe and tokens_per_sec are measured via the OpenAI-compatible chat completions endpoint (/v1/chat/completions) — the endpoint opencode actually uses to call the model — not /api/generate
And tokens_per_sec is completion tokens divided by wall-clock generation time from the /v1/chat/completions response

## AC-001-03 — Probe passes when the follow-up answer contains the marker
Given a probe whose turn-1 message embeds a unique marker token in its first 64 tokens
And the turn-2 completion contains that marker token
When the probe result is evaluated
Then probe_result is PASS

## AC-001-04 — Probe fails when the marker was dropped by truncation
Given a probe whose turn-1 message embeds a unique marker token in its first 64 tokens
And the turn-2 completion does not contain that marker token
When the probe result is evaluated
Then probe_result is FAIL

## AC-001-05 — Under-filled probe is invalid, not a pass or fail
Given a probe run at a given num_ctx
And prompt_tokens is less than 0.8 times num_ctx
When the row is recorded
Then probe_result is INVALID
And the row is excluded from the selection rule

## AC-001-06 — Requested context not honored is invalid
Given a probe run at num_ctx N
And the loaded context reported by the server differs from N
When the row is recorded
Then probe_result is INVALID
And the row is excluded from the selection rule

## AC-001-07 — Selection picks the largest fully viable context
Given a completed report whose rows satisfy probe_result=PASS, size_vram_gib <= 16.0, and tokens_per_sec >= 15
When the summary line is computed
Then the summary records as selected the largest num_ctx among those rows
And the summary line records the thresholds used (min tokens/sec and VRAM headroom)

## AC-001-08 — No viable context records selected=NONE
Given a completed report where no row satisfies probe_result=PASS together with the size and speed thresholds
When the summary line is computed
Then the summary records selected=NONE
And the script still exits 0

## AC-001-09 — Probe-only mode reports pass or fail
Given a running ollama server with qwen3.8:27b available
When scripts/benchmark-ollama-context.sh --probe-only <N> is run
Then the script exits 0 if the retention probe at context N passes
And the script exits 1 if the retention probe at context N fails

## AC-001-10 — Tooling failure exits 2
Given an invocation with no --out argument
Or an unreachable ollama server
Or a model that is not present on the server
When scripts/benchmark-ollama-context.sh is run
Then the script exits 2 with a message naming the failure
