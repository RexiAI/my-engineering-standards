# AC-039-02: Deterministic size/surface classifier

## AC-039-02-01 — Docs-only small spec is lite
Given a spec whose `10-tasks.md` names only `docs/FOO.md`
And `20-acceptance/` contains 3 scenarios
When `scripts/classify-spec-size.sh` runs on it
Then stdout first line is `lite`
And a `Reason:` line is printed

## AC-039-02-02 — Single-script spec is lite
Given a spec naming exactly one file `scripts/x.sh` and 5 scenarios
When the classifier runs
Then stdout first line is `lite`

## AC-039-02-03 — Scenario count above boundary is full
Given a docs-only spec with 6 scenarios
When the classifier runs
Then stdout first line is `full`

## AC-039-02-04 — Two scripts is full
Given a spec naming `scripts/a.sh` and `scripts/b.sh` and 2 scenarios
When the classifier runs
Then stdout first line is `full`

## AC-039-02-05 — Missing inputs fall back to full
Given a spec folder with no `20-acceptance/` directory
When the classifier runs
Then stdout first line is `full`

## AC-039-02-06 — Missing spec folder
Given a path that does not exist
When the classifier runs
Then exit code is non-zero and stderr names the path

## AC-039-02-07 — Determinism
Given any fixed spec folder
When the classifier runs twice
Then both outputs are byte-identical
