---
type: decision
title: When to Use RAG vs Context Stuffing
description: Decision framework for choosing between retrieval-augmented generation and direct context injection
tags: [rag, context, retrieval, search, knowledge]
timestamp: 2026-07-11T00:00:00Z
related:
  - context-window-policy.md
---

# When to Use RAG vs Context Stuffing

## Context

We need to give the AI access to external knowledge (docs, code, data). Two approaches exist: stuff everything into the prompt ("context stuffing") or retrieve relevant pieces on demand (RAG).

Our [context window policy](context-window-policy.md) says every token must earn its keep. This decision applies that principle to knowledge retrieval.

## Decision

**Default: context stuffing with compression.** Reach for RAG only when a specific threshold is met.

| Condition | Use | Rationale |
|-----------|-----|-----------|
| Source fits in <50 KB after headroom compression | Context stuffing | Simpler, faster, no infra |
| Source >50 KB compressed | RAG | Context window too expensive |
| Semantic search across 10+ documents needed | RAG | Can't linearly read all |
| Freshness is critical (user wants "right now") | RAG | Index updated daily vs context = snapshot |
| Single file or two well-known files | Context stuffing | Lower latency, no retrieval cost |
| Exploratory "what do we have on X?" | RAG | Semantic search is the point |

### Stuffing Pattern

```bash
headroom_compress "$(cat relevant-file.md)"
# Use compressed result directly in prompt
```

### RAG Pattern

```json
{
  "instructions": [
    ".standards/okf/context-window-policy.md",
    ".standards/docs/ARCHITECTURE.md"
  ],
  "mcp": {
    "servers": {
      "myinvestor": {
        "command": "search_funds",
        "args": ["query", "filters"]
      }
    }
  }
}
```

### Hybrid Pattern (Most Common)

Stuff the OKF + project AGENTS.md (always loaded). Use RAG/MCP for runtime queries against large external data (fund catalogues, GitHub issue search, weather forecasts).

## Consequences

| Positive | Negative |
|----------|----------|
| Simple setup for most cases | Need to evaluate RAG infra before using |
| No external dependency for common queries | 50 KB threshold is a judgement call, not exact |
| Fresh data when needed | RAG responses are approximate, stuffing is exact |
| Composability between the two | Two code paths to maintain |

## Compliance

Enforced by code review habit. No CI gate. If a change adds a RAG query and the source is under 50 KB, reviewer flags it.

## Open Questions

- [ ] Should we build a simple wrapper that auto-decides: "try stuffing first, fall back to RAG if >50 KB"?
- [ ] 50 KB — correct threshold? Measured or guessed?
