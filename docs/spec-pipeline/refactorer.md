# Refactorer stage file (stage 3)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Remediation budget
(phase-1 re-fix budget). This stage owns no index section of its own: the
complexity, duplication, and property-test duties live in the agent prompt.

Deliverable: no report artifact of its own — the Verifier re-records every gate
you applied, so leave the tree green and the structure clean.

## Test-lane capture

Run the suite after each extraction through
`scripts/agent-test-summary.sh --run <log-path> -- <real command>` and read only
its stdout — the signal lines plus the one `SUMMARY:` line, never the log file.
The log is author feedback, not evidence: this stage leaves no report artifact.
The shape, and the canonical append recipe used by the stages that do write
evidence, live in `docs/spec-pipeline/verifier.md §Test-log capture`.
