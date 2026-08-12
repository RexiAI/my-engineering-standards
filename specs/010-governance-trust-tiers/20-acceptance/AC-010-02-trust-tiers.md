# AC-010-02: Trust Tiers section defines T0–T3

## AC-010-02-01 — The Trust Tiers section exists

Given `docs/GOVERNANCE.md`
When the file is read
Then it contains the heading `## Trust Tiers`

## AC-010-02-02 — T0 is defined as autonomous reads, gates, and comments

Given the `## Trust Tiers` section
When the T0 row is read
Then T0 is named Autonomous
And its capabilities are reads, gates, Jira/Confluence read, and Jira comment

## AC-010-02-03 — T1 is defined as local write

Given the `## Trust Tiers` section
When the T1 row is read
Then T1 is named Local write
And its capabilities are edit, commit, and local branch

## AC-010-02-04 — T2 is defined as confirm, human-triggered

Given the `## Trust Tiers` section
When the T2 row is read
Then T2 is named Confirm (human-triggered)
And its capabilities are push, PR, Confluence publish, and Jira transition

## AC-010-02-05 — T3 is defined as forbidden operations

Given the `## Trust Tiers` section
When the T3 row is read
Then T3 is named Forbidden
And its capabilities are push to main, force-push, and destructive infra

## AC-010-02-06 — T3 applies to every agent uniformly

Given the `## Trust Tiers` section
When the T3 row is read
Then the section states T3 applies to every agent, with no exceptions

## AC-010-02-07 — The sole remote-write carve-out is named

Given the `## Trust Tiers` section
When the section is read
Then it names `spec-pr-opener` as the only push-capable agent
And it states that carve-out is limited to a branch named `spec/NNN-slug`
And it states the push opens a draft PR only after every configured quality gate is green
