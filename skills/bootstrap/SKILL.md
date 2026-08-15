---
name: bootstrap
description: One-time setup to bridge this engineering-standards repo into a child repo as a `.standards/` submodule, including symlinking (or copying) the spec-pipeline agent and command files. Use when a user says "bootstrap this repo against the standards" or "wire up the spec pipeline."
license: See repo root
allowed-tools: Bash(.standards/scripts/bootstrap.sh:*) Bash(./.standards/scripts/bootstrap.sh:*)
---

# When to use

When a child repo needs to consume this standards repo as a `.standards/` submodule and gain the agent/command files.

# Invocation

Run from the root of the child repo. Use the submodule mount path, not the source path:

```bash
./.standards/scripts/bootstrap.sh
```

## Flags

- `--copy-agents` — copy `agents/` and `commands/` into real files in the child repo's `.opencode/` instead of symlinking. Use this when you want to set per-agent model overrides or edit agent bodies without touching files inside the `.standards/` submodule. You own the copies after this — re-run with `--copy-agents` after a submodule update to pull in changes; the script does not merge them for you.

# What the script does

1. Detects whether `.standards/` is already a git submodule in the child repo.
2. Symlinks `agents/` and `commands/` into the child repo's `.opencode/` (or copies, with `--copy-agents`).
3. Prints a one-line summary of next steps.

# Permissions note

The script writes outside any agent's ordinary edit scope (creates `.opencode/` symlinks/copies). Invoke it interactively from a tool callout, not from inside a stage-3/4/5 agent that should be working on a code change.
