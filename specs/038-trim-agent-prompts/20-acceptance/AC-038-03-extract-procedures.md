# AC-038-03: Over-cap agents trimmed

## AC-038-03-01 — Each formerly over-cap agent within cap
Given spec-verifier, spec-ux, spec-pr-opener, spec-pipeline, spec-deployer
When `wc -l` runs on each
Then each count is ≤ 120

## AC-038-03-02 — Extracted artifacts referenced and exist
Given a trimmed agent file
When every `scripts/...` or `skills/...` path it cites is resolved
Then each path exists in the repo
