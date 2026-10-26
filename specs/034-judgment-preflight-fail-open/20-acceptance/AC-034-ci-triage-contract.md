# AC-034: Task 6 — audit `skills/ci-triage/SKILL.md`

## AC-034-24 — ci-triage exit 10 runs the stock classification unchanged
Given the `ci-triage` skill's typed-judgment fast-path in `skills/ci-triage/SKILL.md`
When the fast-path returns exit 10
Then the skill is instructed to run the existing LLM classification procedure unchanged
And it never maps exit 10 to a block or an escalation by itself

## AC-034-25 — ci-triage telemetry records a reason
Given the `ci-triage` skill's fast-path returns exit 10
When the skill records its run-log judgment line
Then the line includes `"judgment_fallback":true`
And the line includes a `"reason"` field whose value is one of
`unconfigured`, `unreachable`, `payload_overflow`, `error`
