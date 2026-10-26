# AC-035: Child-project eligibility detection

## AC-035-01 — Non-git path is skipped, not treated as an error
Given a candidate path that is not a git repository (has neither a `.git` directory nor a `.git` file)
When the script processes the candidate
Then the candidate is reported as skipped with a reason indicating it is not a git repository
And the run continues to the next candidate
And the final exit code is 0

## AC-035-02 — Git repo without a `.gitmodules` file is skipped
Given a candidate path that is a git repository with no `.gitmodules` file
When the script processes the candidate
Then the candidate is reported as skipped with a reason indicating no `.gitmodules`
And the run continues to the next candidate

## AC-035-03 — Git repo whose `.gitmodules` declares no `.standards` submodule is skipped
Given a candidate git repository whose `.gitmodules` does not declare a submodule at path `.standards`
When the script processes the candidate
Then the candidate is reported as skipped with a reason indicating no `.standards` submodule
And the run continues to the next candidate

## AC-035-04 — Git repo declaring a `.standards` submodule is eligible and proceeds
Given a candidate git repository whose `.gitmodules` declares a submodule at path `.standards`
When the script processes the candidate
Then the candidate is eligible
And the script proceeds to the submodule-update step for that candidate
