# AC-014-05: PR Opener performs fix-round re-pushes

## AC-014-05-01 — Fix-round re-push mode (AC-003)
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt is read
Then it states that when invoked for a fix round it commits the fix as a conventional commit referencing the failing check ID(s)
And it states the commit lands on the existing `spec/NNN-slug` branch and is pushed

## AC-014-05-02 — No second PR is opened
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt is read
Then it states the PR Opener does not open a new PR during a fix round
And it confirms the existing PR (e.g. `gh pr view`) and pushes to its branch

## AC-014-05-03 — Re-push re-triggers CI
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt is read
Then it states the fix-round push re-triggers the Self CI workflow on the branch and the PR

## AC-014-05-04 — Initial-open and safety rules are unchanged
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt is read
Then it still requires `30-report.md` to be green before the initial PR open
And it still forbids committing to `main`/`master`
And it still forbids creating git tags

## AC-014-05-05 — Frontmatter is unchanged
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt's frontmatter is read
Then its permission rules are unchanged
And `git push*: ask` still permits the re-push without a new grant

## AC-014-05-06 — No open-ended re-run phrasing is added
Given `agents/spec-pr-opener.md` is edited per task 5
When the prompt is read
Then it does not contain `re-run until green`
And it does not contain any equivalent instruction to re-push without a stated cap
