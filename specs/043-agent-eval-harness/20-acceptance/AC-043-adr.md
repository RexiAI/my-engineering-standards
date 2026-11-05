# AC-043: Agent eval harness decision record

## AC-043-01 — ADR follows the mandated template
Given `docs/adr/0020-agent-eval-harness.md`
When the file is read
Then it carries `## Title`, `## Status`, `## Context`, `## Decision`, `### Alternatives Considered`, `## Consequences`, `## Compliance`, and `## Notes` in that order
And its status is `Proposed`

## AC-043-02 — ADR records the four load-bearing decisions
Given the `## Decision` section of ADR 0020
When its decisions are listed
Then it states that `scripts/check-agent-evals.sh` becomes a self-CI gate
And it states that `evals/` is a top-level package that the pipeline never loads
And it states that eval runs append to `runs.jsonl` through `scripts/record-gate-run.sh` using the existing schema, with `specSlug` prefixed `eval-`
And it states that the Specifier gains a `BLOCKED — <question>` ambiguity path

## AC-043-03 — ADR records rejected alternatives and the out-of-scope list
Given the alternatives table and the consequences of ADR 0020
When they are read
Then the alternatives include a separate eval runs file, a new `runs.jsonl` schema key, a hosted runner, and vendoring the upstream course material
And the out-of-scope list names generic coding benchmarks
And it states that no upstream code is vendored because this repository has no root `LICENSE`, so only patterns are reused
And it names Modal, Opik, Kitaru, sandbox backends, and hosted runners as out of scope

## AC-043-04 — The ADR is indexed
Given `docs/adr/README.md`
When the index table is read
Then exactly one row starts with `| 0020 |`
And that row links to `0020-agent-eval-harness.md`
And that row's status column is `Proposed`
And `bash scripts/check-governance.sh` exits 0
