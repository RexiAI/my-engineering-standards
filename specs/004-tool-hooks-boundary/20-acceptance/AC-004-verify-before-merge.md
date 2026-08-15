# AC-004: Verify before merge

## AC-004-01 — Bad commit message is rejected
Given a `spec/004-tool-hooks-boundary` branch
When the user runs `git commit -m "random commit"`
Then `commit-msg` rejects the commit and suggests the conventional
form

## AC-004-02 — Push aborts on a flipped gate
Given a branch where the scenario-traceability gate is flipped off
When the user runs `git push`
Then `pre-push` aborts the push with the failing gate IDs in
stderr
And the remote never receives the push

## AC-004-03 — Clean branch hooks run but do not BLOCK
Given a `spec/*` branch with all gates green
When `git push` is run
Then the hooks fire
And the push completes successfully

## AC-004-04 — Missing harness is silent
Given `scripts/gates/gate-runner.sh` is removed
When a `git push` is run on `spec/*` branch
Then the hooks run as no-ops
And the push completes successfully
