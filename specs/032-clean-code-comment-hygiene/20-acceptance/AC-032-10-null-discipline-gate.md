# AC-032-10: The null-discipline gate reports null returns and null arguments

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-10-01 — return null is reported
Given a Java file containing `String find() { return null; }`
And a TypeScript file containing `function f() { return null; }`
When `bash scripts/check-code-principles.sh --gates null-discipline <dir>` runs
Then the output contains two `Null-discipline: return null` findings
And the run exits 0

## AC-032-10-02 — Null arguments are reported; comparisons and assignments are not
Given a Java file containing `helper(null);`, `helper(1, null);`, `return x == null;`, `Object s = null;`, and `return c ? this : null;`
When `--gates null-discipline` runs
Then the output contains two `Null-discipline: null argument` findings
And it contains no `Null-discipline: return null` finding
And it reports nothing for `x == null`, the local assignment, or the ternary

## AC-032-10-03 — Python and Rust are not scanned
Given a Python file containing `def f(): return None` and `helper(None)`
And a Rust file containing `fn f() -> Option<u8> { None }`
When `--gates null-discipline` runs
Then the output contains no `Null-discipline:` finding
And the run exits 0

## AC-032-10-04 — Null findings never become FAIL
Given the fixture from AC-032-10-01
When `--gates null-discipline --blocking null-discipline` runs with `STRICT_CLEAN_CODE=1`
Then every `Null-discipline:` finding is prefixed `WARN`
And the run exits 0
