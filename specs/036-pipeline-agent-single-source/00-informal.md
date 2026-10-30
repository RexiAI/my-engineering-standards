# Single source of truth for orchestrator rules

Problem: agents/spec-pipeline.md (140 lines) restates rules that also live in docs/SPEC_PIPELINE.md (remediation budgets, autopilot never-list, carve-out). Two copies drift.

Want: docs/SPEC_PIPELINE.md is the only normative source. agents/spec-pipeline.md keeps only what the orchestrator must act on at runtime (stage order, which agent per stage, stop conditions) and references doc sections by anchor instead of restating. No behavior change. Add a check (or extend check-orchestration.sh) that flags normative rules duplicated verbatim between agents/*.md and docs/SPEC_PIPELINE.md.
