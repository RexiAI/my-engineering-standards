# AC-015: Stage artifacts carry the contract's evidence

## AC-015-04 — The verifier report records real evidence per check

Given the Verifier stage has run for this spec

When I read `specs/NNN-slug/25-verification.md`

Then it contains an overall verdict of PASS or FAIL

And for each of the five contract checks (scenario traceability, full test suite, complexity gate, design-principles gate, scenario-to-behavior spot check) it records an evidence block

And each evidence block contains the exact `command:`

And each evidence block contains an `exit:` code

And each evidence block contains an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ` format

And each evidence block contains the raw output of the command, not a prose paraphrase

## AC-015-05 — The report carries mutation score, final status, and PR evidence

Given the pipeline reached the Mutation Runner and PR Opener stages

When I read `specs/NNN-slug/30-report.md`

Then it contains the mutation score, or an explicit `skipped — <tier> tier` reason

And it contains the final test status

And it carries the Verifier's verdict forward

And when a PR was opened it contains a line starting `PR:` with the PR URL

## AC-015-06 — The pipeline agents record the evidence their artifacts require

Given the audit contract is documented

When I read the pipeline agents in `agents/`

Then `spec-verifier.md` instructs recording, per check, the exact command, real output, exit code, and an ISO-8601 `at:` timestamp

And `spec-coder.md` instructs the handoff to list the exact build/test commands run with their exit codes

And `spec-refactorer.md` instructs the handoff to list the gates applied with before/after measurements

And `spec-mutation-runner.md` instructs writing the mutation score or skip reason and the final test status to `30-report.md`

And `spec-pr-opener.md` instructs appending the PR URL and commit count to `30-report.md` after opening the PR
