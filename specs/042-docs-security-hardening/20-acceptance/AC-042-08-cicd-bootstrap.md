# AC-042-08: The bootstrap example follows the PR-only rule

## AC-042-08-01 — The example branches before committing
Given the `### New Project` fenced block in `docs/CI_CD.md`
When the commit step is read
Then it contains a `git checkout -b` command
And the branch name is neither `main` nor `master`

## AC-042-08-02 — The example pushes the feature branch with an upstream
Given the same fenced block
When the push step is read
Then it contains `git push -u origin`
And the pushed ref is the branch created in the previous step

## AC-042-08-03 — The example opens a pull request
Given the same fenced block
When the final step is read
Then it contains `gh pr create`

## AC-042-08-04 — No bare push or push to the default branch remains
Given `docs/CI_CD.md`
When every line is checked
Then no line is exactly `git push`
And no command in the file pushes to `main` or `master`
And the `### CI Only (already bootstrapped)` section is unchanged
