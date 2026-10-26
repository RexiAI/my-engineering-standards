# AC-033: Interactive menu + non-TTY default

## AC-033-18 — menu renders the catalog grouped
Given a TTY and the single catalog source
When `bootstrap.sh` renders its menu with no flags
Then capabilities appear grouped as Core wiring, Backend stacks, Frontend/mobile stacks, CI platform, Quality gates, Deploy, Agent pipeline, and Loop engineering
And every group's items come from the catalog

## AC-033-19 — menu preselects detected stacks
Given a TTY on a java repo (contains `pom.xml`)
When `bootstrap.sh` renders its menu with no flags
Then the java capability is preselected and other stacks are not

## AC-033-20 — menu selections map to the same flag set
Given the catalog and its non-interactive flags
When a menu selection set is chosen
Then the resulting enabled capabilities equal passing the matching flags non-interactively

## AC-033-21 — non-TTY with no flags preserves core wiring
Given stdin is not a TTY and no flags are passed
When `bootstrap.sh` runs
Then core wiring files are written
And CI setup is skipped
And an exact command to opt into the rest is printed

## AC-033-22 — TTY with no flags shows the full menu
Given a TTY and no flags
When `bootstrap.sh` runs
Then the full menu is shown, preselected by detection, and `--none` is the escape
