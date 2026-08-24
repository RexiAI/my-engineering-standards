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

## Audit contract

Every pipeline stage leaves a specific, machine-checkable trace behind, in the
artifact the layout above already defines — no new spec-folder artifacts. An
artifact may assert anything, but the assertion is only as good as the evidence
recorded with it. This section is that contract; `scripts/check-audit-trail.sh`
enforces it mechanically at pipeline end (see §The gate below).

### What each stage leaves behind

| Stage | Evidence artifact(s) | What it must record |
|---|---|---|
| Specifier | `10-tasks.md` + `20-acceptance/` | Task acceptance criteria and scenario IDs (`AC-NNN-NN`) |
| Coder | the tests in the project suite carrying `AC-NNN-NN` IDs | Leaves no report artifact — the build/test commands it ran and their exit codes are re-recorded by the Verifier in `25-verification.md` |
| Refactorer | gates re-run by the Verifier | The gates it applied (complexity, duplication, property tests) with before/after measurements — re-recorded by the Verifier; the complexity summary is carried into `30-report.md` |
| Verifier | `25-verification.md` | Per check: the exact command, its real output, its exit code, and a timestamp |
| Mutation Runner | `30-report.md` | Mutation score (or skip reason), equivalent mutants, final test status |
| PR Opener | `30-report.md` | PR URL and commit count, appended after the PR opens |

The Coder and Refactorer deliberately leave no report artifact. Their claims
become auditable not because they write them down, but because the Verifier
re-executes every claim and records the command and exit code in
`25-verification.md` — a claim that was never re-run is a gap in the audit
trail, and the gate fails the folder for it.

### The five Verifier checks

`25-verification.md` must record evidence for the five runnable Verifier checks:

1. scenario traceability
2. full test suite
3. complexity gate
4. design-principles gate
5. scenario-to-behavior spot check

The "no unaccounted behavior" skim is not a runnable check: it is recorded as a
finding line, not as a command.

### Machine-readable rule

Machine-readable evidence (gate-script output, CI query, deploy check) is
recorded with an ISO-8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`, i.e.
`date -u +%Y-%m-%dT%H:%M:%SZ`) as raw output or exit code — never as a prose
paraphrase. The timestamp is pinned to UTC so the gate can verify the format
deterministically.

### Evidence block format

In `25-verification.md`, each of the five checks carries one evidence block: a
`## Evidence: <check name>` heading, three marker lines, then the raw output.
Worked example:

```
## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-08-15T10:00:00Z

Scenario IDs found: 16
Scenario traceability check: every scenario traced, every reference resolves.
```

- `command:` — the exact command as run.
- `exit:` — the command's exit code.
- `at:` — when it ran, in `YYYY-MM-DDTHH:MM:SSZ`.
- everything after the markers — the raw output, verbatim (or a representative
  excerpt for very long output), never a paraphrase.

The design-principles gate's exit code and every FAIL / WARN line must be kept
verbatim. `30-report.md` uses the same block style for its machine-readable
rows (mutation score, final test status) plus the `PR:` line appended by the PR
Opener.

### The gate

`scripts/check-audit-trail.sh <slug>` verifies the folder is complete
(`10-tasks.md`, `20-acceptance/` with a scenario heading, `25-verification.md`,
`30-report.md`, and `15-design.md` when present — a zero-byte `15-design.md` is
a failure) and that `25-verification.md` records evidence for all five checks.
It exits 0 only when both hold, and is a no-op when the folder does not exist.
The PR Opener runs it before pushing; self-ci runs it for every spec folder
carrying a `30-report.md` — the pipeline's finished signal, the same
convention as the archive gate (`§Archive in the PR`). In-flight folders
without `30-report.md` are skipped: their pipeline finishing is outside the
job's control and must not fail CI. A finished-but-incomplete spec still
fails the gate — the step never hands the script an unfinished folder.

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

## Stop-and-Ask decision matrix

