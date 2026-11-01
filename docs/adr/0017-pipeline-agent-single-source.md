# Architecture Decision Record (ADR)

## Title

Single source of truth for spec-pipeline rules: agents reference docs/SPEC_PIPELINE.md

## Status

Accepted

## Context

`agents/spec-pipeline.md` restated rules that `docs/SPEC_PIPELINE.md` already
defines (never-list, commit/push carve-out, autopilot trigger, remediation
budgets). Two copies of a rule drift; the agent prompt can silently disagree
with the normative doc.

## Decision

- `docs/SPEC_PIPELINE.md` is the normative source for pipeline rules.
- `agents/spec-pipeline.md` is a runtime procedure (preflight, stage order,
  stop conditions, telemetry exports) and cites doc rules by section reference
  (`docs/SPEC_PIPELINE.md §<Heading>`).
- `scripts/check-agent-doc-duplication.sh` fails when any `agents/*.md` line
  (normalized, >= 8 words, outside code fences and headings) duplicates a doc
  line, or when a section reference does not resolve to a `##`/`###` heading.
  `scripts/check-orchestration.sh` runs it.
- Three agents had section references wrapped across lines; they were
  re-wrapped so each reference sits on one line. No behavior change.

## Consequences

- No pipeline behavior change; only where rules are written.
- Older static tests that asserted restated never-list text in the
  orchestrator now assert the section reference plus the doc content.
- Short rule lines (< 8 words) are not detected as duplicates by design.
