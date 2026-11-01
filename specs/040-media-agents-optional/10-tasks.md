# 040 — Media agents opt-in for child repos — Tasks

Context (facts from repo, not requirements): child repos receive agents via
`templates/Makefile.bridge`, which symlinks (or `COPY_AGENTS=1` copies) the whole
`.standards/agents` directory to `.opencode/agents`. Any file under `agents/` is
therefore loaded in every child session. `scripts/media/install.mjs` already
copies media agents to the opencode global dir (`~/.config/opencode/agents/`).
`scripts/check-orchestration.sh` scans only `agents/*.md` and `commands/*.md`
(maxdepth 1).

Design decision taken by Specifier (see Open question Q1): relocate the four
media agent files from `agents/` to a new top-level directory `agents-optional/`.
Because the bridge links only `agents/`, they leave the default child set without
being deleted. Opt-in = the existing installer (global) or the per-repo
`--with-media` capability.

## Task 1 — Relocate media agents out of the default agent set
- `agents-optional/media-image.md`, `media-video.md`, `media-voice.md`, `media-producer.md` exist; content unchanged except path references.
- None of `agents/media-image.md`, `agents/media-video.md`, `agents/media-voice.md`, `agents/media-producer.md` exists.
- No file in `agents/` or `commands/` names `media-image`, `media-video`, `media-voice`, or `media-producer`.
- `templates/Makefile.bridge` is unchanged in what it links (`.standards/agents` only); nothing under it references `agents-optional`.
- Scenarios: AC-040-01.

## Task 2 — Opt-in mechanisms
- `scripts/media/install.mjs` reads source files from `agents-optional/` (not `agents/`); install and `--uninstall` still target `~/.config/opencode/agents/media-*.md`.
- `scripts/capabilities.tsv` `media-agents` row keeps flag `--with-media`; its description/target text no longer implies default loading.
- When a child repo is bootstrapped with `--with-media`, the four media agents become loadable in that repo per the mechanism documented in `docs/MEDIA_AGENTS.md` (see Q2); without the flag, no media agent file is placed under the child's `.opencode/`.
- Scenarios: AC-040-02.

## Task 3 — ADR amendment
- New ADR `docs/adr/0018-media-agents-opt-in.md` exists, status `Accepted`, with sections Context, Decision, Consequences, and states it amends ADR 0007.
- ADR 0007 `## Status` line references 0016 (e.g. "Amended by 0016").
- `docs/adr/README.md` index lists 0016.
- Scenarios: AC-040-03.

## Task 4 — Docs and tests consistent
- `docs/MEDIA_AGENTS.md` component table paths point to `agents-optional/…`; it contains a section stating media agents are not loaded by default in child repos and describes both opt-in paths (global installer, `--with-media`).
- `docs/GOVERNANCE.md` contains no `agents/media-*` path.
- `scripts/tests/media-agents.bats` checks files under `agents-optional/`; adds a test asserting no `agents/media-*.md` exists; all its tests pass under `make test`.
- `scripts/check-orchestration.sh` exits 0 and `scripts/check-skills.sh` exits 0 on the repo.
- Scenarios: AC-040-04.

## Open questions
- **Q1 (non-blocking, default chosen):** directory name/location `agents-optional/`. Alternative: `agents/optional/` subdir — rejected because whether opencode loads nested agent subdirs is unverified. Human may rename at review.
- **Q2 (needs answer before /build):** per-repo `--with-media` mechanism. `.opencode/agents` is a symlink to the whole `.standards/agents`, so files cannot be added inside it. Options: (a) `--with-media` only prints/runs the global installer (machine-wide, not per-repo); (b) `--with-media` writes `agent` entries into the child `opencode.json` using `{file:.standards/agents-optional/media-*.md}` prompts; (c) drop the per-repo flag, global installer only. Default if unanswered under autopilot: (a), since it reuses existing `install.mjs` without new config surface.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Q1: folder name `agents-optional/` — accepted.
- Q2: option (b) — `--with-media` adds `agent` entries to the child's `opencode.json` pointing at `.standards/agents-optional/`.
