# AC-037-04: check-orchestration.sh coverage

## AC-037-04-01 — Clean tree passes
Given the tree after Tasks 1-3
When `scripts/check-orchestration.sh` runs
Then it exits 0

## AC-037-04-02 — Missing stage file detected
Given a scratch tree where an agent cites `docs/spec-pipeline/nope.md`
When `scripts/check-orchestration.sh <scratch>` runs
Then it exits 1 and prints the citing file and `docs/spec-pipeline/nope.md`

## AC-037-04-03 — Missing section anchor detected
Given a scratch tree where an agent cites `docs/spec-pipeline/coder.md §No Such Section`
When `scripts/check-orchestration.sh <scratch>` runs
Then it exits 1 and prints the citing file:line and the missing section

## AC-037-04-04 — Index anchor resolves
Given a scratch tree where an agent cites `docs/SPEC_PIPELINE.md §Remediation budget` and the index has that heading
When `scripts/check-orchestration.sh <scratch>` runs
Then it exits 0
