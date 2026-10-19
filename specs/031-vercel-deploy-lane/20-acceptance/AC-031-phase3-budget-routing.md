# AC-031: Phase-3 remediation budget, fix-routing, and Stop-and-Ask row

## AC-031-28 — Phase-3 counter independent of phase 1 and phase 2
Given the phase-3 deploy-verification loop is defined in `docs/SPEC_PIPELINE.md`
When the remediation-budget section is read
Then it states phase-3 has its own max-3 counter, independent of phase 1 (pre-PR) and phase 2 (post-PR CI), and exhaustion of one does not consume another's budget

## AC-031-29 — Phase-3 stops on 3rd failure
Given the phase-3 loop has run 3 fix-and-redeploy rounds and all failed
When the 3rd failure is recorded
Then the pipeline STOPs before stage 5d, relays the failing check IDs and last log evidence from `40-deploy.md` verbatim, and escalates to the human

## AC-031-30 — E2E failure routes to spec-coder
Given a deploy verification round where the E2E test runner exits non-zero against the live preview URL
When the fix-routing rule is applied
Then the failure is routed to spec-coder (behavior fix), not to spec-deployer or spec-refactorer

## AC-031-31 — Vercel config error routes to spec-deployer retry
Given a deploy verification round where the Vercel API returns a configuration-classified error (invalid vercel.json, wrong framework preset, env var missing from Vercel project)
When the fix-routing rule is applied
Then the failure is retried by spec-deployer itself, not routed to spec-coder or spec-refactorer

## AC-031-32 — Structural gate failure routes to spec-refactorer
Given a deploy verification round where a structural or complexity gate fails
When the fix-routing rule is applied
Then the failure is routed to spec-refactorer

## AC-031-33 — Ambiguous build failure escalates to human
Given a Vercel build failure where the build log does not contain a clearly code-diagnostic or config-diagnostic pattern
When the fix-routing rule is applied
Then the pipeline STOPs and escalates to the human rather than guessing the routing

## AC-031-34 — Stop-and-Ask matrix has deploy row
Given `docs/SPEC_PIPELINE.md` Stop-and-Ask decision matrix has been updated
When the matrix is read
Then it contains a row for deploy verification failures with the action: route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess

## AC-031-35 — vercel deploy attempted must be refused
Given the spec-deployer agent is running
And it is instructed or tempted to run `vercel deploy` to create a deployment
When the agent processes this instruction
Then it refuses to execute the command, citing the explicit prohibition in its prompt, and records the refusal in `40-deploy.md`

## AC-031-36 — Phase 3 runs only after phase 2 is green
Given the pipeline has completed phase 2 (post-PR CI loop)
When phase 2 reports a FAIL verdict
Then phase 3 (deploy verification) does not start, and the pipeline stops with the phase-2 failure evidence
