# AC-032-07: The comment allowlist suppresses only what it names

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-07-01 — The first five lines of a file are never scanned
Given a shell file whose line 2 is `# ---------` and whose lines 4 and 5 are `# echo "alpha";` and `# echo "beta";`
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
Then the output contains no `Comments:` finding for that file
And the run exits 0

## AC-032-07-02 — Tool directives are skipped per line, and do not disable the file
Given `directives.sh` with lines 6 and 7 being `# shellcheck disable=SC2086` and `# shellcheck disable=SC2046` (both assignment-shaped and therefore code-shaped)
And `plain.sh` with `# ==========` on line 6
When `--gates comments` runs
Then no `Comments:` finding names `directives.sh`
And exactly one `Comments: section-divider comment` finding names `plain.sh`
And `# noqa: E501`, `# type: ignore`, and `# pragma: no cover` lines produce no finding

## AC-032-07-03 — ponytail and standards markers are preserved and skipped
Given a shell file containing the consecutive lines
```
# ponytail: total = 200;
# return total;
```
And a second file containing
```
# standards:allow-comment let total = 200;
# return total;
```
When `--gates comments` runs
Then neither file produces a `Comments: commented-out code` finding
And neither marker line is reported by any other comment rule
And the run exits 0

## AC-032-07-04 — Licence markers and URLs are skipped
Given a shell file containing the consecutive lines
```
# Licensed under MIT;
# return total;
```
And a second file containing
```
# https://example.com/let total = 5;
# return total;
```
And a third file containing `# SPDX-License-Identifier: MIT` and `# Copyright 2026 Acme`
When `--gates comments` runs
Then no `Comments:` finding is reported for any of the three files
And the run exits 0

## AC-032-07-05 — Doc blocks attached to public API are skipped; the same lines on private code are not
Given a Rust file containing
```
/// let x = compute();
/// return x;
pub fn compute() -> i32 { 1 }
```
And a Java file containing a `/** ... */` block whose two content lines are `* let x = 1;` and `* return x;`, immediately followed by `public void compute() { }`
And a Go file containing `// total := a + b;` and `// return total;` immediately followed by `func Add(a, b int) int { return a + b }`
When `--gates comments` runs
Then none of these three files produces a `Comments:` finding
And a control Java file with the same two content lines inside `/** ... */` followed by `private void compute() { }` does produce one `Comments: commented-out code` finding
And a control Rust file with the same two lines as plain `//` comments above `fn compute() -> i32 { 1 }` does produce one `Comments: commented-out code` finding
