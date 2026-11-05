# AC-043: Specifier BLOCKED ambiguity path

## AC-043-25 — Unmakeable criteria stop the Specifier
Given `agents/spec-specifier.md`
When its ambiguity handling is read
Then it instructs the agent to emit `BLOCKED — <question>` naming one specific ambiguity
And it forbids writing `10-tasks.md` and `20-acceptance/` on that path
And it forbids guessing

## AC-043-26 — Autopilot remains free of unconditional questions
Given `agents/spec-specifier.md` contains the literal `BLOCKED —`
When `bash scripts/check-stop-and-ask-matrix.sh` runs
Then it exits 0
And the file references `## Autopilot mode`
And the autopilot instruction chooses the most conservative reversible default, records it in `45-decisions.md`, and continues

## AC-043-27 — The stage file matches the agent
Given `docs/spec-pipeline/specifier.md`
When its ambiguity rule is read
Then it states the `BLOCKED — <question>` outcome and the no-artifacts rule
And it does not contradict `agents/spec-specifier.md`

## AC-043-28 — The normal path is unchanged
Given `agents/spec-specifier.md`
When its job section is read
Then it still requires `10-tasks.md` and `20-acceptance/` for a spec whose criteria can be made checkable
And the `BLOCKED` instruction is conditioned on criteria that cannot be made checkable
