# AC-035: Dirty and diverged child handling

## AC-035-13 — A dirty child is skipped and its working tree is left untouched
Given an eligible child git repository with uncommitted changes
When the script processes the child
Then the child is reported as skipped with a distinguishable status indicating it is dirty
And the run continues to the next child
And the child's uncommitted changes remain exactly as they were (no stash, reset, checkout, or clean)

## AC-035-14 — A diverged local branch is treated the same as dirty
Given an eligible child git repository whose local branch has diverged from its upstream
When the script processes the child
Then the child is reported as skipped with a distinguishable status
And the run continues to the next child
And no commit, push, or PR is created for the child
