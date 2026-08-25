---
type: practice
title: Context Window Policy
description: How we manage LLM context to prevent rot and maximise signal per token
tags: [context, token-efficiency, caveman, rtk, headroom, loop-engineering]
timestamp: 2026-07-11T00:00:00Z
related:
  - when-to-use-rag.md
  - detect-context-rot.md
  - mcp-server-connection.md
---

# Context Window Policy

## Core Principle

**Context is a scarce resource. Every token must earn its keep.**

We enforce this through four layered mechanisms that compound:

| Layer | Tool | Savings | What it does |
|-------|------|---------|--------------|
| 1. Output compression | Caveman mode (full) | 65% | Speaks terse, keeps technical substance |
| 2. Command output filtering | RTK (Rust Token Killer) | 60-99% | Strips noise from shell commands |
| 3. Large content compression | Headroom | 70-90% | Compresses files/logs/results on demand |
| 4. Architecture laziness | Ponytail (full) | varies | Shortest diff that works, fewer files, less code |

The four tools form a **loop engineering** stack: caveman compresses speech, RTK filters tool noise, headroom squashes content, ponytail prevents over-building. Each feeds into the next. Applied together they keep sessions viable 3-5x longer.

## Mandatory Practices

### 1. Caveman Mode: Always On

Default intensity: `full`. Auto-triggers when token efficiency requested in `AGENTS.md`.

Output rules:
- Drop articles, filler, pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: `[thing] [action] [reason]. [next step].`
- Code, commits, and PRs written normal (not caveman)

```bash
# Configure in AGENTS.md:
# caveman: full  (lite|full|ultra|wenyan-*)
```

### 2. RTK Prefix: Every Shell Command

**Always prefix shell commands with `rtk`.** It passes through unchanged if no filter exists.

```bash
# Good
rtk git status
rtk grep pattern src/
rtk pytest tests/

# Bad (wastes tokens)
git status
grep pattern src/
pytest tests/
```

Key filters (measured savings from headroom docs):
- `rtk git *` — 59-80%
- `rtk test *` — 90-99% (failures only)
- `rtk lint *` — 80-90% (errors only)
- `rtk json <file>` — 70-90%

Use `rtk proxy <cmd>` for raw debug output.

### 3. Headroom Compression: Large Content

Use `headroom_compress` for any tool output or file content >2 KB before reasoning over it.

```bash
headroom_compress "$(cat large-log.txt)"
# Returns: [N items compressed... hash=abc123]

# Retrieve full content when needed:
headroom_retrieve abc123
```

Auto-triggers in opencode hooks for tool outputs exceeding thresholds.

### 4. Ponytail: Shortest Working Diff

Apply the laziness ladder to every coding task:
1. Does this need to exist at all? (YAGNI)
2. Already in this codebase? Reuse.
3. Stdlib does it? Use.
4. Native platform feature covers it? Use.
5. Already-installed dependency solves it? Use.
6. Can it be one line? One line.
7. Minimum code that works.

Mark deliberate shortcuts with `// ponytail:` comments naming the ceiling and upgrade path.

## Token Budget Discipline

| Activity | Target | Enforcement |
|----------|--------|-------------|
| Single response | ≤4 lines (unless detail requested) | Caveman + self-discipline |
| Tool output | Compressed if >2 KB | Headroom hooks |
| Session ceiling | 50k tokens | Manual token audit (no stats command ships) |

When approaching ceiling: compress last 5 outputs with headroom, check the session token readout, continue or rotate session.

## What We Don't Do

- ❌ Summarise tool outputs in prose (use headroom instead)
- ❌ Run raw commands "for debugging" without rtk prefix
- ❌ Keep dead context (compress old files, retrieve by hash)
- ❌ Explain code unless asked
- ❌ Write speculative abstractions "for later"

## Open Questions

- [ ] Auto-compress agent outputs via opencode hook — currently manual
- [ ] Wenyan mode for ultra-compression — adopt or not?
- [ ] Hard enforcement of 50k ceiling, or soft guideline?
