# AC-033: Flags — per-capability, --all/--none, refusal, outcomes

## AC-033-23 — every capability has a non-interactive flag
Given the single catalog source
When the flag list is inspected
Then each of `--stack`, `--frontend`, `--with-saga`, `--with-contract`, `--with-mutation`, `--with-security`, `--with-e2e`, `--with-sweeper`, `--with-pr-review`, `--with-release`, `--with-deploy`, `--with-spec-pipeline`, `--with-loop`, `--copy-agents`, `--all`, `--none`, `--dry-run`, `--help`, `--list` exists
And every catalog capability maps to at least one flag

## AC-033-24 — `--none` performs core wiring only
Given a child repo with `.standards/` present
When `bootstrap.sh --none` runs
Then only core wiring files are written
And no CI, stack config, or extra template is written

## AC-033-25 — `--all` enables only compatible entries
Given a java repo (contains `pom.xml`, no frontend)
When `bootstrap.sh --all` runs
Then every java-compatible catalog entry is enabled
And frontend-only entries are skipped with their reason printed

## AC-033-26 — `--all` excludes deploy without a tool
Given any detected stack
When `bootstrap.sh --all` runs without `--with-deploy`
Then no deploy capability is enabled
And the reason deploy was skipped is printed

## AC-033-27 — `--all` includes deploy when a tool is named
Given a detected stack
When `bootstrap.sh --all --with-deploy kamal` runs
Then the deploy capability is enabled

## AC-033-28 — incompatible combination is refused with a named reason
Given a capability selection containing a conflict declared in the catalog
When `bootstrap.sh` runs with those flags
Then the run is refused with the conflict's named reason
And the exit code is non-zero

## AC-033-29 — every capability reports an explicit outcome
Given any capability execution
When `bootstrap.sh` writes it
Then the outcome is exactly one of `CREATED`, `SKIPPED (exists)`, or `REFUSED (reason)`

## AC-033-30 — a re-run writes nothing twice
Given a child repo already bootstrapped with a capability
When `bootstrap.sh` runs the same capability again
Then existing files are not rewritten
And the capability reports `SKIPPED (exists)`
