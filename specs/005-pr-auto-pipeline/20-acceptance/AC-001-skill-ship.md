# AC-001: `openspec-ship` skill halts on BLOCK, proceeds on PASS

## AC-001-01 — Skill files exist at the listed paths
Given `.opencode/skills/openspec-ship/`
And `agents/spec-ship.md`
And `.opencode/commands/ship.md`
When the workspace is listed
Then all three files exist

## AC-001-02 — Skill language states the BLOCK-halt contract
Given `.opencode/skills/openspec-ship/SKILL.md`
When it is read
Then it states: PASS → invoke `spec-architect`
And it states: BLOCK → halt, surface gate IDs, no push, no PR

## AC-001-03 — `spec-ship.md` is a thin orchestrator
Given `agents/spec-ship.md`
When it is read
Then its body contains no procedural rules
And it points at `.opencode/skills/openspec-ship/SKILL.md` as its
source of truth
And it exposes exactly one operation: ship the current spec branch

## AC-001-04 — `/ship` slash command maps to the skill
Given `.opencode/commands/ship.md`
When it is read
Then it maps `/ship <slug>` to the `openspec-ship` skill
