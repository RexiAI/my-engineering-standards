# 006-orchestration-conformance

> Spec pipeline archive. Original source: `specs/006-orchestration-conformance/` (deleted by this script).
> Archived: 2026-08-12

## Original ask

# Orchestration self-conformance check

The spec pipeline orchestration (commands/, agents/, skills/, scripts/) is a
program too, but nothing verifies its wiring. A subagent referenced in a command,
a skill named in an agent, or a script invoked by the verifier can silently not
exist — the failure surfaces mid-run, after the expensive stages.

Bring the acdc-civ practice of a model-free dry-run harness, but pointed inward:
a `scripts/check-orchestration.sh` that asserts every cross-reference in the
orchestration layer resolves to a real file.

## What it must check

- Every `agent_type='...'` / `agent_type="..."` value in commands/*.md and
  agents/*.md resolves to an existing file in agents/.
- Every skill referenced by name in agents/*.md (e.g. `check-principles`,
  `design-taste-frontend`) exists under skills/<name>/SKILL.md.
- Every `scripts/...` path referenced in agents/, commands/, and AGENTS.md
  exists as a file (or as .ps1/.sh twins).
- Every `docs/...` and `language-specific/<lang>/SKILL.md` cross-reference in
  agents/ resolves. (Reuse the Makefile validate-refs pattern.)
- Exit 0 = all references resolve; 1 = at least one dangling reference, with the
  broken ref + the file that cites it.

## Acceptance criteria

- AC-001: a deliberately dangling `agent_type='ghost'` in a scratch command file
  makes the script exit 1 with the file and reference named.
- AC-002: the clean repo passes (exit 0).
- AC-003: runs as part of self-ci (`.github/workflows/self-ci.yml`), so a broken
  orchestration reference fails the standards repo's own PR gate.
- AC-004: README / AGENTS.md documents the command to run it.

## Tasks

# Tasks — Orchestration self-conformance check

Formalization of `specs/006-orchestration-conformance/00-informal.md`. Goal: a
`scripts/check-orchestration.sh` that asserts every cross-reference in the
orchestration layer (commands/, agents/, skills/, scripts/, docs/) resolves to a
real file, exits 0 on a clean repo and 1 with the broken ref + citing file
otherwise, and runs in `.github/workflows/self-ci.yml`.

## Grounded reality (verified against this repo)

- Agent references in this repo take three forms, all of which the script must
  resolve to `agents/<name>.md`:
  1. YAML frontmatter key `agent: <name>` (commands/spec.md:3, commands/build.md:3)
  2. Backtick-quoted `spec-<name>` tokens in prose (commands/build.md:11-12,
     agents/spec-pipeline.md:14-23, agents/spec-pr-opener.md:2)
  3. Literal `agent_type='<name>'` / `agent_type="<name>"` assignments — none exist
     in the repo today, but AC-001 (the negative test) requires the script to
     accept this form.
- **`agents/spec-architect.md` does not exist.** The Architect was split into
  `spec-mutation-runner` + `spec-pr-opener` (see git history), but
  `agents/spec-mutation-runner.md:39` still contains the bare token
  `spec-architect`. Under a token-based agent check the clean repo currently
  fails — the check catches a real dangling reference. Task 5 removes it; only
  then does "clean repo passes" hold.
- `agents/spec-coder.md:40` references `language-specific/<lang>/SKILL.md` — a
  template placeholder, not a real path. The docs check must match concrete
  langs (`language-specific/[a-z]+/SKILL.md`) so `<lang>` is never flagged.
- `agents/spec-verifier.md:58` references `.standards/scripts/…` — the child-repo
  form of a scripts path. It is NOT a `scripts/` reference in this repo and must
  not be flagged.
- All scripts currently referenced in agents/, commands/, AGENTS.md exist
  (check-code-principles.sh, check-scenario-traceability.sh, archive-spec.sh,
  detect-saga-outbox.sh, init-ci.sh, check-saga-timeouts.sh, check-saga-tests.sh,
  lint-outbox-schema.sh, check-outbox-relay.sh).
- The only skill referenced by name in agents/ is `design-taste-frontend`
  (agents/spec-ux.md:16-17); `skills/design-taste-frontend/SKILL.md` exists.
  `check-principles` is referenced only in AGENTS.md (out of scope — see task 4).
- `docs/SPEC_PIPELINE.md` and `docs/CODING_CONVENTIONS.md` (both cited in agents/)
  and `language-specific/go/SKILL.md` all exist.
- The Makefile `validate-refs` target already greps `docs/[A-Z_]+\.md` and reports
  `[BROKEN] <src> -> <ref>`; task 4 reuses that exact pattern and message shape.
- `.github/workflows/self-ci.yml` has a Validate job; the orchestration check
  hooks in as a new step (task 6).

## Tasks

### Task 1 — Implement `scripts/check-orchestration.sh` core and agent-reference resolution

Create `scripts/check-orchestration.sh` with the shared contract (output format,
exit codes) and the first check category.

Acceptance criteria:
- Script is POSIX sh / bash, parses clean under `bash -n`, no unbound deps beyond
  coreutils.
- On any dangling reference, prints one `[BROKEN] <citing-file> -> <broken-ref>`
  line per failure and a `N broken reference(s)!` summary, then `exit 1`.
- When every reference resolves, prints `All orchestration references valid.` and
  `exit 0`.
- Agent check scans all `commands/*.md` and `agents/*.md` for agent references in
  all three forms (frontmatter `agent:` key, backtick-quoted `spec-<name>` tokens,
  literal `agent_type='…'` / `agent_type="…"`). Each extracted name must resolve to
  `agents/<name>.md`.
- `commands/` and `agents/` are the only scanned trees for this category; no other
  directories.
- The script accepts an optional directory argument (or equivalent isolation
  mechanism) so acceptance tests can point it at scratch files without touching the
  real `commands/`/`agents/`.
- On the real repo as it stands, the agent check reports exactly one broken
  reference — `agents/spec-mutation-runner.md -> spec-architect` — and nothing
  else; exit code is 1. (This is the genuine dangling reference task 5 fixes.)

Scenarios: `20-acceptance/AC-006-01-check-agent-refs.md`

### Task 2 — Skill-reference resolution

Extend the script to resolve every skill referenced by name in `agents/*.md` to
`skills/<name>/SKILL.md`.

Acceptance criteria:
- A skill reference is a backtick-quoted name on a line in `agents/*.md` that also
  contains the word `skill`, or a `name: <name>` assignment (per
  agents/spec-ux.md:16-17).
- Each extracted name must resolve to `skills/<name>/SKILL.md`.
- On the real repo, the skill check reports zero broken references (only
  `design-taste-frontend` is cited; it exists). A scratch agent file citing
  `skills/nonexistent-skill/SKILL.md` (e.g. a line `Load the `ghost-skill` skill.`)
  makes the script exit 1 naming the skill and the citing file.
- Check scope is `agents/*.md` only. `check-principles` cited in AGENTS.md is out
  of scope and must not be checked here.

Scenarios: `20-acceptance/AC-006-02-check-skills.md`

### Task 3 — `scripts/...` path resolution

Extend the script to resolve every `scripts/<name>.sh` (or `.ps1` twin) path
referenced in `agents/`, `commands/`, and `AGENTS.md`.

Acceptance criteria:
- Extract `scripts/<file>` paths (accepting `.sh` or `.ps1` suffix, i.e. the
  `<file>` may be `foo.sh` or `foo.ps1`) from `agents/*.md`, `commands/*.md`, and
  `AGENTS.md`.
- Each path must resolve to an existing file relative to the repo root. A
  `.sh`/`.ps1` twin counts as resolving (informal spec: "as a file (or as
  .ps1/.sh twins)").
- `.standards/scripts/…` (agents/spec-verifier.md:58) is a child-repo path, not a
  `scripts/` reference in this repo, and must NOT be matched.
- On the real repo, the scripts check reports zero broken references (all nine
  cited scripts exist). A scratch file citing `scripts/nonexistent.sh` makes the
  script exit 1 naming the path and the citing file.
- Scope is exactly agents/, commands/, AGENTS.md — not docs/ (which is task 4).

Scenarios: `20-acceptance/AC-006-03-check-scripts.md`

### Task 4 — `docs/...` and `language-specific/<lang>/SKILL.md` resolution in agents/

Extend the script to resolve every docs/ and language-specific cross-reference in
`agents/*.md`, reusing the Makefile `validate-refs` pattern.

Acceptance criteria:
- Match `docs/[A-Z_]+\.md` tokens in `agents/*.md` (same regex as the Makefile
  `validate-refs` target) and resolve each to an existing file at repo root.
- Match `language-specific/[a-z]+/SKILL.md` tokens in `agents/*.md` and resolve
  each. `language-specific/<lang>/SKILL.md` must NOT match (angle brackets are not
  `[a-z]`), so the template placeholder in agents/spec-coder.md:40 is never
  flagged.
- Output format identical to the agent/skill/scripts categories:
  `[BROKEN] <citing-file> -> <ref>`.
- On the real repo, the docs check reports zero broken references
  (docs/SPEC_PIPELINE.md, docs/CODING_CONVENTIONS.md,
  language-specific/go/SKILL.md all exist). A scratch agent file citing
  `docs/NONEXISTENT.md` makes the script exit 1 naming the ref and the citing file.
- Scope is `agents/*.md` only (this mirrors the informal spec: "in agents/").
  `docs/` refs in AGENTS.md, commands/, and other markdown are not this script's
  job — `make validate-refs` already covers the whole repo.

Scenarios: `20-acceptance/AC-006-04-check-docs.md`

### Task 5 — Fix the dangling `spec-architect` reference in `agents/spec-mutation-runner.md`

Remove the only currently-dangling orchestration reference so the clean repo
passes.

Acceptance criteria:
- `agents/spec-mutation-runner.md:39` no longer contains the bare token
  `spec-architect`. Reword the prose so the Architect role is described without
  naming a nonexistent agent file (e.g. "the Architect role runs at every tier")
  — the split into mutation-runner (5a) + pr-opener (5b) stays accurate.
- No other text in the file changes.
- After this change, running the script (tasks 1-4 complete) on the real repo
  reports zero broken references and exits 0.
- No `agents/spec-architect.md` file is created — the informal spec forbids
  inventing files, and the split design is intentional.
- The line does not gain a backtick quoting `spec-architect`; the token must be
  gone entirely so no future regex match can resurrect it.

Scenarios: `20-acceptance/AC-006-05-fix-dangling-architect-ref.md`

### Task 6 — Wire into self-ci and document the run command; clean-repo pass

Make the check part of the standards repo's own PR gate and document how to run
it, so a broken orchestration reference fails CI (AC-003) and is discoverable
(AC-004).

Acceptance criteria:
- `.github/workflows/self-ci.yml` Validate job gains a step that runs
  `scripts/check-orchestration.sh` (a step name like "Check orchestration
  references" — placed alongside the existing `make validate-all` step). A
  dangling reference therefore fails the repo's own PR gate.
- The step runs after `make validate-all` and before `make lint` (or adjacent to
  them) — exact position is at the Coder's judgment, but it must be in the same
  Validate job.
- AGENTS.md documents how to run the check standalone (a bullet or short section,
  e.g. under General Rules, mirroring how `check-code-principles.sh` and
  `check-scenario-traceability.sh` are surfaced). It names the script and its
  contract: exit 0 = all orchestration references resolve; exit 1 = broken
  reference, with the broken ref and citing file printed.
- With tasks 1-5 done, running `scripts/check-orchestration.sh` against the real
  repo prints `All orchestration references valid.` and exits 0. This is AC-002
  ("the clean repo passes"), which only becomes true after task 5.
- No git tags are created; no commits/pushes are made by the agent.

Scenarios: `20-acceptance/AC-006-06-wire-ci-and-docs.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 dangling `agent_type='ghost'` → exit 1 naming file+ref | 1 | `AC-006-01-check-agent-refs.md` |
| AC-002 clean repo passes (exit 0) | 6 (after 5) | `AC-006-06-wire-ci-and-docs.md` |
| AC-003 runs as part of self-ci | 6 | `AC-006-06-wire-ci-and-docs.md` |
| AC-004 README/AGENTS.md documents the command | 6 | `AC-006-06-wire-ci-and-docs.md` |

## Open questions (need a human answer before /build)

1. **AGENTS.md still cites `agents/spec-architect.md`** (AGENTS.md:19, and the
   model table at AGENTS.md:53 lists `spec-architect`). That file does not exist.
   AGENTS.md is only in scope for `scripts/` paths per the informal spec, so the
   check will not flag these. Is that acceptable, or should task 5 also reword
   AGENTS.md (its model table and the Architect carve-out line) to reference the
   real mutation-runner/pr-opener split — or should the check scope expand to
   `agents/...` path tokens in AGENTS.md? My recommendation: fix AGENTS.md prose in
   the same change as task 5, since it is the same stale reference, but keep the
   *check* scope as specified (AGENTS.md = scripts/ paths only) to avoid
   over-matching the model table's plain names.
2. **`agent_type=` literal form.** The informal spec and AC-001 name this syntax,
   but the repo's real files use YAML `agent:` frontmatter and backticked `spec-*`
   prose tokens. Task 1 implements all three forms so AC-001 still holds as
   written. Confirm that is the intended reading (it is grounded; nothing in the
   repo uses `agent_type=` today).
3. **Scratch-file isolation for tests.** AC-001 needs a deliberately dangling
   command file without polluting the real `commands/`. Task 1 gives the script an
   optional path/dir argument for that. Confirm tests may use a scratch dir under
   the repo (gitignored) or /tmp, and that the script's default (no arg) is always
   the real repo.
4. **Docs scope excludes docs/ refs in commands/ and AGENTS.md.** The informal spec
   says "in agents/" for docs refs, and the Makefile `validate-refs` already
   covers every `*.md` repo-wide. Confirm the new script should not duplicate that
   (task 4 checks agents/ only).

## Acceptance scenarios

## AC-006-01-01 — A dangling `agent_type='ghost'` makes the script exit 1 with the file and reference named (AC-001)
## AC-006-01-02 — Double-quoted `agent_type="..."` form is also detected
## AC-006-01-03 — A dangling YAML frontmatter `agent:` value is detected
## AC-006-01-04 — A dangling backtick-quoted `spec-*` prose token is detected
## AC-006-01-05 — Every existing agent reference resolves without a BROKEN line
## AC-006-01-06 — The current repo reports exactly one dangling agent reference
## AC-006-01-07 — An isolated scope with all agent references valid exits 0
## AC-006-02-01 — A dangling skill name makes the script exit 1 naming the skill and citing file
## AC-006-02-02 — A `name: <skill>` assignment form is also detected
## AC-006-02-03 — A referenced skill that exists resolves without a BROKEN line
## AC-006-02-04 — The current repo's skill references all resolve
## AC-006-02-05 — A dangling skill reference makes the script exit 1 even when all agent references resolve
## AC-006-03-01 — A dangling scripts/ path makes the script exit 1 naming the path and citing file
## AC-006-03-02 — A `.ps1` twin counts as resolving a `.sh` reference (and vice versa)
## AC-006-03-03 — A child-repo `.standards/scripts/...` path is not treated as a repo scripts/ reference
## AC-006-03-04 — Every scripts/ reference in the current repo resolves
## AC-006-03-05 — A dangling scripts/ path in AGENTS.md makes the script exit 1
## AC-006-04-01 — A dangling docs/ reference makes the script exit 1 naming the ref and citing file
## AC-006-04-02 — Only uppercase-named docs/ references are matched (Makefile validate-refs pattern)
## AC-006-04-03 — The `language-specific/<lang>/SKILL.md` template placeholder is not flagged
## AC-006-04-04 — A concrete `language-specific/<lang>/SKILL.md` reference resolves
## AC-006-04-05 — Every docs/ and language-specific reference in the current repo's agents/ resolves
## AC-006-05-01 — The bare `spec-architect` token is removed
## AC-006-05-02 — The split into Mutation Runner (5a) and PR Opener (5b) stays accurate
## AC-006-05-03 — No `agents/spec-architect.md` file is created and no other agent file changes
## AC-006-05-04 — The script exits 0 against the repo after the fix
## AC-006-06-01 — The check runs as part of self-ci (AC-003)
## AC-006-06-02 — The check fails the repo's own PR gate on a broken reference
## AC-006-06-03 — AGENTS.md documents the standalone run command (AC-004)
## AC-006-06-04 — The clean repo passes (AC-002)

## Verification

_(not produced)_

## Quality gates

_(not produced)_
