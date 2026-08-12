# Governance document + trust tiers

Split governance from operations. Add docs/GOVERNANCE.md:

1. **Trust tiers.** T0 autonomous (reads, gates, Jira/Confluence read, Jira
   comment), T1 local write (edit, commit, local branch), T2 confirm (push, PR,
   Confluence publish, Jira transition — human-triggered), T3 forbidden (push to
   main, force-push, destructive infra). Each pipeline agent maps to a tier.
2. **Model-assignment discipline.** "Change the model only by editing the agent
   frontmatter AND the model table (AGENTS.md / opencode.json) in the same
   commit." Prevents the config drift observed this session.
3. **ADR requirement.** Any change to pipeline roles, gate catalog, or billing
   constraint must be recorded as an ADR (templates/ADR.md exists but is unused)
   before merging. Review-blocking otherwise.

## Acceptance criteria

- AC-001: docs/GOVERNANCE.md exists with the three sections.
- AC-002: each agent's trust tier is stated (frontmatter or table).
- AC-003: model assignments live in exactly one authoritative place (opencode.json)
  and the AGENTS.md table is a mirror with a conformance note.
- AC-004: ADRs are indexed; pipeline-role/gate changes require one.
