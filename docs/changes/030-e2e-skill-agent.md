# 030-e2e-skill-agent

> Spec pipeline archive. Original source: `specs/030-e2e-skill-agent/` (deleted by this script).
> Archived: 2026-10-14

## Original ask

# 030 — Agentic E2E standard: `e2e-testing` skill + `e2e-runner` agent

## The ask

Add an end-to-end testing standard to this repo, delivered as:

1. A skill: `skills/e2e-testing/SKILL.md` (Agent Skills spec, progressive disclosure).
2. An agent: `agents/e2e-runner.md` (OpenCode agent spec).

Based on the TesterArmy `e2e` framework and the patterns described in
https://www.webreactiva.com/blog/e2e-tester-army (article dated 2026-06-10,
anchored to `e2e` v0.17.0, `@e2e-dev/web` 0.12.0, npm package `e2e`,
repo github.com/tester-army/e2e, Apache-2.0).

## What `e2e` is (source facts, verified from the article)

TypeScript E2E framework (web + mobile) where each test can carry AI agents:

- `agent.act('<natural-language goal>')` — an actor agent drives the UI toward
  the goal; web engine is Playwright (pinned `playwright-core` 1.63.0),
  coexists with `@playwright/test`. The actor sees a redacted text snapshot of
  the screen (roles, names, texts, states) — never raw HTML, cookies, headers,
  or env vars; password fields masked; configured secrets replaced by
  `<secret:name>`. Optional vision (`{ vision: true | 'only' }`).
- `agent.assert(...)` — a judge model decides pass/fail from **only the
  instruction and the current screen**; it never sees the actor's steps or
  summaries (no self-grading). A separate judge model is configurable.
  Outcomes distinguish `ASSERTION_FAILED` from `ASSERTION_INCONCLUSIVE`.
- Deterministic Playwright locators + `expect` remain available and mixable
  in the same test ("choose how much AI each test carries").
- `agent.waitFor(...)` polls the screen, calls the model only when the
  observation changes; `agent.extract(...)` returns schema-validated data.
- The **runner** is the non-AI authority: authorizes each action, counts it
  against budgets, caps actions at 15s, detects loops (3 consecutive failed
  actions force a strategy change, 5 force a verdict).
- Default budgets: `act` 25 model calls / 25 actions / 120s; `waitFor`
  25/0/30s; `extract` 2/0/30s; `assert` 2/0/30s → `STEP_BUDGET_EXHAUSTED` /
  `STEP_TIMEOUT`. Per-agent configurable.
- Verdicts: `passed` / `failed` / `blocked` (blocked = external cause).
  Exit codes: 1 test failure, 2 config/policy/blocked-credentials,
  3 engine/app/model-provider/dead-env, 4 internal, 130 interrupted.
- **Replay cache**: verified `act` steps replay with zero model calls
  (`replayed` / `handed off` / `missed`). Modes: `read-write` (local default),
  `read-only` (CI default), `off`. `--strict-cache` fails stale recordings
  with `REPLAY_STALE` without calling the model. Cache entries are JSON,
  contain no prompts/screenshots but keep typed non-secret values → reviewable
  in PRs. Model change does **not** invalidate; instruction/params/target/
  engine-minor-version changes do. Only `act` caches; judgments always live.
- **Golden rule**: every `act` must be followed immediately by an
  `expect`/`agent.assert` — for correctness and because only a verified `act`
  gets cached. "An agent that achieves the goal doesn't guarantee it took the
  path your user would take."
- **Secrets**: `credentials.user('admin')` yields opaque `Secret` values —
  unreadable from the test; the runner fills the field itself; after a secret
  is filled, screenshots stop being sent to the model for that attempt.
  `e2e` does **not** load `.env` files.
- Sessions (cookies + localStorage + IndexedDB) encrypted on disk, key only in
  memory, wiped at run end. `test.setup(..., { sessions: ['admin'] }, ...)`
  with `session.save('admin')` after a deterministic URL check.
- **Explore mode**: `npx e2e explore '<persona + area>'` — agent plans its own
  steps, streams findings (location, expected vs observed, repro steps,
  screenshot). Default 8 steps (1–12), 10 min (3–15), via `--max-steps` /
  `--timeout`. Findings: `issue` (functional) vs `warning` (cosmetic). Does
  not replace a regression suite.
- **Bug bash** (the "army"): several explore runs **in parallel**, each over
  one area with a distinct persona (novice user, edge cases, error paths…),
  then a reproduction test per finding. **Only findings whose repro test fails
  with `ASSERTION_FAILED` count as bugs.**
- Config: `e2e.config.ts`; tests at `tests/**/*.e2e.ts`; outputs under `.e2e/`
  (`report.json`, `summary.md`, `failures/` — one markdown page per failed
  test with code line, steps, last model turns, screen text; `cache/`;
  `logs/app.log`). Treat `.e2e/` as read-only output.
- App launch: `targets[].app.command` (shell-less; child inherits only
  `PATH`/`HOME`/temp), `url` with port `0` + `{port}` substitution for
  multi-branch parallelism; CI ignores `reuseExisting` → `APP_ALREADY_RUNNING`.
- Model connectivity: `npx e2e login openai|github-copilot|opencode-console|spacexai`,
  API keys (`AI_GATEWAY_API_KEY`, `OPENROUTER_API_KEY`), gateways, or local
  OpenAI-compatible (Ollama). Claude subscriptions unsupported. Model must
  support **tool calls + images**. `ai` package required. Node 24.8+ (or
  22.22.3+).
- CI (GitHub Actions): `pnpm exec e2e-web install chromium --with-deps`, then
  `npx e2e run --reporter list,junit`, upload `.e2e/report.json` + `junit.xml`.
  Workers: cores/2 local, **1 in CI**. Retries: 0 local, 1 CI. `test.only`
  rejected in CI (`ONLY_IN_CI`).
- Coding-agent workflow imposed by the vendor's own SKILL.md (5 steps):
  inspect existing state → know the screens before writing (read components or
  open the app via the MCP server) → write `tests/<feature>.e2e.ts`, one
  `agent.act` per goal with `expect`/`assert` right behind → run a single file
  (`npx e2e run tests/<feature>.e2e.ts`) → read `.e2e/failures/` +
  `report.json`, fix locator/expectation/app. **"Never add a sleep."**
- Also ships an MCP server (`npx e2e mcp`) whose `locate` tool validates a
  locator against the live app; each agent session (subagents included) opens
  its own session.
- **Telemetry on by default** — opt-out `npx e2e telemetry disable` or
  `E2E_TELEMETRY_DISABLED=1`.
- Pre-1.0: API may change between minor versions.

## Decisions (all confirmed by the user as "all defaults")

1. **Hybrid standard**: the *patterns* are the standard (act+expect golden
   rule, actor/judge isolation, budgets, replay-cache discipline, explore
   mode, bug-bash confirmation gate); TesterArmy `e2e` is the **reference
   implementation for TS/Node child repos**. Pin the documented version
   (0.17.0) in examples and carry an explicit pre-1.0 instability warning.
2. **One agent, two duties**: `e2e-runner` is (a) test author/maintainer —
   given user flows or `AC-NNN-NN` acceptance scenarios, writes `*.e2e.ts`,
   runs single files, reads `.e2e/failures/`, fixes until green; and (b)
   bug-bash orchestrator (explicit mode) — launches parallel persona
   explorations with bounded persona count and per-persona step/time budgets,
   gates every finding through a repro test failing with `ASSERTION_FAILED`.
3. **Supersession**: repo `agents/e2e-runner.md` supersedes the user-level
   `~/.config/opencode/agent/e2e-runner.md` (Playwright-based) for repos
   consuming this standard — same filename so project-level loading wins.
   The user-level file is **not** touched or deleted by this spec.
   Likewise the skill name `e2e-testing` intentionally shadows the generic
   global `e2e-testing` skill in child repos that load this standard.
