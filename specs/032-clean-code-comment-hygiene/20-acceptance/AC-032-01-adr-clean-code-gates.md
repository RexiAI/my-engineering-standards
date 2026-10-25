# AC-032-01: ADR 0011 records the gate decision

## AC-032-01-01 — The ADR exists with the mandated section shape
Given `docs/adr/` contains ADRs 0001–0010 and no ADR 0011
When `docs/adr/0011-clean-code-comment-gates.md` is read
Then the file exists
And its first heading matches `# ADR 0011: `
And its level-2 headings appear in the order `## Status`, `## Context`, `## Decision`, `## Consequences`, `## Compliance`
And `### Alternatives Considered` appears between `## Decision` and `## Consequences`
And the first non-empty line under `## Status` is either `Proposed` or `Accepted`

## AC-032-01-02 — The ADR records the taxonomy, the rollout, and the rejected blanket ban
Given `docs/adr/0011-clean-code-comment-gates.md`
When its `## Context`, `## Decision`, and `### Alternatives Considered` sections are read
Then `## Context` mentions Clean Code Ch.4 and distinguishes endorsed from forbidden comment kinds
And it names at least four forbidden kinds, including commented-out code and redundant comments
And `## Decision` names `comments`, `naming`, and `null-discipline`
And `## Decision` names `STRICT_CLEAN_CODE=1` and states the gates are WARN by default
And `## Decision` lists the excluded directories `docs/`, `specs/`, `agents/`, `templates/`, `node_modules/`
And the alternatives table has a row for a blanket comment ban
And that row's cons cell names shebangs, `shellcheck` directives, usage headers, and `ponytail:` markers as what the ban would delete
And the ADR records that this spec supersedes spec 011's assertion that no `naming` gate exists

## AC-032-01-03 — The ADR is indexed and governance still passes
Given `docs/adr/README.md`
When the index table is read and `bash scripts/check-governance.sh` runs
Then the index has a row beginning `| 0011 |`
And that row links to `0011-clean-code-comment-gates.md` and that file exists
And that row's status cell is `Proposed` or `Accepted`
And `docs/GOVERNANCE.md` is unchanged in its heading structure (`## Trust Tiers`, `## Model-Assignment Discipline`, `## ADR Requirement`)
And the governance check exits 0
