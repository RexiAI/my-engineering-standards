# AC-001: Hooks at the tool boundary

## AC-001-01 — `agents/hooks/hooks.json` declares both matchers
Given `agents/hooks/hooks.json`
When it is read
Then it contains a `preToolUse` rule whose `matcher` includes
`bash`
And it contains a `postToolUse` rule whose `matcher` includes
`edit|create`

## AC-001-02 — `find-harness.sh` and `format-guard.sh` exist
Given `agents/hooks/`
When the directory is listed
Then it contains `find-harness.sh` and `format-guard.sh`

## AC-001-03 — `pre-push` invokes the gate-runner with the fast subset
Given a `spec/NNN-slug` branch
When `git push` is simulated against the local pre-push
Then the hook runs `gate-runner.sh -Phase local
-Gates G0,G1,G6,S1` (verified by reading the script or running it in
a test harness)

## AC-001-04 — `commit-msg` enforces Conventional Commits
Given `agents/hooks/commit-msg`
When a `git commit -m "random text"` is attempted on a `spec/*`
branch
Then the hook rejects the commit

## AC-001-05 — Soft-fail pattern works
Given `scripts/gates/gate-runner.sh` does NOT exist
When any hook is invoked
Then the hook exits `0` and logs nothing
