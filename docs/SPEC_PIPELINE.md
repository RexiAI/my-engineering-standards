# Spec Pipeline

A six-stage pipeline that turns an informal spec you write into a mutation-tested,
gated pull request. Based on Robert C. Martin's agent-pipeline description
(Specifier → Coder → Refactorer → Architect), adapted to this repo's languages and
tooling, with an added independent QA stage (Verifier) between Refactorer and
Architect — Uncle Bob's original has no dedicated agent whose only job is to
re-verify prior stages' claims before the pipeline commits anything. You write
stage 0. You review once, after stage 1. Everything after that runs to a draft PR.

## Stages

| # | Stage | Agent | You do |
|---|---|---|---|
| 0 | Informal spec | — (you) | Write `specs/NNN-slug/00-informal.md` in your own words |
| 1 | Specifier | `spec-specifier` | Nothing yet — review the output |
| 1.5 | UX Designer | `spec-ux` | Nothing — skips automatically if no frontend surface |
| — | **Human gate** | — | Read `10-tasks.md` + `20-acceptance/` + `15-design.md` (if present). Fix or approve. |
| 2 | Coder | `spec-coder` | Nothing — runs to green tests |
| 3 | Refactorer | `spec-refactorer` | Nothing — runs to clean structure |
| 4 | Verifier | `spec-verifier` | Nothing — independently re-checks stages 2-3 |
| 5 | Architect | `spec-architect` | Nothing — runs to mutation-clean, only if Verifier passed |
| — | Output | — | Review the draft PR |

Two commands drive it: `/spec` runs stage 1 and stops. `/build` runs stages 2-5 and
opens the PR.

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

## Artifact layout

```
specs/NNN-slug/                          ← PR branch only, gone on main
  00-informal.md        you write this, and only this
  10-tasks.md           specifier: numbered tasks, acceptance criteria
  15-design.md          ux designer: design read, dial values, per-task directives (frontend specs only)
  20-acceptance/
    AC-NNN-name.md      specifier: Given/When/Then scenarios, one file per task
  25-verification.md    verifier: independent re-check results, PASS/FAIL verdict
  30-report.md          architect: mutation score, complexity, gate results

docs/changes/NNN-slug.md                 ← long-lived, on main, written by archive-spec.sh
```

`NNN` is a zero-padded 3-digit sequence, e.g. `001-discount-system`.

## Archive on merge

The `specs/NNN-slug/` folder is pipeline scratch. It belongs on the PR branch
for review, not on `main` — committed specs drift into a graveyard of "what we
thought then" that future maintainers read instead of the actual code, and the
information barrier (`§The information barrier`) is harder to reason about when
the spec is reachable from `main` to anyone with read access.

`scripts/archive-spec.sh NNN-slug` runs after the PR is merged. It writes a
single one-pager to `docs/changes/NNN-slug.md` containing the original ask,
task list, acceptance-scenario IDs, verification verdict, and the
mutation/complexity report, then `git rm -r specs/NNN-slug/`. The script
stages both moves and prints the commit message to run. It does not commit or
push — that stays with the human, like every other commit in `AGENTS.md`.

This is the only spec artifact that survives to `main`: a one-pager per
merged feature, not seven files per feature. The acceptance scenarios survive
in the test files as `AC-NNN-NN` IDs (the traceability check requires this
anyway, `§Why no scenario mutation`); the verification verdict and mutation
score survive in the one-pager; the original prose does not, because what the
code actually does is the source of truth.

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
| `spec-ux` | nothing denied | Pre-gate stage — reads `00-informal.md` same as the Specifier; writes `15-design.md` only |
| `spec-coder` | `specs/*/00-informal.md` | Must reason from tasks + scenarios + `15-design.md` only |
| `spec-refactorer` | `specs/**` (all) | No knowledge of requirements — judges structure only |
| `spec-verifier` | `specs/*/00-informal.md` | Verifies against tasks + scenarios, same discipline as the Coder |
| `spec-architect` | `specs/*/00-informal.md` | Kills mutants from tests + scenarios only |

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

## Commit and push carve-out

`AGENTS.md` says never commit or push without explicit instruction. The pipeline is
a narrow, stated exception:

- Pipeline agents may commit, push, and open a **draft** PR, but only:
  - on a branch named `spec/NNN-slug`, never `main`/`master`
  - one conventional commit per task from `10-tasks.md`
  - only after the Verifier reports PASS and the Architect reports every
    configured gate green
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
| UX Designer (frontend specs only) | yes | yes | yes |
| Coder | yes | yes | yes |
| Refactorer — complexity + duplication | yes | yes | yes |
| Refactorer — property tests | skip | yes | yes |
| Verifier — traceability, tests, complexity re-check | yes | yes | yes |
| Architect — mutation testing | skip | yes | yes |

An `mvp` project runs a 4-stage pipeline (Specifier, Coder, Refactorer, Verifier)
and conforms fully to it — see `docs/CONFORMANCE_TIERS.md` for what "conforms fully
to a subset" means. Architect still runs at `mvp` to commit/push/open the PR; it
simply skips the mutation-testing gate.

## Model configuration

Shipped agents (`agents/spec-*.md`) intentionally ship **without** a `model:` key.
Per opencode's documented config precedence, `.opencode/agents/` (where these land
via the submodule symlink) is loaded *after* your project's `opencode.json` — so if
a shipped agent file pinned a model, your `opencode.json` could not override it. Only
by leaving `model:` unset does `agent.<name>.model` in your own `opencode.json` take
effect. Verified directly against `opencode debug config` (not assumed from the
docs): a `.md` with no `model:` resolves to whatever `opencode.json` sets; a `.md`
that does pin `model:` silently wins over `opencode.json` every time.

With nothing configured, each subagent inherits the model of whichever primary
agent invoked it — no vendor coupling, works with any provider you already use.

If you want per-stage differentiation, set it in your own `opencode.json`:

```json
{
  "agent": {
    "spec-specifier":  { "model": "your-provider/strong-model" },
    "spec-ux":         { "model": "your-provider/strong-model" },
    "spec-verifier":   { "model": "your-provider/strong-model" },
    "spec-architect":  { "model": "your-provider/strong-model" },
    "spec-coder":      { "model": "your-provider/fast-model" },
    "spec-refactorer": { "model": "your-provider/fast-model" },
    "spec-pipeline":   { "model": "your-provider/fast-model" }
  }
}
```

The reasoning behind that split (this repo's own local pins, in
`opencode.json` at the repo root, not shipped): Specifier, UX Designer, Verifier, and
Architect do the pipeline's highest-judgment work — detecting ambiguity, inferring
design direction from a brief, adversarially checking prior stages' claims, and
reasoning about surviving mutants — and Architect alone holds commit/push authority.
Coder, Refactorer, and the orchestrator do more bounded, well-specified work. A weak Verifier is worse than none: it manufactures
false confidence instead of catching real gaps, which is the reason this stage
exists at all (see `§Why a separate Verifier stage` above).

If you need to customize an agent's prompt or permissions, not just its model, run
`./scripts/bootstrap.sh --copy-agents` (or `make init-ai COPY_AGENTS=1`) to get real,
editable files in `.opencode/agents/` and `.opencode/commands/` instead of a
symlink. You own the copies after that — re-run with the same flag after a
submodule update to pull in changes; it will not overwrite or merge your edits.

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
