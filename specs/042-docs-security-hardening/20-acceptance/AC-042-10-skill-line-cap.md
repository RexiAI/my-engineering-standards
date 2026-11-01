# AC-042-10: 200-line cap for `language-specific/*/SKILL.md`

## AC-042-10-01 — This repo still passes the gate
Given the repository's current `language-specific/` guides
When `./scripts/check-skills.sh` runs with no arguments
Then it exits `0`
And it reports no `[FAIL]` line, including none for a guide under `language-specific/`

## AC-042-10-02 — A new guide at exactly 200 lines passes
Given a fixture root with `language-specific/foo/SKILL.md`
And that file has valid frontmatter with `name: foo` and a total of 200 lines
When `scripts/check-skills.sh <fixture-root>` runs
Then it exits `0`
And it reports no `[FAIL]` line for that file

## AC-042-10-03 — A new guide at 201 lines fails with an actionable message
Given a fixture root with `language-specific/foo/SKILL.md`
And that file has valid frontmatter with `name: foo` and a total of 201 lines
When `scripts/check-skills.sh <fixture-root>` runs
Then it exits `1`
And the output contains a `[FAIL]` line naming `language-specific/foo/SKILL.md`
And that line contains `200`
And that line names a sibling file to move detail into (`PATTERNS.md` or `TESTING.md`)

## AC-042-10-04 — A grandfathered guide at its ceiling passes
Given a fixture root with `language-specific/java/SKILL.md`
And that file has valid frontmatter and a total of 282 lines
When `scripts/check-skills.sh <fixture-root>` runs
Then it exits `0`
And no `[FAIL]` line names that file

## AC-042-10-05 — A grandfathered guide that grows fails
Given a fixture root with `language-specific/java/SKILL.md`
And that file has valid frontmatter and a total of 283 lines
When `scripts/check-skills.sh <fixture-root>` runs
Then it exits `1`
And a `[FAIL]` line names `language-specific/java/SKILL.md`
And the same ceiling behaviour holds for `python` at 271, `rust` at 241, and `go` at 223

## AC-042-10-06 — `skills/` keeps the 500-line warning
Given a fixture root with `skills/foo/SKILL.md`
And that file has valid frontmatter with `name: foo` and a total of 501 lines
When `scripts/check-skills.sh <fixture-root>` runs
Then it exits `0`
And the output contains a `[WARN]` line naming `skills/foo/SKILL.md` and `500`

## AC-042-10-07 — The documented checklist matches the script
Given `docs/AGENTS_AND_SKILLS.md`
When the Skills Checklist and §Mechanical Enforcement are read
Then the line-count item states a `200`-line cap for `language-specific/*/SKILL.md`
And it states the grandfather rule for java, python, rust, and go
And it states that `skills/*/SKILL.md` keeps a `500`-line warning
And the `scripts/check-skills.sh` bullet no longer describes line-count handling as warnings only
And the document names the split of the grandfathered guides as a separate spec
