# AC-042-09: Unenforced rules are marked advisory

## AC-042-09-01 — The four affected bullets carry the advisory suffix
Given `AGENTS.md` §General Rules
When the layering, business-logic-in-services, `/health`, and structured-logging bullets are read
Then each of them ends with `— *advisory* (see §Enforcement status)`
And no other bullet in §General Rules carries that suffix

## AC-042-09-02 — An Enforcement status subsection names the advisory set
Given `AGENTS.md`
When the section after §General Rules is read
Then it contains the heading `### Enforcement status`
And it states that advisory rules are reviewed in PR and are not enforced by a gate

## AC-042-09-03 — The advisory table has exactly three rows
Given the `### Enforcement status` subsection
When its table is read
Then it has exactly three data rows
And those rows cover layering, `/health`, and structured logging with trace IDs
And each row's status cell is `advisory`

## AC-042-09-04 — The subsection states no check exists and that adding one is a new spec
Given the `### Enforcement status` subsection
When its closing paragraph is read
Then it contains `no script check`
And it contains `new spec`
And it states that rules citing a `scripts/check-*.sh` gate are mechanically enforced in self-ci

## AC-042-09-05 — No false enforcement claim remains
Given `AGENTS.md`
When the four marked bullets are read
Then none of them states or implies that a script checks the rule
And the enforcement-claim bullets for `scripts/check-code-principles.sh`, `scripts/check-orchestration.sh`, and `scripts/check-skills.sh` are unchanged and unmarked
