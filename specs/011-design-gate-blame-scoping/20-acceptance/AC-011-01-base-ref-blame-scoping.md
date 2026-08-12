# AC-011-01: check-code-principles.sh accepts `-BaseRef` and applies blame scoping

## AC-011-01-01 — The script accepts the literal `-BaseRef <ref>` flag (AC-001)
Given `scripts/check-code-principles.sh` with a scratch git repo and a resolvable base ref
When the script runs with `-BaseRef <ref>` plus the positional source directory
Then the run succeeds and applies blame scoping rather than rejecting the flag as unknown
And the run does not exit 2 for an unrecognized option

## AC-011-01-02 — An unknown `-*` option still exits 2
Given `scripts/check-code-principles.sh`
When the script runs with a `-*` option other than `-BaseRef` (or a flag the script supports)
Then the script writes "Unknown option" to stderr and exits 2

## AC-011-01-03 — A pre-existing finding in a touched file is WARN, not FAIL (AC-001)
Given a scratch git repo with a base commit containing a legacy method whose cyclomatic complexity is >6
And the working tree touches that file by one line that does not overlap the legacy method's line range
When the script runs with `-BaseRef <base>`
Then the complexity finding is reported as WARN, not FAIL
And the script exits 0

## AC-011-01-04 — A diff-introduced finding is FAIL (AC-001)
Given a scratch git repo with a clean base commit
And the working tree adds a method whose cyclomatic complexity is >6 inside a touched file
When the script runs with `-BaseRef <base>`
Then the complexity finding is reported as FAIL
And the script exits 1

## AC-011-01-05 — Complexity overlap is tested against the whole method span
Given a scratch git repo where a legacy method with cyclomatic complexity >6 spans lines 10-40 of a file
And the working tree edits a line inside that method's span (e.g. line 25)
When the script runs with `-BaseRef <base>`
Then the finding is classified as diff-introduced and reported as FAIL
And the script exits 1

## AC-011-01-06 — Without `-BaseRef` behavior is unchanged (AC-001)
Given `scripts/check-code-principles.sh` before this change runs all five gate categories and exits 0 or 1
When the script runs with no `-BaseRef` and no new flags
Then it runs the same gate categories with the same severities as before the change

## AC-011-01-07 — Unresolvable base ref or non-git tree is a tooling failure, never a false PASS
Given `scripts/check-code-principles.sh` run with `-BaseRef not-a-real-ref`
Or run with `-BaseRef <ref>` outside a git repository
When the script attempts to compute the diff
Then it writes an error to stderr naming the failed diff operation
And the script exits 2 (not 0 and not 1)

## AC-011-01-08 — Files with no diff overlap are not evaluated (AC-001)
Given a scratch git repo whose working tree touches only file A
And an unrelated legacy complexity violation exists in file B
When the script runs with `-BaseRef <base>`
Then no finding is reported for file B
And the script exits 0

## AC-011-01-09 — A file added entirely by the diff is fully diff-introduced (AC-001)
Given a scratch git repo where the working tree adds a brand-new file containing a complexity violation
When the script runs with `-BaseRef <base>`
Then the violation is classified as diff-introduced and reported as FAIL
And the script exits 1
