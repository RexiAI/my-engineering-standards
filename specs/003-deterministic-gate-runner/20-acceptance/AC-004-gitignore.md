# AC-004: `.civ/` runner state is gitignored

## AC-004-01 — `.civ/` is gitignored
Given the repository's `.gitignore`
When it is searched for the string `.civ/`
Then a line matches

## AC-004-02 — `.civ-dryrun/` is gitignored
Given the repository's `.gitignore`
When it is searched for the string `.civ-dryrun/`
Then a line matches

## AC-004-03 — `git status` does not show runner state
Given a harness run that produced `<RepoPath>/.civ/gate-report.json`
and `<RepoPath>/.civ-dryrun/dry-run-summary.json`
When `git status --porcelain` is run
Then neither path appears in the output
