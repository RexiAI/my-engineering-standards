# AC-041: Hash recording and suite reuse in the pipeline

Applies to Task 5.

## AC-041-38 — Verifier records the hash inside the full-test-suite block

Given a `25-verification.md` written after Task 5
When the `## Evidence: full test suite` block is read
Then it contains a `Test-run hash: <64-hex>` line immediately after the `at:` line
And `scripts/check-audit-trail.sh <slug>` exits 0 on that spec folder

## AC-041-39 — A tree that changes during the run is recorded, not hidden

Given a pre-run hash that differs from the post-run hash
When the Verifier writes the block
Then it records the post-run hash in `Test-run hash:`
And it adds the finding line `tree-changed-during-run` naming both hashes

## AC-041-40 — Reuse branch executes no test command

Given a `25-verification.md` whose block authorizes reuse
When the Mutation Runner's final-test-status step runs
Then `scripts/test-run-reuse.sh --check` prints `REUSE <hash>`
And no test command is executed
And the `30-report.md` row carries the Verifier's `command:`, `exit: 0` and `at:`
verbatim
And the row carries
`reused-from: 25-verification.md §Evidence: full test suite (test-run hash <hash>)`

## AC-041-41 — Re-run branch records its own evidence

Given a hash mismatch after mutation-kill work
When the Mutation Runner's final-test-status step runs
Then the suite runs through `scripts/agent-test-summary.sh --run`
And the `30-report.md` row carries that command, its real exit code, and a fresh
`at:` timestamp
And the row carries the post-run `Test-run hash:`
And no `reused-from:` line is written

## AC-041-42 — Mutation testing is never reused

Given the Mutation Runner's procedure
When it is searched for a reuse path
Then mutation testing is described as always running
And no instruction allows skipping or reusing the mutation run itself

## AC-041-43 — The Verifier never reuses

Given `agents/spec-verifier.md` and its stage file
When searched for `test-run-reuse.sh`
Then the only occurrence is `--print-hash`
And no occurrence of `--check` exists
And the procedure requires the Verifier to run the suite itself every time

## AC-041-44 — A reuse-form report still passes the audit-trail gate

Given a fixture spec folder whose `30-report.md` uses the `reused-from:` form
When `scripts/check-audit-trail.sh <slug>` runs
Then it exits 0
