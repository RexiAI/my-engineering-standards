# AC-035: Child-project discovery

## AC-035-08 — `--parent-dir` scans immediate children and selects `.standards` repos
Given a directory `P` containing a non-git directory `A`
And a git repository `B` whose `.gitmodules` does not declare `.standards`
And a git repository `C` whose `.gitmodules` declares `.standards`
And a git repository `D` declaring `.standards` that lives two levels below `P` (in a subdirectory)
When the script runs with `--parent-dir P`
Then `C` is discovered and processed
And `A` and `B` are ignored (not processed)
And `D` is not discovered (discovery is one level deep)

## AC-035-09 — Default parent directory is the standards repo's own parent, not the cwd
Given the script is located at `X/standards/scripts/update-submodules.sh`
And `X` contains sibling git repositories declaring `.standards`
When the script runs with no explicit paths, no `--parent-dir`, no `--auto`, and no `repo-list.txt`, from an unrelated cwd
Then the script scans `X` (the parent of its own location)
And the sibling repositories under `X` are discovered and processed
And the caller's cwd does not affect discovery

## AC-035-10 — Explicit path arguments process only those paths
Given two git repositories `R1` and `R2` declaring `.standards`
When the script runs with the explicit arguments `R1`
Then `R1` is processed
And `R2` is not processed (no additional discovery)

## AC-035-11 — `repo-list.txt` is read when no higher-precedence input is given
Given a `repo-list.txt` containing one path per line, plus a `#` comment line and a blank line
And the script is invoked with no explicit paths, no `--parent-dir`, and no `--auto`
When the script runs
Then exactly the non-comment, non-blank paths from `repo-list.txt` are processed

## AC-035-12 — `--auto` remains cwd-relative
Given the current directory contains a child git repository `C` declaring `.standards` at depth 2
When the script runs with `--auto`
Then `C` is discovered from the current directory
And repositories outside the current directory tree are not discovered
