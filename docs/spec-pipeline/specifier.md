# Specifier stage file (stage 1)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Artifact layout. Everything
else this stage needs is in the section below.

## Scenario format

No Cucumber, no Gherkin runner, in any language — see
`docs/spec-pipeline/rationale.md §Why no BDD runner`.
Scenarios are structured markdown with stable IDs:

```markdown
# AC-002: Apply discount to a product

## AC-002-01 — Apply a percentage discount
Given a product with base price 100.00
And a percentage discount of 20
When the discount is applied
Then the effective price is 80.00

## AC-002-02 — Price cannot go below zero
Given a product with base price 10.00
And a fixed amount discount of 50.00
When the discount is applied
Then the effective price is 0.00
```

The Coder turns each scenario into a normal test in the project's existing test
framework, with the ID in the test name:

- Java: `shouldApplyPercentageDiscount_AC_002_01()`
- Go: `TestAC_002_01_ApplyPercentageDiscount`
- JS/TS: `it("AC-002-01: applies a percentage discount", ...)`

The ID is what `scripts/check-scenario-traceability.sh` greps for
(`docs/spec-pipeline/rationale.md §Why no scenario mutation`).
