# Auditable agent steps

Every step the pipeline agents take should be verifiable after the fact — a
human (or a later run) can reconstruct what happened and why, from artifacts,
not from trusting the agent's word. acdc-civ's auditability comes from: the
gate-runner emitting a machine-readable JSON report per gate; the Verifier
recording evidence (build number, image tag, pod readiness) in a verdict
contract; and ADR-0001 recording the architectural decision. This repo's
pipeline already writes artifacts per stage (10-tasks, 20-acceptance,
25-verification, 30-report) but has no uniform rule for *what evidence each
stage must leave behind*.

## What it must provide

- A documented audit contract: each pipeline stage records, in its artifact, the
  evidence a reviewer needs to trust its claim:
  - Specifier → the acceptance criteria and the scenario IDs it derived.
  - Coder → the tests it wrote (traceable to scenario IDs) and the build/test
    commands it ran, with exit codes.
  - Refactorer → the gates it applied (complexity, duplication, property tests)
    and their before/after measurements.
  - Verifier → each check it ran, the exact command, and its real output/exit
    code (already partially there — make it uniform).
  - Architect → the mutation score, gate results, and the PR it opened.
- Every agent step that can leave machine-readable evidence (a gate script, a CI
  query, a deploy check) records it as JSON or a log line with timestamp — not a
  prose paraphrase.
- The pipeline's report artifact (25-verification.md / 30-report.md) links or
  embeds that evidence so a reviewer does not have to re-run anything to audit.
- A small `scripts/check-audit-trail.sh` (or a gate) that, given a spec slug,
  verifies each expected artifact exists and is non-empty, and that the verifier
  report cites real evidence for each check. Run at pipeline end.

## Acceptance criteria

- AC-001: the audit contract is documented (which artifact, which evidence per
  stage) in docs/SPEC_PIPELINE.md.
- AC-002: each stage artifact includes the evidence required by the contract.
- AC-003: machine-readable evidence (gate JSON, CI query, deploy check) is
  recorded with timestamp, not paraphrased.
- AC-004: `scripts/check-audit-trail.sh <slug>` verifies every expected artifact
  exists and is non-empty; exit 0 only when complete.
- AC-005: the verifier's report cites real evidence per check (command + output),
  and check-audit-trail verifies that.
