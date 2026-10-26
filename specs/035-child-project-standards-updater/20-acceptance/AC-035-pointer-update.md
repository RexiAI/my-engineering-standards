# AC-035: Submodule pointer update and commit

## AC-035-06 — Moved remote pointer is fetched, updated, and committed
Given a candidate git repository with an initialized `.standards` submodule
And the `.standards` remote has a newer commit than the child's current pointer
When the script processes the candidate
Then the child's `.standards` pointer is updated to the remote's current commit
And a local commit is created whose message uses the conventional `chore:` prefix and names the standards submodule
And the commit touches only the `.standards` pointer and no other tracked files

## AC-035-07 — Already-at-latest pointer produces no commit
Given a candidate git repository with an initialized `.standards` submodule
And the child's `.standards` pointer is already at the remote's current commit
When the script processes the candidate
Then the pointer is unchanged
And no new commit is created
And the candidate is reported as already at latest