4. **No pipeline change**: the skill+agent are standalone, invoked ad hoc or
   via `/build`-adjacent human request. No new `/build` stage, no gate-catalog
   change, no GOVERNANCE ADR needed. This operationalizes the AGENTS.md rule
   "verify agent-delivered work against the live system".
5. **Stack scope**: TS/Node web + React Native (via `@e2e-dev/mobile`,
   iOS simulators / Android emulators). Java/Go child repos: the skill
   contains a short "not for you" pointer to `docs/TESTING.md` (integration /
   contract layers) instead of pretending coverage.
6. **Governance**:
   - No literal model/provider ids in tracked files. The `e2e-runner` agent
     ships without a `model:` key (ADR 0003 pattern). If `opencode.json`'s
     agent block gains an `e2e-runner` entry, it must be
     `{env:SPEC_E2E_RUNNER_MODEL}` and the var must be added to
     `config/model.local.env.example` (`scripts/check-model-env.sh` requires
     example and references to match exactly).
   - Framework-side models: child-repo `e2e.config.ts` reads actor/judge model
     ids from env (e.g. `E2E_AGENT_MODEL`, `E2E_JUDGE_MODEL` via
     `process.env`) — never hardcoded in the tracked config. Separate judge
     model is **recommended, not mandated**.
   - Skill mandates telemetry opt-out (`E2E_TELEMETRY_DISABLED=1`) in setup.
   - CI guidance: replay cache `read-only` + `--strict-cache` in CI; upload
     `.e2e/report.json` + `junit.xml` as artifacts.
7. **Process**: this spec runs the standard pipeline (`/spec` → human gate →
   `/build`).

## Deliverables

| File | Kind | Notes |
|---|---|---|
| `skills/e2e-testing/SKILL.md` | new | Frontmatter per `docs/AGENTS_AND_SKILLS.md` (name matches dir, description = what + when + triggers, body ≤500 lines). Sections: When to use / Invocation / What it does / What it is not / Exit codes. |
| `skills/e2e-testing/references/*.md` | new | Progressive disclosure, one level deep: e.g. `setup.md` (init, model connectivity, telemetry opt-out, Node version), `writing-tests.md` (act+expect golden rule, judge isolation, params/unique, sessions/secrets, waitFor/extract), `running-debugging.md` (single-file runs, `.e2e/failures/`, exit codes, budgets, never-sleep, cache modes, `--strict-cache`), `bug-bash.md` (personas, parallel explorations, ASSERTION_FAILED confirmation gate), `ci.md` (GHA snippet, workers/retries, artifacts), `mobile-rn.md` (React Native scope). Vendor docs also ship offline in `node_modules/e2e/docs` / `npx e2e guide [topic]` — reference, don't duplicate wholesale. |
| `skills/e2e-testing/assets/e2e.config.example.ts` | new | Config template with env-var model indirection, app launch, port-0 pattern, budgets, cache modes, telemetry opt-out comment. |
| `agents/e2e-runner.md` | new | OpenCode agent frontmatter (`description`, `mode: subagent`, `permission` block; deny `git push*`, deny `git commit*`, deny edits outside `tests/`, `e2e.config.ts`, `.e2e/` read-only). No `model:` key. Body per AGENTS_AND_SKILLS Part 2: role, the one rule, execution steps for both duties (author/maintainer; bug-bash mode), explicit stopping conditions (max 3 fix rounds per failing test file; framework budgets are the inner bound; "re-run until green" is forbidden phrasing — every re-run is a counted attempt), ground-truth requirement (read `.e2e/failures/` + `report.json` after every run, never assume green), output summary contract. |
| `docs/TESTING.md` | edit | E2E section (new or extended): agentic E2E is the standard for TS/Node + RN child repos; points at `skills/e2e-testing/SKILL.md`; keeps existing Playwright guidance for repos not adopting `e2e`. |
| `AGENTS.md` | edit | One line in "Reading the Standards": read `skills/e2e-testing/SKILL.md` before writing or running E2E tests in a TS/Node or RN child repo. |
| `config/model.local.env.example` (+ `opencode.json` agent block) | edit, conditional | Only if an `agent.e2e-runner.model` entry is added: `{env:SPEC_E2E_RUNNER_MODEL}` + matching example var. `scripts/check-model-env.sh` must pass. |

## Hard constraints

- `scripts/check-skills.sh` exits 0 (frontmatter, name-dir match, ≤500-line body, references one level deep).
- `scripts/check-orchestration.sh` exits 0 (every agent/skill/script/doc reference in `agents/*.md`, `commands/`, `AGENTS.md` resolves; a `docs/[A-Z_]+.md` reference from the agent must exist).
- `scripts/check-model-env.sh` exits 0 if model wiring is touched.
- No literal model or provider ids anywhere in tracked files (docs included — switch models by editing gitignored local env).
- No secrets, tokens, or credentials in any tracked file; the skill must teach the framework's opaque-`Secret` path and forbid inline credentials.
- Skill and agent follow Anthropic "Building Effective Agents" principles: simplest-thing justification (workflow vs agent choice documented in the agent file), transparency (agent surfaces plan + per-run evidence), poka-yoke tool guidance (absolute paths, single-file runs), ground truth per step, explicit stopping conditions.
- Bug-bash mode must bound parallelism (persona count cap) and per-persona budgets (`--max-steps`, `--timeout`), and must state that explore findings are not regressions — only `ASSERTION_FAILED` repro tests count.

## Out of scope

- No new `/build` stage, no gate-catalog change, no CI workflow changes to this repo's Self CI.
- No child-repo workflow templates under `ci/` (follow-up candidate).
- No `init-ci.sh --with-e2e` flag (follow-up candidate).
- No modification or deletion of the user-level `~/.config/opencode/agent/e2e-runner.md` or global `e2e-testing` skill.
- No Java/Go E2E tooling.
- No hosted-infrastructure integration (`@e2e-dev/kernel`, `@e2e-dev/eas`) beyond a one-line mention.

## Tasks

# 030 — Tasks: Agentic E2E standard (`e2e-testing` skill + `e2e-runner` agent)

Test approach: this repo has no test framework for docs/config deliverables (no
`tests/` dir, no bats, no package.json). The Coder implements each scenario as a
plain shell assertion test (bash script with `set -euo pipefail`, using `grep`,
`wc -l`, `test -f`, and the existing gate scripts). Each test is runnable via
`bash tests/AC-030-NN.sh` and exits 0 on pass. The test file for each task lives
alongside the scenario file or in a `tests/` directory the Coder creates.

---

## T1 — Create `skills/e2e-testing/SKILL.md`

**Goal**: New skill entry point following Agent Skills spec. Progressive-disclosure
hub that points at references/ for depth.

**Files touched**: `skills/e2e-testing/SKILL.md` (new)

**Acceptance criteria**:
- Frontmatter exists, bounded by `---`, with `name`, `description`, and optionally `license`, `compatibility`, `metadata`.
- `name` field is exactly `e2e-testing` (matches directory name).
- `name` is lowercase `[a-z0-9-]`, ≤64 chars, no leading/trailing/consecutive hyphens.
- `description` is non-empty, ≤1024 chars, includes what the skill does AND when to use it (trigger keywords).
- Body has sections: "When to use", "Invocation", "What it does", "What it is not", "Exit codes".
- Body is ≤500 lines.
- Body mentions the reference implementation pin: `e2e` v0.17.0.
- Body carries an explicit pre-1.0 instability warning.
- Body mandates telemetry opt-out (`E2E_TELEMETRY_DISABLED=1`) in setup guidance.
- Body states the act+expect golden rule.
- Body contains no literal model or provider ids.
- Body contains no secrets, tokens, or credentials.
- Body teaches the framework's opaque-`Secret` path (`credentials.user(...)`) and forbids inline credentials.
- Body references `skills/e2e-testing/references/` files (one level deep).
- No "re-run until green" phrasing anywhere in the file.
- `scripts/check-skills.sh` exits 0 after this task.

**Scenarios**: AC-030-01 (AC-030-01-01 through AC-030-01-12)

