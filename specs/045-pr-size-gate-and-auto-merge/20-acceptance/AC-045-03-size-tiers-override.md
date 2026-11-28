# AC-045-03: Size tiers, override label, and exit contract

## AC-045-03-01 — Exactly 200 lines is the auto-merge tier
Given a diff totalling 200 changed lines after exclusions
When the size gate runs
Then stdout contains `tier=auto`
And `automerge=true`
And the exit code is 0

## AC-045-03-02 — 201 lines requires a human
Given a diff totalling 201 changed lines after exclusions
When the size gate runs
Then stdout contains `tier=human`
And `automerge=false`
And the exit code is 0

## AC-045-03-03 — Exactly 400 lines still requires a human
Given a diff totalling 400 changed lines after exclusions
When the size gate runs
Then stdout contains `tier=human`
And `automerge=false`
And the exit code is 0

## AC-045-03-04 — 401 lines fails the check
Given a diff totalling 401 changed lines after exclusions
And no effective override
When the size gate runs
Then stdout contains `tier=blocked`
And `automerge=false`
And the exit code is 1

## AC-045-03-05 — Zero changed lines is the auto-merge tier
Given an empty diff
When the size gate runs
Then stdout contains `tier=auto`
And `automerge=true`
And the exit code is 0

## AC-045-03-06 — Override label is ignored below the 400 threshold
Given a diff totalling 200 changed lines
And the `size-override` label is present
And the label actor is a CODEOWNER
When the size gate runs
Then stdout contains `tier=auto`
And `override=ignored`
And `automerge=true`

## AC-045-03-07 — 401 lines without the label is blocked
Given a diff totalling 401 changed lines
And the `size-override` label is absent
When the size gate runs
Then stdout contains `override=absent`
And `tier=blocked`
And the exit code is 1

## AC-045-03-08 — An authorized override passes but never auto-merges
Given a diff totalling 401 changed lines
And the `size-override` label is present
And the label actor is `alice`
And the CODEOWNERS file contains `* @alice`
When the size gate runs
Then stdout contains `tier=override`
And `override=authorized`
And `automerge=false`
And the exit code is 0

## AC-045-03-09 — An unauthorized override does not pass
Given a diff totalling 401 changed lines
And the `size-override` label is present
And the label actor is `mallory`
And the CODEOWNERS file contains only `* @alice`
When the size gate runs
Then stdout contains `tier=blocked`
And `override=unauthorized`
And the exit code is 1

## AC-045-03-10 — No CODEOWNERS file falls back to the repo owner
Given a diff totalling 401 changed lines
And the `size-override` label is present
And no CODEOWNERS file exists
And the label actor equals the supplied repository owner
When the size gate runs
Then stdout contains `tier=override`
And `override=authorized`
And the exit code is 0
