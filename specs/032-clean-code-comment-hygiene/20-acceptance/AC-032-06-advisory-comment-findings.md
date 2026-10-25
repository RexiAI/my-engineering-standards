# AC-032-06: Advisory comment findings are WARN-only

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-06-01 — TODO and FIXME without an issue reference warn
Given a Java file containing `// TODO: handle retry`
And a shell file containing `# FIXME fix this before release`
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
Then the output contains two `Comments: TODO/FIXME without an issue reference` findings
And the run exits 0

## AC-032-06-02 — An issue reference suppresses the TODO/FIXME finding
Given a source directory containing
`// TODO(#123): handle retry`, `// TODO 456`, and `// FIXME https://example.com/i/7`
When `--gates comments` runs
Then the output contains no `Comments: TODO/FIXME without an issue reference` finding
And the run exits 0

## AC-032-06-03 — Section dividers and attributions warn
Given a source directory containing `// ==========`, `# ---------`, `// @author Jane Doe`, `// Created by Jane Doe`, and `// -- note`
When `--gates comments` runs
Then the output contains two `Comments: section-divider comment` findings
And it contains two `Comments: attribution comment` findings
And the `// -- note` line produces neither finding
And the run exits 0

## AC-032-06-04 — Advisory findings never become FAIL
Given the fixture from AC-032-06-01
When `--gates comments` runs with `STRICT_CLEAN_CODE=1`
And when `--gates comments --blocking comments` runs
Then each run exits 0
And each output contains `WARN`
And no output line for these two findings contains `FAIL`
