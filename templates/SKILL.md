---
name: skill-name-here
description: Clear description of what this skill does and when to use it (including trigger phrases). Max 1024 characters.
license: See repo root
# compatibility: Optional environment requirements (max 500 chars, e.g., Requires git, docker, jq)
# allowed-tools: Optional space-separated allowed tools string
---

# When to use

Explain when the agent should invoke this skill. List clear trigger phrases and context conditions.

# Invocation

Provide exact execution commands from the repository root:

```bash
./scripts/example.sh --flag
```

# What the script/tool does

1. Step 1 description.
2. Step 2 description.
3. Step 3 description.

# What it is not

Explicit non-goals or boundary limits.

# Exit codes

- `0` — Success / All checks passed
- `1` — Failure / Validation error

# Margin notes

Corrections from real sessions that are not yet general rules. Promote a note
into the body once it repeats; delete it if it never does.

-

# Validation

Behavioral validation record (see `docs/AGENTS_AND_SKILLS.md` §Behavioral
Validation). A skill with no level-1 row is unvalidated, however clean the
frontmatter is. Level 1 = used on a second real task, different inputs.

| Level | Date | Task / inputs | Corrections needed |
|---|---|---|---|
| 1 | | | |

<!--
Checklist before merging:
- [ ] name matches directory name
- [ ] name is lowercase a-z, 0-9, single hyphens (<=64 chars)
- [ ] description is <=1024 chars, includes what + when to use, and contains the phrases that should trigger it
- [ ] SKILL.md body <=500 lines
- [ ] Relative file refs one level deep
- [ ] Level-1 validation row filled with a real second session
- [ ] Session-specific details scrubbed (client names, absolute paths, internal URLs)
- [ ] ./scripts/check-skills.sh passes
-->
