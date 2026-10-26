# AC-035: `--dry-run` plan-only mode

## AC-035-24 — `--dry-run` prints the plan and performs no mutation
Given an eligible, clean child git repository whose `.standards` pointer is behind its remote
When the script runs with `--dry-run`
Then a plan line is printed describing the action that would be taken for the child
And no branch is created
And no commit is created
And nothing is pushed
And no pull request is opened

## AC-035-25 — `--dry-run` makes no network calls
Given an eligible, clean child git repository whose `.standards` remote is an unreachable URL
When the script runs with `--dry-run`
Then the script completes without attempting to fetch from the unreachable remote
And a plan line is still printed for the child
