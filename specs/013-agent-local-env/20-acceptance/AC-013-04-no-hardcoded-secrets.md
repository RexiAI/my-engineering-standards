# AC-013-04: no hardcoded credential value in agents/, commands/, scripts/, docs/

## AC-013-04-01 — A literal token prefix in a scanned dir fails the check
Given a scratch fixture file under one of the scanned dirs containing a literal token prefix (e.g. `ghp_` followed by hex, `github_pat_`, `AKIA`, `xoxb-`)
When `scripts/check-no-hardcoded-secrets.sh` runs with that fixture in scan scope
Then it exits 1
And prints the matching file and line

## AC-013-04-02 — A secret-style assignment with a literal value fails the check
Given a scratch fixture line of the form `GITHUB_TOKEN=ghp_abc123` or `export API_TOKEN=literal-value` under a scanned dir
When `scripts/check-no-hardcoded-secrets.sh` runs with that fixture in scan scope
Then it exits 1

## AC-013-04-03 — Clean scanned dirs pass; placeholders and variable references do not trip
Given the four scanned dirs (`agents/`, `commands/`, `scripts/`, `docs/`) contain no literal credential values
When `scripts/check-no-hardcoded-secrets.sh` runs over them
Then it exits 0
And values like `<your-github-personal-access-token>` and `${GITHUB_TOKEN}` are not reported as matches

## AC-013-04-04 — The check runs in self-ci and a violation fails the job
Given `.github/workflows/self-ci.yml` has a `validate` job
When the job runs
Then one step runs `bash scripts/check-no-hardcoded-secrets.sh` (no `continue-on-error`)
And a hypothetical literal token committed under a scanned dir makes that step exit 1
And the `validate` job fails

## AC-013-04-05 — The selftest proves the check fires, without tripping it
Given `scripts/agent-env.selftest.sh` exists under `scripts/` (itself a scanned dir)
When the selftest step runs in the `validate` job
Then it exercises the check against scratch fixtures whose literal values are constructed at runtime (string concatenation, never inline literals)
And the selftest file itself contains no string that literally matches the check's patterns
