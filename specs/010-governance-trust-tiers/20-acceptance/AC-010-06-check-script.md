# AC-010-06: check-governance.sh enforces the governance document

## AC-010-06-01 — The check script exists and is executable

Given the repo root
When the filesystem is scanned
Then a file `scripts/check-governance.sh` exists
And it has the executable bit set

## AC-010-06-02 — The script passes on the compliant repo

Given tasks 1-5 have created `docs/GOVERNANCE.md` with the Trust Tiers,
Model-Assignment Discipline, and ADR Requirement sections
And `docs/adr/README.md` exists
When `scripts/check-governance.sh` runs against the real repo
Then it exits 0
And its output contains `PASS` for every check category

## AC-010-06-03 — The script fails when the governance document is missing

Given a repo state with no `docs/GOVERNANCE.md`
When `scripts/check-governance.sh` runs
Then it exits 1
And it names the missing `docs/GOVERNANCE.md`

## AC-010-06-04 — The script fails when a required heading is missing

Given a `docs/GOVERNANCE.md` missing the `## Trust Tiers` heading
When `scripts/check-governance.sh` runs
Then it exits 1
And it names the missing `## Trust Tiers` heading

## AC-010-06-05 — The script fails when an agent row is missing from the tier table

Given a `docs/GOVERNANCE.md` whose agent-to-tier table omits `spec-verifier`
When `scripts/check-governance.sh` runs
Then it exits 1
And it names the missing agent `spec-verifier`

## AC-010-06-06 — The script fails when the mirror note is missing

Given a `docs/GOVERNANCE.md` whose Model-Assignment Discipline section does not
state `opencode.json` is the authoritative model source
When `scripts/check-governance.sh` runs
Then it exits 1
And it names the missing authoritative-source statement

## AC-010-06-07 — The script fails when the ADR index is missing

Given a repo state with no `docs/adr/README.md`
When `scripts/check-governance.sh` runs
Then it exits 1
And it names the missing `docs/adr/README.md`

## AC-010-06-08 — The script cites every scenario ID

Given the acceptance scenarios in `20-acceptance/`
When `scripts/check-governance.sh` runs
Then its output contains every `AC-010-NN-NN` scenario ID from this spec
