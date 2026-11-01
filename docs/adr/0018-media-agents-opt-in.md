# Architecture Decision Record (ADR)

## Title

Media agents are opt-in: relocate the family to `agents-optional/` and load it
per repo through `--with-media`

## Status

Accepted

## Context

ADR [0007](0007-media-agent-family.md) introduced a machine-level media agent
family (image, video, voice, producer), and
[0016](0016-provider-agnostic-media-agents.md) made it provider-agnostic: the
agents drive a user-configured `backends.json` argv contract instead of one
hosted vendor CLI.

Placement was never revisited. 0016 keeps the four agents in `agents/`, and
every consumer links that directory wholesale — a child repo's `.opencode/agents`
is a symlink to `.standards/agents` (or a `COPY_AGENTS=1` copy of it), and the
global installer copies from it. Anything under `agents/` therefore loads in
**every** child session, whether or not that repo produces media.

That default is wrong for this family:

- Media work is machine-level, not repo-level. It needs a filled-in
  `backends.json`, `ffmpeg` on the machine, and a human approval gate for
  spend. In a backend or CI-reference repo that is irrelevant noise in every
  child session.
- Four extra agents widen the prompt surface and the permission-blast radius of
  every child repo for a capability most of them never use.
- The family cannot simply be dropped into a child's `.opencode/agents/`: that
  path is a **symlink** to the whole `.standards/agents` tree, so no file can be
  added per repo, and `--copy-agents` copies the same whole tree.

The capability itself stays: it is opt-in, not removed.

## Decision

1. The four media agents move out of the default agent set: the sources live in
   `agents-optional/media-{image,video,voice,producer}.md` and no longer under
   `agents/`. `agents/` and `commands/` name none of them. The bridge keeps
   linking `.standards/agents` only, so every child keeps today's wiring and
   stops loading the family by accident.
2. Two opt-in paths remain, both explicit:
   - **Global (machine-wide)** — `node scripts/media/install.mjs` (or
     `make install-media`) copies the four agents, sourced from
     `agents-optional/`, into `~/.config/opencode/agents/`, where they load for
     every opencode session on that machine.
   - **Per repo** — `--with-media` writes one `agent.*` entry per media agent
     into the child's own `opencode.json`, with a
     `{file:.standards/agents-optional/media-<name>.md}` prompt. Nothing is
     written under `.opencode/`; the symlink stays untouched, the entries point
     into the submodule, and deleting them is the off switch.
3. `scripts/capabilities.tsv` keeps `media-agents` on the `--with-media` flag but
   it is a real capability row (it writes `opencode.json`), no longer an
   informational one.
4. `docs/MEDIA_AGENTS.md` states that the family is not loaded by default in
   child repos and documents both opt-in paths.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep the family in `agents/` (status quo of 0016) | zero wiring, present everywhere | every child session loads four irrelevant, permission-broad agents |
| `--with-media` only re-runs the global installer | no new config surface | machine-wide, not per repo; a child cannot opt in or out independently, and CI/other machines get nothing |
| Drop the per-repo flag, global installer only | smallest surface | no per-repo opt-in at all; the capability catalog's existing `--with-media` row would dangle |
| `agents/optional/` subdirectory | keeps one tree | unverified whether opencode loads nested agent subdirectories — a silent no-load |
| Copy the four files into the child's `.opencode/agents/` | plain files | impossible: that path is a symlink to the whole standards tree, and a copy would go stale on every submodule bump |
| Delete the family | smallest surface | loses a useful machine capability instead of making it opt-in |

## Consequences

- Every child repo's default agent set shrinks by four files; nothing changes
  for a child until it asks for the family.
- The global install path is unchanged from a user's point of view
  (`make install-media` → `~/.config/opencode/agents/media-*.md`), only the
  repo-side source directory moved.
- A per-repo opt-in adds four keys to the child's `opencode.json` and is
  re-runnable: a second `--with-media` run is a no-op, unrelated keys and agent
  entries are preserved, and an unparsable (JSON-with-comments) config is left
  untouched with a WARN naming the manual step.
- `--all` selects the row like any other non-baseline capability; the family is
  still never part of a default (flagless) run.
- ADR 0016's placement sentence ("keep the four agents in `agents/`") is
  superseded by this record; its provider-agnostic contract decision stands.

## Compliance

- `scripts/tests/ac-040-media-agents-optional.bats` — `agents-optional/` holds
  the four files, `agents/` holds none, the bridge exposes none, the installer
  sources from `agents-optional/`, and `--with-media` writes and merges the
  entries. Two runs bracket the selection: a `--none` child carries no media
  entry (and no media file under `.opencode/`), while a `--all` child carries
  all four — the row is a normal non-baseline capability, so `--all` selects it
  exactly as it selects any other opt-in row. Only a flagless run and `--none`
  leave the family out.
- `scripts/tests/media-agents.bats` — the family's structural contract
  (frontmatter, no pinned model, backend-contract reference, no vendor tokens)
  asserted against `agents-optional/`.
- `scripts/check-orchestration.sh` and `scripts/check-skills.sh` stay green: the
  default `agents/` and `commands/` trees contain no reference to the relocated
  family.
- `scripts/check-orchestration.sh` deliberately does **not** scan
  `agents-optional/`: it verifies references that resolve in this repo's own
  tree (`agents/`, `commands/`, `AGENTS.md`), while these four files are only
  reached from a child repo's `opencode.json` through
  `.standards/agents-optional/…`, whose paths resolve inside the submodule.
  Widening the scan would judge those paths against the wrong root.

## Notes

- 2026-11-01: Decision recorded. Amends ADR [0007](0007-media-agent-family.md)
  (family scope) and supersedes ADR 0016's placement rule; ADR 0016's
  provider-agnostic backend contract is unchanged.
