# 005 — PR auto-pipeline: Tasks

`/ship <slug>` and the `openspec-ship` skill halts on BLOCK, proceeds
on PASS. No override. Additive to existing `/spec` and `/build`.

## Dependency order

1. **Task 1** (`openspec-ship` skill + `spec-ship` orchestrator +
   `/ship` command) is the user-facing spine; implement first.
2. **Task 2** (wire existing agents) depends on Task 1.
3. **Task 3** (end-to-end verify) runs last.

---

## Task 1 — Author the skill and orchestrator

- `.opencode/skills/openspec-ship/SKILL.md` — BLOCK-halt contract
  language.
- `.opencode/skills/openspec-ship/README.md` — usage examples, stop
  conditions.
- `agents/spec-ship.md` — `mode: primary`, thin pointer to the
  skill. Exposes one operation: "ship the current spec branch".
- `.opencode/commands/ship.md` — slash command, maps `/ship <slug>`
  to the skill.

Acceptance criteria:

- All four files exist at the listed paths.
- The skill's SKILL.md explicitly states: BLOCK → halt, no push, no
  PR; PASS → invoke `spec-architect`.

---

## Task 2 — Wire the existing agents

- `agents/spec-pipeline.md`: add a third invocation mode
  (`/ship <slug>`). Update its pointer to the new skill.
- `agents/spec-architect.md`: add a pre-push check that requires
  `<RepoPath>/.civ/gate-report.json` exists, `status: PASS`, and
  report's branch+SHA match `HEAD`. Refuse to push on mismatch.
- `agents/spec-verifier.md`: change verdict contract to be a
  transcription of `.civ/gate-report.json` plus
  `warnings[]` for model-vs-JSON disagreements.

Acceptance criteria:

- `spec-pipeline.md` exposes three modes: `/spec`, `/build`, `/ship`.
- `spec-architect.md` aborts on stale/missing/blocked gate report.
- `spec-verifier.md` verdict fields come from the JSON, not from
  re-execution.

---

## Task 3 — End-to-end verify

Manual end-to-end on a test branch:

1. Create `spec/NNN-test-ship/00-informal.md` with a trivial feature
   ("create `~/echo.txt` containing the word hello").
2. Run `/spec` → `/build` → `/ship`.
3. Confirm PASS path pushes the branch. (PR creation is
   user-driven; the agent pushes, the user clicks.)
4. Introduce a failing scenario on a branch. Run `/ship`. Confirm
   BLOCK halts, surfaces gate IDs, no push.
5. Remove the failure, re-run `/ship`. Confirm PASS resumes.

Plus documentation:

- `README.md` — "Ship a feature" section explaining
  `/spec` → `/build` → `/ship`.
- `.standards/instructions/00-pipeline-overview.md` — link to
  `/ship`.

Acceptance criteria:

- All four `Task 3` checks pass.
- `dry-run.sh` is green.
- README and pipeline-overview both reference `/ship`.
