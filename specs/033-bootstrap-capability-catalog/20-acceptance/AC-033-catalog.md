# AC-033: Capability catalog (single source of truth)

## AC-033-01 — `--list` prints every catalog entry
Given a child repo with `.standards/` present
When `bootstrap.sh --list` runs with stdin not a TTY
Then every catalog entry is printed, one per line, as `id<TAB>label<TAB>category`
And the exit code is 0

## AC-033-02 — `--list` output is generated from the catalog
Given the single catalog source
When `bootstrap.sh --list` runs
Then its output matches a rendering of the catalog byte-for-byte
And no capability id, label, or category appears in the output that is absent from the catalog

## AC-033-03 — menu and `--all` consume the same catalog
Given the single catalog source
When `bootstrap.sh` reads its capabilities for the menu and for `--all`
Then both derive their entries from the catalog
And no capability label or flag is hardcoded outside the catalog

## AC-033-04 — every catalog entry carries complete fields
Given the single catalog source
When each entry is inspected
Then every entry has a non-empty id, label, category, and files-written list
And `required stack` is one of backend, frontend, ci, or none
And the `conflicts` field is present (empty list allowed)
