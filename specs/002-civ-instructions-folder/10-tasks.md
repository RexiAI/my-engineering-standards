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
