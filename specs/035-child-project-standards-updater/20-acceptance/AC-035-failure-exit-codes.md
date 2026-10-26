# AC-035: Per-child failure handling and exit codes

## AC-035-18 — A child whose `.standards` submodule has no remote fails and is skipped
Given an eligible, clean child git repository whose `.standards` submodule has no remote configured
When the script processes the child
Then the child is reported failed with a reason indicating no remote
And the run continues to the next child
And the summary records the child as failed
And the exit code is 1

## AC-035-19 — A non-GitHub remote (or missing `gh`) fails in default mode
Given an eligible, clean child git repository whose remote is not GitHub, or where `gh` is unavailable
When the script processes the child in default mode
Then the child is reported failed with a reason
And the run continues to the next child
And the summary records the child as failed
And the exit code is 1

## AC-035-20 — A network failure during fetch is skipped and recorded
Given an eligible, clean child git repository whose `.standards` remote is unreachable
When the script processes the child
Then the fetch fails
And the child is reported failed with a reason indicating the fetch failed
And the run continues to the next child
And the exit code is 1

## AC-035-21 — A mixed run reports both outcomes and exits 1
Given a run over two eligible children, one that succeeds and one that fails (e.g. no remote)
When the script runs
Then the summary reports one success and one failure
And the failed child is named with its reason
And the exit code is 1

## AC-035-22 — Zero eligible children is success
Given discovery selects no eligible children
When the script runs
Then the summary reports that no children were processed
And the exit code is 0

## AC-035-23 — `--parent-dir` naming a non-existent path is a usage error
Given `--parent-dir /does/not/exist`
When the script runs
Then an error message naming the directory is printed to stderr
And the exit code is 2
