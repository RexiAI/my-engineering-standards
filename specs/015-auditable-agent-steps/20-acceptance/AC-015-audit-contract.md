# AC-015: Audit contract documented in docs/SPEC_PIPELINE.md

## AC-015-01 — The audit contract section maps every stage to an evidence artifact

Given the spec pipeline has stages: Specifier, Coder, Refactorer, Verifier, Mutation Runner, and PR Opener

When I read the `## Audit contract` section in `docs/SPEC_PIPELINE.md`

Then the section names each of the six stages

And for each stage the section names the artifact(s) that carry its evidence

And the section references at least these artifacts: `10-tasks.md`, `20-acceptance/`, `25-verification.md`, and `30-report.md`

## AC-015-02 — The contract specifies the evidence each stage must record

Given the `## Audit contract` section in `docs/SPEC_PIPELINE.md`

When I read the per-stage evidence requirements

Then the Specifier requirement mentions acceptance criteria and scenario IDs

And the Coder requirement mentions tests traceable to scenario IDs and build/test commands with exit codes

And the Refactorer requirement mentions the gates applied (complexity, duplication, property tests) with before/after measurements

And the Verifier requirement mentions, per check, the exact command and its real output and exit code

And the Mutation Runner requirement mentions the mutation score, equivalent mutants, and final test status

And the PR Opener requirement mentions the PR URL and commit count

## AC-015-03 — The contract mandates raw, timestamped machine-readable evidence

Given the `## Audit contract` section in `docs/SPEC_PIPELINE.md`

When I read the evidence-recording rule

Then the section states that machine-readable evidence (gate script output, CI query, deploy check) is recorded with a timestamp

And the timestamp format is ISO-8601 UTC `YYYY-MM-DDTHH:MM:SSZ`

And the section states the raw output or exit code is recorded, not a prose paraphrase
