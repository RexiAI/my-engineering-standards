# Spec Pipeline

A five-stage pipeline that turns an informal spec you write into a mutation-tested,
gated pull request. Based on Robert C. Martin's agent-pipeline description
(Specifier → Coder → Refactorer → Architect), adapted to this repo's languages and
tooling. You write stage 0. You review once, after stage 1. Everything after that
runs to a draft PR.

## Stages

| # | Stage | Agent | You do |
|---|---|---|---|
| 0 | Informal spec | — (you) | Write `specs/NNN-slug/00-informal.md` in your own words |
| 1 | Specifier | `specifier` | Nothing yet — review the output |
| — | **Human gate** | — | Read `10-tasks.md` + `20-acceptance/`. Fix or approve. |
| 2 | Coder | `coder` | Nothing — runs to green tests |
| 3 | Refactorer | `refactorer` | Nothing — runs to clean structure |
| 4 | Architect | `architect` | Nothing — runs to mutation-clean |
| — | Output | — | Review the draft PR |

Two commands drive it: `/spec` runs stage 1 and stops. `/build` runs stages 2-4 and
opens the PR.

## Artifact layout

```
specs/NNN-slug/
  00-informal.md        you write this, and only this
  10-tasks.md           specifier: numbered tasks, acceptance criteria
  20-acceptance/
    AC-NNN-name.md      specifier: Given/When/Then scenarios, one file per task
  30-report.md          architect: mutation score, complexity, gate results
```

`NNN` is a zero-padded 3-digit sequence, e.g. `001-discount-system`.

## Scenario format

No Cucumber, no Gherkin runner, in any language — see "Why no BDD runner" below.
Scenarios are structured markdown with stable IDs:

```markdown
# AC-002: Apply discount to a product

## AC-002-01 — Apply a percentage discount
Given a product with base price 100.00
And a percentage discount of 20
When the discount is applied
Then the effective price is 80.00

## AC-002-02 — Price cannot go below zero
Given a product with base price 10.00
And a fixed amount discount of 50.00
When the discount is applied
Then the effective price is 0.00
```

The Coder turns each scenario into a normal test in the project's existing test
framework, with the ID in the test name:

- Java: `shouldApplyPercentageDiscount_AC_002_01()`
- Go: `TestAC_002_01_ApplyPercentageDiscount`
- JS/TS: `it("AC-002-01: applies a percentage discount", ...)`

The ID is what `scripts/check-scenario-traceability.sh` greps for (see below).

## The information barrier

The Coder must not see `00-informal.md`. This is the pipeline's core discipline —
per Uncle Bob's description, a Coder that can read your loose prose will fill
ambiguity from context it was never meant to have, instead of asking. It reasons
only from `10-tasks.md` and `20-acceptance/`.

| Agent | Should not use | Rationale |
|---|---|---|
| `coder` | `specs/*/00-informal.md` | Must reason from tasks + scenarios only |
| `refactorer` | `specs/**` (all) | No knowledge of requirements — judges structure only |
| `architect` | `specs/*/00-informal.md` | Kills mutants from tests + scenarios only |

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
by a stage-4 gate that catches the failure mode this barrier exists to prevent —
see below. If opencode's permission enforcement for `read`/`edit` is confirmed
stronger in a later version, tighten this section accordingly.

## Compensating control: catch it, don't just prevent it

Because the read barrier can't be proven to hold under adversarial pressure, the
pipeline does not rely on prevention alone. `scripts/check-scenario-traceability.sh`
(§Why no scenario mutation, below) is a behavioral check: it doesn't ask whether an
agent *could* have read the informal spec, it verifies whether the *output* looks
like it came from the formalized tasks and scenarios — every implemented behavior
traces to a scenario ID, nothing appears that isn't accounted for in
`20-acceptance/`. An agent that peeked at `00-informal.md` and implemented
something not in any scenario still fails this gate. This is weaker than a real
access boundary, but it's the honest state of what's actually verified here.

## Commit and push carve-out

`AGENTS.md` says never commit or push without explicit instruction. The pipeline is
a narrow, stated exception:

- Pipeline agents may commit, push, and open a **draft** PR, but only:
  - on a branch named `spec/NNN-slug`, never `main`/`master`
  - one conventional commit per task from `10-tasks.md`
  - only after the Architect reports every configured gate green
- Any gate failure halts the pipeline. Nothing is committed. `30-report.md`
  explains what failed.
- The PR body links `10-tasks.md` and `30-report.md`. CI gates are the reviewer of
  record; you review the diff same as any other PR.

## Conformance tiers

Per `docs/CONFORMANCE_TIERS.md`, the pipeline runs fewer stages at lower tiers
instead of being all-or-nothing:

| Stage | `mvp` | `production` | `multi-service` |
|---|---|---|---|
| Specifier | yes | yes | yes |
| Coder | yes | yes | yes |
| Refactorer — complexity + duplication | yes | yes | yes |
| Refactorer — property tests | skip | yes | yes |
| Architect — scenario traceability | yes | yes | yes |
| Architect — mutation testing | skip | yes | yes |

An `mvp` project runs a 3-stage pipeline and conforms fully to it — see
`docs/CONFORMANCE_TIERS.md` for what "conforms fully to a subset" means.

## Tooling by language

| Concern | Java | Go | JS/TS |
|---|---|---|---|
| Unit / acceptance tests | JUnit 5 | stdlib `testing` | Vitest/Jest |
| Property testing (`production`+) | jqwik | stdlib `testing/quick` | fast-check |
| Complexity gate | PMD `CyclomaticComplexity`/`CognitiveComplexity` (≤6) | golangci `cyclop`/`gocognit` (≤6) | ESLint `complexity` (≤6) |
| Mutation testing (`production`+) | PiTest, `mvn verify -Pmutation`, ≥80% | `go-mutesting` or `gremlins` (verify current maintenance status before adopting) | Stryker, `npx stryker run`, ≥80% |

`testing/quick` is stdlib — no new Go dependency, consistent with this repo's
"prefer stdlib, justify each dependency" rule (`docs/CODING_CONVENTIONS.md`) and the
existing demotion of `testify`/`gomock` to optional. It generates simple types well
(ints, strings, slices); reach for a real library only if a project's domain types
need custom generators it can't express.

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
citing an ID must reference one that exists. It does not catch a test that cites the
right ID but asserts nothing useful — but code mutation testing already catches
that.
