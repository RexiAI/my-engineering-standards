# AC-035: Progression (branch, push, PR, and `--local`)

## AC-035-15 — Default mode creates a branch, commits, pushes, and opens a PR
Given an eligible, clean child git repository whose `.standards` pointer is behind its remote
When the script processes the child in default mode
Then a branch named `chore/bump-engineering-standards` is created
And the pointer bump is committed on that branch
And the branch is pushed to the child's remote
And a pull request is opened from that branch against the child's default branch via `gh pr create`
And no commit is made to `main`/`master`

## AC-035-16 — A re-run reuses the existing branch and open PR without duplicating
Given a prior run already created the branch `chore/bump-engineering-standards` and an open PR for it in a child
When the script runs again over the same child
Then no duplicate branch is created
And no duplicate PR is created (exactly one open PR remains for the branch)

## AC-035-17 — `--local` commits on the current branch only
Given an eligible, clean child git repository whose `.standards` pointer is behind its remote
When the script processes the child with `--local`
Then the pointer bump is committed on the current branch
And no new branch is created
And nothing is pushed
And no pull request is opened
