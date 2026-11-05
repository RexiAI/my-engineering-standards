# AC-039-05: /build stage selection

## AC-039-05-01 — Lite stage list
Given resolved mode `lite`
When `commands/build.md` stage selection is read
Then the stages run are Coder, Verifier, PR Opener, Archiver in that order
And Refactorer, Mutation Runner, UX Designer, Deploy Verifier are not invoked

## AC-039-05-02 — Full stage list unchanged
Given resolved mode `full`
When stage selection is read
Then the stage list equals the pre-change stage list

## AC-039-05-03 — Report records lite mode
Given a lite run with Verifier PASS
When `30-report.md` is written
Then it contains `Pipeline mode: lite`
And each skipped stage is listed as `skipped (lite)`
And the PR Opener green-report precondition passes

## AC-039-05-04 — Orchestration check passes
Given the changes are applied
When `scripts/check-orchestration.sh` runs
Then exit code is 0
