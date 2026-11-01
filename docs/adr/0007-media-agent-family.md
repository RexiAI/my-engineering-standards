# Architecture Decision Record (ADR)

## Title

Media agent family (image, video, voice, producer)

## Status

Superseded by [0016](0016-provider-agnostic-media-agents.md) — amended by
[0018](0018-media-agents-opt-in.md)

## Context

This record introduced a machine-level media agent family: four agents
(image, video, voice, producer) that produced images, video, narration, and
end-to-end videos through one hosted vendor CLI, shipped under `agents/` with a
Windows bootstrap and a realtime voice app.

That shape assumed a single provider. When the provider wiring was removed, the
decision it recorded no longer described the shipped system, and the record was
retired with it (2026-10-31).

## Decision

Nothing here is in force. Read the two successors instead:

- [0016](0016-provider-agnostic-media-agents.md) — the family is
  provider-agnostic: the agents drive a user-configured `backends.json` argv
  contract, pin no model, and ship no vendor surface.
- [0018](0018-media-agents-opt-in.md) — the family's placement: it lives in
  `agents-optional/`, is absent from the default agent set every child repo
  links, and is loaded by explicit opt-in only (global installer, or
  `--with-media` per repo).

This record is retained rather than deleted so the family has one continuous
lineage: scope (0007) → provider-agnostic contract (0016) → opt-in placement
(0018). Records 0016 and 0018 point back here.

### Alternatives Considered

Retaining versus removing a superseded record: removal keeps the index short but
erases the lineage and leaves the successor's "amends 0007" reference dangling;
a superseded pointer keeps both intact at the cost of one extra index row. The
pointer wins.

## Consequences

- The family's history stays resolvable in the index; a reader following 0016 or
  0018 back to "why does this family exist at all" lands here.
- No behaviour is defined by this file. Editing it cannot change what ships.

## Compliance

- `docs/adr/README.md` lists this record with its Superseded status, and
  `docs/adr/0018-media-agents-opt-in.md` references it — both asserted by
  `scripts/tests/ac-040-media-agents-optional.bats`.

## Notes

- 2026-10-28: superseded by the provider-agnostic rewrite (ADR 0016).
- 2026-11-01: reinstated as a superseded pointer, and named as the record ADR
  0018 amends (the opt-in placement decision).
