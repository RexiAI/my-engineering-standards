# Split docs/SPEC_PIPELINE.md per stage

Problem: docs/SPEC_PIPELINE.md is 892 lines; stage agents are told to read it, paying the full cost 5-7 times per /build.

Want: a short index doc (overview, stage table, cross-cutting rules: carve-out, remediation budget, autopilot never-list, stop-and-ask matrix) plus one file per stage (e.g. docs/spec-pipeline/<stage>.md). Each agent reads only the index section it needs plus its stage file. Every existing reference (agents/, commands/, AGENTS.md, docs/, scripts/) is updated; check-orchestration.sh resolves all of them. Measurable: tokens a stage agent must read drop by at least 50% versus today.
Depends on 036 landing first (avoid conflicting edits).
