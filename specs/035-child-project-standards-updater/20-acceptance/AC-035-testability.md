# AC-035: Hermetic testability and README characterization

## AC-035-26 — A bats suite characterizes the decision logic hermetically
Given a bats test file under `scripts/tests/` exercising the update script
When the suite runs
Then the tests construct local `git init` fixtures with `file://` submodule remotes
And no test touches the network or a real sibling repository
And `scripts/tests/README.md` no longer lists `update-submodules.sh` in its "Not characterized" table (or the entry states it is now characterized)
