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
