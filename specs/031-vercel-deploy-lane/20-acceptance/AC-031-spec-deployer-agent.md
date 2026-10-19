# AC-031: Create spec-deployer agent

## AC-031-01 — Agent file exists with correct frontmatter
Given the spec-deployer agent has been created
When `agents/spec-deployer.md` is read
Then the file exists and contains valid YAML frontmatter with `description`, `mode: subagent`, `permission.read`, `permission.edit`, and `permission.bash` keys

## AC-031-02 — Agent refuses to run vercel deploy
Given the spec-deployer agent is running
And the agent's prompt instructs it to deploy changes
When the agent attempts to execute `vercel deploy` or `vercel deploy --prod`
Then the `permission.bash` deny rule matches `vercel deploy*` and the command is refused, not executed

## AC-031-03 — Agent read-deny on informal spec
Given the spec-deployer agent is running in the information-barrier convention
When the agent's `permission.read` is inspected
Then `specs/*/00-informal.md` is listed as `deny`, matching the spec-coder pattern

## AC-031-04 — Agent prompt lists allowed CLI commands
Given the spec-deployer agent prompt
When the prompt text is read
Then it explicitly lists `vercel inspect`, `vercel logs`, `vercel ls`, `vercel env pull`, `vercel env add`, `vercel pull`, and `vercel domains` as the only permitted CLI commands

## AC-031-05 — Agent prompt prohibits vercel deploy with stated reason
Given the spec-deployer agent prompt
When the prompt text is read
Then it contains an explicit prohibition against `vercel deploy` with a stated reason citing double-build, race with Git integration, and orphaned deployments
