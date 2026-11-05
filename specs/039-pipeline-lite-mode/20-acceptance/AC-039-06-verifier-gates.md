# AC-039-06: Verifier hard gates retained in lite

## AC-039-06-01 — Hard gates run in lite
Given resolved mode `lite`
When the Verifier runs
Then the test suite, `scripts/check-no-hardcoded-secrets.sh`, `scripts/check-code-principles.sh`, and scenario traceability each run

## AC-039-06-02 — Principles FAIL stops lite run
Given resolved mode `lite`
And `scripts/check-code-principles.sh` reports FAIL
When the Verifier finishes
Then the verdict is FAIL
And the PR Opener is not invoked

## AC-039-06-03 — Secrets finding stops lite run
Given resolved mode `lite`
And the secrets scan exits non-zero
When the Verifier finishes
Then the verdict is FAIL
And no commit or push occurs