This matrix is authoritative for every pipeline agent: each agent resolves the
listed conditions per the matrix, never by improvisation.

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery (wrong directory, `.standards/` submodule missing) | Ask for the absolute path once; never scaffold (no `git init`, no submodule creation) unprompted |
| Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`) | Tell the user to run `/spec` first; never create the artifacts yourself |
| Project type ambiguous (language stack / conformance tier undetectable) | Defer to the harness default (`mvp` tier; language per `language-specific/<lang>/SKILL.md`); ask only if interactive and unconfirmed |
| Version bump / git tag not requested | Off by default; never infer from SemVer or the diff; never create git tags — CI (Semantic Release) owns versioning |
| A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold) | Fix the code, never the threshold — gate config is off-limits to agents |
| Design gate WARN (not FAIL) | Record in the report; do not stop; flag to the Architect |
| Out-of-scope finding | Record it (Verifier: `25-verification.md`); do not fix; propose a follow-up spec |
| Acceptance criteria ambiguous | Resolve before delegating implementation — stop and ask one specific question |
| Verifier verdict FAIL | STOP the pipeline; relay the report; do not run stage-5 agents; do not fix it yourself |
| PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green) | STOP; commit nothing, push nothing |

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

Per-stage differentiation works through a **per-machine direnv mechanism** — no
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

1. **Install direnv and wire the hook once** so every shell loads the env
   automatically before opencode launches:

   ```bash
   eval "$(direnv hook bash)"   # or your shell's hook (zsh, fish, …)
   ```

2. **Copy the parent `.envrc` template and allow it:**

   ```bash
   cp templates/.envrc.example .envrc
   direnv allow
   ```

   The repo-root `.envrc` is **per-machine and gitignored** — never committed.
   It is the only committed-adjacent wiring: the committed surface is the
   template (`templates/.envrc.example`), and it loads, in order via
   `dotenv_if_exists`:

   | Line | File | Role |
   |---|---|---|
   | 1 | `config/model.local.env.example` | committed defaults for the 8 `SPEC_*_MODEL` vars |
   | 2 | `config/model.local.env` | gitignored per-machine override |
   | 3 | `config/agent.local.env` | gitignored per-machine credentials (`GITHUB_TOKEN`, `GH_TOKEN`) |

3. **Only if you want to override a model** (otherwise skip this entirely):

   ```bash
   cp config/model.local.env.example config/model.local.env
   # edit config/model.local.env, fill in the model ids you want
   ```

   Then **restart opencode** — config is read once at startup, so a restart is
   required after any change. **No commit, no PR** — `config/model.local.env`
   is gitignored and can never be committed.

**Child repos** (this repo consumed as a `.standards/` submodule) get the same
shape from `scripts/bootstrap.sh`: it copies `templates/.envrc.child` to the
child's root `.envrc` when absent (and appends `.envrc` to the child's root
`.gitignore`), and writes/keeps a child `config/.gitignore` covering
`model.local.env` and `agent.local.env`. The child template's first
`dotenv_if_exists` line points at
`.standards/config/model.local.env.example` — the **parent's committed**
defaults. The submodule never carries gitignored files, so a parent's
per-machine override never propagates to children; a child's own
`config/model.local.env` override wins over the parent defaults.

**Precedence** (per var): later `dotenv_if_exists` lines win. A dotenv line
**clobbers** any pre-existing value — pre-exported shell vars included. This is
accepted and documented: the `.envrc` is the per-directory source of truth.
The example loads first, which is what prevents the empty-string failure:
`{env:VAR}` with an unset var resolves to empty — this opencode build has
**no default syntax** (`{env:VAR:-default}`, `{env:VAR|default}`, and
`{env:VAR=default}` all resolve to `""` when unset) — so the defaults must
arrive via the first dotenv line.

**Boundary, honestly documented**: the supported launch path is a shell loaded
by direnv — interactive shells, and shells spawned from them (`opencode run`,
`/spec`, `/build`, subagents), all inherit the loaded vars. A GUI or
daemon-launched opencode that spawns no direnv-loaded shell will resolve the
`{env:SPEC_*_MODEL}` references to empty — surfaced as empty model resolution,
not a loud failure.

**Structural enforcement**: `scripts/check-model-env.sh` is the gate — every
`agent.*.model` in the `agent` block must be an `{env:SPEC_*_MODEL}` reference
(no literal model id in the agent block; the standalone PR-review agent's
deliberate literal model pin is the one exception, see `§Using OpenCode Zen`
below), `config/model.local.env`
and `config/agent.local.env` must never be tracked by git, and the example must
define exactly the referenced vars. Self-ci additionally runs
`scripts/model-env.selftest.sh` (hermetic dotenv-emulation regressions) and
downloads a pinned opencode binary to run `scripts/model-env.runtime-check.sh`
against a scratch project, verifying the actual resolution behavior in three
cases (example loaded → defaults; file override + untouched pre-exported var;
nothing loaded → empty).

If you need to customize an agent's prompt or permissions, not just its model, run
`./scripts/bootstrap.sh --copy-agents` (or `make init-ai COPY_AGENTS=1`) to get real,
editable files in `.opencode/agents/` and `.opencode/commands/` instead of a
symlink. You own the copies after that — re-run with the same flag after a
submodule update to pull in changes; it will not overwrite or merge your edits.

## Using OpenCode Zen

[OpenCode Zen](https://opencode.ai/docs/zen) is the provider behind the
`opencode-go/*` model ids used across this repo. It is wired in two places:

- **Provider config** — `opencode.json` carries a `provider.opencode-zen` block:
  base URL `https://opencode.ai/zen/go/v1`, auth env var `OPENCODE_API_KEY`, and
  the model ids available to it. The spec-pipeline agents still resolve their
  models from `{env:SPEC_*_MODEL}` references (see `§Model configuration`); the
  provider block is what those references point at.
- **Auth** — the provider reads the `OPENCODE_API_KEY` env var (verified
  against the pinned binary's provider registry, see `docs/changes/019`). Locally
  the var is exported by your shell profile; in CI it arrives from the
  `OPENCODE_API_KEY` GitHub Actions secret and is never committed.

**The one deliberate model pin**: `agents/pr-review.md` (the PR review agent,
spec 024) carries a literal `model: opencode-zen/kimi-k3` in its frontmatter —
not an `{env:...}` reference. This is the exception to the "agents ship without
`model:`" convention: the PR review agent is a standalone, PR-time reviewer
unrelated to the spec-pipeline stages, and its model must not be per-machine
overridable through `agent.*.model` in `opencode.json`. Everything about that
agent — scope lock, permissions, endpoint, secret handling, cost bounds — is
documented in `docs/CI_CD.md §PR Review Agent`, which is the authoritative
reference for wiring it into child repos (`init-ci.sh --with-pr-review`).

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
