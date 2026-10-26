# AC-035: Orchestrator autopilot behavior

## AC-035-15 — No questions in autopilot
Given `agents/spec-pipeline.md`
And autopilot is on
When the orchestrator resolves any ask
Then it never calls the question tool
And it never relays `BLOCKED — <question>` as a stop
And it never waits for human input
And it resolves per the `## Autopilot mode` disposition table and records the decision

## AC-035-16 — Never-list refusals are hard even in autopilot
Given `agents/spec-pipeline.md`
When the orchestrator would take a never-list action
Then it refuses, as a hard stop not a decision
And the 9 refusals are stated (merge, tag, push `main`/`master`, force-push, branch deletion, threshold change, secret creation/rotation, writes outside the target repo, `git init`/submodule scaffolding)

## AC-035-17 — Queue stops at the first hard stop
Given a queue of slugs in order
When an earlier slug hits a hard stop
Then the queue stops at that slug
And it does not skip to the next slug
And it writes the morning report before stopping
