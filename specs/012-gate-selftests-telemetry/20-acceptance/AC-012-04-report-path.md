# AC-012-04: gate scripts accept -ReportPath for telemetry output

## AC-012-04-01 — check-code-principles.sh writes its JSON report to the given file (AC-002)
Given a scratch source tree with one cyclomatic-complexity violation
When `scripts/check-code-principles.sh -ReportPath /tmp/rpt.json "$SCRATCH"` runs
Then `/tmp/rpt.json` exists and contains a single JSON object with `tier`, `gates`, `fails`, and `warns` keys
And the `fails` array contains the complexity violation
And the script exits 1 (same as without `-ReportPath`)
And human-readable stdout is unchanged (still prints FAIL/WARN lines and the summary)

## AC-012-04-02 — -ReportPath combines with --gates and --json without collision
Given a scratch tree with a DRY violation only
When `scripts/check-code-principles.sh -ReportPath /tmp/rpt.json --gates dry --json "$SCRATCH"` runs
Then the JSON is written to both stdout (via `--json`) and `/tmp/rpt.json`
And both contain the DRY finding
And the script exits 0 (DRY is a WARN)

## AC-012-04-03 — check-scenario-traceability.sh writes its JSON report to the given file
Given a scratch specs tree with an orphaned scenario
When `bash scripts/check-scenario-traceability.sh -ReportPath /tmp/trace.json "$SPECS" "$SRC"` runs
Then `/tmp/trace.json` exists and contains a single JSON object with `passes` and `fails`
And the `fails` array contains the orphaned scenario ID
And the script exits 1

## AC-012-04-04 — A missing -ReportPath value is a usage error (exit 2)
Given `-ReportPath` with an empty value
When the script runs
Then it writes an error to stderr
And it exits 2 (the 007-defined could-not-run code)

## AC-012-04-05 — The report file is written atomically
Given a scratch run that produces a report
When `-ReportPath` is used
Then the file is written via a temp sibling renamed into place
And a reader never observes a partially-written report

## AC-012-04-06 — Default behavior without -ReportPath is unchanged
Given `scripts/check-code-principles.sh` before this task
When it runs with no `-ReportPath` and no `--json`
Then stdout and exit codes are exactly as before
