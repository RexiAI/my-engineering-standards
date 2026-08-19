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
| 5a | Mutation Runner | `spec-mutation-runner` | Nothing — runs to mutation-clean, only if Verifier passed |
| 5b | PR Opener | `spec-pr-opener` | Nothing — commits, archives the spec, pushes, opens draft PR, only if Mutation Runner green |
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
  30-report.md          architect: mutation score, complexity, gate results, remediation record

docs/changes/NNN-slug.md                 ← long-lived, on main, written by stage 5b via archive-spec.sh
```

`NNN` is a zero-padded 3-digit sequence, e.g. `001-discount-system`.

## Archive in the PR

The `specs/NNN-slug/` folder is pipeline scratch. It belongs on the PR branch
for review, not on `main` — committed specs drift into a graveyard of "what we
thought then" that future maintainers read instead of the actual code, and the
information barrier (`§The information barrier`) is harder to reason about when
the spec is reachable from `main` to anyone with read access.

`scripts/archive-spec.sh NNN-slug` writes a single one-pager to
`docs/changes/NNN-slug.md` containing the original ask, task list,
acceptance-scenario IDs, verification verdict, and the mutation/complexity
report, then `git rm -r specs/NNN-slug/`. **Stage 5b (PR Opener) runs this as
its final act, inside the spec PR** — so the merge commit itself carries the
archive: `main` lands with `docs/changes/NNN-slug.md` present and `specs/NNN-slug/`
absent. Nothing runs after the merge; there is no post-merge cleanup step.

Enforcement: `scripts/check-specs-archived.sh` (wired into the `validate` job of
`.github/workflows/self-ci.yml`, no `continue-on-error`) fails any PR that would
merge a *finished* spec — one with a `30-report.md` — without its
`docs/changes/NNN-slug.md` archive. The check is index-aware (`git ls-files`), so
untracked local scratch under `specs/` is not policed.

`archive-spec.sh` refuses to archive a spec that is not finished (no
`30-report.md`), so stage 5b cannot run it early; for legacy specs merged before
this flow existed, a human can still run it manually post-merge — the script
stages both moves and prints the commit message to run. It does not commit or
push — outside stage 5b, that stays with the human, like every other commit in
`AGENTS.md`.

This is the only spec artifact that survives to `main`: a one-pager per
merged feature, not seven files per feature. The acceptance scenarios survive
in the test files as `AC-NNN-NN` IDs (the traceability check requires this
anyway, `§Why no scenario mutation`); the verification verdict and mutation
score survive in the one-pager; the original prose does not, because what the
code actually does is the source of truth.

## Definition of done

A spec pipeline run is done when all of the following hold — mechanically, not
aspirationally:

1. **Every stage reported green.** Coder suite green; Refactorer structure
   clean; Verifier PASS (`25-verification.md`); Mutation Runner GREEN
   (`30-report.md`).
2. **`specs/NNN-slug/30-report.md` exists.** This is the *finished* signal —
   both `archive-spec.sh` (refuses to archive without it) and the enforcement
   gate (`check-specs-archived.sh`) key off it.
3. **Stage 5b ran `scripts/archive-spec.sh` as its final act.** The PR carries
   `docs/changes/NNN-slug.md` and no longer contains `specs/NNN-slug/`.
4. **Draft PR open** on `spec/NNN-slug`, body linking `10-tasks.md` and
   `30-report.md`.
5. **Gate green.** `scripts/check-specs-archived.sh` (self-ci `validate` job, no
   `continue-on-error`) passes — a finished spec can never merge without its
   archive.

The pipeline finishes at the moment stage 5b pushes the archive commit and
opens the draft PR. Nothing runs after the merge; the merge commit itself lands
`main` with the spec already archived. What happens after merge is out of
scope for the pipeline: release tagging (Semantic Release) and human review of
the diff.

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

## Remediation budget

Every gate-failure loop in the spec pipeline is bounded. The budget has two
phases, each with its own counter, and each capped at **max 3**. The exact
phrasing `re-run until green is forbidden phrasing`: no gate is ever re-run
"until green" — every re-run is a counted attempt under one of the two
budgets.

**Phase 1 — Pre-PR loop.** The local gates and the design gates, run before
anything is pushed. On a Verifier BLOCK the pipeline hands the failing fix
back to the Coder (behavior failures) or the Refactorer (structural/complexity
failures), then re-invokes the Verifier for **scoped re-verification**: it
re-runs only the failing gates, not the whole suite. The Phase 1 budget is
**max 3**.

**Phase 2 — Post-PR loop.** The CI gates that run after the push. Its budget
is **max 3**, and its counter is independent of **Phase 1** — a Phase 1
exhaustion does not consume Phase 2 budget or vice versa. This section states
the policy; the loop's mechanics are spec 014's territory, not this document's.

Exhausting either budget stops the pipeline: the stop emits the failing gate
IDs and the last evidence, and escalates to the human. This is the halt the
"Commit and push carve-out" describes — a gate failure triggers remediation up
to the cap, and only the post-exhaustion stop is the halt that wording means.
Before exhaustion, a gate failure is a re-delegation signal, not a stop.

`30-report.md` records which phase and attempt count each BLOCK was resolved
at, carried forward from the verifier's `25-verification.md` attempt entries,
so budget exhaustion is auditable.

## Post-PR CI check-and-remediate loop (phase 2)

After the PR Opener opens the draft PR (stage 5b), the pipeline checks the PR's
CI status and, on FAIL, runs a bounded fix-and-repush loop. The budget *policy*
for this loop — at most 3 rounds, counter **independent of Phase 1** — comes from
spec 008's remediation-budget section (`008-remediation-budget`, "Phase 2 —
Post-PR loop"); this section defines only the *mechanics*, and is valid only once
008's section exists.

The repo's CI on a feature-branch PR is the **Self CI** workflow
(`.github/workflows/self-ci.yml`, GitHub Actions). Immediately after the PR is
opened, the Verifier queries its checks and records PASS/FAIL per check:

- Status query: `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`.
  The `bucket` field (`pass`/`fail`/`pending`) is the PASS/FAIL parse rule.
- Pending checks are polled until terminal (`gh pr checks --watch` or a bounded
  re-query); `pending` is neither a pass nor a fail.
- On FAIL, failing check IDs are captured from the checks API
  (`gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`,
  `conclusion == "failure"`, record `name` + `id`), the failing job logs are read
  (`gh run list --branch spec/NNN-slug --workflow "Self CI"` then
  `gh run view <RUN-ID> --log-failed`), and the concrete failure reason is
  recorded in `25-verification.md`.
- The CI outcome is recorded per check and per round in `25-verification.md`.

On FAIL the orchestrator routes the diagnosed fix to the Coder (behavior) or the
Refactorer (structure), the PR Opener commits and pushes the fix round — each
re-push re-triggers CI — and the Verifier re-checks. The loop runs at most 3
fix-and-repush rounds (counter independent of Phase 1). On exhaustion the pipeline
stops and escalates to the human with the failing check IDs and the last log evidence
— never a silent green.

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
| Verifier — traceability, tests, complexity re-check, design-principles gate | yes | yes | yes |
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

Per-stage differentiation works through a **per-machine env mechanism** — no
editing and committing `opencode.json` is involved. `opencode.json` (repo root)
resolves every `agent.<name>.model` from an `{env:SPEC_*_MODEL}` reference, and
the committed `config/model.local.env.example` carries the defaults. The
reasoning behind the default split (Specifier, UX Designer, Verifier, and
Architect do the pipeline's highest-judgment work — detecting ambiguity,
inferring design direction from a brief, adversarially checking prior stages'
claims, and reasoning about surviving mutants — while Coder, Refactorer, and
the orchestrator do more bounded, well-specified work; a weak Verifier is worse
than none) is encoded as the committed defaults in `config/model.local.env.example`,
not as literals in `opencode.json`.

### One-time setup (per machine)

1. **Wire the loader into your shell profile once** so every shell exports the
   model vars automatically before opencode launches:

   ```bash
   echo 'source <repo>/scripts/load-model-env.sh' >> ~/.bashrc   # or ~/.zshrc
   ```

   The loader is never sourced per-launch by hand — the profile wiring is the
   mechanism. It exports the 8 `SPEC_*_MODEL` vars with the committed defaults
   when no override file exists, so the steady state (no env file present)
   resolves to the defaults with no empty-string breakage.

2. **Only if you want to override a model** (otherwise skip this entirely):

   ```bash
   cp config/model.local.env.example config/model.local.env
   # edit config/model.local.env, fill in the model ids you want
   ```

   Then **restart opencode** — config is read once at startup, so a restart is
   required after any change. **No commit, no PR** — `config/model.local.env`
   is gitignored and can never be committed.

**Precedence** (per var, first non-empty source wins): a pre-existing exported
env var > the gitignored `config/model.local.env` when present > the committed
defaults in `config/model.local.env.example`. The profile wiring is what
prevents the empty-string failure: `{env:VAR}` with an unset var resolves to
empty — this opencode build has **no default syntax** (`{env:VAR:-default}`,
`{env:VAR|default}`, and `{env:VAR=default}` all resolve to `""` when unset),
so the defaults must arrive via the loader.

**Boundary, honestly documented**: the supported launch path is shell-launched
opencode — interactive shells, and shells spawned from them (`opencode run`,
`/spec`, `/build`, subagents), all inherit the exported vars. A GUI or
daemon-launched opencode that spawns no interactive shell will not have the
vars; the loader's fail-loudly branch (exit 1, naming the var) surfaces that
state instead of silently shipping empty models.

**Structural enforcement**: `scripts/check-model-env.sh` is the gate — every
`agent.*.model` must be an `{env:SPEC_*_MODEL}` reference (no literal model id
anywhere in `opencode.json`), `config/model.local.env` must never be tracked by
git, and the example must define exactly the referenced vars. Self-ci
additionally downloads a pinned opencode binary and runs
`scripts/model-env.runtime-check.sh` against a scratch project to verify the
actual resolution behavior in three cases (defaults via loader, overrides win,
loader absent → empty).

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
| Design-principles gate (KISS/DRY/YAGNI/SOLID) | `scripts/check-code-principles.sh` — language-agnostic heuristic | same | same |
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
