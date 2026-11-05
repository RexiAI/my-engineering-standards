# AC-041: Test-run reuse helper

Applies to Task 4. All scenarios use scratch git repositories; none touches the
repo's own worktree.

## AC-041-27 — Hash output is one lowercase sha256 line

Given a scratch git repo with one commit and a clean worktree
When `scripts/test-run-reuse.sh --print-hash` runs
Then stdout is exactly one line
And that line matches `^[0-9a-f]{64}$`
And the script exits 0

## AC-041-28 — The hash is deterministic on an unchanged tree

Given a scratch repo with a dirty tracked file
When `--print-hash` runs twice with no change in between
Then both runs print the same 64-character hash
And both exit 0

## AC-041-29 — A tracked content change changes the hash

Given a scratch repo with a clean worktree
When a tracked file's content is modified without staging
Then `--print-hash` prints a different hash than before the modification

## AC-041-30 — A new untracked file changes the hash

Given a scratch repo with a clean worktree
When a new file is created inside a new subdirectory and left untracked
Then `--print-hash` prints a different hash than before the file was created

## AC-041-31 — A new commit changes the hash

Given a scratch repo whose worktree content is identical before and after
`git commit --allow-empty`
When `--print-hash` runs before and after that commit
Then the two hashes differ

## AC-041-32 — A matching hash authorizes reuse

Given a `25-verification.md` whose `## Evidence: full test suite` block carries
`exit: 0` and a `Test-run hash:` line equal to `--print-hash`'s current output
When `scripts/test-run-reuse.sh --check <file>` runs
Then stdout is `REUSE <hash>`
And the script exits 0

## AC-041-33 — A hash mismatch forces a re-run

Given the same block but a `Test-run hash:` value that differs from the current
`--print-hash` output
When `--check <file>` runs
Then stdout is `RERUN hash-mismatch`
And the script exits 1

## AC-041-34 — No evidence block forces a re-run

Given a `25-verification.md` with no `## Evidence: full test suite` block
When `--check <file>` runs
Then stdout is `RERUN no-evidence-block`
And the script exits 1

## AC-041-35 — A non-zero recorded exit forces a re-run

Given the block with a matching `Test-run hash:` but `exit: 1`
When `--check <file>` runs
Then stdout is `RERUN exit-nonzero`
And the script exits 1

## AC-041-36 — A missing hash line forces a re-run

Given the block with `exit: 0` and no `Test-run hash:` line
When `--check <file>` runs
Then stdout is `RERUN hash-missing`
And the script exits 1

## AC-041-37 — Usage error and non-repo are tooling errors

Given a directory that is not a git work tree
When `--print-hash` runs there
Then the script exits 2
And stdout carries no hash
Given no arguments
When the script runs
Then it exits 2
And stderr prints the usage block
