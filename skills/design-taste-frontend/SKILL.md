---
name: design-taste-frontend
description: Anti-slop frontend skill for landing pages, portfolios, and redesigns. The agent reads the brief, infers the right design direction, and ships interfaces that do not look templated. Real design systems when applicable, audit-first on redesigns, strict pre-flight check.
license: See repo root
---

# design-taste-frontend

Landing pages, portfolios, and redesigns. **Not** dashboards, data tables, or
multi-step product UI.

Every rule in this skill is **contextual**. None of it fires automatically. Read
the brief, then pull only what fits from the references below.

## How to use

1. Read **[references/00-brief-inference.md](references/00-brief-inference.md)**
   first. Output a one-line "Design Read" before generating any code.
2. Set the three dials per
   **[references/01-three-dials.md](references/01-three-dials.md)** — baseline
   `8 / 6 / 4`. Do not ask the user to edit this file; overrides happen
   conversationally.
3. Pick the design system via
   **[references/02-design-system-map.md](references/02-design-system-map.md)**
   when one is named in the brief.
4. Apply the directives in
   **[references/04-design-engineering-directives.md](references/04-design-engineering-directives.md)**
   as bias correction. Cross-check every output against the forbidden patterns in
   **[references/09-ai-tells.md](references/09-ai-tells.md)**.
5. Run the
   **[references/14-final-preflight.md](references/14-final-preflight.md)**
   checklist before declaring done.

## When this skill applies

| Trigger | Skill action |
|---|---|
| User asks for a landing page, marketing site, or portfolio | Activate |
| User invokes `audit` or `redesign` by name | Activate (Section 11 protocol) |
| User asks for a dashboard, table, or product UI | Skip — out of scope |
| User asks for a redesign without specifying scope | Ask **one** question, then Section 11 |

## Reference index

Each file below is self-contained. Load only what the current brief needs.

- [00 — Brief Inference](references/00-brief-inference.md) — read first.
- [01 — The Three Dials](references/01-three-dials.md) — set after the design read.
- [02 — Brief → Design System Map](references/02-design-system-map.md) — picking the system.
- [03 — Default Architecture & Conventions](references/03-architecture-conventions.md)
- [04 — Design Engineering Directives](references/04-design-engineering-directives.md) — the bulk of bias correction.
- [05 — Context-Aware Proactivity](references/05-context-aware-proactivity.md)
- [06 — Performance & Accessibility Guardrails](references/06-performance-accessibility.md)
- [07 — Dial Definitions](references/07-dial-definitions.md)
- [08 — Dark Mode Protocol](references/08-dark-mode-protocol.md)
- [09 — AI Tells (Forbidden Patterns)](references/09-ai-tells.md)
- [10 — Reference Vocabulary](references/10-reference-vocabulary.md)
- [11 — Redesign Protocol](references/11-redesign-protocol.md)
- [12 — The Block Library](references/12-block-library.md)
- [13 — Out of Scope](references/13-out-of-scope.md)
- [14 — Final Pre-Flight Check](references/14-final-preflight.md)

## One rule to remember

Reach past the LLM defaults — purple gradients, centered hero over dark mesh,
three equal feature cards, generic glassmorphism on everything, infinite-loop
micro-animations, Inter + slate-900. The design read + dials tell you when to
keep them anyway.
