# AC-011-02: Scratch-repo blame-scoping behavior

## AC-011-02-01 — Pre-existing bad class touched by one line exits 0 (AC-002)
Given a scratch git repo committed at a base ref
And the base commit contains a class with a pre-existing cyclomatic-complexity violation (>6)
And the working tree modifies exactly one line of that class, outside the violating method's span
When `scripts/check-code-principles.sh -BaseRef <base>` runs against the scratch repo
Then the script exits 0
And the output reports the finding as WARN, not FAIL
And a test asserting this behavior carries the scenario ID AC-011-02-01

## AC-011-02-02 — A diff-introduced violation exits 1 (AC-002)
Given a scratch git repo committed at a base ref with no complexity violations
And the working tree adds a method with cyclomatic complexity >6
When `scripts/check-code-principles.sh -BaseRef <base>` runs against the scratch repo
Then the script exits 1
And the output reports the finding as FAIL
And a test asserting this behavior carries the scenario ID AC-011-02-02

## AC-011-02-03 — A violation in a new file added by the change exits 1
Given a scratch git repo committed at a base ref
And the working tree adds a brand-new file containing a complexity violation
When `scripts/check-code-principles.sh -BaseRef <base>` runs against the scratch repo
Then the script exits 1
And the output reports the finding as FAIL
And a test asserting this behavior carries the scenario ID AC-011-02-03

## AC-011-02-04 — A diff-introduced judgment-gate finding stays WARN
Given a scratch git repo where the working tree introduces a judgment-gate finding (e.g. a DRY duplication or a DIP import)
When `scripts/check-code-principles.sh -BaseRef <base>` runs under the default blocking set
Then the finding is reported as WARN
And the script exits 0
And a test asserting this behavior carries the scenario ID AC-011-02-04

## AC-011-02-05 — Legacy invocation without `-BaseRef` keeps pre-011 behavior
Given a scratch git repo containing a pre-existing complexity violation in a touched file
When `scripts/check-code-principles.sh` runs with no `-BaseRef`
Then the script applies the pre-011 full-tree classification for that finding
And a test asserting this behavior carries the scenario ID AC-011-02-05

## AC-011-02-06 — Blame-scoping tests run in self-ci (AC-002)
Given `.github/workflows/self-ci.yml`
When the self-ci workflow runs
Then a job or step executes the blame-scoping test script
And a violation in any assertion of the AC-011-02 scenarios fails the workflow
