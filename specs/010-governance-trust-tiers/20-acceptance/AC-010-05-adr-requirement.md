# AC-010-05: ADRs are indexed; pipeline role/gate/billing changes require one

## AC-010-05-01 — The ADR Requirement section exists

Given `docs/GOVERNANCE.md`
When the file is read
Then it contains the heading `## ADR Requirement`

## AC-010-05-02 — Pipeline role, gate catalog, and billing changes require an ADR

Given the `## ADR Requirement` section
When the section is read
Then it states any change to pipeline roles requires an ADR
And any change to the gate catalog requires an ADR
And any change to billing constraints requires an ADR

## AC-010-05-03 — The requirement is review-blocking

Given the `## ADR Requirement` section
When the section is read
Then it states the requirement is review-blocking: a PR that makes one of those
changes without an accompanying ADR cannot merge

## AC-010-05-04 — ADRs use the template and live in docs/adr/

Given the `## ADR Requirement` section
When the section is read
Then it references `templates/ADR.md` as the mandated template
And it references `docs/adr/` as the location where ADRs are stored

## AC-010-05-05 — The ADR index exists and references the template

Given the repo file `docs/adr/README.md`
When the file is read
Then it exists
And it states ADRs are indexed there, one file per ADR
And it references `templates/ADR.md` as the mandated template

## AC-010-05-06 — The index records that no ADR exists yet

Given `docs/adr/README.md`
When the file is read
Then it states no ADRs are recorded yet
