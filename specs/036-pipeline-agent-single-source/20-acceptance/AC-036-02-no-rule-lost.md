# AC-036-02: No normative content lost

## AC-036-02-01 — Remediation budgets present in doc
Given docs/SPEC_PIPELINE.md after this change
When the Remediation budget and phase-2 sections are read
Then they state a max of 3 phase-1 cycles and an independent max-3 phase-2 budget

## AC-036-02-02 — Never-list complete in doc
Given docs/SPEC_PIPELINE.md §Never-list
When its items are listed
Then all nine items are present: no merge, no git tag, no push to main/master, no force-push, no branch deletion, no gate-threshold change, no secret creation/rotation, no writes outside the target repo, no git init/submodule scaffolding

## AC-036-02-03 — Carve-out and autopilot trigger present in doc
Given docs/SPEC_PIPELINE.md
When §Commit and push carve-out and §Autopilot mode are read
Then the carve-out requires branch spec/NNN-slug and a green 30-report.md
And the autopilot trigger is the literal token autopilot or SPEC_AUTOPILOT=1
