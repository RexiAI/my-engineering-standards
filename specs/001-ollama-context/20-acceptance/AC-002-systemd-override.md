# AC-002: Systemd ollama service override

## AC-002-01 — Template ships the three environment variables
Given the summary line of the Task 1 benchmark report records a selected context value S (not NONE)
When templates/ollama.service.d/context.conf is read
Then it contains exactly three Environment lines: OLLAMA_CONTEXT_LENGTH=S, OLLAMA_FLASH_ATTENTION=1, OLLAMA_KV_CACHE_TYPE=q8_0
And S equals the selected value recorded in the Task 1 report

## AC-002-02 — Applied override matches the template and takes effect
Given the template exists and the override was applied via systemctl daemon-reload and systemctl restart ollama
When scripts/check-ollama-override.sh is run
Then it exits 0
And /etc/systemd/system/ollama.service.d/context.conf is byte-identical to the template
And systemctl show ollama.service -p Environment carries all three variables with the template values
And ollama ps reports qwen3.8:27b with CONTEXT equal to the selected value

## AC-002-03 — Divergence between applied file and template is a failure
Given /etc/systemd/system/ollama.service.d/context.conf differs from templates/ollama.service.d/context.conf in any variable or value
When scripts/check-ollama-override.sh is run
Then it exits 1 and names the differing variable

## AC-002-04 — Wrong service environment is a failure
Given the applied file matches the template
But systemctl show ollama.service -p Environment does not carry all three variables with the template values
When scripts/check-ollama-override.sh is run
Then it exits 1

## AC-002-05 — Missing tooling exits 2
Given cmp, systemctl, or ollama is not available on the machine
When scripts/check-ollama-override.sh is run
Then it exits 2 with a message naming the missing tool

## AC-002-06 — Re-probe at the selected context passes under the target environment
Given the override has been applied and the ollama service restarted
When scripts/benchmark-ollama-context.sh --probe-only <selected> is run
Then it exits 0
And the report header of the run records flash attention on and KV cache type q8_0

## AC-002-07 — selected=NONE keeps the last-known-good context and reports SKIP
Given the Task 1 summary records selected=NONE
When the apply step is performed
Then the live override retains OLLAMA_CONTEXT_LENGTH=16384
And scripts/check-ollama-override.sh exits 0 with a SKIP report

## AC-002-08 — keepalive override is untouched
Given the apply step has been performed
When /etc/systemd/system/ollama.service.d/keepalive.conf is read
Then it still contains OLLAMA_KEEP_ALIVE=24h and no other variables
