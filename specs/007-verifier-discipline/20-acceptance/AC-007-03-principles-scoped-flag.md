# AC-007-03: check-code-principles.sh supports scoped gates, JSON output, and a tooling-failure exit code

## AC-007-03-01 — `--gates` runs only the listed gate categories (AC-003)
Given a scratch source tree containing one `complexity` violation (a method with cyclomatic complexity >6) and one `dry` violation (an identical duplicated 4-line block)
When `scripts/check-code-principles.sh --gates dry` runs against that tree
Then the output contains the DRY finding but no Cyclomatic complexity FAIL
And the script exits 0 for the dry-only finding being a WARN (duplication is a WARN), or 1 if the fixture's DRY finding is a FAIL — matching the fixture's severity
And the summary reports the subset of gates that ran

## AC-007-03-02 — `--gates complexity` fires only the complexity gate
Given a scratch source tree containing a method with cyclomatic complexity >6
And the same tree contains a DRY violation and a YAGNI violation
When `scripts/check-code-principles.sh --gates complexity` runs against that tree
Then the script exits 1
And the output reports the CC>6 FAIL
And the output contains no DRY, YAGNI, SOLID, or property-test findings

## AC-007-03-03 — `--gates` combines with `--tier` and `--warn-as-error`
Given a scratch tree whose `AGENTS_*.md` declares `Conformance tier: mvp`
When `scripts/check-code-principles.sh --gates complexity --tier production` runs against it
Then `--tier production` is honored (e.g. property-tests would be required if `property-tests` were among the gates)
And `scripts/check-code-principles.sh --gates dry --warn-as-error` promotes a DRY WARN to a failure (exit 1) instead of a WARN

## AC-007-03-04 — An unknown gate name is a usage error (exit 2)
Given `scripts/check-code-principles.sh` accepts gate names complexity, dry, yagni, solid, and property-tests
When the script runs with `--gates bogus`
Then the script writes an error message to stderr naming the unknown gate
And the script exits 2

## AC-007-03-05 — `--json` emits the same findings as machine-readable output with the same exit code
Given a scratch source tree with no principle violations
When `scripts/check-code-principles.sh --json` runs against it
Then stdout is a single JSON object containing `tier`, `gates`, an empty `fails` array, and the `warns` present
And the script exits 0

## AC-007-03-06 — `--json` with a finding includes the FAIL and still exits 1
Given a scratch source tree with one cyclomatic-complexity violation
When `scripts/check-code-principles.sh --gates complexity --json` runs against it
Then the JSON object's `fails` array contains one entry with the message and file reference for the violation
And the script exits 1

## AC-007-03-07 — A missing tool is a tooling failure (exit 2), never a false PASS
Given the script runs on a system where a required tool such as `awk` or `find` is unavailable
When `scripts/check-code-principles.sh` runs
Then the script does not exit 0
And the script exits 2 (or otherwise non-0, non-1) with an error to stderr naming the missing tool
And the run never prints a PASS summary for a gate it could not execute

## AC-007-03-08 — Default invocation is unchanged
Given `scripts/check-code-principles.sh` before this task runs all five gates and exits 0 or 1
When the script runs with no `--gates` and no `--json`
Then it still runs all five gate categories
And it exits 0 when no FAILs and 1 when findings exist, matching its prior behavior
