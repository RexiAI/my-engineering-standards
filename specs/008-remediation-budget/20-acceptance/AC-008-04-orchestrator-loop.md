# AC-008-04: Phase-1 loop is bounded in the orchestrator and the /build command

## AC-008-04-01 — commands/build.md describes a bounded phase-1 loop
Given `commands/build.md` is edited per task 4
When the command is read
Then it describes a loop where a Verifier BLOCK re-delegates the failing fix back to the Coder or Refactorer
And it states the loop re-invokes the Verifier for scoped re-verification after each fix
And it states the loop runs at most **3** cycles

## AC-008-04-02 — agents/spec-pipeline.md describes the same bounded loop
Given `agents/spec-pipeline.md` is edited per task 4
When the prompt is read
Then it describes the same phase-1 loop: fix → scoped re-verify, up to **3** cycles, routing behavior failures to the Coder and structural/complexity failures to the Refactorer

## AC-008-04-03 — Exhaustion stops the pipeline with the escalation payload
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both state that on the 3rd BLOCK the pipeline stops
And both state the pipeline relays the failing gate IDs and the last evidence from `25-verification.md`
And both state the pipeline escalates to the human
And neither allows a 4th re-delegation

## AC-008-04-04 — Stage-5 agents still require a Verifier PASS
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both still run the mutation-runner and pr-opener stages only after a Verifier PASS

## AC-008-04-05 — Phase-2 independence is acknowledged but not implemented
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then they acknowledge a post-PR CI loop exists with its own independent max-3 budget
And neither file specifies how CI status is queried or how failing CI logs are read

## AC-008-04-06 — No open-ended re-run phrasing in the loop
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then neither contains `re-run until green`
And neither contains any equivalent instruction to keep re-running until green

## AC-008-04-07 — No new infrastructure is introduced
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When the change is reviewed
Then it introduces no new files, agents, or infrastructure beyond edits to these two files
