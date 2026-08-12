# Bounded remediation budget

Every gate-failure loop is bounded. Two independent phases:

- **Phase 1 — Pre-PR loop** (local gates + design gates; Verifier BLOCK →
  Coder/Refactorer): max 3.
- **Phase 2 — Post-PR loop** (CI gates, after push): max 3, independent of Phase 1.

On exhausting either budget: stop, emit the failing gate IDs + last evidence,
escalate to the human. "Re-run until green" is forbidden phrasing. On a BLOCK,
the Verifier re-runs only the failing gates (scoped re-verification), not the
whole suite.

## Acceptance criteria

- AC-001: docs/SPEC_PIPELINE.md documents both phases with the max-3 budgets and
  the independent-counter rule.
- AC-002: spec-verifier.md and spec-coder.md encode the budget (verifier stops
  relaying BLOCKs after 3; coder stops re-fixing after 3).
- AC-003: "re-run until green is forbidden phrasing" appears verbatim in the
  pipeline docs.
- AC-004: 30-report.md records which phase and attempt count a BLOCK was resolved
  at, so budget exhaustion is auditable.
