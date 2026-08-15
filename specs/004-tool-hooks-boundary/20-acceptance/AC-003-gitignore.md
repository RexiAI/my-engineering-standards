# AC-003: Gitignore includes runner state

## AC-003-01 — `.civ/` is gitignored
Given `.gitignore` at the repository root
When it is searched for `.civ/`
Then a line matches

## AC-003-02 — `.civ-dryrun/` is gitignored
Given `.gitignore` at the repository root
When it is searched for `.civ-dryrun/`
Then a line matches

## AC-003-03 — `git status` stays clean after a runner run
Given a runner run that produced files under `.civ/` and
`.civ-dryrun/`
When `git status --porcelain` is run
Then neither directory's contents appear
