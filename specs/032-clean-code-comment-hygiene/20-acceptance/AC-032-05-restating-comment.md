# AC-032-05: A comment that restates the next line is reported

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-05-01 — A token-subset comment produces a finding
Given a Java file containing
```
// return total
return total;
```
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
Then the output contains `Comments: comment restates the following line`
And the run exits 0 (WARN by default)

## AC-032-05-02 — An extra token in the comment suppresses the finding
Given a Java file containing
```
// parse the config file
const parsed = parseConfig(file);
```
When `--gates comments` runs
Then the output contains no `Comments: comment restates the following line` finding
And the run exits 0

## AC-032-05-03 — Short comments and non-adjacent comments do not fire
Given a Java file containing a one-token comment `// total` directly above `return total;`
And a two-token comment `// return total`, a blank line, then `return total;`
And a two-token comment at the end of the file with no following line
When `--gates comments` runs
Then the output contains no `Comments: comment restates the following line` finding
And the run exits 0
