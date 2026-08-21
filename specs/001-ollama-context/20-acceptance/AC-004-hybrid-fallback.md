# AC-004: Per-stage hybrid fallback wiring

## AC-004-01 — Local stages resolve to the local model
Given the Task 3 decision file lists stages in LOCAL_STAGES
When config/model.local.env is parsed
Then every stage in LOCAL_STAGES has SPEC_<STAGE>_MODEL=ollama/qwen3.8:27b

## AC-004-02 — Fallback stages resolve to the cloud model
Given the Task 3 decision file lists stages in CLOUD_FALLBACK_STAGES
When config/model.local.env is parsed
Then every stage in CLOUD_FALLBACK_STAGES has SPEC_<STAGE>_MODEL=opencode-go/deepseek-v4-flash

## AC-004-03 — No stage is left unassigned or set to another value
Given the eight agent names from opencode.json (spec-specifier, spec-ux, spec-verifier, spec-mutation-runner, spec-pr-opener, spec-coder, spec-refactorer, spec-pipeline)
When config/model.local.env is parsed
Then exactly eight SPEC_*_MODEL variables are set, one per agent
And every variable's value is either ollama/qwen3.8:27b or opencode-go/deepseek-v4-flash

## AC-004-04 — Header documents mechanism, restart, and spending-limit caveat
When the header comments of config/model.local.env are read
Then they state that opencode.json still resolves agent.*.model from {env:SPEC_*_MODEL} unchanged
And they state that a restart of opencode is required for the change to take effect
And they state that the opencode-go fallback may be unavailable until the monthly $25 spend limit resets

## AC-004-05 — Wiring check passes when values match the decision
Given config/model.local.env and the Task 3 decision file both exist
And every stage value matches the decision mapping
When scripts/check-ollama-hybrid-wiring.sh is run
Then it exits 0

## AC-004-06 — Wiring check fails and names the stage on mismatch
Given config/model.local.env and the Task 3 decision file both exist
And at least one stage value disagrees with the decision mapping
When scripts/check-ollama-hybrid-wiring.sh is run
Then it exits 1 and names the mismatching stage

## AC-004-07 — Missing input exits 2
Given the Task 3 decision file is missing
Or config/model.local.env is missing or unreadable
When scripts/check-ollama-hybrid-wiring.sh is run
Then it exits 2 with a message naming the missing input
