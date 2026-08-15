# 002-civ-instructions-folder

> Spec pipeline archive. Original source: `specs/002-civ-instructions-folder/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

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

## Tasks

# 002 — Split spec pipeline into numbered, scoped instructions: Tasks

No source code, no CI. No behavior change. Pure organization: nine files
under `.standards/instructions/`, a slimmed `docs/SPEC_PIPELINE.md`, and
seven `agents/spec-*.md` files reduced to one-line pointers.

## Dependency order

1. **Tasks 1–2** (the nine instruction files + the slimmed index)
   define the shape; implement first.
2. **Task 3** (per-agent pointer updates) depends on Task 1 (the files
   exist before they can be referenced).
3. **Task 4** (root pointer updates) depends on Task 3.
4. **Task 5** (verification) runs last.

---

## Task 1 — Author the nine instruction files

Create `.standards/instructions/` and one Markdown file per SDLC step.
Each file has YAML frontmatter with `description:` and (where it does
not apply globally) `applyTo:` scoping the instruction to the files
that stage edits.

Files:

- `00-pipeline-overview.md` — pipeline shape, role boundaries, hand-off
  contracts. (Content moves from `docs/SPEC_PIPELINE.md §Stages`.)
- `01-specify.md` — what `spec-specifier` must produce; scenario
  format; do-not-invent rule.
- `02-design.md` — when `spec-ux` runs; `15-design.md` shape.
  `applyTo: **/*.{tsx,jsx,vue,svelte,css,scss,swift,kt}`.
- `03-implement.md` — Coder's per-task sequence; do-not-read
  informal-spec rule. `applyTo: src/**, tests/**, lib/**`.
- `04-refactor.md` — Refactorer's structural pass.
  `applyTo: src/**, lib/**`.
- `05-verify.md` — Verifier's re-execution rules.
- `06-architect.md` — Architect's mutation-test pass + commit/push
  carve-out.
- `07-archive.md` — how `archive-spec.sh` runs.
- `99-validation-checklist.md` — single-source checklist.

Acceptance criteria:

- Each file has YAML frontmatter with `description:`.
- Each file declares `applyTo:` matching the globs listed above.
- `00-pipeline-overview.md` is a faithful restatement of
  `docs/SPEC_PIPELINE.md §Stages` (no invention).

---

## Task 2 — Slim `docs/SPEC_PIPELINE.md`

Reduce the file to:

1. A link to `.standards/instructions/00-pipeline-overview.md`.
2. The human-review-gate description (kept verbatim).
3. The commit/push carve-out (kept verbatim).

At the top, a one-line notice: "Behavioral rules now live under
`.standards/instructions/`. This document is an index."

Acceptance criteria:

- The file contains no behavioral rule text duplicated from any
  `.standards/instructions/NN-*.md`.
- The human-review-gate paragraph and commit/push carve-out paragraph
  are preserved verbatim.
- File opens with the one-line notice.

---

## Task 3 — Update the seven agent specs

For each of `agents/spec-specifier.md`, `agents/spec-ux.md`,
`agents/spec-coder.md`, `agents/spec-refactorer.md`,
`agents/spec-verifier.md`, `agents/spec-architect.md`,
`agents/spec-pipeline.md`:

- Replace any restated workflow steps with a single pointer line:
  > Read `.standards/instructions/<NN>-<topic>.md` first.
- Keep the agent's delta (model, tool list, permission block).

Acceptance criteria:

- Each spec has exactly one pointer line.
- No workflow step, hand-off JSON, gate catalog, layer order, or retry
  budget is restated in any spec file.

---

## Task 4 — Update root pointers

`AGENTS.md` and `README.md`:

- Replace any reference to `docs/SPEC_PIPELINE.md` (for behavioral
  content) with `.standards/instructions/00-pipeline-overview.md`.
- Keep the link to `docs/SPEC_PIPELINE.md` only where it points at
  meta content (pipeline shape, archive-on-merge).

Acceptance criteria:

- Every `docs/SPEC_PIPELINE.md` link in `AGENTS.md` and `README.md` is
  accompanied by either an `applyTo`-aware equivalent or marked as a
  meta-content link.

---

## Task 5 — Verify before merge

- `bash scripts/check-scenario-traceability.sh` passes on any open
  spec branch.
- `grep -r "## " docs/SPEC_PIPELINE.md` shows the slimmed file is an
  index, not a duplicate.
- Visual review confirms no duplicated rule text between `docs/` and
  `.standards/instructions/`.

Acceptance criteria:

- Both checks pass.
- A draft PR is opened and CI is green.

## Acceptance scenarios

## AC-001-01 — `.standards/instructions/` exists with all nine files
## AC-001-02 — Each file has YAML frontmatter with `description:`
## AC-001-03 — Step files declare `applyTo` matching their stage's edit surface
## AC-001-04 — `02-design.md` `applyTo` matches frontend file extensions
## AC-001-05 — `03-implement.md` covers the Coder's edit surface
## AC-001-06 — `00-pipeline-overview.md` faithfully restates the pipeline shape
## AC-002-01 — File opens with the redirect notice
## AC-002-02 — No duplicated rule text
## AC-002-03 — Human-review gate paragraph preserved verbatim
## AC-002-04 — Commit/push carve-out paragraph preserved verbatim
## AC-002-05 — File still links from the README
## AC-003-01 — Each spec has exactly one pointer line
## AC-003-02 — Specifier points at `01-specify.md`
## AC-003-03 — Coder points at `03-implement.md`
## AC-003-04 — Verifier points at `05-verify.md`
## AC-003-05 — No restated rules in agent specs
## AC-004-01 — `AGENTS.md` points at `00-pipeline-overview.md` for behavior
## AC-004-02 — `AGENTS.md` keeps the slimmed-index link only for meta
## AC-004-03 — README references stay resolvable
## AC-005-01 — Traceability check passes
## AC-005-02 — No duplicated rule text between `docs/` and `.standards/`
## AC-005-03 — Draft PR is opened and CI is green

## Verification

# 002 — Verification

This file is populated by `spec-verifier` after Coder + Refactorer
finish. The Verifier transcribes its independent re-check here. The
human does not write this file.

## Re-execution checklist (run before writing the verdict)

- [ ] `bash scripts/check-scenario-traceability.sh` — exit code
- [ ] `grep -F "## " docs/SPEC_PIPELINE.md` — list of section headings
  to confirm slimness
- [ ] For each of the nine new `.standards/instructions/NN-*.md`
  files: existence check + YAML frontmatter sanity check
- [ ] For each of seven `agents/spec-*.md` files: pointer-line count
  = 1, no restated rules
- [ ] For root `AGENTS.md` and `README.md`: every behavioral pointer
  resolves

## Verdict

(Verdict block written by the Verifier agent.)

- [ ] PASS — every box above is green and every AC scenario file
  under `20-acceptance/` is satisfied by the implementation.
- [ ] FAIL — describe what failed and which AC scenarios are
  unsatisfied. Do not fix; the Coder will re-run.

## Quality gates

# 002 — Architect Report

Written by `spec-architect` after Verifier passes. Captures the
final gate result so `scripts/archive-spec.sh` can include it in the
long-lived `docs/changes/002-civ-instructions-folder.md` one-pager.

## Mutation / coverage results

(Populated by `spec-architect` after the run completes.)

## Gate results

| Gate | Status | Notes |
|---|---|---|
| S1 (scenario traceability) | _(populated by Verifier)_ | |
| Mutation (if run) | _(populated by Architect)_ | |
| Complexity | _(populated by Architect)_ | |

## Branch / commit summary

- Branch: `spec/002-civ-instructions-folder`
- Commit count: _(populated by Architect)_
- Tasks touched: 5 of 5

## Verdict

(Populated by `spec-architect`. One of: PASS, FAIL, PARTIAL.)
