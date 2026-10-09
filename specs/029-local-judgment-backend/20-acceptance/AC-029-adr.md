# AC-029: ADR 0005

## AC-029-50 — ADR 0005 exists
Given the spec 029 changes are applied
When the repo is inspected
Then `docs/adr/0005-local-judgment-backend.md` exists

## AC-029-51 — ADR documents billing-constraint change
Given ADR 0005 exists
When it is read
Then it states the billing-constraint change: the typed-judgment layer now supports an optional local compute backend alongside the hosted paid API

## AC-029-52 — ADR documents backend-switch semantics
Given ADR 0005 exists
When it is read
Then it documents `JUDGMENT_BACKEND` values (`local`, `hosted`)
And documents the default (`hosted`)
And documents auth behavior per mode (key required for hosted, optional for local)
And documents the optionality guarantee (unset/unconfigured → exit 10)

## AC-029-53 — ADR summarizes spike results
Given ADR 0005 exists
When it is read
Then it contains a spike-results section with measured numbers: VRAM, latency p50, accuracy, confidence distributions
And the numbers match the spike report

## AC-029-54 — ADR documents recalibrated threshold
Given ADR 0005 exists
When it is read
Then it states the recalibrated `JUDGMENT_MIN_CONFIDENCE` value
And states the method used to derive it
And the value matches the spike report and config template

## AC-029-55 — ADR extends ADR 0004
Given ADR 0005 exists
When it is read
Then it states it extends (not supersedes) ADR 0004

## AC-029-56 — ADR indexed
Given ADR 0005 exists
When `docs/adr/README.md` is read
Then it lists ADR 0005

## AC-029-57 — ADR respects no-docs-mirror
Given ADR 0005 exists
When it is read
Then provider/product names (Kev, CLM, jaredpalmer, Contrastive-LM) appear only in the evidence section
And general references use "local judgment backend"

## AC-029-58 — Content-contract test verifies ADR
Given the spec 029 changes are applied
When `scripts/tests/typed-judgment-integration.bats` is run
Then a content-contract test verifies ADR 0005 exists and contains sections for billing-constraint, backend-switch, spike-summary, and threshold
