# AC-035: Uninitialized-submodule guard

## AC-035-05 — Declared but uninitialized `.standards` is skipped with a hint
Given a candidate git repository that declares a `.standards` submodule
And `git submodule status .standards` reports the submodule as uninitialized (leading `-`)
When the script processes the candidate
Then the candidate is reported as skipped with a hint naming `git submodule update --init .standards`
And the script does not initialize the submodule
And the run continues to the next candidate
