# AC-033: --dry-run and --help

## AC-033-43 — `--dry-run` writes nothing
Given a child repo and a flag selection
When `bootstrap.sh --dry-run` runs with that selection
Then the file set of the repo is unchanged
And the exit code is 0

## AC-033-44 — `--dry-run` prints the exact plan
Given `bootstrap.sh --dry-run --stack java --with-saga`
When the script runs
Then the plan lists each selected capability, the files it would write, and the flags it would pass to `init-ci.sh`

## AC-033-45 — `--help` lists every flag
Given `bootstrap.sh --help`
When the script runs
Then every non-interactive flag from the catalog/flag set is listed
And the exit code is 0
