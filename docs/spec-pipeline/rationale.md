# Rationale: why the pipeline is shaped this way (shared)

Shared reference. Read it from the stage file that names it; the index is
`docs/SPEC_PIPELINE.md`.

## Why a separate Verifier stage

Coder and Refactorer report their own work as green. Without an independent check,
"green" is just their self-report — nothing re-runs their claims before Architect
commits and pushes. The Verifier's only job is to distrust every prior claim and
re-execute it: re-run the real test suite, re-run the real linter, re-run the
traceability script, and spot-check that at least a couple of tests actually assert
what their scenario says, not just that a test with the right name exists and
passes. It writes no production code and fixes nothing itself — if something's
wrong, it stops the pipeline and reports why, the same way a human QA reviewer would
kick a PR back rather than fix it in someone else's branch.

This mirrors what actually caught real bugs in this pipeline's own development:
config files that looked correct on read but failed the moment they were actually
executed (a JSON-with-comments parse failure, a missing Maven plugin dependency,
stale linter rule names). The Verifier exists to make that kind of check part of
every pipeline run, not something that only happens when a human manually re-tests
after the fact.

## The information barrier

The Coder must not see `00-informal.md`. This is the pipeline's core discipline —
per Uncle Bob's description, a Coder that can read your loose prose will fill
ambiguity from context it was never meant to have, instead of asking. It reasons
only from `10-tasks.md` and `20-acceptance/`.

| Agent | Should not use | Rationale |
|---|---|---|
| `spec-ux` | nothing denied | Pre-gate stage — reads `00-informal.md` same as the Specifier; writes `15-design.md` only |
| `spec-coder` | `specs/*/00-informal.md` | Must reason from tasks + scenarios + `15-design.md` only |
| `spec-refactorer` | `specs/**` (all) | No knowledge of requirements — judges structure only |
| `spec-verifier` | `specs/*/00-informal.md` | Verifies against tasks + scenarios, same discipline as the Coder |
| `spec-mutation-runner` | `specs/*/00-informal.md` | Kills mutants from tests + scenarios only |
| `spec-pr-opener` | `specs/*/00-informal.md` | Reads `30-report.md` only; commits + pushes + opens PR |

**This is a documented convention in each agent's frontmatter (`permission.read`
deny patterns), not a proven hard wall.** Live-fire testing against this exact
pipeline found the barrier holds under normal instruction but is not reliably
enforced under an explicit user override: three of four agents held when told
directly to ignore their own scoping and read the file anyway, but the Architect
complied, invoked its read tool, and returned the file's contents verbatim. The
`permission.read` object-with-path-pattern shape is schema-valid
(`PermissionRuleConfig` in opencode's config schema), but nothing observed here
confirms the runtime enforces path-pattern matching against a `read` tool's target
argument the way it demonstrably does for `bash` command-pattern strings — and at
least one case proves it does not, reliably.

Practical consequence: do not treat this barrier as a security boundary. Treat it
as a strongly-worded convention that most models follow most of the time, backed
by a stage-4 (Verifier) gate that catches the failure mode this barrier exists to
prevent — see below. If opencode's permission enforcement for `read`/`edit` is
confirmed stronger in a later version, tighten this section accordingly.

## Compensating control: catch it, don't just prevent it

Because the read barrier can't be proven to hold under adversarial pressure, the
pipeline does not rely on prevention alone. The Verifier stage runs
`scripts/check-scenario-traceability.sh` (§Why no scenario mutation, below) — a
behavioral check that doesn't ask whether an agent *could* have read the informal
spec, it verifies whether the *output* looks like it came from the formalized tasks
and scenarios — every implemented behavior traces to a scenario ID, nothing appears
that isn't accounted for in `20-acceptance/`. An agent that peeked at
`00-informal.md` and implemented something not in any scenario still fails this
gate. This is weaker than a real access boundary, but it's the honest state of what's
actually verified here.

## Why no BDD runner

The article this pipeline is based on uses Gherkin `.feature` files executed by
Reqnroll (.NET). This repo has no .NET and no existing BDD tooling in Java, Go, or
JS/TS. Adding Cucumber-JVM, godog, or a JS Cucumber runner across three languages is
a new test layer and a new dependency in each — the opposite of this repo's recent
direction (v1.5.0 demoted `testify`/`gomock` to optional for the same reason).
Structured markdown scenarios keep the same information barrier and the same
human-reviewable artifact, in the existing test frameworks, at zero new
dependencies.

## Why no scenario mutation

Uncle Bob's pipeline includes a second mutation pass that mutates the Gherkin
scenarios themselves, to catch a scenario that was never wired to a real test. No
tooling for this exists for Java, Go, or JS/TS (the article's own source admits none
exists for .NET either — "custom Stryker plugin or purpose-built tooling"). Building
one is a project of its own, three times over.

`scripts/check-scenario-traceability.sh` catches the same failure mode at a fraction
of the cost: every scenario ID must be cited by at least one test, and every test
citing an ID must reference one that exists — in `specs/*/20-acceptance/` for a
live spec, or `docs/changes/*.md` for one already archived
(`docs/spec-pipeline/pr-opener.md §Archive in the PR`),
with references to spec numbers in neither place left out of scope.
It does not catch a test that cites the right ID but asserts nothing useful — but
code mutation testing already catches that.
