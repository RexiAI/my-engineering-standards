# AC-029: Confidence recalibration and config templates

## AC-029-40 — model.local.env.example gains JUDGMENT_BACKEND
Given the spec 029 changes are applied
When `config/model.local.env.example` is read
Then it contains a commented line `# JUDGMENT_BACKEND=local`
And a comment explains valid values (`local` | `hosted`) and states the default is `hosted`

## AC-029-41 — model.local.env.example gains local URL example
Given the spec 029 changes are applied
When `config/model.local.env.example` is read
Then it contains a commented `JUDGMENT_API_URL` line with a local URL example (port from spike report)

## AC-029-42 — model.local.env.example has recalibrated threshold
Given the spec 029 changes are applied
When `config/model.local.env.example` is read
Then it contains a commented `JUDGMENT_MIN_CONFIDENCE` line with the recalibrated value
And a comment states the derivation method (e.g. "5th percentile of correct-answer confidence on spike fixtures")
And the value matches the spike report's recommendation

## AC-029-43 — Existing hosted config lines preserved
Given the spec 029 changes are applied
When `config/model.local.env.example` is read
Then the existing `JUDGMENT_API_URL`, `JUDGMENT_MODEL`, `JUDGMENT_DAILY_CAP` commented lines are still present
And their values are unchanged from spec 028

## AC-029-44 — agent.local.env.example notes key optionality
Given the spec 029 changes are applied
When `config/agent.local.env.example` is read
Then the existing `JUDGMENT_API_KEY` line is present
And a comment states the key is optional when `JUDGMENT_BACKEND=local`

## AC-029-45 — No secrets committed
Given the spec 029 changes are applied
When `scripts/check-no-hardcoded-secrets.sh` is run
Then the exit code is 0
And no real API keys, tokens, or credentials appear in any tracked file

## AC-029-46 — Content-contract tests verify config presence
Given the spec 029 changes are applied
When `scripts/tests/typed-judgment-integration.bats` is run
Then content-contract tests verify `config/model.local.env.example` contains `JUDGMENT_BACKEND`
And contains a local URL example
And contains a recalibrated `JUDGMENT_MIN_CONFIDENCE` comment
