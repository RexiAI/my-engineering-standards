# AC-011-03: Only objective checks block; the blocking set is configurable and documented

## AC-011-03-01 — The default blocking set is documented in the script header (AC-003)
Given `scripts/check-code-principles.sh`
When the script's header usage comment is read
Then it documents a **blocking set** naming the gate categories that may emit FAIL
And the documented default blocking set is the objective gates: `complexity` (cyclomatic + KISS size findings) and `property-tests`
And it documents that gates outside the blocking set are warn-only

## AC-011-03-02 — Judgment gates are warn-only even when diff-introduced (AC-003)
Given a scratch git repo whose working tree introduces a judgment-gate finding (e.g. a DIP domain-to-infrastructure import, or a YAGNI single-implementation interface)
When `scripts/check-code-principles.sh -BaseRef <base>` runs under the default blocking set
Then the finding is reported as WARN
And the script exits 0
And no FAIL is emitted for the judgment gate

## AC-011-03-03 — The blocking set is configurable (AC-003)
Given a scratch git repo whose working tree introduces a finding for a gate that is not in the default blocking set (e.g. a DRY duplication)
When the script runs with a documented override that adds that gate to the blocking set (e.g. `--blocking complexity,property-tests,dry` or the equivalent env var)
Then the diff-introduced finding for that gate is reported as FAIL
And the script exits 1

## AC-011-03-04 — An unknown gate name in the blocking-set override is a usage error
Given the script's documented blocking-set gate names are `complexity`, `dry`, `yagni`, `solid`, and `property-tests`
When the script runs with `--blocking bogus` (or `PRINCIPLES_BLOCKING_GATES=bogus`)
Then the script writes an error to stderr naming the unknown gate
And the script exits 2

## AC-011-03-05 — `property-tests` is a presence gate and is not blame-scoped (AC-003)
Given a project at `production` tier with Java, Go, or JS/TS source but no property-test framework usage
When `scripts/check-code-principles.sh` runs with or without `-BaseRef`
Then the missing-property-tests finding keeps its pre-011 severity (FAIL at `production`+ tier)
And the presence of `-BaseRef` does not change that classification

## AC-011-03-06 — `--warn-as-error` still promotes the new WARNs to failures
Given a scratch git repo with a pre-existing complexity violation in a touched file
When the script runs with `-BaseRef <base> --warn-as-error`
Then the pre-existing finding (a WARN under blame scoping) is promoted to a failure
And the script exits 1

## AC-011-03-07 — No naming or test-delta gates are added (AC-003)
Given `scripts/check-code-principles.sh` has gate categories `complexity`, `dry`, `yagni`, `solid`, and `property-tests`
When the script's gate categories are listed after this change
Then no `naming` gate and no `test-delta` gate exist
And the documented blocking set and severity mapping cover only the gates the script actually runs

## AC-011-03-08 — The blocking set and severity mapping are documented in the skill (AC-003)
Given `skills/check-principles/SKILL.md`
When the skill's gate/severity table is read
Then it documents the default blocking set, that judgment gates are warn-only, and the `-BaseRef` invocation
