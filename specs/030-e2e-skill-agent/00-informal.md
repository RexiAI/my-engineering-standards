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
