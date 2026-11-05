# AC-041: Test-log summary helper

Applies to Task 2. Every scenario runs against a scratch log path outside the
repo; no scenario writes into `specs/`.

## AC-041-09 — `--run` captures the full log and prints only the summary

Given a command that prints three lines and exits 0, none of them a signal line
When `scripts/agent-test-summary.sh --run <log> -- <command>` runs
Then `<log>` contains the command's output byte-for-byte
And stdout is exactly one line
`SUMMARY: mode=run exit=0 signal=0 log_lines=<n> log=<log>`
And the helper exits 0

## AC-041-10 — A command with no output yields a zero-valued summary

Given a command that prints nothing and exits 0
When the helper runs with `--run <log> --`
Then `<log>` exists and is empty
And stdout is exactly one line with `signal=0` and `log_lines=0`
And the helper exits 0

## AC-041-11 — A failing command keeps its signal lines and its exit status

Given a command that prints `FAIL TestA` and `FAIL TestB` and exits 1
When the helper runs
Then both `FAIL` lines appear on stdout verbatim, in that order
And the last line is `SUMMARY: mode=run exit=1 signal=2 log_lines=<n> log=<log>`
And `<log>` still contains the complete output
And the helper exits 1

## AC-041-12 — Exit status other than 1 passes through unchanged

Given a command that exits 42
When the helper runs with `--run`
Then the helper exits 42
And the summary line records `exit=42`

## AC-041-13 — Missing command exits 127

Given `--run <log> -- no-such-command-041`
When the helper runs
Then the helper exits 127
And the summary line records `exit=127`
And `<log>` exists

## AC-041-14 — At most 50 signal lines are printed

Given a log of 500 short signal lines, each a `FAIL` line
When the helper runs with `--read`
Then exactly 50 signal lines appear on stdout
And the next line is `TRUNCATED: 450 more signal lines omitted; full log: <log>`
And the summary line records `signal=500`

## AC-041-15 — The 8,192-byte cap stops the signal block

Given a log of 5 signal lines, each 2,048 characters long
When the helper runs with `--read`
Then 3 signal lines are printed
And the truncation line reads `TRUNCATED: 2 more signal lines omitted; full log: <log>`
And the printed signal block is at most 8,192 bytes

## AC-041-16 — Zero-count lines are not signals

Given a log containing `failures=0` and `OK 12 tests` and no other failure marker
When the helper runs with `--read`
Then no signal line is printed
And the summary line records `signal=0`

## AC-041-17 — A log path inside `specs/` is refused before the command runs

Given `--run specs/041-pipeline-token-savings/evidence.log -- touch <marker>`
When the helper runs
Then the helper exits 2
And stderr contains `refusing to write a log inside specs/`
And `<marker>` was not created
And no file was created under `specs/`

## AC-041-18 — `--read` formats an existing failing log and exits 0

Given a log file containing three `FAIL` lines
When `scripts/agent-test-summary.sh --read <log>` runs
Then three signal lines are printed
And the last line is `SUMMARY: mode=read exit=- signal=3 log_lines=<n> log=<log>`
And the helper exits 0

## AC-041-19 — `--read` on a missing file is a tooling error

Given a path that does not exist
When the helper runs with `--read <missing>`
Then the helper exits 2
And stdout is empty
And stderr names the path

## AC-041-20 — No mode is a usage error

Given no arguments
When the helper runs
Then the helper exits 2
And stderr prints the usage block
