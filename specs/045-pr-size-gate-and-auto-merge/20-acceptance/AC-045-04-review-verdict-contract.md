# AC-045-04: The pr-review output contract carries a verdict

## AC-045-04-01 — The contract names both verdict lines
Given `agents/pr-review.md`
When its output-contract section is read
Then it requires the line `Review-Verdict: pass` for a review with no findings
And it requires the line `Review-Verdict: findings` for a review with findings

## AC-045-04-02 — The verdict matches the findings count
Given `agents/pr-review.md`
When the output-contract section is read
Then `pass` is required only when zero findings are reported
And `findings` is required when one or more findings are reported

## AC-045-04-03 — Omission is fail-closed, not a silent pass
Given `agents/pr-review.md`
When the output-contract section is read
Then it states the values are case-sensitive
And it states that omitting the line or emitting any other value is a
fail-closed failure for the workflow

## AC-045-04-04 — Reviewed-SHA is unchanged
Given `agents/pr-review.md`
When the output contract is read
Then it still requires the final marker line `Reviewed-SHA: <head sha>`
And the verdict line is required after that marker

## AC-045-04-05 — Scope lock and permission block are unchanged
Given `agents/pr-review.md`
When its scope lock and frontmatter are read
Then it still forbids `auto-merge`, approval, `describe`, `improve`,
`auto-apply`, and push
And the `permission` block still denies `edit` and `bash`

## AC-045-04-06 — The existing review checks stay green
Given the updated `agents/pr-review.md`
When `scripts/check-pr-review.sh` runs
Then it exits 0