---

## T2 — Create `skills/e2e-testing/references/*.md`

**Goal**: Progressive disclosure files — one per topic, referenced from SKILL.md.

**Files touched**:
- `skills/e2e-testing/references/setup.md` (new)
- `skills/e2e-testing/references/writing-tests.md` (new)
- `skills/e2e-testing/references/running-debugging.md` (new)
- `skills/e2e-testing/references/bug-bash.md` (new)
- `skills/e2e-testing/references/ci.md` (new)
- `skills/e2e-testing/references/mobile-rn.md` (new)

**Acceptance criteria**:
- All six reference files exist.
- Each file is referenced from `skills/e2e-testing/SKILL.md` by relative path.
- No reference file contains a relative link to another reference file (one level deep, no nested chains).
- `setup.md` covers: init, model connectivity (env-var indirection, no literal ids), telemetry opt-out, Node version requirement (24.8+ or 22.22.3+).
- `writing-tests.md` covers: act+expect golden rule, judge isolation (actor/judge see different data), params/unique, sessions/secrets (opaque `Secret`), `waitFor`/`extract`.
- `running-debugging.md` covers: single-file runs, `.e2e/failures/` reading, exit codes (1/2/3/4/130), budgets (default and per-agent), never-sleep rule, cache modes (`read-write`/`read-only`/`off`), `--strict-cache`.
- `bug-bash.md` covers: persona count cap, `--max-steps`/`--timeout` per-persona bounds, ASSERTION_FAILED confirmation gate (only repro tests failing with ASSERTION_FAILED count as bugs), explore findings are not regressions.
- `ci.md` covers: GHA snippet, workers (cores/2 local, 1 in CI), retries (0 local, 1 CI), `test.only` rejected in CI, replay cache `read-only` + `--strict-cache` in CI, artifacts (`.e2e/report.json` + `junit.xml`).
- `mobile-rn.md` covers: React Native scope via `@e2e-dev/mobile`, iOS simulators / Android emulators, one-line mention of `@e2e-dev/kernel`/`@e2e-dev/eas`.
- No reference file contains literal model or provider ids.
- No reference file contains secrets, tokens, or credentials.
- No reference file contains "re-run until green" phrasing.
- `scripts/check-skills.sh` exits 0 (validates no nested reference chains).

**Scenarios**: AC-030-02 (AC-030-02-01 through AC-030-02-08)

---

## T3 — Create `skills/e2e-testing/assets/e2e.config.example.ts`

**Goal**: Config template demonstrating all governance rules.

**Files touched**: `skills/e2e-testing/assets/e2e.config.example.ts` (new)

**Acceptance criteria**:
- File exists and is valid TypeScript (parseable by `tsc --noEmit` or syntactically valid).
- Model ids read from `process.env` (e.g. `E2E_AGENT_MODEL`, `E2E_JUDGE_MODEL`) — never hardcoded.
- Contains the port-0 pattern: `url` with port `0` and `{port}` substitution.
- Contains app launch via `targets[].app.command` (shell-less).
- Contains budget configuration (defaults or commented examples).
- Contains cache mode configuration (`read-write`/`read-only`/`off`).
- Contains a telemetry opt-out comment (`E2E_TELEMETRY_DISABLED=1`).
- Tests path configured: `tests/**/*.e2e.ts`.
- No literal model or provider ids.
- No secrets, tokens, or credentials.
- No `.env` file loading (framework does not load `.env` files — config must not suggest it).

**Scenarios**: AC-030-03 (AC-030-03-01 through AC-030-03-05)

---

## T4 — Create `agents/e2e-runner.md`

**Goal**: Agent file with two duties (author/maintainer + bug-bash orchestrator), following OpenCode agent spec and Anthropic principles.

**Files touched**: `agents/e2e-runner.md` (new)

**Acceptance criteria**:
- YAML frontmatter with `description`, `mode: subagent`, and `permission` block.
- `permission.bash` denies `git push*` and `git commit*`.
- `permission.edit` denies edits outside `tests/`, `e2e.config.ts`, and `.e2e/` (read-only).
- No `model:` key in frontmatter.
- Body defines: Role, The one rule, Execution steps for both duties (author/maintainer; bug-bash mode), Stopping conditions, Output summary.
- Workflow vs Agent choice is justified (simplest-thing principle documented).
- Ground truth requirement: agent reads `.e2e/failures/` + `report.json` after every run, never assumes green.
- Stopping conditions: max 3 fix rounds per failing test file; framework budgets are the inner bound.
- "re-run until green" is stated as forbidden phrasing — every re-run is a counted attempt.
- Bug-bash mode bounds: persona count cap, per-persona `--max-steps`/`--timeout`, ASSERTION_FAILED confirmation gate stated.
- Poka-yoke tool guidance: absolute paths, single-file runs.
- Transparency: agent surfaces plan + per-run evidence in output.
- Output summary contract defined.
- No literal model or provider ids.
- No secrets, tokens, or credentials.
- `scripts/check-orchestration.sh` exits 0 (agent references resolve).

**Scenarios**: AC-030-04 (AC-030-04-01 through AC-030-04-08)

---

## T5 — Doc wiring (`docs/TESTING.md` + `AGENTS.md`)

**Goal**: Wire the new standard into the existing doc surface.

**Files touched**: `docs/TESTING.md` (edit), `AGENTS.md` (edit)

**Acceptance criteria**:
- `docs/TESTING.md` has a new or extended E2E section stating agentic E2E is the standard for TS/Node + RN child repos.
- `docs/TESTING.md` section points at `skills/e2e-testing/SKILL.md`.
- `docs/TESTING.md` keeps existing Playwright guidance for repos not adopting `e2e`.
- `AGENTS.md` "Reading the Standards" section has a line: read `skills/e2e-testing/SKILL.md` before writing or running E2E tests in a TS/Node or RN child repo.
- No literal model or provider ids added to either file.
- `scripts/check-orchestration.sh` exits 0 (doc references resolve).

**Scenarios**: AC-030-05 (AC-030-05-01 through AC-030-05-03)

---

## T6 — Conditional model wiring (explicitly conditional)

**Goal**: If adding `e2e-runner` to `opencode.json`'s agent block, wire it through the
`{env:SPEC_E2E_RUNNER_MODEL}` pattern consistently across all three files. **This task
is skipped if the human decides not to add `e2e-runner` to opencode.json** — the
agent file in T4 has no `model:` key regardless (ADR 0003 pattern), so it functions
without this task.

**Files touched (only if executed)**:
- `opencode.json` (edit — add `e2e-runner` entry)
- `config/model.local.env.example` (edit — add `SPEC_E2E_RUNNER_MODEL` var)
- `scripts/model-env.vars.sh` (edit — add `e2e-runner` to `MODEL_ENV_AGENTS`, `SPEC_E2E_RUNNER_MODEL` to `MODEL_ENV_VARS`, and case entry in `model_env_var_for_agent()`)

**Acceptance criteria**:
- `opencode.json` has `e2e-runner` entry with `"model": "{env:SPEC_E2E_RUNNER_MODEL}"` — no literal model id.
- `config/model.local.env.example` defines `SPEC_E2E_RUNNER_MODEL` with a default value.
- `scripts/model-env.vars.sh` roster includes `e2e-runner` in `MODEL_ENV_AGENTS` and `SPEC_E2E_RUNNER_MODEL` in `MODEL_ENV_VARS`, and `model_env_var_for_agent()` maps `e2e-runner` → `SPEC_E2E_RUNNER_MODEL`.
- `scripts/check-model-env.sh` exits 0.
- No literal model or provider ids in any touched file.

**Scenarios**: AC-030-06 (AC-030-06-01 through AC-030-06-03)

---

## T7 — Gate verification (final holistic check)

**Goal**: Confirm all three gate scripts pass on the final tree.

**Files touched**: none (verification only)

