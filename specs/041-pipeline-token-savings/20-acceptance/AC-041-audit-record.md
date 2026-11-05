# AC-041: Token-savings audit record

Applies to Task 7.

## AC-041-50 — One measured row per informal item

Given `specs/041-pipeline-token-savings/10-tasks.md`
When the `## Measured before/after` table is read
Then it has exactly four item rows
And each row states the baseline command or fixture, a before value, an after
value, and a status

## AC-041-51 — Every rejected item carries its reason

Given the same table and the recorded-decisions section
When item 4's status is read
Then it is marked rejected with the reason that the `xhigh` premise is false
And the record also names the coder/refactorer suite runs and
`agents/pr-review.md:69` as out of scope with reasons

## AC-041-52 — Every gate named in the record is green

Given the hand-off state
When each gate named in the record runs
Then `make test`, `scripts/check-doc-section-refs.sh`,
`scripts/check-agent-line-cap.sh`, `scripts/check-orchestration.sh`,
`scripts/check-skills.sh`, `scripts/check-scenario-traceability.sh` and
`scripts/check-code-principles.sh` each exit 0
And each exit code is recorded alongside the gate name

## AC-041-53 — No gate script or threshold changed

Given the diff for this spec
When `scripts/check-audit-trail.sh`, `scripts/check-scenario-traceability.sh`,
`scripts/check-code-principles.sh` and `scripts/check-agent-line-cap.sh` are
compared with the base commit
Then `git diff --quiet <base-commit> -- <script>` exits 0 for each, so each is
byte-identical to the base commit
And no threshold value changed anywhere: complexity 6, mutation ≥80%, agent cap 120,
and the five audit-trail checks are unchanged

## AC-041-54 — The no-weakening claims are stated, not implied

Given the recorded-decisions section
When it is read
Then it states that the design-principles lane and the complexity linters are not
routed through the log filter, and that every FAIL and WARN line stays verbatim
And it states that reuse is granted only on an exact hash match, so the failure
mode is a redundant run and never a skipped one
