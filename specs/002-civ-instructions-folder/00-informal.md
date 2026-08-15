# 002 — Split the spec pipeline into numbered, scoped instructions

## Why

Today the SDLC rules for this repo's spec pipeline live in one big prose
document (`docs/SPEC_PIPELINE.md`) and seven per-agent specs (`agents/spec-*.md`).
Each agent discovers its rules by reading several files and assembling a
mental picture — a process with no boundary check, no per-topic `applyTo`,
no path-scoping. When a reviewer asks "what did the Coder follow?" the
honest answer is "whatever it remembered after reading three documents."

Reference: ACDC's plugin splits the same SDLC into numbered
`instructions/NN-*.md` files, each with `applyTo` glob, every agent a
one-line pointer. That gives every step an exact document, and lets a
review ask "did the agent read `03-implement.md` before writing code?" —
a check you can perform with grep.

Adopt that pattern here as **Phase A** of four. (Phases B/C/D add a
deterministic gate-runner, hooks at the boundary, and the PR auto-pipeline.
Phase A only changes organization; no behavior change.)

## What I want

A new `.standards/instructions/` directory with one file per SDLC step,
numbered in execution order:

- `00-pipeline-overview.md` — pipeline shape, role boundaries, hand-off
  contracts. (Today's `docs/SPEC_PIPELINE.md §Stages` content.)
- `01-specify.md` — what `spec-specifier` must produce; scenario format;
  the do-not-invent rule.
- `02-design.md` — when `spec-ux` runs, what `15-design.md` contains.
  Scoped via `applyTo: **/*.{tsx,jsx,vue,svelte,css,scss,swift,kt}`.
- `03-implement.md` — Coder's per-task sequence; the do-not-read
  informal-spec rule.
- `04-refactor.md` — Refactorer's structural pass.
- `05-verify.md` — Verifier's re-execution rules.
- `06-architect.md` — Architect's mutation-test pass + commit/push
  carve-out.
- `07-archive.md` — how `archive-spec.sh` runs.
- `99-validation-checklist.md` — single-source checklist.

Each instruction file declares its own `applyTo` glob.

Plus:

- `docs/SPEC_PIPELINE.md` slimmed to an index (link to
  `00-pipeline-overview.md`, the human-review gate, the commit/push
  carve-out). No behavioral rules duplicated.
- The 7 `agents/spec-*.md` files become one-line pointers plus their
  delta (model, tools, permissions). No workflow steps restated.
- `AGENTS.md` updates its pointer to match.

## What I don't want

- Any change to agent behavior, model choice, or tool list. Only the
  source-of-truth moves.
- Any change to how `archive-spec.sh` runs.
- New agents or new stages.
- Renaming the existing `spec-ux` agent to `spec-designer` (matches ACDC
  but it's a follow-up; defer).

## Out of scope

The `.ps1` cross-platform mirroring from ACDC (this repo is Linux-only;
child repos can vendor their own `.ps1`). Language-specific gates
(`scripts/gates/`). Hooks. The PR auto-pipeline. Those are Phases B–D.

## How child repos will use this

The new folder lives at `.standards/instructions/` and travels with the
existing `.standards/` submodule mount. No child-repo wiring changes;
existing consumers gain the new files automatically when they bump the
submodule.
