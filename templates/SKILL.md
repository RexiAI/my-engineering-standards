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

<!--
Checklist before merging:
- [ ] name matches directory name
- [ ] name is lowercase a-z, 0-9, single hyphens (<=64 chars)
- [ ] description is <=1024 chars and includes what + when to use
- [ ] SKILL.md body <=500 lines
- [ ] Relative file refs one level deep
- [ ] ./scripts/check-skills.sh passes
-->
