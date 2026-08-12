# AC-009-03: "Fix the code, never the threshold" is enforced

## AC-009-03-01 — No agent may edit gate config

Given every pipeline agent file in `agents/`
When each file's `permission.edit` block (or its absence) is inspected
Then no agent may edit `scripts/check-code-principles.sh` or a linter config
that sets the complexity threshold (PMD / golangci / eslint config, or a
`.standards/` equivalent)

## AC-009-03-02 — Threshold stays a hard constant

Given `scripts/check-code-principles.sh`
When the script is read
Then the cyclomatic complexity threshold remains hard-coded at ≤6 and the
script exposes no threshold-override flag an agent could tune

## AC-009-03-03 — Script's threshold value unchanged

Given `scripts/check-code-principles.sh` before and after this spec's
implementation
When both versions are compared
Then the complexity threshold value is identical (6) in both

## AC-009-03-04 — Matrix row preserves the rule

Given the matrix in `docs/SPEC_PIPELINE.md`
When the row for condition "A design gate blocks" is read
Then its action is "Fix the code, never the threshold" and it states gate
config is off-limits to agents