**Acceptance criteria**:
- `scripts/check-skills.sh` exits 0.
- `scripts/check-orchestration.sh` exits 0.
- `scripts/check-model-env.sh` exits 0 (whether T6 was executed or not — must pass in both cases).
- No literal model or provider ids in any tracked file (full-repo grep).
- No secrets, tokens, or credentials in any tracked file.
- No "re-run until green" phrasing in any tracked file under `skills/` or `agents/`.

**Scenarios**: AC-030-07 (AC-030-07-01 through AC-030-07-03)

## Acceptance scenarios

## AC-030-01-01 — Frontmatter exists with required fields
## AC-030-01-02 — Name matches directory
## AC-030-01-03 — Name format valid
## AC-030-01-04 — Description non-empty and within limit
## AC-030-01-05 — Body line count within limit
## AC-030-01-06 — Required body sections present
## AC-030-01-07 — Version pin and pre-1.0 warning present
## AC-030-01-08 — Telemetry opt-out mandated
## AC-030-01-09 — Act+expect golden rule stated
## AC-030-01-10 — Opaque Secret path taught, inline credentials forbidden
## AC-030-01-11 — No literal model or provider ids
## AC-030-01-12 — No forbidden phrasing
## AC-030-02-01 — All six reference files exist
## AC-030-02-02 — Each reference file is referenced from SKILL.md
## AC-030-02-03 — No nested reference chains
## AC-030-02-04 — setup.md content coverage
## AC-030-02-05 — writing-tests.md content coverage
## AC-030-02-06 — running-debugging.md content coverage
## AC-030-02-07 — bug-bash.md content coverage
## AC-030-02-08 — ci.md and mobile-rn.md content coverage
## AC-030-03-01 — Config example file exists
## AC-030-03-02 — Model ids from environment variables
## AC-030-03-03 — Port-0 pattern and app launch present
## AC-030-03-04 — Budgets and cache modes configured
## AC-030-03-05 — Telemetry opt-out and tests path present
## AC-030-04-01 — Frontmatter has required fields
## AC-030-04-02 — Permission denies git push and git commit
## AC-030-04-03 — Permission denies edits outside allowed paths
## AC-030-04-04 — No model key in frontmatter
## AC-030-04-05 — Body has required sections
## AC-030-04-06 — Workflow vs Agent choice justified
## AC-030-04-07 — Ground truth and stopping conditions
## AC-030-04-08 — Bug-bash mode bounds and confirmation gate
## AC-030-05-01 — docs/TESTING.md has agentic E2E section
## AC-030-05-02 — AGENTS.md Reading the Standards line added
## AC-030-05-03 — No literal model ids added to docs
## AC-030-06-01 — opencode.json e2e-runner entry uses env reference
## AC-030-06-02 — config/model.local.env.example defines the var
## AC-030-06-03 — scripts/model-env.vars.sh roster updated
## AC-030-07-01 — check-skills.sh exits 0
## AC-030-07-02 — check-orchestration.sh exits 0
## AC-030-07-03 — check-model-env.sh exits 0

## Verification

# 25-verification.md — spec 030 (e2e-skill-agent)

- **Verdict: PASS**
- Attempt index: 1 (first full run), phase 1 (pre-PR)
- Verified by: spec-verifier (stage 4), 2026-10-14
- Information barrier honored: `specs/030-e2e-skill-agent/00-informal.md` was **not**
  read. Verification is against `10-tasks.md` and `20-acceptance/AC-030-01..07.md` only.
- Working-tree state: all spec-030 deliverables are uncommitted changes on `main`'s
  working tree at HEAD `8af331a` (per orchestrator instruction; nothing was stashed,
  committed, or fixed by the Verifier).

## Summary

| # | Check | Result | Exit |
|---|---|---|---|
| 1 | Scenario traceability | PASS | 0 |
| 2 | Full test suite | PASS (green in CI-equivalent env; 8 machine-local environmental failures proven unrelated — see judgment) | 0 (CI-equivalent) |
| 3 | Complexity gate | PASS (0 violations; worst function CC=6 ≤6) | 0 |
| 3.5 | Design-principles gate | PASS (0 FAIL; 14 WARN all pre-existing in ci/templates) | 0 |
| 4 | Scenario-to-behavior spot check (a–d) | PASS | 0 |
| 5 | No unaccounted behavior | PASS (finding line; no untraced behavior) | — |
| extra | check-skills / check-orchestration / check-model-env / check-bats-assertions | PASS | 0/0/0/0 |
| extra | no-literal-model-id + no-secrets over new deliverables | PASS (zero hits) | 0 |

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-10-14T14:41:14Z

```
PASS AC-030-01 — traced to a test
PASS AC-030-02 — traced to a test
PASS AC-030-03 — traced to a test
PASS AC-030-04 — traced to a test
PASS AC-030-05 — traced to a test
PASS AC-030-06 — traced to a test
PASS AC-030-07 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.
```

Machine-readable transcript (`--json`):

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-14T14:41:34Z

```json
{
  "checks": [1, 2],
  "passes": ["AC-030-01 — traced to a test", "AC-030-02 — traced to a test", "AC-030-03 — traced to a test", "AC-030-04 — traced to a test", "AC-030-05 — traced to a test", "AC-030-06 — traced to a test", "AC-030-07 — traced to a test"],
  "fails": []
}
```

Independent 42-ID verification (the script's ERE truncates IDs to task level
`AC-030-NN` on both sides — heading scan and reference scan — so it verifies at
task granularity; the full scenario-level citation was checked mechanically):

