# AC-035: Enforcement in `check-stop-and-ask-matrix.sh`

## AC-035-30 — Missing autopilot section FAILs
Given a `docs/SPEC_PIPELINE.md` with a matrix but no `## Autopilot mode` section
When `scripts/check-stop-and-ask-matrix.sh` runs against that tree
Then it prints a `FAIL AC-035-30` line
And it exits 1

## AC-035-31 — Missing disposition for a matrix row FAILs
Given a `## Autopilot mode` section missing the disposition for at least one of the 12 matrix conditions
When `scripts/check-stop-and-ask-matrix.sh` runs
Then it prints a `FAIL AC-035-31` line naming the missing condition
And it exits 1

## AC-035-32 — An unconditional question in an agent FAILs
Given a pipeline agent file containing a question-instruction phrase with no autopilot conversion reference
When `scripts/check-stop-and-ask-matrix.sh` runs
Then it prints a `FAIL AC-035-32` line naming the agent
And it exits 1
