# Make media agents opt-in for child repos

Problem: agents/media-{image,video,voice,producer}.md ship to every child repo via the .standards submodule, adding unrelated agents to every engineering session's agent list (token + selection noise). ADR 0007 (docs/adr/0007-media-agent-family.md) deliberately added them, so this is NOT a deletion.

Want: media agents stay in this repo but are not loaded by default in child repos; a child opts in explicitly (e.g. an init flag or documented opencode.json snippet). Supersede/amend ADR 0007 with the rationale. scripts/tests/media-agents.bats, scripts/capabilities.tsv and docs/MEDIA_AGENTS.md stay consistent. check-orchestration.sh and check-skills.sh stay green.
