# AC-045-05: Verdict parser and fail-closed behaviour

## AC-045-05-01 — A pass for the head is accepted
Given a comments JSON whose latest comment for head `abc123` ends with
`Reviewed-SHA: abc123` and `Review-Verdict: pass`
When `scripts/pr-review-verdict.sh --head-sha abc123` runs
Then it prints `verdict=pass`
And the exit code is 0

## AC-045-05-02 — Findings fail the check
Given a comments JSON whose latest comment for head `abc123` carries
`Review-Verdict: findings`
When the parser runs for head `abc123`
Then it prints `verdict=findings`
And the exit code is 1

## AC-045-05-03 — No comment for the head is missing
Given a comments JSON with no comment carrying `Reviewed-SHA: abc123`
When the parser runs for head `abc123`
Then it prints `verdict=missing`
And the exit code is 1

## AC-045-05-04 — A missing verdict line is malformed
Given a comments JSON whose latest comment for head `abc123` carries
`Reviewed-SHA: abc123` but no `Review-Verdict:` line
When the parser runs for head `abc123`
Then it prints `verdict=malformed`
And the exit code is 1

## AC-045-05-05 — Verdict values are case-sensitive
Given a comments JSON whose latest comment for head `abc123` carries
`Review-Verdict: PASS`
When the parser runs for head `abc123`
Then it prints `verdict=malformed`
And the exit code is 1

## AC-045-05-06 — Multiple verdict lines are malformed
Given a comments JSON whose latest comment for head `abc123` carries both
`Review-Verdict: pass` and `Review-Verdict: findings`
When the parser runs for head `abc123`
Then it prints `verdict=malformed`
And the exit code is 1

## AC-045-05-07 — The latest comment wins
Given two comments for head `abc123`: an older one with
`Review-Verdict: findings` and a newer one with `Review-Verdict: pass`
When the parser runs for head `abc123`
Then it prints `verdict=pass`
And the exit code is 0

## AC-045-05-08 — A newer findings comment supersedes an older pass
Given two comments for head `abc123`: an older one with
`Review-Verdict: pass` and a newer one with `Review-Verdict: findings`
When the parser runs for head `abc123`
Then it prints `verdict=findings`
And the exit code is 1
