# AC-032-08: Comments are WARN by default and blocking when opted in

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-08-01 — Default classification is WARN with exit 0
Given a file containing two consecutive code-shaped comments
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs with `STRICT_CLEAN_CODE` unset
Then the output contains `Comments: commented-out code`
And the finding line is prefixed `WARN`
And the output contains no `FAIL` prefix on that finding
And the run exits 0

## AC-032-08-02 — STRICT_CLEAN_CODE=1 promotes the blocking-class rules
Given the same fixture
When `--gates comments` runs with `STRICT_CLEAN_CODE=1`
Then the `Comments: commented-out code` finding is prefixed `FAIL`
And the run exits 1

## AC-032-08-03 — --blocking comments promotes without the environment switch
Given the same fixture and an unset `STRICT_CLEAN_CODE`
When `--gates comments --blocking comments` runs
Then the `Comments: commented-out code` finding is prefixed `FAIL`
And the run exits 1

## AC-032-08-04 — Only the literal value 1 promotes, and advisory rules never promote
Given the same fixture
When the run uses `STRICT_CLEAN_CODE=0`, `STRICT_CLEAN_CODE=true`, and `STRICT_CLEAN_CODE=""` respectively
Then each run exits 0 and reports the finding as `WARN`
And given the TODO/FIXME fixture from AC-032-06-01, a run with `STRICT_CLEAN_CODE=1` exits 0 with the finding reported as `WARN`

## AC-032-08-05 — Python and Rust findings stay WARN under the strict switch
Given a Python fixture containing two consecutive code-shaped `#` comment lines
When `--gates comments` runs with `STRICT_CLEAN_CODE=1`
Then the finding is prefixed `WARN`
And the run exits 0 (ADR 0006 D6 warn phase)

## AC-032-08-06 — --json and -ReportPath carry the classification
Given a file containing two consecutive code-shaped comments
When `--gates comments --json` runs by default
Then the JSON `warns` array contains one entry whose `message` contains `Comments: commented-out code` and whose `file` and `line` are non-empty
And the JSON `fails` array is empty
And when the same run uses `STRICT_CLEAN_CODE=1`, the entry appears in `fails` and the process exits 1
And when `-ReportPath <file>` is used instead of `--json`, the written JSON shows the same classification
