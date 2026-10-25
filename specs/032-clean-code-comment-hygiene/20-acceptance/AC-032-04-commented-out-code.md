# AC-032-04: Commented-out code is reported

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-04-01 — Two consecutive code-shaped comment lines produce one finding
Given a throwaway source directory whose `src/Ledger.java` contains, inside a method,
```
// total = price * quantity;
// printTotal(total);
```
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
Then the output contains exactly one `Comments: commented-out code` finding
And the finding is anchored at the line of the first comment
And the run exits 0 (WARN by default)

## AC-032-04-02 — A single code-shaped comment line is not a finding
Given a Java file containing one commented-out statement `// total = 1;`
When `--gates comments` runs
Then the output contains no `Comments:` finding
And the run exits 0

## AC-032-04-03 — Two consecutive prose comment lines are not a finding
Given a Java file containing
```
// The totals are kept in cents to avoid rounding drift.
// See the billing note above for the historical reason.
```
When `--gates comments` runs
Then the output contains no `Comments:` finding
And the run exits 0
And a `/* ... */` block whose two continuation lines each end in `;` does produce one `Comments: commented-out code` finding
