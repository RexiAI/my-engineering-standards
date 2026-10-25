# AC-032-03: Comment scanning covers shell and honours the exclusions

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-03-01 — `*.sh` files are scanned for comments
Given a throwaway source directory whose `src/ok.sh` contains
```
#!/bin/bash
echo start
echo middle-one
echo middle-two
echo middle-three
# echo "alpha";
# echo "beta";
echo done
```
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
Then the output contains `Comments: commented-out code`
And the finding names `ok.sh`
And the run exits 0 (the rule is WARN by default)

## AC-032-03-02 — Excluded directories are not scanned
Given a throwaway source directory containing the same two-line commented-out-code violation in `src/a.sh`, `docs/b.sh`, `specs/c.sh`, `agents/d.sh`, `templates/e.sh`, and `node_modules/f.sh`
When `--gates comments` runs against it
Then exactly one `Comments: commented-out code` finding is reported
And it names `src/a.sh`
And no output line names `docs/b.sh`, `specs/c.sh`, `agents/d.sh`, `templates/e.sh`, or `node_modules/f.sh`

## AC-032-03-03 — Shell is not dragged into the existing gates
Given a throwaway source directory whose `src/branchy.sh` contains one function with seven `if` statements
When `--gates complexity` runs
Then the output contains no `Cyclomatic complexity` finding
And it contains no `KISS` finding for `branchy.sh`
And when `--gates comments` runs, the output contains no complexity or KISS text

## AC-032-03-04 — The scanned-extension message names shell, and its test is updated
Given an empty throwaway directory
When the script runs with no `--gates` filter
Then the output contains `scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh`
And `scripts/tests/check-code-principles.bats` contains that same extension string in its ADR-0006 D5 assertion
