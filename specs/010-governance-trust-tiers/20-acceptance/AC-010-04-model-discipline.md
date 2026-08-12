# AC-010-04: Model assignments live in one authoritative place, with a mirror and conformance note

## AC-010-04-01 — The Model-Assignment Discipline section exists

Given `docs/GOVERNANCE.md`
When the file is read
Then it contains the heading `## Model-Assignment Discipline`

## AC-010-04-02 — opencode.json is the single authoritative source

Given the `## Model-Assignment Discipline` section
When the section is read
Then it names `opencode.json` (the `agent.<name>.model` key) as the single
authoritative place where model assignments live

## AC-010-04-03 — The AGENTS.md table is a mirror

Given the `## Model-Assignment Discipline` section
When the section is read
Then it states the `AGENTS.md` model table is a mirror of `opencode.json`
And it states the mirror is not a second source of truth

## AC-010-04-04 — The same-commit rule is stated

Given the `## Model-Assignment Discipline` section
When the section is read
Then it states a model change is made only by editing `opencode.json` AND the
`AGENTS.md` mirror table in the same commit
And it forbids editing one without the other

## AC-010-04-05 — Agent frontmatter must not pin models

Given the `## Model-Assignment Discipline` section
When the section is read
Then it states agent files must not pin a `model:` key
And it explains a pinned frontmatter model silently overrides `opencode.json`

## AC-010-04-06 — A conformance note ties the rule to the observed drift

Given the `## Model-Assignment Discipline` section
When the section is read to the end
Then it contains an explicit conformance note
And that note says violating the same-commit rule is a governance defect
And that note names the observed `spec-architect` drift as the failure mode the
rule exists to prevent
