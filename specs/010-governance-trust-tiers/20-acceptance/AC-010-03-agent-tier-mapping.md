# AC-010-03: Every pipeline agent maps to a trust tier

## AC-010-03-01 — All 8 real agents appear in the mapping table

Given the `## Trust Tiers` section of `docs/GOVERNANCE.md`
When the agent-to-tier mapping table is read
Then it names each of the 8 real pipeline agents: `spec-pipeline`,
`spec-specifier`, `spec-ux`, `spec-coder`, `spec-refactorer`,
`spec-verifier`, `spec-mutation-runner`, and `spec-pr-opener`

## AC-010-03-02 — spec-verifier is T0

Given the mapping table
When the `spec-verifier` row is read
Then its trust tier is T0

## AC-010-03-03 — spec-pr-opener is T2

Given the mapping table
When the `spec-pr-opener` row is read
Then its trust tier is T2

## AC-010-03-04 — No agent is assigned T3

Given the mapping table
When every row is read
Then no agent row assigns trust tier T3

## AC-010-03-05 — The tier is derived from actual permission frontmatter

Given the mapping table
When the table's stated basis is read
Then it says each agent's tier is its highest granted action class per its
permission frontmatter
And the table states T3 prohibitions apply to all agents regardless of tier

## AC-010-03-06 — The spec-pipeline gap is recorded, not hidden

Given the mapping table
When the `spec-pipeline` row is read
Then the row records that `spec-pipeline` has no permission frontmatter
And it does not silently present that agent as frontmatter-restricted
