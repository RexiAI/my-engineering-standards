# AC-041: Stage wiring for the summary helper

Applies to Task 3. "Stage procedure" means wherever that stage's steps live after
037/038: its `agents/spec-*.md` file and/or its `docs/spec-pipeline/<stage>.md`
file.

## AC-041-21 — Verifier's full-test-suite block records the filtered shape

Given a `25-verification.md` produced after Task 3
When the `## Evidence: full test suite` block is read
Then its `command:` line contains `scripts/agent-test-summary.sh --run` and the
real test command verbatim after `--`
And its body contains the `SUMMARY:` line
And its body contains `full log: §Raw log: full test suite`

## AC-041-22 — The append recipe puts the full log in the evidence file verbatim

Given the canonical append recipe from the stage procedure
And a fixture log file
When the recipe is executed against a fixture `25-verification.md` with that log
Then the appended `## Raw log: full test suite` section's content, from the line
after its blank line to the next `^## ` heading or EOF, is byte-identical to the
fixture log (equal sha256)
And the recipe's only access to the log path is `cat "$LOG"` inside that append
redirect — no other use of `$LOG` appears

## AC-041-23 — Every suite-running stage cites the helper

Given `agents/spec-coder.md`, `agents/spec-refactorer.md`,
`agents/spec-verifier.md`, `agents/spec-mutation-runner.md` and the stage files
under `docs/spec-pipeline/`
When those texts are searched for `scripts/agent-test-summary.sh`
Then each of the four stages' procedures contains at least one reference

## AC-041-24 — The append recipe exists exactly once

Given `agents/` and `docs/spec-pipeline/`
When searched for the append recipe that writes a `## Raw log:` section
Then exactly one occurrence exists
And every stage refers to it rather than repeating it

## AC-041-25 — Design-principles and complexity lanes are never filtered

Given the Verifier's design-principles and complexity gate invocations
When they are read
Then each invokes `scripts/check-code-principles.sh` (and the language complexity
linter) directly
And neither routes its output through `scripts/agent-test-summary.sh`
And the procedure still requires every FAIL and WARN line verbatim

## AC-041-26 — Agent caps and orchestration stay green

Given the tree after Task 3
When `scripts/check-agent-line-cap.sh` runs
Then it exits 0
When `scripts/check-orchestration.sh` runs
Then it exits 0
