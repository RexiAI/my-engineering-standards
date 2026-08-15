# AC-002: Existing agents rewire around `gate-report.json`

## AC-002-01 — `spec-pipeline.md` exposes three modes
Given `agents/spec-pipeline.md`
When it is read
Then it lists three invocation modes: `/spec`, `/build`, `/ship`

## AC-002-02 — `spec-architect.md` requires a fresh PASS report
Given `agents/spec-architect.md`
When it is read
Then it states a pre-push check that requires
`<RepoPath>/.civ/gate-report.json` to exist
And its `status` field equals `"PASS"`
And the report's branch + SHA matches `HEAD`
And the push is refused if any check fails

## AC-002-03 — `spec-verifier.md` verdict is a transcription
Given `agents/spec-verifier.md`
When it is read
Then the verdict contract describes the output as a transcription of
the `.civ/gate-report.json` fields (`status`, `blockingGates`,
`evidence`)
And the JSON wins on disagreement with the agent's own read

## AC-002-04 — Stale report is rejected
Given a `.civ/gate-report.json` whose branch SHA is one commit
behind `HEAD`
When `spec-architect` is invoked
Then it aborts the push and surfaces the refresh-gate-runner
command
