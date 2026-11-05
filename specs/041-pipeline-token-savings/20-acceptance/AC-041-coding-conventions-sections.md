# AC-041: Section-scoped `CODING_CONVENTIONS.md` references

Applies to Task 1. Fixture convention: `scripts/check-doc-section-refs.sh [ROOT]`
treats `ROOT` as a tree containing `agents/`, `commands/` and
`docs/CODING_CONVENTIONS.md`, so every negative case below runs against a scratch
`ROOT` instead of editing the repo.

## AC-041-01 — Coder points at named sections, not the whole file

Given `agents/spec-coder.md`
When its `docs/CODING_CONVENTIONS.md` reference line is read
Then it carries the anchors `§Naming`, `§File Organization`, `§Design Principles`,
`§Error Handling Philosophy`, `§Logging`, `§Exception Handling` and
`§Imports Ordering`
And it carries no `§Formatting` anchor

## AC-041-02 — Refactorer points at `§Design Principles` only

Given `agents/spec-refactorer.md`
When its `docs/CODING_CONVENTIONS.md` reference line is read
Then the reference is exactly `docs/CODING_CONVENTIONS.md §Design Principles`
And it carries no other `§` anchor

## AC-041-03 — Checker passes on the repo tree

Given the repo tree after Task 1
When `scripts/check-doc-section-refs.sh` runs
Then it exits 0
And it prints one `[OK]` line per scanned file

## AC-041-04 — Bare whole-file reference is a violation

Given a fixture `agents/spec-x.md` whose line 7 reads
`Follow docs/CODING_CONVENTIONS.md for the house style.`
When `scripts/check-doc-section-refs.sh <root>` runs against that fixture root
Then it exits 1
And its output contains `agents/spec-x.md:7` and `bare-reference`

## AC-041-05 — Anchor that matches no heading is a violation

Given a fixture agent referencing `docs/CODING_CONVENTIONS.md §Design Principals`
And the fixture doc has no `## Design Principals` heading
When the checker runs
Then it exits 1
And its output names `§Design Principals` and `section-missing`

## AC-041-06 — Anchor matching two headings is ambiguous and fails

Given a fixture doc containing two `## Logging` headings
And a fixture agent referencing `docs/CODING_CONVENTIONS.md §Logging`
When the checker runs
Then it exits 1
And its output names `§Logging` and `section-ambiguous`

## AC-041-07 — `--cost` reports referenced-section bytes only

Given a fixture doc where `## Alpha` spans 100 bytes, `## Beta` spans 200 bytes,
and the file is 400 bytes
And a fixture agent whose two reference lines both cite `§Alpha` and never `§Beta`
When `scripts/check-doc-section-refs.sh --cost <root>` runs
Then it prints one line
`cost <agent-path> sections=1 bytes=100 file_bytes=400 ratio=0.25`
And it exits 0

## AC-041-08 — Missing conventions doc is a tooling failure, not a pass

Given a fixture root with an `agents/` directory but no
`docs/CODING_CONVENTIONS.md`
When the checker runs
Then it exits 2
And its stderr names the missing doc