command: grep -hoE '^## AC-030-[0-9]{2}-[0-9]{2}' specs/030-e2e-skill-agent/20-acceptance/*.md | sort -u → per-ID grep in scripts/tests/ac-030-e2e-skill-agent.bats and tests/
exit: 0
at: 2026-10-14T14:41:34Z

```
42
all-42-cited-in-bats: YES
all-42-cited-in-bash-tests: YES
scripts/tests/ac-004-005-007-trace.bats 2547bytes
```

Coder's scan-pattern claim — **verified from the script source**
(`scripts/check-scenario-traceability.sh` lines 204–207): the reference scan is
`grep --include="*.bats" --include="*_test.go" --include="*Test.java"
--include="*PropertyTest.java" --include="*.test.ts" --include="*.test.js"
--include="*.spec.ts" --include="*.spec.js"`. Plain `tests/AC-030-NN.sh` matches
none of these patterns, so the prescribed bash tests alone would leave all 42
IDs uncited and check 1 would fail. The ID-citing bats wrapper
`scripts/tests/ac-030-e2e-skill-agent.bats` is therefore load-bearing, and the
precedent file `scripts/tests/ac-004-005-007-trace.bats` exists (2547 bytes).
The wrapper cites all 42 full `AC-030-NN-MM` IDs — strictly more granular than
the script's task-level truncation.

## Evidence: full test suite

command: make test (repo suite, this machine's dirty env) → then the CI-equivalent run: pristine-HEAD git worktree + deliverables copied in + sanitized env (JUDGMENT_* unset, no gitignored credential files)
exit: 0
at: 2026-10-14T14:50:35Z

**Spec-030 bash suites (prescribed by 10-tasks.md), current tree:**

command: for n in 01..07; do bash tests/AC-030-$n.sh; done
exit: 0
at: 2026-10-14T14:42:04Z

```
tests/AC-030-01.sh exit=0 :: RESULT AC-030-01: passed=23 failed=0
tests/AC-030-02.sh exit=0 :: RESULT AC-030-02: passed=97 failed=0
tests/AC-030-03.sh exit=0 :: RESULT AC-030-03: passed=21 failed=0
tests/AC-030-04.sh exit=0 :: RESULT AC-030-04: passed=40 failed=0
tests/AC-030-05.sh exit=0 :: RESULT AC-030-05: passed=13 failed=0
tests/AC-030-06.sh exit=0 :: RESULT AC-030-06: passed=4 failed=0
tests/AC-030-07.sh exit=0 :: RESULT AC-030-07: passed=8 failed=0
SPEC030_BASH_OVERALL=0
```

**Spec-030 bats wrapper (49 tests: 42 scenario + 7 full-suite):**

command: bats --tap scripts/tests/ac-030-e2e-skill-agent.bats
exit: 0
at: 2026-10-14T14:42:17Z

```
ok 45 AC-030-03: T3 full suite (scenarios + units) exits 0
ok 46 AC-030-04: T4 full suite (scenarios + units) exits 0
ok 47 AC-030-05: T5 full suite (scenarios + units) exits 0
ok 48 AC-030-06: T6 full suite (scenarios + units) exits 0
ok 49 AC-030-07: T7 full suite (scenarios + units) exits 0
49 ok, 0 not ok
```

**Repo suite, this machine's live (dirty) env — reproduces the claimed 8 failures:**

command: make test
exit: 2
at: 2026-10-14T14:42:42Z

```
not ok 5 AC-001-05: No secrets in harness or fixtures
not ok 80 agent-env.selftest: exits 0 and reports every case passing
not ok 81 agent-env.selftest: reports a non-zero assertion count and zero failures
not ok 82 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
not ok 263 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
not ok 310 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
not ok 312 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
not ok 334 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
352 ok / 8 not ok (360 tests)
```

**Environmental proof A — same tree, sanitized env, typed-judgment files only:**

command: env -u JUDGMENT_API_URL -u JUDGMENT_BACKEND -u JUDGMENT_MIN_CONFIDENCE -u JUDGMENT_API_KEY -u JUDGMENT_MODEL bats --tap scripts/tests/typed-judgment.bats scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-10-14T14:46:36Z

```
130 ok / 0 not ok  (all 4 AC-028 failures vanish when this machine's
JUDGMENT_* vars — JUDGMENT_BACKEND=local et al., loaded by direnv from the
gitignored config/model.local.env — are unset; deliverables still present)
```

**Environmental proof B — pristine HEAD worktree (zero spec-030 deliverables), same dirty env:**

command: git worktree add --detach /tmp/ver030-head HEAD && cd /tmp/ver030-head && make test
exit: 2
at: 2026-10-14T14:47:49Z

```
not ok 214 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
not ok 261 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
not ok 263 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
not ok 285 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
307 ok / 4 not ok
```

The 4 AC-028 failures reproduce identically with **no spec-030 deliverable in
the tree** → they cannot be caused by spec-030. The 4 agent-env/AC-001-05
failures do *not* reproduce in the worktree because its root lacks this
machine's gitignored `config/agent.local.env`; in the main tree,
`scripts/check-no-hardcoded-secrets.sh` (a HEAD-tracked script, unmodified by
spec-030) fails solely on that file:

```
config/agent.local.env:9: literal token prefix                 [value REDACTED]
config/agent.local.env:14: literal token prefix                 [value REDACTED]
config/agent.local.env:9: secret-style assignment: GITHUB_TOKEN=<REDACTED live machine credential>
config/agent.local.env:14: secret-style assignment: GH_TOKEN=<REDACTED live machine credential>
config/agent.local.env:18: secret-style assignment: BAILIAN_TOKEN_PLAN_API_KEY=<REDACTED live machine credential>
✘ check-no-hardcoded-secrets: 5 violation(s) in agents, commands, scripts, docs, .github, config, templates, ci.
```

All 5 violations are in the gitignored per-machine credential file that the
repo standard *requires* to exist locally (`AGENTS.md §Per-machine agent
environment`); zero violations in any spec-030 file. A CI checkout does not
contain this file. (Real token values are redacted here — this report becomes a
tracked PR artifact and must not carry credentials.)

**Environmental proof C — CI-equivalent: pristine HEAD worktree + deliverables + sanitized env:**

command: cd /tmp/ver030-head && env -u JUDGMENT_API_URL -u JUDGMENT_BACKEND -u JUDGMENT_MIN_CONFIDENCE -u JUDGMENT_API_KEY -u JUDGMENT_MODEL make test
exit: 0
at: 2026-10-14T14:50:35Z

```
NO FAILURES
360 ok / 0 not ok
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

360 = 311 (HEAD suite) + 49 (spec-030 bats). Deliverables copied into the
worktree: `tests/`, `skills/e2e-testing/`, `agents/e2e-runner.md`,
`scripts/tests/ac-030-e2e-skill-agent.bats`, modified `docs/TESTING.md` +
`AGENTS.md`, `specs/`.

**Verifier judgment:** the Coder's environmental claim is CONFIRMED by
independent method. In a CI-equivalent environment (clean checkout replica, no
`JUDGMENT_*` shell vars, no gitignored credential files) the full suite — repo
plus all spec-030 tests — is **green, 360/360, exit 0**. The 8 failures on this
machine split cleanly into two machine-local causes, each isolated by a
controlled experiment: (1) 4× AC-028 — `JUDGMENT_BACKEND=local` exported in the
shell (proven: fails at pristine HEAD without deliverables; passes with
deliverables when the vars are unset); (2) 4× agent-env/AC-001-05 — the
gitignored `config/agent.local.env` real-credential file on disk (proven: does
not fail in a worktree lacking the file; every violation line names that file
only). Neither cause touches a spec-030 deliverable. No test is skipped or
silently disabled: the dirty-env run and the clean run both execute 360 tests.

## Evidence: complexity gate

command: python3 /tmp/cc-count-030.py tests/ac-030-lib.sh tests/AC-030-01.sh tests/AC-030-02.sh tests/AC-030-03.sh tests/AC-030-04.sh tests/AC-030-05.sh tests/AC-030-06.sh tests/AC-030-07.sh scripts/tests/ac-030-e2e-skill-agent.bats  (decision-point counter mirroring check-code-principles.sh's awk heuristic: word-boundary if/for/while/case + && + || per function, FAIL at >6; KISS at >20 body lines)
exit: 0
at: 2026-10-14T14:53:40Z

```
 CC lines  function @ file:line
  6    15  u_030_07_no_secrets @ tests/AC-030-07.sh:123
  6    10  u_030_06_no_half_wiring @ tests/AC-030-06.sh:89
  6    10  t6_wired_checks @ tests/AC-030-06.sh:61
  5     7  u_030_07_deliverables_clean @ tests/AC-030-07.sh:108
  5     8  u_030_02_no_secrets @ tests/AC-030-02.sh:121
  5     9  s_030_04_01 @ tests/AC-030-04.sh:10
  5    10  s_030_02_03 @ tests/AC-030-02.sh:28
  (…73 more functions, all CC ≤ 4)
functions measured: 80  worst CC: 6  violations(CC>6): 0  KISS(>20 lines): 0
```

Scope note: `scripts/check-code-principles.sh` audits only `*.java|go|ts|tsx|js|jsx`
(its `find` at lines 307–309) — shell/bats files are outside its scan, so the
Refactorer's shell-file claim was re-measured with a counter mirroring the
script's exact heuristic (documented at script lines 11–13: if/for/while/
switch/case/catch/&&/||/ternary, threshold >6). The only spec-030 file inside
the script's own scope, `skills/e2e-testing/assets/e2e.config.example.ts`, is
covered by the design-principles run below (zero findings).

**Refactorer claim verified: 0 violations.** Worst measured function CC = 6
(within the ≤6 bound). The extracted helpers the Refactorer introduced
(`t6_wired_checks`, `t7_ids_clause`, `t7_phrase_clause`) each sit at ≤6 with
explanatory comments citing the bound. CI's real shell linter (self-ci.yml
lines 214–220: `shellcheck scripts/*.sh templates/*.sh`) does not cover
`tests/` or `scripts/tests/` and no spec-030 file changes its scope;
shellcheck is not installed on this machine, CI remains the authority for that
gate — recorded, not a blocker (out of spec-030's declared gate set).

## Evidence: design-principles gate

command: scripts/check-code-principles.sh .
exit: 0
at: 2026-10-14T14:54:17Z

```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: "directBrokerCall", /data: { name }, /}); /node,
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
✔ Design-principles check: 0 FAIL(s), 14 WARN(s).
  WARNs are review hints — verify each before merging.
```

JSON transcript:

command: scripts/check-code-principles.sh . --json
exit: 0
at: 2026-10-14T14:54:35Z

```
tier: mvp
gates: ['complexity', 'dry', 'yagni', 'solid', 'component-per-file', 'property-tests']
fails: []
warns: 14
warn files: ['./ci/templates/archunit/OutboxArchRules.java', './ci/templates/archunit/SagaArchRules.java', './ci/templates/eslint-saga-rules/saga-compensation.js', './ci/templates/go-saga-lint.go']
```

**0 FAIL. All 14 WARNs are in `ci/templates/*`** — exactly matching the
baseline claim (14 pre-existing WARNs in ci/templates). **No FAIL or WARN
references any spec-030 file.** Per the Stop-and-Ask matrix the WARNs are
recorded and flagged to the Architect; they do not stop the pipeline.

## Evidence: scenario-to-behavior spot check

command: 4 scenario spot checks (a) AC-030-07-03, (b) AC-030-04-07↔AC-030-07-03 conflict, (c) bats-wrapper mutation test, (d) AC-030-06 both branches + T6-literal-wiring claim — commands and raw outputs below
exit: 0
at: 2026-10-14T15:00:12Z

### (a) AC-030-07-03 — holistic hygiene implementation judged FAITHFUL (with recorded divergence)

The scenario requires: check-model-env exit 0, no literal model/provider ids in
any tracked file (full-repo grep for `gpt-|claude-|gemini-|openai/|anthropic/|google/|mistral/`,
carve-outs: node_modules, .git, commented examples in config/model.local.env.example),
and no "re-run until green" phrasing under skills/ or agents/.

The Coder implemented it as: strict zero-tolerance id scan of every spec-030
deliverable (`u_030_07_deliverables_clean`, no exclusions) + tracked-tree scan
(`t7_ids_clause`) with a commented allow-list of 4 pre-existing files + an
opencode.json provider-region carve-out using the same `sed` as
check-model-env.sh's own literal scan.

Independent verification of the allow-list (all pre-existing, unchanged):

command: git grep -niE '<id patterns>' -- . ':(exclude)opencode.json' | cut -d: -f1 | sort | uniq -c  + per-file comparison against git show HEAD:<file>
exit: 0
at: 2026-10-14T15:00:12Z

```
      2 CHANGELOG.md
      1 scripts/sync-qwen-settings.sh
      1 skills/hallmark/references/assets.md
      1 skills/hallmark/references/custom-craft.md
CHANGELOG.md HEAD=2 WT=2 SAME
scripts/sync-qwen-settings.sh HEAD=1 WT=1 SAME
skills/hallmark/references/assets.md HEAD=1 WT=1 SAME
skills/hallmark/references/custom-craft.md HEAD=1 WT=1 SAME
outside-provider-hits=0        (opencode.json)
provider-region-hits=1 total-in-file  → line 20: "baseURL": "https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic/v1"
```

Hit content: CHANGELOG.md = historical release notes quoting a retired pin;
sync-qwen-settings.sh:48 = an API endpoint URL path (`/apps/anthropic/v1`
inside a string replace), not a model id; hallmark references = third-party
`ai.google.dev/gemini-api` doc URLs; opencode.json = the single provider-block
baseURL. All five exist identically at pristine HEAD; spec-030 introduced zero
new hits.

Judgment: **faithful.** (1) The provider carve-out is not a test invention —
it is the repo's own authoritative semantics: check-model-env.sh (which this
same scenario requires to exit 0) defines a literal id as anything *outside*
the provider block, and docs/SPEC_PIPELINE.md §PR review model wiring declares
provider blocks operator config (ADR 0002/0003). Scanning opencode.json's
provider region would contradict the scenario's own first clause. (2) The
allow-list divergence from the scenario's literal carve-out list is forced:
the 5 hits predate the spec in files outside every T1–T7 file list, and T7 is
"Files touched: none (verification only)"; the Stop-and-Ask matrix says
out-of-scope findings are recorded, never fixed. The test compensates exactly
where the scenario's intent lives: any *new* hit outside the documented
pre-existing set fails `t7_ids_clause`, and every spec-030 deliverable is held
to strict zero tolerance with no exclusions. (3) Recorded caveat:
`t7_ids_clause`/`t7_phrase_clause` use `git grep`, which scans tracked files
only — while the deliverables are uncommitted they are covered instead by the
file-level strict scans (`u_030_07_deliverables_clean`, `s_030_01_12`,
`s_030_02_06`, `s_030_04_08`) and by the Verifier's own working-tree scan
below; after the PR Opener commits, git grep covers them too. The
working-tree scan (grep -r over skills/ agents/, untracked included) found
zero phrase hits and zero id hits — the scenario's outcome holds now.

### (b) AC-030-04-07 ↔ AC-030-07-03 conflict resolution judged CORRECT

AC-030-04-07 requires the phrase "re-run until green" to be *stated as
forbidden* in agents/e2e-runner.md; AC-030-07-03 forbids the literal phrase
from *existing* anywhere under agents/. Both can only hold if the agent names
the prohibition without the contiguous literal string.

agents/e2e-runner.md line 100 (verbatim):

```
- Any phrasing that treats a suite as something to re-run *"until green"* is forbidden as an operating instruction: every re-run is a counted attempt under the budget above (docs/SPEC_PIPELINE.md §Remediation budget).
```

command: grep -rniE 're-run until green' skills agents   (naive whole-working-tree grep, untracked included)
exit: 1
at: 2026-10-14T14:56:01Z

```
phrase hits: NONE
```

The semantic content the scenario demands is fully present: the phrasing is
named (*"until green"* re-run framing), declared forbidden as an operating
instruction, and paired with "every re-run is a counted attempt" plus the
§Remediation budget citation. Test `s_030_04_07`'s assertion
(`until green[^.]*forbidden|forbidden[^.]*until green`) matches this
construction, and the remaining 04-07 requirements were read and confirmed
present: ground truth from `.e2e/failures/` + `.e2e/report.json` after every
run (lines 51–56, "The one rule"), never assume green (51–56), max 3 fix
rounds per failing file (94–96), framework budgets as inner bound (97–99).
The naive agents/ grep passes (zero hits, exit 1 = no match). Note:
AC-030-04-08's "only as forbidden" wording could be read as permitting the
literal phrase in a prohibition; 07-03's zero-tolerance is stricter, and the
implementation satisfies the stricter reading of both. Judgment: **faithful**.

### (c) bats wrapper genuinely executes the underlying bash scenario — PROVEN by mutation

command: sed -i 's/--strict-cache/STRICT_FLAG_REMOVED/g' skills/e2e-testing/references/running-debugging.md && bats --tap --filter "AC-030-02-06" scripts/tests/ac-030-e2e-skill-agent.bats   (in the /tmp/ver030-head scratch worktree, never the live repo; file restored after)
exit: 1
at: 2026-10-14T14:58:30Z

```
=== MUTATED: --strict-cache removed from running-debugging.md ===
1..1
not ok 1 AC-030-02-06: running-debugging.md content coverage
# (from function `run_scenario' in file scripts/tests/ac-030-e2e-skill-agent.bats, line 22,
#  in test file scripts/tests/ac-030-e2e-skill-agent.bats, line 107)
#   `run_scenario 02 AC-030-02-06' failed
MUTATED_EXIT=1
=== RESTORED ===
1..1
ok 1 AC-030-02-06: running-debugging.md content coverage
RESTORED_EXIT=0
```

Removing one scenario-required token from one deliverable flips exactly the
corresponding @test to `not ok`; restoring it flips back to `ok`. The wrapper
is not vacuous — it dispatches to `bash tests/AC-030-02.sh AC-030-02-06` and
asserts exit 0 + no FAIL line. The repo's own anti-vacuity gate agrees:
`scripts/check-bats-assertions.sh` → "PASS: 43 bats file(s), no vacuous
assertions" (below).

### (d) AC-030-06 conditional scenario — BOTH branches verified, T6-literal-wiring claim PROVEN

**Skipped branch (live tree):** `grep -c '"e2e-runner"' opencode.json` → `0`
(no entry; task skipped per its explicit conditional). Run at 14:42:04Z:
`RESULT AC-030-06: passed=4 failed=0` with N/A-by-default PASS lines for
-01/-02 exactly as the scenario's conditional note prescribes, and
check-model-env exit 0 asserted in-branch (required in both branches).

**Wired branch (scratch worktree, T6 wired):**

command: cd /tmp/ver030-head && bash tests/AC-030-06.sh   (after wiring e2e-runner into opencode.json + config/model.local.env.example + scripts/model-env.vars.sh + templates/opencode.json.bridge)
exit: 0
at: 2026-10-14T14:57:10Z

```
PASS AC-030-06-01: e2e-runner entry is exactly the {env:SPEC_E2E_RUNNER_MODEL} reference
PASS AC-030-06-01: no literal model/provider id in the e2e-runner entry
PASS AC-030-06-02: SPEC_E2E_RUNNER_MODEL defined with a default value
PASS AC-030-06-02: definition follows the comment+value pattern
PASS AC-030-06-03: model_env_var_for_agent maps e2e-runner -> SPEC_E2E_RUNNER_MODEL
PASS AC-030-06-03: roster arrays updated in scripts/model-env.vars.sh
PASS AC-030-06-03: scripts/check-model-env.sh exits 0 (required in both branches)
PASS unit T6: wiring is consistent (all-three or none): oc=1 ex=1 vars=1
RESULT AC-030-06: passed=8 failed=0
```

**Coder's mechanical claim — independently proven.** Wiring T6 *exactly as
literally listed* (only its 3 files: opencode.json, config/model.local.env.example,
scripts/model-env.vars.sh — bridge template untouched):

command: bash scripts/check-model-env.sh   (in /tmp/ver030-head, T6-wired-as-listed)
exit: 1
at: 2026-10-14T14:56:50Z

```
FAIL templates/opencode.json.bridge: agent e2e-runner missing
✘ check-model-env: 1 violation(s).
```

Mechanism confirmed from source: check-model-env.sh check 4 runs
`validate_model_wiring` over `templates/opencode.json.bridge`, whose roster
loop (`for agent in "${MODEL_ENV_AGENTS[@]}"`) fails on any roster agent
missing from the file. Adding `e2e-runner` to `MODEL_ENV_AGENTS` (T6's own
instruction) without editing the bridge template (not in T6's file list) makes
T6's own acceptance criterion "scripts/check-model-env.sh exits 0"
unsatisfiable. Adding the bridge entry (4th file) → exit 0 (verified:
`PASS check-model-env: all model values are {env:SPEC_*_MODEL} references…`).
**The skip is justified, not lazy**: T6 as literally written is internally
inconsistent, and the scenario's own conditional ("if skipped, all three
scenarios are considered N/A and pass by default") is the specified escape
hatch. The test detects the branch mechanically (`wired()`), judges each
branch correctly, and `u_030_06_no_half_wiring` blocks the half-wired state.
Recorded for the Architect/human: if a future human decides to wire
`e2e-runner`, the change needs 4 files (T6's 3 + `templates/opencode.json.bridge`).

## Additional claimed gates — re-executed

command: scripts/check-skills.sh
exit: 0
at: 2026-10-14T14:54:38Z

```
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
```

(1 WARN — pre-existing `skills/hallmark`, not a spec-030 file; `skills/e2e-testing/SKILL.md` is 113 lines. Recorded, not blocking.)

command: scripts/check-orchestration.sh
exit: 0
at: 2026-10-14T14:54:39Z

```
Checking docs/ and language-specific/ references (agents/)...

All orchestration references valid.
```

command: bash scripts/check-model-env.sh
exit: 0
at: 2026-10-14T14:54:55Z

```
PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired, bridge template checked.
```

(Tooling note: invoking `scripts/check-model-env.sh` directly exits 126 — the
file is tracked at mode 100644, no execute bit, at HEAD `8af331a`; pre-existing,
not a spec-030 change. Every caller in the repo, including the spec-030 tests,
invokes it via `bash`, which exits 0.)

command: scripts/check-bats-assertions.sh
exit: 0
at: 2026-10-14T14:54:39Z

```
PASS check-bats-assertions: 43 bats file(s), no vacuous assertions.
```

## No-literal-model-id and no-secrets constraints over the new deliverables

command: grep -rniE '<7 id patterns, runtime-assembled>' skills/e2e-testing tests agents/e2e-runner.md scripts/tests/ac-030-e2e-skill-agent.bats + git diff -U0 HEAD -- docs/TESTING.md AGENTS.md added-lines scan + credential-shaped literal scan (ghp_/sk-/AKIA/-----BEGIN/api_key|token|secret|password assignments)
exit: 0
at: 2026-10-14T14:56:01Z

```
file hits: NONE
diff-added hits: NONE
secret hits: NONE
phrase hits: NONE      (forbidden re-run phrase, skills/ + agents/ whole working tree)
```

All spec-030 deliverables — skill tree, agent file, bash tests, bats wrapper,
and both doc diffs (added lines only) — are clean of literal model/provider
ids, credential-shaped literals, and the forbidden phrase.
`config/model.local.env.example` carries concrete default model ids by repo
policy (AGENTS.md §Model Configuration) and matches none of the scenario's
seven id patterns — consistent, no finding.

## No unaccounted behavior (finding line, not a command)

Finding: **none — every deliverable element traces to 10-tasks.md /
20-acceptance.** Skimmed: `skills/e2e-testing/` (SKILL.md sections map 1:1 to
T1 criteria; 6 references map to T2 coverage lists; `assets/e2e.config.example.ts`
blocks map to T3 bullets — env-sourced models, port-0 + `{port}`, shell-less
argv `app.command`, budgets, cache modes, telemetry comment, tests glob, no
`.env` loading), `agents/e2e-runner.md` (frontmatter/permissions/sections map
to T4 criteria), doc diffs (map to T5), `tests/` + lib (test approach per the
10-tasks header; `u_*` unit checks each implement a T1–T7 acceptance bullet
the scenarios don't reach), bats wrapper (traceability requirement, cited
precedent). Two elaborations noted and judged traceable, not unaccounted: the
config example's `artifacts:`/`callbackUrl:` blocks (demonstrate the T2 ci.md
artifact criteria and reinforce the T3 port-0 pattern) and the agent's
"Full-suite mode (not your call)" bullet (elaborates T4's single-file poka-yoke
guidance). Neither adds behavior outside the tasks.

## Out-of-scope findings (recorded, NOT fixed — Stop-and-Ask matrix)

1. **Test hermeticity (environmental):** on this machine 8 repo-suite tests
   fail from machine-local state — `JUDGMENT_*` vars exported into every
   direnv-loaded shell (from gitignored `config/model.local.env`) break 4
   AC-028 typed-judgment tests that assume an unconfigured environment, and
   the gitignored `config/agent.local.env` credential file (required locally by
   AGENTS.md) breaks `check-no-hardcoded-secrets.sh` and hence 4
   agent-env/AC-001-05 tests. The suite is not hermetic against the very
   per-machine setup the repo mandates. Proven environmental above; CI is
   unaffected. Follow-up candidate: make those tests scrub `JUDGMENT_*` and
   scan a tracked-tree replica (as spec-030's own `u_030_07_no_secrets` does).
2. **Secret scanner echoes secrets:** `check-no-hardcoded-secrets.sh` prints
   matched credential *values* verbatim to stdout (observed: live `ghp_…` and
   API-key values from `config/agent.local.env` appeared in terminal output and
   would land in any captured log). Redacted in this report. Follow-up
   candidate: print file:line + pattern name only.
3. **Scanner dir coverage:** `check-no-hardcoded-secrets.sh` scans `agents,
   commands, scripts, docs, .github, config, templates, ci` — not `skills/` or
   `tests/`. Consequence for spec-030: `u_030_07_no_secrets`'s replica scan
   cannot actually see the `skills/e2e-testing/` or `tests/` copies it makes
   (its agents/ and scripts/tests/ copies are scanned). The Verifier's
   independent scan (above, zero hits over all deliverables) confirms the
   outcome the unit claims, so no false green today; the unit's coverage claim
   is nonetheless wider than its mechanism. Follow-up candidate: widen the
   scanner's dir list or the unit's scan.
4. **`scripts/check-model-env.sh` lacks the execute bit** (tracked mode 100644
   at HEAD, unlike sibling check scripts) — direct invocation exits 126; all
   repo callers use `bash`. Pre-existing; cosmetic.
5. **Refactorer-recorded SKILL.md/references duplication mandate-conflict**
   (as relayed by the orchestrator; the Refactorer's own record governs):
   Agent-Skills progressive-disclosure rules push detail into references/
   while some acceptance criteria require specific content in SKILL.md itself —
   recorded here for the Architect per the relay; the delivered files satisfy
   both `check-skills.sh` and every scenario, so no gate impact.
6. **Traceability script granularity:** `check-scenario-traceability.sh`'s ERE
   truncates scenario ids to task level (`AC-030-NN`) on both the heading and
   reference side, so check 1 cannot distinguish which `-MM` scenario is
   cited. The bats wrapper's full 42-ID citation exceeds the script's
   granularity; no gap for spec-030, but a scenario-level typo inside a cited
   task would pass the script. Informational.

## Overall verdict

**PASS** — every gate ran and produced no findings against spec-030:
traceability exit 0 (42/42 IDs cited and resolving), full suite green
(360/360) in a CI-equivalent environment with the 8 machine-local failures
independently proven environmental, complexity 0 violations (worst CC 6 ≤ 6),
design-principles exit 0 (0 FAIL, 14 WARNs all pre-existing ci/templates),
spot checks (a)–(d) faithful, additional gates (check-skills,
check-orchestration, check-model-env, check-bats-assertions) all exit 0, and
zero literal model ids / secrets / forbidden phrasing in the deliverables.
Architect (stage 5a) may proceed.

## Quality gates

# Report — spec 030 (e2e-skill-agent)

- **Verifier verdict (carried forward):** PASS (25-verification.md, attempt 1, 2026-10-14)
- **Mutation score:** skipped — `mvp` tier
- **Complexity summary (carried from 25-verification.md / Refactorer):** worst measured CC = 6 (≤6 bound); 0 violations; 0 KISS violations; 80 functions measured across the spec-030 shell/bats deliverables
- **Equivalent mutants:** N/A (mutation testing skipped at `mvp` tier)
- **Final test status:** green — 255 spec-030 assertions across 7 bash suites + 1 bats wrapper, exit 0

## Tier determination

`mvp`. Independently determined from three converging signals (none trusted from prior stages):

1. `grep 'Conformance tier' AGENTS.md` → no declaration in repo root `AGENTS.md`.
2. No `AGENTS_<PROJECT>.md` file exists at the repo root (no project-specific tier declaration anywhere).
3. `make mutation` (Makefile lines 134–141) greps `AGENTS.md`/`AGENTS_*.md` for "Conformance tier: production"; absent → falls through to the else branch which prints "skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)".
4. Verifier's independent `check-code-principles.sh --json` run: `"tier": "mvp"`.

Per docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix ("Project type ambiguous / conformance tier undetectable → defer to the harness default (`mvp` tier)") and docs/CONFORMANCE_TIERS.md (tier not declared → project conforms to the `mvp` floor), the repo's tier is `mvp`.

Per docs/SPEC_PIPELINE.md §Conformance tiers, the Architect's mutation-testing stage runs only at `production` and above. At `mvp`, it is skipped.

## Mutation testing

Not run. `mvp` tier does not require mutation testing (docs/SPEC_PIPELINE.md §Conformance tiers; `make mutation` else-branch). Skip reason recorded as the mutation-score row above.

## Final test status

Spec-030 test suite re-executed by the Mutation Runner after the Verifier's PASS — confirms the spec-030 slice itself is green on this machine in the working tree. The repo-wide `make test` environmental caveat (8 failures from this machine's gitignored `config/agent.local.env` + direnv-loaded `JUDGMENT_*` vars) is proven environmental by the Verifier's three controlled experiments (pristine HEAD worktree with/without deliverables, sanitized env); in a CI-equivalent environment the full suite is 360/360 green. The Mutation Runner cites the Verifier's evidence rather than re-running the full repo suite in a sanitized env — the spec-030 slice under test is the Mutation Runner's gate, and it is green.

command: for n in 01 02 03 04 05 06 07; do bash tests/AC-030-$n.sh; done
exit: 0
at: 2026-10-14T15:12:34Z

```
RESULT AC-030-01: passed=23 failed=0
RESULT AC-030-02: passed=97 failed=0
RESULT AC-030-03: passed=21 failed=0
RESULT AC-030-04: passed=40 failed=0
RESULT AC-030-05: passed=13 failed=0
RESULT AC-030-06: passed=4 failed=0
RESULT AC-030-07: passed=8 failed=0
total passed=206 failed=0
```

command: bats --tap scripts/tests/ac-030-e2e-skill-agent.bats
exit: 0
at: 2026-10-14T15:12:34Z

```
ok 1  AC-030-01-01: ...
...
ok 49 AC-030-07: T7 full suite (scenarios + units) exits 0
49 ok, 0 not ok
```

Spec-030 total: 206 bash-suite assertions + 49 bats tests = **255 spec-030 assertions, all green, exit 0.**

## Gate results (carried from Verifier)

| Gate | Verifier result | Exit |
|---|---|---|
| Scenario traceability | PASS (42/42 IDs cited and resolving) | 0 |
| Full test suite | PASS (360/360 in CI-equivalent env; 8 machine-local environmental failures proven unrelated) | 0 |
| Complexity | PASS (worst CC=6 ≤6; 0 violations) | 0 |
| Design-principles | PASS (0 FAIL; 14 WARNs all pre-existing in `ci/templates/`) | 0 |
| Scenario-to-behavior spot check | PASS (4 spot checks, all faithful) | 0 |
| check-skills | PASS (1 pre-existing WARN in `skills/hallmark`) | 0 |
| check-orchestration | PASS | 0 |
| check-model-env | PASS | 0 |
| check-bats-assertions | PASS (43 bats files, no vacuous assertions) | 0 |
| No literal model ids / secrets / forbidden phrase in deliverables | PASS | 0 |

## Remediation record

Per docs/SPEC_PIPELINE.md §Remediation budget: each BLOCK is recorded with phase and attempt count at which it was resolved.

- **Phase 1 (pre-PR) BLOCKs:** none. Verifier PASS at attempt 1.
- **Phase 2 (post-PR) BLOCKs:** none. Not yet applicable (PR not opened).

**Remediation: 0 BLOCKs total.** Phase-1 retries: 0. Phase-2 retries: 0. The Verifier's first full run produced a PASS verdict; no re-delegation, no re-verification rounds.

## Out-of-scope findings (carried from 25-verification.md, recorded — not fixed)

1. Test hermeticity: 8 repo-suite tests fail on this machine from machine-local state (`JUDGMENT_*` vars + gitignored `config/agent.local.env`); proven environmental; CI unaffected.
2. Secret scanner echoes matched values verbatim to stdout.
3. Secret scanner does not scan `skills/` or `tests/`.
4. `scripts/check-model-env.sh` lacks the execute bit (mode 100644); all callers use `bash`.
5. Refactorer-recorded SKILL.md/references duplication mandate-conflict.
6. Traceability script's ERE truncates scenario IDs to task-level granularity.

Per the Stop-and-Ask matrix: recorded, not fixed; propose follow-up specs if warranted.

## PR

(to be appended by the PR Opener after the draft PR opens)

PR: https://github.com/RexiAI/my-engineering-standards/pull/78
Commit count: 6
