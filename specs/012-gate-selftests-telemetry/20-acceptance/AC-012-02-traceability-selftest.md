# AC-012-02: check-scenario-traceability.sh selftest proves both checks in both directions

## AC-012-02-01 — A traced scenario passes (AC-001)
Given a scratch `specs/999-slug/20-acceptance/AC-999-01-traced.md` containing a `## AC-999-01 — widget renders` heading
And a scratch `src/widget_test.go` containing `TestWidget_AC_999_01`
When `check-scenario-traceability.selftest.sh` runs its `pass` fixture
Then the checker exits 0
And its output contains `AC-999-01 — traced to a test`

## AC-012-02-02 — An orphaned scenario is caught
Given a scratch `specs/999-slug/20-acceptance/` file containing a `## AC-999-02 —` heading
And a scratch `src/` directory whose files reference no AC ID at all
When the selftest runs its `orphan` fixture
Then the checker exits 1
And its output contains `no test references it` for AC-999-02

## AC-012-02-03 — A dangling test reference is caught
Given a scratch specs tree with a traced `## AC-999-03 —` heading
And a scratch `src/widget_test.go` citing `TestBogus_AC_888_88` (an ID with no heading)
When the selftest runs its `dangle` fixture
Then the checker exits 1
And its output contains `no matching scenario heading exists` for AC-888-88
And its output still shows AC-999-03 as traced

## AC-012-02-04 — Selftest passes only when all three cases assert correctly
Given `scripts/check-scenario-traceability.selftest.sh` exists
When it runs its pass, orphan, and dangle fixtures
Then it exits 0 only if all three produced their expected exit code and message
And on any failure it names the failing case and exits 1
And it removes its scratch trees (trap) regardless of outcome
