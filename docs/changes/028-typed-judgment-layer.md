# 028-typed-judgment-layer

> Spec pipeline archive. Original source: `specs/028-typed-judgment-layer/` (deleted by this script).
> Archived: 2026-09-30

## Original ask

# 028 — Typed-Judgment Layer (opt-in System One fast-path for agent classifications)

## Problem

Several points in the multi-agent architecture spend a full LLM agent turn on a
pure classification decision:

- `skills/ci-triage/SKILL.md` — classify a failing CI run as exactly one of
  `flake` / `regression` / `infra` / `config` (the "class" field).
- `agents/spec-ux.md` — decide applicability: does the spec have a frontend
  surface? Today a whole agent turn is burned to emit `SKIPPED`, run the design
  skill, or emit `BLOCKED — <one question>`.

A typed-judgment API (TypeSafe "System One" style: send state + typed
questions, get Choice/Noul/Score answers with calibrated probabilities and
confidence in ~150ms, far cheaper than a frontier LLM call) can answer these
directly. Later phases could cover orchestrator behavior-vs-structure routing,
loop-triage spec-state classification, pr-review severity/injection checks,
verifier spot-checks (advisory only), and mutation-runner equivalent-mutant
classification — all out of scope here.

## Solution (pilot)

Add an **optional, opt-in typed-judgment fast-path**:

1. **`scripts/typed-judgment.sh`** — a curl+jq wrapper:
   - Input: a state payload (string or JSON, via file or stdin) and a
     questions JSON payload (map of question id → `{type: choice|noul|score,
     instructions, criteria}`) plus the model id from env.
   - POSTs to `$JUDGMENT_API_URL` with `Authorization: Bearer $JUDGMENT_API_KEY`.
   - Output on success: normalized JSON answer per question
     (`choice`/`noul`/`score`, `confidence`, `probabilities`, `usage` tokens,
     measured `latency_ms`) on stdout.
   - Exit codes: `0` = usable answer; `10` = fallback (caller must use its
     stock LLM procedure). Exit `10` covers: credentials/URL not configured,
     network failure, HTTP 401/422/429/529 after at most 2 exponential-backoff
     retries, daily cap exceeded, and confidence below
     `$JUDGMENT_MIN_CONFIDENCE`.
   - Daily call cap enforced via a gitignored per-day counter file; cap value
     from `$JUDGMENT_DAILY_CAP`.
   - Never prints the API key; never logs full state payloads (truncate).

2. **Hard optionality requirement (user-mandated):** if `JUDGMENT_API_KEY` or
   `JUDGMENT_API_URL` is unset or empty in the environment, the script exits
   `10` immediately with no network call, and every consumer behaves exactly
   as it does today. Absence of credentials must be indistinguishable from
   stock pipeline behavior. The LLM classification path in each consumer stays
   fully documented and intact — the judgment call is a fast-path, never a
   replacement of the procedure.

3. **Config** (per-machine, direnv-loaded, gitignored real files):
   - `config/model.local.env.example` gains OPTIONAL entries:
     `JUDGMENT_API_URL`, `JUDGMENT_MODEL`, `JUDGMENT_MIN_CONFIDENCE`
     (default 0.6), `JUDGMENT_DAILY_CAP`.
   - `config/agent.local.env.example` gains `JUDGMENT_API_KEY` as a
     commented-out optional entry.
   - No docs may contain provider/product ids, endpoints, or model ids —
     those live only in config (GOVERNANCE.md no-docs-mirror rule; ADR
     0002/0003 precedent). Docs and agent/skill files refer to it only as
     "the typed-judgment API" / `scripts/typed-judgment.sh`.

4. **Pilot consumer A — ci-triage skill**: the classification step becomes:
   gather evidence via `gh` (unchanged) → build state JSON (failed-log
   excerpt, changed files, prior `STATE.md` entries for this failure) → one
   Choice question {flake, regression, infra, config} with rubrics lifted from
   the skill's existing decision guide → exit 0: use the typed class, record
   evidence per the existing "no classification without evidence" rule;
   exit 10: run the current LLM classification and note
   `judgment_fallback: true` in the run-log. `allowed-tools` gains
   `Bash(scripts/typed-judgment.sh:*)`.

5. **Pilot consumer B — spec-ux agent**: before loading the design skill,
   one Choice question {run, skip, ambiguous} over state {00-informal.md,
   10-tasks.md}. `run`/`skip` map to the existing proceed/`SKIPPED` outputs;
   `ambiguous`, low confidence, or any fallback exits map to the existing
   `BLOCKED — <one question>` path (LLM formulates the question as today).
   The agent's bash permission allow-list gains the script.

6. **Telemetry**: each consumer records per call in its existing run-log:
   `{judgment, answer, confidence, latency_ms, tokens, fallback}` — mirrors
   the existing `tokens_estimate` convention.

7. **Governance**:
   - **ADR 0004** (`docs/adr/0004-typed-judgment-layer.md` from
     `templates/ADR.md`, indexed in `docs/adr/README.md`) is mandatory and
     review-blocking (GOVERNANCE.md: billing constraints). It records:
     opt-in optionality, replace-with-fallback semantics, confidence
     threshold defaults, daily cap, T0 trust tier (read/gate only), and that
     **gate authority is unchanged** — a probabilistic judgment never
     overrides a deterministic gate (spec-verifier.md: "the gate wins").
   - Docs updates: `docs/SPEC_PIPELINE.md` new section "Typed-judgment
     layer" (mechanism only, provider-agnostic) and a note in
     `docs/LOOP_ENGINEERING.md`.
   - OKF: `okf/when-to-use-typesafe.md` decision doc (deterministic code vs
     typed judgment vs full LLM; primitives cheat-sheet; cookbook pointers;
     jaggedness caveat), plus `okf/index.md` and `okf/log.md` entries. OKF is
     scoped operator content — the product name is allowed there and only
     there.

## Verification

- Bats tests in `scripts/tests/` (offline): not-configured → exit 10 first;
  cap logic; exit-code mapping for 401/422/429/529/network; answer parsing
  from fixture responses via an injected fake transport or `--dry-run`.
- Existing repo checks stay green without any key present:
  `check-orchestration.sh`, `check-gate-consistency.sh`, `check-model-env.sh`,
  `check-no-hardcoded-secrets.sh`, `check-skills.sh`.
- Live smoke (only when a key is configured in the environment; otherwise
  skipped with a note): one real call each for the ci-triage question shape
  and the spec-ux question shape; assert answer/confidence parse and that
  removing the key flips both consumers to fallback with unchanged behavior.

## Out of scope (follow-up specs)

- Phase 2 consumers: orchestrator behavior-vs-structure BLOCK routing,
  loop-triage spec-state/ACTION_REQUIRED, pr-review severity + injection
  checks.
- Phase 3 advisory-only consumers: verifier spot-check scoring,
  mutation-runner equivalent-mutant classification.
- Any change to deterministic gate scripts or gate thresholds ("fix the code,
  never the threshold").

## Commit policy

No auto-commit. Work lands on a `spec/028-typed-judgment-layer` branch via the
pipeline's PR Opener stage only after all gates are green; merge is human.

## Tasks

# 028 — Typed-Judgment Layer: Tasks

## Task 1: Core `scripts/typed-judgment.sh` script

Create `scripts/typed-judgment.sh` — a curl+jq wrapper that sends a state payload
and typed questions to a judgment API and returns normalized JSON answers.

**Acceptance criteria:**

- Reads state payload from `--state-file <path>` or stdin (string or JSON).
- Reads questions from `--questions <json>` argument (map of question id →
  `{type, instructions, criteria}`).
- Reads model id from `$JUDGMENT_MODEL` environment variable.
- POSTs JSON body to `$JUDGMENT_API_URL` with `Authorization: Bearer $JUDGMENT_API_KEY`.
- On HTTP 200 with valid JSON: outputs normalized answer per question to stdout
  (fields: `answer`, `confidence`, `probabilities`, `usage` tokens, `latency_ms`).
- Exit `0`: usable answer returned and confidence ≥ `$JUDGMENT_MIN_CONFIDENCE`.
- Exit `10`: fallback — covers all of:
  - `$JUDGMENT_API_KEY` or `$JUDGMENT_API_URL` unset or empty (no network call).
  - Network failure (curl non-zero exit).
  - HTTP 401, 422, 429, or 529 after at most 2 exponential-backoff retries
    (3 total attempts max).
  - Daily cap exceeded (counter file shows today's count ≥ `$JUDGMENT_DAILY_CAP`).
  - Confidence below `$JUDGMENT_MIN_CONFIDENCE` (default `0.6`).
- Daily cap: increments a gitignored per-day counter file on each successful
  API call (HTTP 2xx). File path and format documented in script header.
- Never prints `$JUDGMENT_API_KEY` value in stdout, stderr, or any log output.
- Truncates state payload in any diagnostic/log output (max 200 characters).
- Supports `--dry-run` flag: prints the request body to stdout and exits 0
  without making a network call (for offline testing).

**Resolved (human, pre-/build):** Counter file path confirmed as proposed:
`.cache/judgment-cap-YYYY-MM-DD` (gitignored).

---

## Task 2: Config entries for typed-judgment

Add optional typed-judgment config entries to the per-machine env templates.

**Acceptance criteria:**

- `config/model.local.env.example` contains commented-out entries:
  `JUDGMENT_API_URL`, `JUDGMENT_MODEL`, `JUDGMENT_MIN_CONFIDENCE` (default
  comment shows `0.6`), `JUDGMENT_DAILY_CAP`.
- `config/agent.local.env.example` contains a commented-out entry:
  `JUDGMENT_API_KEY`.
- All entries are commented out by default (opt-in).
- No provider/product ids, endpoints, or model ids appear in any tracked doc
  file — only in the config templates.
- `scripts/check-model-env.sh` still passes (new vars are optional, not
  referenced by `opencode.json` `{env:}` — no structural violation).

---

## Task 3: ci-triage skill integration (Pilot Consumer A)

Wire `scripts/typed-judgment.sh` into the ci-triage skill's classification step
as an opt-in fast-path.

**Acceptance criteria:**

- Classification step builds state JSON: `{failed_log_excerpt, changed_files,
  prior_state_entries}` from existing `gh` evidence gathering.
- Sends one Choice question with options `{flake, regression, infra, config}`
  and rubrics from the skill's existing decision guide.
- On script exit 0: uses the typed classification as the `class` field; records
  `{judgment, answer, confidence, latency_ms, tokens, fallback: false}` in the
  run-log.
- On script exit 10: runs the existing LLM classification procedure unchanged;
  records `judgment_fallback: true` in the run-log.
- `allowed-tools` in the skill frontmatter includes
  `Bash(scripts/typed-judgment.sh:*)`.
- Existing ci-triage behavior is unchanged when credentials are absent.

---

## Task 4: spec-ux agent integration (Pilot Consumer B)

Wire `scripts/typed-judgment.sh` into the spec-ux agent's applicability decision
as an opt-in fast-path.

**Acceptance criteria:**

- Before loading the design skill, sends one Choice question with options
  `{run, skip, ambiguous}` over state `{00-informal.md content, 10-tasks.md
  content}`.
- `run` → proceed with design skill (existing "has frontend surface" path).
- `skip` → emit `SKIPPED` (existing "no frontend surface" path).
- `ambiguous`, confidence below threshold, or script exit 10 → emit
  `BLOCKED — <one question>` (LLM formulates the question as today).
- Records telemetry per call: `{judgment, answer, confidence, latency_ms,
  tokens, fallback}`.
- Agent's bash permission allow-list includes the script.
- Existing spec-ux behavior is unchanged when credentials are absent.

**Resolved (human, pre-/build):** State payload confirmed as full content of
`00-informal.md` and `10-tasks.md` (no truncation of the payload itself; the
200-character diagnostic/log truncation rule still applies to log output only).

---

## Task 5: ADR 0004 — Typed-judgment layer

Write ADR 0004 recording the architectural decision.

**Acceptance criteria:**

- `docs/adr/0004-typed-judgment-layer.md` exists, created from
  `templates/ADR.md`.
- Records: opt-in optionality, replace-with-fallback semantics, confidence
  threshold default (0.6), daily cap, T0 trust tier (read/gate only), and that
  gate authority is unchanged (probabilistic judgment never overrides a
  deterministic gate).
- Indexed in `docs/adr/README.md` with a one-line entry.

---

## Task 6: Docs updates (SPEC_PIPELINE.md, LOOP_ENGINEERING.md)

Add provider-agnostic mechanism documentation to pipeline and loop docs.

**Acceptance criteria:**

- `docs/SPEC_PIPELINE.md` contains a new section "Typed-judgment layer"
  describing: the opt-in mechanism, `scripts/typed-judgment.sh` reference,
  exit-code contract (0 = usable, 10 = fallback), and that consumers must
  preserve their stock procedure.
- `docs/LOOP_ENGINEERING.md` contains a note about the typed-judgment
  fast-path being available for loop-triage classification (future phase).
- No provider/product ids, endpoints, or model ids appear in either file.

---

## Task 7: OKF docs

Create operator-facing decision doc and update OKF index/log.

**Acceptance criteria:**

- `okf/when-to-use-typesafe.md` exists with sections: deterministic code vs
  typed judgment vs full LLM decision matrix, primitives cheat-sheet
  (Choice/Noul/Score), cookbook pointers, and jaggedness caveat.
- `okf/index.md` has a new entry linking to `when-to-use-typesafe.md`.
- `okf/log.md` has a new log entry for the typed-judgment layer addition.
- Product name is used only within `okf/` scope (per informal spec: "OKF is
  scoped operator content — the product name is allowed there and only there").

---

## Task 8: Bats tests for `scripts/typed-judgment.sh`

Write offline Bats tests covering all script behaviors without network access.

**Acceptance criteria:**

- Tests exist in `scripts/tests/typed-judgment.bats`.
- All tests run offline (no real API calls).
- Test coverage includes:
  - Not-configured: `JUDGMENT_API_KEY` unset → exit 10; `JUDGMENT_API_URL`
    unset → exit 10.
  - Daily cap logic: cap not reached → proceeds; cap reached → exit 10.
  - Exit-code mapping: HTTP 401 → exit 10; HTTP 422 → exit 10; HTTP 429 →
    exit 10; HTTP 529 → exit 10; network failure → exit 10 (all after retries).
  - Answer parsing: fixture JSON response parsed correctly; confidence above
    threshold → exit 0; confidence below threshold → exit 10.
  - `--dry-run` mode: outputs request body, exits 0, no network call.
- Tests use injected fake transport (mock curl) or `--dry-run` flag.
- `scripts/tests/typed-judgment.bats` follows the same helper conventions as
  existing Bats files in `scripts/tests/` (uses `test_helper.bash`).

## Acceptance scenarios

## AC-028-01 — Successful API call returns normalized JSON
## AC-028-02 — API key unset exits 10 without network call
## AC-028-03 — API URL unset exits 10 without network call
## AC-028-04 — API key empty string exits 10 without network call
## AC-028-05 — HTTP 401 after retries exits 10
## AC-028-06 — HTTP 422 after retries exits 10
## AC-028-07 — HTTP 429 after retries exits 10
## AC-028-08 — HTTP 529 after retries exits 10
## AC-028-09 — Retryable error succeeds on second attempt exits 0
## AC-028-10 — Network failure after retries exits 10
## AC-028-11 — Confidence below minimum threshold exits 10
## AC-028-12 — Confidence at exact minimum threshold exits 0
## AC-028-13 — Daily cap reached exits 10
## AC-028-14 — Daily cap not reached proceeds normally
## AC-028-15 — API key never appears in stdout or stderr
## AC-028-16 — State payload truncated in diagnostic output
## AC-028-17 — State payload read from file via --state-file
## AC-028-18 — State payload read from stdin
## AC-028-19 — Dry-run mode outputs request without network call
## AC-028-20 — Default minimum confidence is 0.6
## AC-028-21 — model.local.env.example contains all typed-judgment entries
## AC-028-22 — agent.local.env.example contains JUDGMENT_API_KEY entry
## AC-028-23 — All typed-judgment config entries are commented out by default
## AC-028-24 — No provider or model ids in tracked docs
## AC-028-25 — check-model-env.sh still passes with new config entries
## AC-028-26 — Typed judgment exit 0 uses typed classification
## AC-028-27 — Typed judgment exit 10 falls back to LLM classification
## AC-028-28 — State JSON contains required fields
## AC-028-29 — Choice question uses correct options and rubrics
## AC-028-30 — ci-triage allowed-tools includes typed-judgment script
## AC-028-31 — ci-triage behavior unchanged without credentials
## AC-028-32 — Choice "run" proceeds with design skill
## AC-028-33 — Choice "skip" emits SKIPPED
## AC-028-34 — Choice "ambiguous" emits BLOCKED
## AC-028-35 — Low confidence emits BLOCKED
## AC-028-36 — Script fallback emits BLOCKED
## AC-028-37 — spec-ux bash permission includes typed-judgment script
## AC-028-38 — spec-ux behavior unchanged without credentials
## AC-028-39 — Telemetry recorded per call
## AC-028-40 — ADR 0004 file exists and uses template structure
## AC-028-41 — ADR 0004 records required decisions
## AC-028-42 — ADR 0004 indexed in ADR README
## AC-028-43 — SPEC_PIPELINE.md contains typed-judgment layer section
## AC-028-44 — LOOP_ENGINEERING.md contains typed-judgment note
## AC-028-45 — when-to-use-typesafe.md exists with required sections
## AC-028-46 — okf/index.md updated with new entry
## AC-028-47 — okf/log.md updated with new entry
## AC-028-48 — Product name scoped to okf/ only
## AC-028-49 — Bats test file exists and uses project conventions
## AC-028-50 — All tests pass offline
## AC-028-51 — Tests cover not-configured exit 10
## AC-028-52 — Tests cover daily cap logic
## AC-028-53 — Tests cover HTTP exit-code mapping
## AC-028-54 — Tests cover answer parsing and confidence threshold
## AC-028-55 — Tests cover dry-run mode
## AC-028-56 — Tests use fake transport or dry-run (no real API calls)

## Verification

# 25 — Verification: 028-typed-judgment-layer

Verifier runs: **attempt 1, phase 1** (first full run — verdict FAIL, preserved
verbatim below) and **attempt 2, phase 1** (scoped re-verification of the
failed gates only — see the "Attempt 2" section at the end of this file).
Date: 2026-09-28.
Branch at verification time: `feat/bailian-token-plan-provider` (see Note N1).

## Overall verdict (current — attempt 2): **PASS**

Attempt 2 re-ran only the previously-failing gates: **traceability**
(`--checks 1` → exit 0, 56/56; AC-028-50 now traced to a genuine, non-vacuous,
passing offline test) and **check 5** (F1 `.gitignore` regression fixed — diff
vs HEAD is only the authorized `.cache/` block, +4/-0). Gates 2 (out-of-scope
ruling), 3, 3.5, 4 stand from attempt 1 and were not re-executed, per the
scoped re-verification contract. F2/F3/N1 remain human/orchestrator
preconditions for stage 5b — non-blocking for this verdict (Attempt-2 ruling).
The Architect may proceed.

## Attempt-1 verdict (historical): **FAIL** — pipeline stopped there

Failing gate IDs: `traceability`, `test-suite` (out-of-scope ruling, see
Adjudication B), `unaccounted`. No stage-5 agent may run until the in-scope
findings are fixed and a scoped re-verification (gates 1 + 5 only) passes.

### Attempt-1 gate results

| # | Check | Result | Summary |
|---|---|---|---|
| 1 | Scenario traceability | **FAIL** | exit 1 — AC-028-50 defined but no test references it (55/56 traced) |
| 2 | Full test suite | **FAIL (out-of-scope, env-caused)** | exit 2 — 213 ok / 3 not ok; all 3 proven local-env-caused (clean HEAD passes 8/8); not attributable to spec 028 |
| 3 | Complexity gate | **PASS** | shellcheck exit 0 on `scripts/typed-judgment.sh`; repo-wide findings all in untouched files (CI step is advisory) |
| 3.5 | Design-principles gate | **PASS (change-scoped)** | `-BaseRef HEAD` exit 0, zero findings; plain-tree exit 1 = 5 FAIL / 17 WARN proven pre-existing at HEAD (byte-identical clean-worktree JSON) |
| 4 | Scenario-to-behavior spot check | **PASS** | 3 randomly drawn scenarios (AC-028-12, -37, -41) assert what their Given/When/Then says |
| 5 | No unaccounted behavior | **FAIL** | `.gitignore` line corruption (regression); spec-001 remnants + scratch dir riding in the tree |

Prior-stage claims re-verified independently:

- **Coder "65 new tests green, tasks 1–8 delivered"** — CONFIRMED. 27 `@test`
  blocks in `scripts/tests/typed-judgment.bats` + 38 in
  `scripts/tests/typed-judgment-integration.bats` = 65; all 65 appear as `ok`
  in the suite run below; every task 1–8 artifact exists in the tree.
- **Refactorer "shellcheck clean"** — CONFIRMED for `scripts/typed-judgment.sh`
  (exit 0, zero findings).
- **Refactorer "worst CC ≤6 in scripts/typed-judgment.sh"** — NOT MECHANICALLY
  VERIFIABLE: this repo has no shell cyclomatic-complexity gate
  (`check-code-principles.sh` audits Java/Go/TS/JS only; CI's shell gate is
  shellcheck). Recorded as a note (W4), not a finding; the authoritative shell
  gate passes.
- **Refactorer "traceability exit 1, AC-028-50 untraced"** — CONFIRMED (claim a).
- **Refactorer "check-code-principles 5 FAIL / 17 WARN pre-existing in
  ci/templates"** — CONFIRMED (claim c, see Adjudication C).

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 1
at: 2026-09-28T19:52:07Z

```
Scenario IDs found: 56 live, 170 archived

PASS AC-028-01 — traced to a test
… (AC-028-02 through AC-028-49: PASS, one line each — 49 lines)
FAIL AC-028-50 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced.
PASS AC-028-51 — traced to a test
… (AC-028-52 through AC-028-56: PASS — 5 lines)

✘ Scenario traceability check: 1 violation(s).
```

JSON transcript (`scripts/check-scenario-traceability.sh --json`, exit 1, at
2026-09-28T19:52:08Z) — `fails` array verbatim:

```json
{
  "checks": [1, 2],
  "passes": ["AC-028-01 — traced to a test", "… 54 more …"],
  "fails": ["AC-028-50 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced."]
}
```

Corroborating census: `grep -roh "AC-028-[0-9]*" scripts/tests/ | sort -V |
uniq -c` lists every ID 01–49 and 51–56; **AC-028-50 is the only ID absent
from every test file**. The script is the authority; gate FAILs.

**Routing (phase 1, Coder):** AC-028-50 is the meta-scenario "all tests pass
offline" (`20-acceptance/AC-028-bats-tests.md`). Fix options: name an existing
offline-proof test with the AC-028-50 ID, or have the Specifier mark the
scenario obsolete and remove it. Scoped re-verification:
`scripts/check-scenario-traceability.sh --checks 1`.

## Evidence: full test suite

command: make test-scripts
exit: 2
at: 2026-09-28T19:52:52Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 41 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..216
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
…
not ok 5 AC-001-05: No secrets in harness or fixtures
# (in test file scripts/tests/ac-001-harness.bats, line 53)
#   `[ "$status" -eq 0 ]' failed
…
not ok 31 agent-env.selftest: exits 0 and reports every case passing
# (in test file scripts/tests/agent-env.selftest.bats, line 14)
#   `[ "$status" -eq 0 ]' failed
not ok 32 agent-env.selftest: reports a non-zero assertion count and zero failures
# (in test file scripts/tests/agent-env.selftest.bats, line 20)
#   `[ "$status" -eq 0 ]' failed
…
```

Totals: **213 ok / 3 not ok** of 216. All 65 spec-028 tests (IDs AC-028-*)
report `ok`. No test was skipped or silently disabled.

### Clean-HEAD control runs (pre-existing-claim proof)

A detached worktree of `HEAD` (`git worktree add --detach /tmp/opencode/clean-head HEAD`;
gitignored files — including `config/agent.local.env` — absent by construction)
was used. Worktree removed after the runs.

command: bash /tmp/opencode/clean-head/scripts/check-no-hardcoded-secrets.sh
exit: 0
at: 2026-09-28T19:53:02Z

```
PASS check-no-hardcoded-secrets: no hardcoded credential values in agents, commands, scripts, docs, .github, config, templates, ci.
```

command: bats --tap /tmp/opencode/clean-head/scripts/tests/ac-001-harness.bats /tmp/opencode/clean-head/scripts/tests/agent-env.selftest.bats
exit: 0
at: 2026-09-28T19:53:07Z

```
1..8
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
ok 7 agent-env.selftest: exits 0 and reports every case passing
ok 8 agent-env.selftest: reports a non-zero assertion count and zero failures
```

### Root cause (verified, not trusted)

Direct run of `bash scripts/agent-env.selftest.sh` in the working tree (exit 1)
shows the single failing case:

```
FAIL real scanned dirs (agents/ commands/ scripts/ docs/) are clean (rc=1, out=
  config/agent.local.env:9: literal token prefix
  config/agent.local.env:14: literal token prefix
  config/agent.local.env:9: secret-style assignment: GITHUB_TOKEN=ghp_[REDACTED-BY-VERIFIER]
  config/agent.local.env:14: secret-style assignment: GH_TOKEN=ghp_[REDACTED-BY-VERIFIER]
  config/agent.local.env:18: secret-style assignment: BAILIAN_TOKEN_PLAN_API_KEY=sk-sp-[REDACTED-BY-VERIFIER]
✘ check-no-hardcoded-secrets: 5 violation(s) …
```

(Credential values redacted in this report; the scanner printed them verbatim
— see security note W3.) `AC-001-05` asserts
`check-no-hardcoded-secrets.sh` exits 0, so the same local file fails it.

**Ruling on claim (b):** the 3 failures are caused exclusively by the
machine-local, gitignored `config/agent.local.env` holding real credentials —
the same code at clean HEAD passes 8/8. They are **not introduced by spec
028**, cannot occur in CI (the file is never committed), and per the
Stop-and-Ask matrix ("Out-of-scope finding — record, do not fix, propose a
follow-up spec") they **do not block this spec's authorship**. The gate is
still transcribed as FAIL (the suite is not green on this machine); the
follow-up proposal is in W3.

## Evidence: complexity gate

command: shellcheck scripts/typed-judgment.sh
exit: 0
at: 2026-09-28T19:52:52Z

```
(no output — zero findings; shellcheck 0.10.0)
```

Tooling note: shellcheck was not installed locally; the Verifier provisioned
the standard v0.10.0 static binary into a temp dir (`/tmp/opencode/bin`,
removed at end of run). CI installs shellcheck via apt and runs the
repo-scope scan.

command: shellcheck scripts/*.sh templates/*.sh
exit: 1
at: 2026-09-28T19:52:59Z

```
In scripts/agent-env.selftest.sh line 113:
  bad "template enumerates exactly GITHUB_TOKEN and GH_TOKEN (got: $(printf '%s ' $vars))"
                                                                                  ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.
… (853 lines total)
```

Census: **0 errors, 33 warnings, 115 info** — every finding in files
**untouched by this spec** (`agent-env.selftest.sh`, `bootstrap.sh`, …). The
only shell file spec 028 adds/changes is `scripts/typed-judgment.sh` (clean,
exit 0). The CI step `shellcheck scripts/*.sh templates/*.sh` carries
`continue-on-error: true` (self-ci.yml, advisory). Gate ruling: **PASS** for
the changed-file scope; the repo-wide advisory backlog is recorded as a note,
not attributed to spec 028 (identical findings were already recorded as
warnings in the spec-001 telemetry line in `runs.jsonl`).

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-09-28T19:53:01Z

```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

This is the gate verdict for spec 028: blame-scoped to the change (the
script's own documented mechanism — "the gate judges the author's change, not
the whole tree" — and the mode self-ci uses), the diff introduces **zero**
findings. Spec 028 adds/changes no Java/Go/TS/JS source file; its only
production code is bash, which this script does not audit (shellcheck is the
authoritative shell gate — Evidence block above, exit 0).

Plain full-tree run, transcribed for completeness:

command: scripts/check-code-principles.sh --json
exit: 1
at: 2026-09-28T19:53:00Z

FAIL lines (verbatim, all 5):

```
Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:CC=14
Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:CC=10
Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:CC=10
Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:CC=8
Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:69:getSagaStepOptions:CC=7
```

WARN lines (verbatim, all 17):

```
Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:KISS_LINES=59
Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:KISS_LINES=42
Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:KISS_LINES=38
Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:KISS_LINES=31
Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): type: "problem", /docs: { /description: /meta: {
Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): schema: [], /}, /create(context) { /},
Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): }, /create(context) { /return { /schema: [],
Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:239): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:240): messageId: "directBrokerCall", /data: { name }, /}); /node,
Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:125): if len(base) > 0 { /compensations[strings.ToLower(base[:1])+base[1:]] = true /compensations[strings.ToUpper(base[:1])+base[1:]] = true /compensations[base] = true
Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:165): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Pre-existing proof:

command: bash -c "cd /tmp/opencode/clean-head && scripts/check-code-principles.sh --json"
exit: 1
at: 2026-09-28T19:53:08Z

Output byte-identical to the working-tree plain run (`cmp` clean): the exact
same 5 FAIL / 17 WARN exist at clean `HEAD` (40adcd6), all inside
`ci/templates/*` — files spec 028 does not touch. **Ruling on claim (c):**
confirmed pre-existing debt. Per the script's blame-scoping policy and the
Stop-and-Ask matrix (out-of-scope finding → record, propose follow-up), the
gate verdict for this spec is the `-BaseRef HEAD` exit 0; the ci/templates
debt is recorded verbatim above and flagged to the Architect. A follow-up was
already recommended in the spec-001 telemetry record (runs.jsonl line 1) and
remains open.

## Evidence: scenario-to-behavior spot check

command: grep -n -A6 "AC-028-12" scripts/tests/typed-judgment.bats; sed -n 66,69p scripts/tests/typed-judgment.bats; grep -n -A2 "AC-028-37" scripts/tests/typed-judgment-integration.bats; grep -n -A8 "AC-028-41" scripts/tests/typed-judgment-integration.bats; grep -n "unset JUDGMENT_MIN_CONFIDENCE" scripts/tests/typed-judgment.bats
exit: 0
at: 2026-09-28T19:55:03Z

Draw: 3 of 56 scenarios selected with `shuf -n 3 --random-source=<(yes)` over
AC-028-01…56 (reproducible): **AC-028-37, AC-028-41, AC-028-12**.

**AC-028-12 — "Confidence at exact minimum threshold exits 0"**
(typed-judgment.bats:224–230)

```
224:@test "AC-028-12: confidence exactly at threshold 0.6 exits 0" {
225-  seq_always 200 exact
226-  sf=$(make_state 'build failed at step 3')
227-  invoke -- --state-file "$sf" --questions "$Q"
228-  assert_exit_code 0 "$status"
229-  printf '%s' "$output" | jq -e '.classification.confidence == 0.6'
230-}
```

- Given URL+KEY set → setup() exports `JUDGMENT_API_URL`/`JUDGMENT_API_KEY` ✓
- Given threshold 0.6 → setup() runs `unset JUDGMENT_MIN_CONFIDENCE` (line 88),
  exercising the default-0.6 path — same semantics the scenario fixes, and the
  complement of AC-028-11 (0.55 → exit 10) and AC-028-20 (default threshold) ✓
- Given HTTP 200 + confidence exactly 0.6 → fixture `exact.json` (lines 66–68)
  contains `"confidence":0.6` — exact boundary, not a nearby value ✓
- Then exit 0 ✓ and stdout normalized JSON → `jq -e` parses stdout and asserts
  strict equality `== 0.6` ✓
- Transport is the fake curl stub on PATH (never network) ✓
**Verdict: assertions match the scenario. No false green.**

**AC-028-37 — "spec-ux bash permission includes typed-judgment script"**
(typed-judgment-integration.bats:143–145)

```
143:@test "AC-028-37: spec-ux bash permission allow-list includes scripts/typed-judgment.sh" {
144-  awk '/^permission:/,/^---$/' "$AGENT" | grep -q 'scripts/typed-judgment.sh'
145-}
```

`$AGENT` = `agents/spec-ux.md` (line 15). The awk slice restricts the search
to the frontmatter `permission:` block, so a stray mention elsewhere in the
agent file would not satisfy it — scoped exactly like the scenario's "bash
permission allow-list is inspected". Working-tree cross-check: the diff adds
`"scripts/typed-judgment.sh*": allow` inside `permission:` ✓.
**Verdict: assertions match the scenario.**

**AC-028-41 — "ADR 0004 records required decisions"**
(typed-judgment-integration.bats:173–181)

```
173:@test "AC-028-41: ADR 0004 records opt-in, replace-with-fallback, 0.6 threshold, daily cap, T0 tier, unchanged gate authority" {
174-  grep_file "$ADR" \
175-    'opt-in' \
176-    'allback' \
177-    '0\.6' \
178-    '[Dd]aily cap' \
179-    'T0' \
180-    'never overrides'
181-}
```

`$ADR` = `docs/adr/0004-typed-judgment-layer.md`; `grep_file` requires **every**
pattern (fails with the missing pattern named — not vacuous). Pattern↔Then-clause
mapping: opt-in optionality → `opt-in`; replace-with-fallback → `allback`;
threshold default 0.6 → `0\.6`; daily cap → `[Dd]aily cap`; T0 trust tier →
`T0`; gate authority unchanged → `never overrides`. All six Then clauses are
asserted. Note (minor): content-grep is the appropriate depth for a
documentation AC; the `allback` pattern is the loosest of the six but each
pattern is still individually required.
**Verdict: assertions match the scenario.**

Spot-check gate result: **PASS** (3/3 genuine; zero false greens found).

---

## Check 5 — no unaccounted behavior (finding line, not a command)

Diff skim (`git status --porcelain` + per-file diffs) against tasks 1–8:

Traced to tasks (no unaccounted logic found): `scripts/typed-judgment.sh`
(task 1; header documents every env var including test seams
`JUDGMENT_CAP_DIR`/`JUDGMENT_BACKOFF_SECONDS`/`JUDGMENT_DEBUG`/
`JUDGMENT_TIMEOUT_SECONDS` — documented affordances, not hidden behavior);
`config/*.example` (task 2, all entries commented, placeholders only);
`skills/ci-triage/SKILL.md` (task 3: allowed-tools entry, 3-field state JSON,
one Choice question with exactly {flake,regression,infra,config} + decision-guide
rubrics, exit 0/10 branching, run-log fields, gate-authority disclaimer);
`agents/spec-ux.md` (task 4: permission entry, {run,skip,ambiguous} Choice over
full 00-informal+10-tasks content, BLOCKED on ambiguous/exit-10, telemetry
fields, stock path preserved); `docs/adr/0004-*` + README index (task 5;
README diff is only the 0004 row + EOF-newline artifact); `docs/SPEC_PIPELINE.md`
§Typed-judgment layer + `docs/LOOP_ENGINEERING.md` future-phase note (task 6,
provider-agnostic); `okf/when-to-use-typesafe.md` + index + log (task 7);
`scripts/tests/typed-judgment*.bats` (task 8; the integration file goes beyond
task 8's letter — which names only `typed-judgment.bats` — but is required by
the traceability gate to cite AC-028-21…56; legitimate).

**Unaccounted findings (FAIL):**

- **F1 — `.gitignore` regression (blocking, in-scope).** The task-1 edit that
  added `.cache/` also collapsed two pre-existing entries into one:
  `-.idea/` `-.vscode/` → `+.idea/.vscode/`. The single pattern
  `.idea/.vscode/` ignores neither `.idea/` nor a root-level `.vscode/` —
  both lose their ignore coverage. No task or scenario calls for touching
  those lines. Route to Coder: restore the two separate lines, keep the
  `.cache/` addition.
- **F2 — spec-001 remnants riding in the working tree (non-blocking for 028
  authorship, must be dispositioned before stage 5b).** `docs/changes/001-tdd-scaffolding-both-tracks.md`
  (+310: a spec-001 phase-2 "Post-PR CI check, round 2" verification record)
  and `runs.jsonl` (+3: spec-001 telemetry lines) are uncommitted leftovers of
  a prior pipeline, traceable to nothing in 028's tasks. If the PR Opener
  commits the tree as-is, unrelated spec-001 content lands in the 028 PR.
  Human/orchestrator must decide: commit separately or discard. Not fixed here.
- **F3 — `.playwright-mcp/` untracked scratch directory.** Not task output;
  must not enter the PR. Human/orchestrator to remove or gitignore.
- Note: `specs/` shows untracked as a whole (this spec folder) — expected
  pipeline scratch, archived at stage 5b.

## Adjudications (known context a/b/c)

- **(a) Traceability exit 1 — CONFIRMED, in-scope, blocking.** AC-028-50 is
  cited by no test (census above). Script-is-authority: gate FAILs; the
  verdict is transcribed, not judged away. Coder fixes (test rename/addition
  or Specifier removal), then scoped re-run with `--checks 1`.
- **(b) 3 suite failures — CONFIRMED local-env-caused; ruled NOT blocking for
  spec 028.** Same-code clean-HEAD worktree (no gitignored credentials file)
  passes the two affected test files 8/8 and `check-no-hardcoded-secrets.sh`
  exits 0. Root cause: the scanner scans the working tree including the
  gitignored `config/agent.local.env`, whose real credentials it flags (and
  echoes). CI can never see this file. Recorded as an out-of-scope FAIL with a
  follow-up proposal (W3); it does not route to this spec's Coder.
- **(c) check-code-principles 5 FAIL / 17 WARN — CONFIRMED pre-existing;
  ruled out-of-scope.** Clean-HEAD JSON is byte-identical to the working-tree
  plain run; every finding sits in `ci/templates/*` (untouched). The script's
  own blame-scoped mode (`-BaseRef HEAD`, the self-ci invocation) exits 0 with
  zero findings — the gate verdict for this change. Debt recorded verbatim,
  flagged to Architect, follow-up spec recommended (already recommended once
  in spec-001's telemetry; still open).

## Warnings and notes for Architect / orchestrator

- **W1 (design-principles WARN backlog):** the 17 WARNs above — review hints
  only; do not stop the pipeline (matrix: "Design gate WARN — record; do not
  stop; flag to the Architect").
- **W2 (complexity):** shellcheck repo-wide backlog (0 errors / 33 warnings /
  115 info) in untouched files; CI step is `continue-on-error` advisory.
- **W3 (security, out-of-scope follow-up proposal):** `check-no-hardcoded-secrets.sh`
  (a) scans gitignored local files, making local runs of `AC-001-05` and
  `agent-env.selftest` fail on any correctly-configured dev machine, and
  (b) **echoes matched secret values verbatim into its findings output**
  (observed: real `GITHUB_TOKEN`/`GH_TOKEN`/`BAILIAN_TOKEN_PLAN_API_KEY`
  values printed during this run; redacted in this report). A follow-up spec
  should restrict the scan to tracked content (or honor `.gitignore`) and
  redact matched values in output.
- **W4:** Refactorer's "worst CC ≤6" claim for `scripts/typed-judgment.sh` has
  no mechanical checker in this repo (see claims table); shellcheck, the
  authoritative shell gate, is clean.
- **N1 (branch):** current branch is `feat/bailian-token-plan-provider`, not
  `spec/028-typed-judgment-layer`. The PR Opener's precondition (branch =
  `spec/NNN-slug`) will STOP at stage 5b unless the orchestrator creates and
  switches to the spec branch first.
- **N2:** two prunable stale worktrees exist (`/tmp/m3`, `/tmp/pr64`) —
  pre-existing, untouched by this run.

## Remediation routing and re-verification scope

Per docs/SPEC_PIPELINE.md §Remediation budget (phase 1, max 3; this was
attempt 1):

1. **Coder** (behavior/changes): fix F1 (`.gitignore` two-line restore) and
   resolve AC-028-50 (cite it from a test, or Specifier removes the scenario).
2. **Human/orchestrator**: disposition F2 (spec-001 remnants) and F3
   (`.playwright-mcp/`) before any commit; decide N1 branch strategy.
3. Re-invoke Verifier for **scoped re-verification, attempt 2, phase 1**:
   gate 1 only via `scripts/check-scenario-traceability.sh --checks 1`, plus a
   re-skim of the `.gitignore` diff under check 5. Gates 2 (out-of-scope
   ruling stands), 3, 3.5, 4 prior results stand and will not be re-executed.

Tooling note: this run provisioned shellcheck v0.10.0 into a temp dir (absent
locally) and removed it, together with the clean-HEAD worktree and all scratch
files, before finishing. No production file was modified by the Verifier; the
only writes are this report and the `runs.jsonl` telemetry line appended via
`scripts/record-gate-run.sh`.

- **W5 (tooling, out-of-scope):** `scripts/record-gate-run.sh` is committed
  mode 644 (not executable) — direct invocation exits 126; this run invoked it
  via `bash scripts/record-gate-run.sh` per contract. Telemetry appended
  successfully (exit 0, valid JSON line in `runs.jsonl`:
  specSlug=028-typed-judgment-layer, outcome=fail, loopCount=1,
  phase1Retries=0, phase2Retries=0, runId generated). Follow-up should set
  the executable bit or document the `bash` invocation.

---

# Attempt 2 — scoped re-verification (phase 1, attempt 2 of max 3)

Date: 2026-09-28. Trigger: Coder remediation of the attempt-1 in-scope
findings — the `traceability` FAIL (AC-028-50 untraced) and check-5 finding F1
(`.gitignore` line corruption). Scope per contract: only the previously-failing
gates re-run — gate 1 via `scripts/check-scenario-traceability.sh --checks 1`,
check 5 as a `.gitignore` diff re-skim, plus genuineness confirmation of the
new AC-028-50 test (not vacuous). Gates 2 (out-of-scope ruling stands), 3,
3.5, 4: attempt-1 results stand and were **not** re-executed.

## Attempt-2 verdict: **PASS**

| # | Check | Attempt-2 result | Basis |
|---|---|---|---|
| 1 | Scenario traceability | **PASS** | `--checks 1` exit 0 — 56/56 traced (attempt 1: 55/56) |
| 2 | Full test suite | stands — FAIL (out-of-scope, env-caused, non-blocking) | attempt-1 Adjudication B; not re-executed |
| 3 | Complexity gate | stands — PASS | not re-executed |
| 3.5 | Design-principles gate | stands — PASS (change-scoped) | not re-executed |
| 4 | Scenario-to-behavior spot check | stands — PASS | not re-executed |
| 5 | No unaccounted behavior | **PASS** (F1 fixed; F2/F3 carried as 5b preconditions) | `.gitignore` re-skim + tree census below |

Coder remediation claims re-verified independently (not trusted):

- **"AC-028-50 test added; 39/39 integration; suite now 66; traceability exit 0,
  56/56"** — CONFIRMED (census 27+39=66 `@test` blocks; 66/66 `ok`; script
  exit 0).
- **"F1 fixed — `.idea/` and `.vscode/` restored as separate lines; diff vs HEAD
  only the authorized `.cache/` block (+4/-0)"** — CONFIRMED (raw diff below,
  single hunk +4/-0).

## Evidence: scenario traceability (attempt 2, scoped)

command: scripts/check-scenario-traceability.sh --checks 1
exit: 0
at: 2026-09-28T20:06:02Z

```
Scenario IDs found: 56 live, 170 archived

PASS AC-028-01 — traced to a test
… (AC-028-02 through AC-028-49: PASS, one line each — 48 lines)
PASS AC-028-50 — traced to a test
PASS AC-028-51 — traced to a test
… (AC-028-52 through AC-028-56: PASS — 5 lines)

✔ Scenario traceability check: every scenario traced, every reference resolves.
```

JSON transcript (verbatim `passes` array):

command: scripts/check-scenario-traceability.sh --checks 1 --json
exit: 0
at: 2026-09-28T20:06:16Z

```json
{
  "checks": [1],
  "passes": ["AC-028-01 — traced to a test", "AC-028-02 — traced to a test", "AC-028-03 — traced to a test", "AC-028-04 — traced to a test", "AC-028-05 — traced to a test", "AC-028-06 — traced to a test", "AC-028-07 — traced to a test", "AC-028-08 — traced to a test", "AC-028-09 — traced to a test", "AC-028-10 — traced to a test", "AC-028-11 — traced to a test", "AC-028-12 — traced to a test", "AC-028-13 — traced to a test", "AC-028-14 — traced to a test", "AC-028-15 — traced to a test", "AC-028-16 — traced to a test", "AC-028-17 — traced to a test", "AC-028-18 — traced to a test", "AC-028-19 — traced to a test", "AC-028-20 — traced to a test", "AC-028-21 — traced to a test", "AC-028-22 — traced to a test", "AC-028-23 — traced to a test", "AC-028-24 — traced to a test", "AC-028-25 — traced to a test", "AC-028-26 — traced to a test", "AC-028-27 — traced to a test", "AC-028-28 — traced to a test", "AC-028-29 — traced to a test", "AC-028-30 — traced to a test", "AC-028-31 — traced to a test", "AC-028-32 — traced to a test", "AC-028-33 — traced to a test", "AC-028-34 — traced to a test", "AC-028-35 — traced to a test", "AC-028-36 — traced to a test", "AC-028-37 — traced to a test", "AC-028-38 — traced to a test", "AC-028-39 — traced to a test", "AC-028-40 — traced to a test", "AC-028-41 — traced to a test", "AC-028-42 — traced to a test", "AC-028-43 — traced to a test", "AC-028-44 — traced to a test", "AC-028-45 — traced to a test", "AC-028-46 — traced to a test", "AC-028-47 — traced to a test", "AC-028-48 — traced to a test", "AC-028-49 — traced to a test", "AC-028-50 — traced to a test", "AC-028-51 — traced to a test", "AC-028-52 — traced to a test", "AC-028-53 — traced to a test", "AC-028-54 — traced to a test", "AC-028-55 — traced to a test", "AC-028-56 — traced to a test"],
  "fails": []
}
```

Script-is-authority: exit 0, `fails` empty → gate **PASS** (transcribed).

## Evidence: AC-028-50 test genuineness (traceability-fix confirmation)

New test located at `scripts/tests/typed-judgment-integration.bats:247-268`
(`grep -n "AC-028-50" scripts/tests/*.bats` → single hit, line 247).

Non-vacuity scanner (whole tests dir; the scanner takes a directory, not a
file — a file argument exits 2 by design):

command: scripts/check-bats-assertions.sh scripts/tests
exit: 0
at: 2026-09-28T20:06:59Z

```
PASS check-bats-assertions: 41 bats file(s), no vacuous assertions.
```

Targeted execution of the traced test:

command: bats --tap --filter "AC-028-50" scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-09-28T20:07:05Z

```
1..1
ok 1 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
```

Both spec-028 files in full (tail shown; 66/66 `ok`, zero `not ok`, zero
skipped — `grep -c '^ok '` = 66):

command: bats --tap scripts/tests/typed-judgment.bats scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-09-28T20:07:54Z

```
ok 62 AC-028-52: typed-judgment.bats names tests for daily cap reached and not-reached
ok 63 AC-028-53: typed-judgment.bats names tests for HTTP 401 422 429 529 and network failure
ok 64 AC-028-54: typed-judgment.bats names tests for fixture parsing and confidence threshold both ways
ok 65 AC-028-55: typed-judgment.bats names a test for dry-run mode
ok 66 AC-028-56: typed-judgment.bats injects the fake curl stub and never targets a real host
```

Census: `grep -c "^@test"` → `typed-judgment.bats` 27 +
`typed-judgment-integration.bats` 39 = **66** (attempt 1: 27+38=65 — exactly
one test added, the AC-028-50 fix; no other test delta).

Manual read against the scenario (`specs/028-typed-judgment-layer/20-acceptance/AC-028-bats-tests.md:9-13`):

- Given "no JUDGMENT_API_URL or JUDGMENT_API_KEY is configured in the
  environment" → nested suite runs under `env -u JUDGMENT_API_URL -u
  JUDGMENT_API_KEY` ✓
- Given "no network access is available" → all six proxy variables curl honors
  (`http_proxy`/`https_proxy`/`HTTP_PROXY`/`HTTPS_PROXY`/`all_proxy`/
  `ALL_PROXY`) point at dead loopback `http://127.0.0.1:1`; any accidental
  real request is refused instantly; the suite's fake-curl stub is a bash
  script and ignores them, so a genuinely offline suite is unaffected ✓
- When "bats scripts/tests/typed-judgment.bats is executed" → nested
  `bats "$BATS_SCRIPTS"` where `$BATS_SCRIPTS` = `scripts/tests/typed-judgment.bats` ✓
- Then "all tests pass (exit code 0)" → `assert_exit_code 0 "$status"`, plus
  non-empty-green guards: TAP plan line present (`grep -qE '^1\.\.[0-9]+'`),
  at least one passing test (`grep -c '^ok '` `-gt 0`), zero failing tests
  (`grep -c '^not ok '` `-eq 0`) — an empty or all-skipped nested run cannot
  read as green ✓

**Verdict: the test genuinely asserts; assertions match the scenario's
Given/When/Then; no false green.**

## Evidence: check 5 — `.gitignore` re-skim (F1)

command: git --no-pager diff HEAD -- .gitignore
exit: 0
at: 2026-09-28T20:09:42Z

```
diff --git a/.gitignore b/.gitignore
index 04a27ec..f2ffade 100644
--- a/.gitignore
+++ b/.gitignore
@@ -31,6 +31,10 @@ config/agent.local.env
 # trackable.
 .envrc
 
+# Local cache for machine-generated, never-committed state (spec 028: the
+# typed-judgment daily counter files .cache/judgment-cap-YYYY-MM-DD).
+.cache/
+
 # Local dogfooding scaffold — this repo's own agent/ and command/ symlinked in
 # for testing the spec pipeline against itself (docs/SPEC_PIPELINE.md). Child
 # repos get the real thing via scripts/bootstrap.sh pointing at .standards/.
```

Finding line: single hunk, **+4/-0**, exactly the authorized `.cache/` block.
`.idea/` (file line 7) and `.vscode/` (file line 8) are restored as separate
patterns (`grep -n` census: `7:.idea/  8:.vscode/  36:.cache/`). **F1 FIXED.**

No other unaccounted delta since attempt 1: `git status --porcelain` file set
is unchanged (same 12 modified + 7 untracked entries), and the only content
changes are the `.gitignore` restore and the single added AC-028-50 test —
both trace directly to the attempt-1 routing. Check 5: **PASS**.

## Attempt-2 ruling: F2/F3 (and N1) — non-blocking for this verdict, binding preconditions at 5b

F2 (`docs/changes/001-tdd-scaffolding-both-tracks.md` +310 and `runs.jsonl` +3
— spec-001 remnants) and F3 (`.playwright-mcp/` untracked scratch) are still
present in the tree (confirmed via `git status --porcelain` at attempt 2). Per
the Stop-and-Ask matrix row "Out-of-scope finding → Record it; do not fix;
propose a follow-up spec": neither is spec-028 task output, neither is
coder-fixable, and neither fails any gate of this spec. **Ruling: F2/F3 do not
block the attempt-2 PASS.** They remain **binding preconditions for stage 5b**:
the commit-and-push carve-out permits only task-traceable files with one
conventional commit per `10-tasks.md` task, so the PR Opener must not sweep
F2/F3 into the 028 PR. Human/orchestrator disposition required before or at
5b: commit the F2 spec-001 remnants separately (or discard), and remove F3 or
add it to `.gitignore`. N1 stands likewise: the branch is
`feat/bailian-token-plan-provider`, not `spec/028-typed-judgment-layer` — the
PR Opener precondition ("branch not `spec/NNN-slug` → STOP") will halt at 5b
unless the orchestrator creates and switches to the spec branch first.

## Attempt-2 telemetry and hygiene

Appended via `bash scripts/record-gate-run.sh` (mode-644 note W5 stands) with
`SPEC_LOOP_COUNT=2 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=0` exported:
one record — `specSlug` 028-typed-judgment-layer, `gatesFailed` [] (no gate
FAILed or BLOCKed in this attempt), `outcome` pass, `warnings` carrying the
standing items (test-suite out-of-scope ruling / W3 security follow-up, W1
design-principles WARN backlog, F2/F3 disposition pending at 5b, N1 branch
precondition, W5), `durationSec` measured, `runId` generated by the script.
Result recorded in the Attempt-2 telemetry line below.

No production file was modified by the Verifier in this attempt; the only
writes are this report section and the `runs.jsonl` telemetry line appended
via `scripts/record-gate-run.sh`. No scratch files were left behind (no
worktree, no temp binaries provisioned in attempt 2).

Attempt-2 telemetry line (appended to `runs.jsonl`, verbatim):

command: SPEC_LOOP_COUNT=2 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=0 bash scripts/record-gate-run.sh -record '<json>'
exit: 0
at: 2026-09-28T20:12:58Z

```json
{"specSlug":"028-typed-judgment-layer","gatesFailed":[],"warnings":["test-suite FAIL stands out-of-scope (local-env credentials file; clean HEAD passes; CI unaffected) - W3 follow-up proposal open","W1: 17 pre-existing design-principles WARNs in ci/templates (flagged to Architect)","F2 spec-001 remnants + F3 .playwright-mcp/ - human disposition required before stage 5b","N1: branch is feat/bailian-token-plan-provider not spec/028-typed-judgment-layer - PR Opener precondition will STOP at 5b","W5: record-gate-run.sh mode 644 - invoked via bash"],"durationSec":416,"outcome":"pass","runId":"7b1e1251-270a-401d-9db9-374213791802","loopCount":2,"phase1Retries":1,"phase2Retries":0}
```

Script output: `record-gate-run: appended record to /home/dbueno/projects/my-engineering-standards/runs.jsonl`

## Quality gates

# 30 — Mutation Runner report: 028-typed-judgment-layer

Date: 2026-09-28.
Branch at report time: `feat/bailian-token-plan-provider` (pre-5b; PR Opener
will switch to `spec/028-typed-judgment-layer` before push — N1 precondition
carried from `25-verification.md`).

## Conformance tier ruling

**Tier: `mvp`.**

No `Conformance tier:` declaration exists anywhere in `agents/`, `docs/`, or
the repo-root `AGENTS.md` — verified via `grep -i "Conformance tier" agents/
docs/ AGENTS.md` (exit 1, zero matches). Per the Stop-and-Ask decision matrix
row "Project type ambiguous (language stack / conformance tier undetectable)"
(`docs/SPEC_PIPELINE.md` §Stop-and-Ask decision matrix, line 326): "Defer to
the harness default (`mvp` tier...)". This is the authoritative, non-improvised
ruling.

Per `docs/CONFORMANCE_TIERS.md` and `docs/SPEC_PIPELINE.md` §Conformance tiers
(stage table): mutation testing is a `production`-tier gate. At `mvp`, the
Architect / Mutation Runner stage runs but **skips the mutation test itself**,
recording the skip in this report.

command: grep -i "Conformance tier" -R agents/ docs/ AGENTS.md
exit: 1
at: 2026-09-28T20:15:34Z

```
(no matches)
```

command: grep -n "Architect — mutation testing" docs/SPEC_PIPELINE.md
exit: 0
at: 2026-09-28T20:15:34Z

```
425:| Architect — mutation testing | skip | yes | yes |
```

## Mutation score

**Skipped — `mvp` tier.**

command: (no command — skip is a tier-ruling consequence, not a test execution)
exit: n/a
at: 2026-09-28T20:15:34Z

Reason: conformance tier is `mvp`; mutation testing is gated to `production`
and above per the stage table at `docs/SPEC_PIPELINE.md` line 425 and the
`Mutation testing (PiTest / Gremlins / Stryker)` row of the tier assignments
table in `docs/CONFORMANCE_TIERS.md`. My agent contract
(`agents/spec-mutation-runner.md`) is explicit: "At `mvp` tier, skip this stage
entirely and write a one-line note in `30-report.md` saying so." This section
is that note.

## Equivalent mutants

None. Mutation testing was not run (tier skip), so no mutants — equivalent or
otherwise — were generated. This field is empty by construction at `mvp`.

## Complexity summary (carried from Refactorer, re-verified by Verifier)

- `scripts/typed-judgment.sh` — shellcheck clean (exit 0, zero findings) on
  the file spec 028 adds. The only authoritative shell gate in the repo.
- Refactorer's "worst CC ≤6 in `scripts/typed-judgment.sh`" claim is **not
  mechanically verifiable**: this repo has no shell cyclomatic-complexity gate
  (`check-code-principles.sh` audits Java/Go/TS/JS only; CI's shell gate is
  shellcheck). Recorded as Verifier note W4 in `25-verification.md`, not as a
  finding. The authoritative shell gate passes.
- Design-principles gate, blame-scoped to the change (`-BaseRef HEAD`): exit 0,
  zero FAIL, zero WARN. Full-tree run surfaces 5 FAIL / 17 WARN, all
  pre-existing at clean HEAD in `ci/templates/*` (untouched by this spec) —
  out-of-scope per Stop-and-Ask matrix, flagged to Architect as standing
  debt (W1).

command: shellcheck scripts/typed-judgment.sh
exit: 0
at: 2026-09-28T19:52:52Z
(carried from `25-verification.md` attempt 1, re-verified as standing)

command: scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-09-28T19:53:01Z
(carried from `25-verification.md` attempt 1)

```json
{"tier":"mvp","gates":["complexity","dry","yagni","solid","component-per-file","property-tests"],"fails":[],"warns":[]}
```

## Final test status (full spec-028 suite, re-confirmed)

**66/66 spec-028 tests green.** 27 `@test` blocks in
`scripts/tests/typed-judgment.bats` + 39 in
`scripts/tests/typed-judgment-integration.bats` = 66. The Verifier's attempt-2
scoped re-verification (phase 1) already re-executed the spec-028 suite after
the AC-028-50 fix and recorded the 66/66 `ok` census; this Mutation Runner
re-confirms the per-file `@test` census (27 + 39 = 66) at report time, with no
intervening edits to the test files.

command: grep -c "^@test" scripts/tests/typed-judgment.bats scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-09-28T20:15:34Z

```
scripts/tests/typed-judgment.bats:27
scripts/tests/typed-judgment-integration.bats:39
```

command: bats --tap scripts/tests/typed-judgment.bats scripts/tests/typed-judgment-integration.bats (carried from 25-verification.md attempt 2)
exit: 0
at: 2026-09-28T20:07:54Z

```
1..66
ok 1 AC-028-01: … (65 more lines, all `ok`)
ok 66 AC-028-56: injects the fake curl stub and never targets a real host
```

Full-suite note: the wider `make test-scripts` run still exits 2 on this
machine (213 ok / 3 not ok of 216) — all 3 failures are the same local-env
cause documented in `25-verification.md` Adjudication B (gitignored
`config/agent.local.env` holding real credentials on this dev box, which the
secrets scanner flags and echoes). Clean-HEAD control run passes the affected
files 8/8. The 3 failures are out-of-scope for spec 028, cannot appear in CI,
and do not affect this spec's verdict (Stop-and-Ask matrix: "Out-of-scope
finding → Record it; do not fix; propose a follow-up spec"). All 66 spec-028
tests are `ok`.

## Verifier's verdict (carried forward)

**PASS — attempt 2, phase 1** (scoped re-verification).

| Check | Attempt-2 result | Basis |
|---|---|---|
| 1 — Scenario traceability | PASS | `--checks 1` exit 0, 56/56 traced (AC-028-50 now traced) |
| 2 — Full test suite | stands — FAIL (out-of-scope, env-caused, non-blocking) | Adjudication B |
| 3 — Complexity gate | stands — PASS | not re-executed |
| 3.5 — Design-principles gate | stands — PASS (change-scoped) | not re-executed |
| 4 — Scenario-to-behavior spot check | stands — PASS | not re-executed |
| 5 — No unaccounted behavior | PASS | F1 fixed; F2/F3 carried as 5b preconditions |

Full evidence in `specs/028-typed-judgment-layer/25-verification.md`.

## Remediation record

Per `docs/SPEC_PIPELINE.md` §Remediation budget: one BLOCK occurred during
this spec's phase-1 loop, resolved at the second attempt.

| Phase | BLOCK ID | Attempt where it occurred | Attempt where it was resolved |
|---|---|---|---|
| 1 | Traceability FAIL (AC-028-50 untraced) + check-5 finding F1 (`.gitignore` line corruption) | attempt 1 | attempt 2 (scoped re-verification; `--checks 1` exit 0, 56/56 traced; `.gitignore` diff +4/-0) |
| 2 | none (PR not yet opened; phase-2 loop has not started) | n/a | n/a |

Source: the attempt counts and resolution come verbatim from
`25-verification.md` — "Attempt 2 — scoped re-verification (phase 1, attempt 2
of max 3)" — and the Verifier's telemetry line (`runs.jsonl` record with
`loopCount:2, phase1Retries:1, phase2Retries:0, outcome:pass`). No BLOCK has
reached phase 2.

## Readiness for stage 5b (PR Opener)

The report is green on every field within this Mutation Runner's remit:
- Verifier verdict: PASS ✓
- Mutation score: skipped (tier-gated, documented) ✓
- Complexity: carried, gate-clean for the change ✓
- Final test status: 66/66 spec-028 tests green ✓
- Equivalent mutants: none (tier skip) ✓
- Remediation record: one phase-1 BLOCK, resolved at attempt 2 ✓

PR Opener preconditions still binding (carried from `25-verification.md`, not
introduced here): N1 (branch must become `spec/028-typed-judgment-layer`), F2
(spec-001 remnants) and F3 (`.playwright-mcp/` scratch) require human/
orchestrator disposition before any commit.

Report path: `specs/028-typed-judgment-layer/30-report.md`.

---

PR: https://github.com/RexiAI/my-engineering-standards/pull/73
Commits: 11

---

# Post-PR CI check (phase 2) — round 1 of max 3

Date: 2026-09-30. Verifier run: **attempt 3, phase 2, round 1** (phase-2 counter
independent of phase 1 per docs/SPEC_PIPELINE.md §Post-PR CI check-and-remediate
loop; phase 1 closed at attempt 2 PASS). PR #73 (draft),
https://github.com/RexiAI/my-engineering-standards/pull/73, branch
`spec/028-typed-judgment-layer`, head `7bf10afd46a93b1907d98866d48e0270dad5c85a`.
Local HEAD parity confirmed (E7): same SHA, working tree clean — the local
reproduction below ran on the exact tree CI saw.

Spec folder is archived (stage 5b), so per the orchestrator's archived-spec
instruction this phase-2 record is appended to this one-pager instead of
`specs/028-typed-judgment-layer/25-verification.md` (deleted). Written without
committing; the PR Opener handles pushes.

## Round-1 verdict: **FAIL** — Self CI failed on both events; fix round 1 of max 3 opens

Check suite (all checks terminal at ruling; an early transient poll showed the
two IN_PROGRESS entries that E1/E3 record as completed — pending was never
ruled on):

| Check | Workflow | Event | Bucket | Run / check id |
|---|---|---|---|---|
| Review PR / Review PR | PR Review Agent | pull_request | **pass** | run 36717384478 |
| Validate | Self CI | pull_request | **fail** | run 36717384099, check id **109893554694** |
| Validate | Self CI | push | **fail** | run 36717375700, check id **109893527396** |

Both Validate runs failed in the same job step (`Run shell gate bats tests
(spec 001 Track B)`, step 29 — `make test-scripts`) with the **same single test
failure**: CI suite is **224 ok / 1 not ok of 225**. The phase-1 local-env
failures (AC-001-05, agent-env.selftest ×2 — Adjudication B) did **not** occur
in CI, exactly as that adjudication predicted (gitignored
`config/agent.local.env` is absent in CI); they are not implicated here.

Failing test (verbatim from CI log):

```
not ok 190 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
# (in test file scripts/tests/typed-judgment-integration.bats, line 237)
#   `[ -z "$matches" ]' failed
```

## Evidence: post-PR CI check (phase 2, round 1)

command: gh pr checks 73 --json name,state,bucket,workflow,link
exit: 0
at: 2026-09-30T12:57:28Z

```
[{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717384478/job/109894084613","name":"Review PR / Review PR","state":"SUCCESS","workflow":"PR Review Agent"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717384099/job/109893554694","name":"Validate","state":"FAILURE","workflow":"Self CI"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717375700/job/109893527396","name":"Validate","state":"FAILURE","workflow":"Self CI"}]
```

command: gh api repos/RexiAI/my-engineering-standards/commits/7bf10afd46a93b1907d98866d48e0270dad5c85a/check-runs --jq '.check_runs[] | select(.conclusion=="failure") | {id, name, conclusion, html_url}'
exit: 0
at: 2026-09-30T12:57:29Z

```
{"conclusion":"failure","html_url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717384099/job/109893554694","id":109893554694,"name":"Validate"}
{"conclusion":"failure","html_url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717375700/job/109893527396","id":109893527396,"name":"Validate"}
```

command: gh run list --branch spec/028-typed-judgment-layer --json databaseId,workflowName,event,status,conclusion,headSha,url --jq '.[] | select(.headSha=="7bf10afd46a93b1907d98866d48e0270dad5c85a")'
exit: 0
at: 2026-09-30T12:58:04Z

```
{"conclusion":"failure","databaseId":36717384099,"event":"pull_request","headSha":"7bf10afd46a93b1907d98866d48e0270dad5c85a","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717384099","workflowName":"Self CI"}
{"conclusion":"success","databaseId":36717384478,"event":"pull_request","headSha":"7bf10afd46a93b1907d98866d48e0270dad5c85a","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717384478","workflowName":"PR Review Agent"}
{"conclusion":"failure","databaseId":36717375700,"event":"push","headSha":"7bf10afd46a93b1907d98866d48e0270dad5c85a","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36717375700","workflowName":"Self CI"}
```

command: gh run view 36717384099 --log-failed 2>&1 | grep -E "not ok 190|line 237|\[ -z|make: \*\*\*|##\[error\]"
exit: 0
at: 2026-09-30T12:58:05Z

```
206:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T12:51:41.8303707Z not ok 190 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
207:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T12:51:41.8309865Z # (in test file scripts/tests/typed-judgment-integration.bats, line 237)
208:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T12:51:41.8325763Z #   `[ -z "$matches" ]' failed
244:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T12:51:46.4222047Z make: *** [Makefile:115: test-scripts] Error 1
245:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T12:51:46.4227466Z ##[error]Process completed with exit code 2.
```

The push-event run 36717375700 fails identically (`gh run view 36717375700
--log-failed` → `not ok 190 AC-028-48` … `make: *** [Makefile:115:
test-scripts] Error 1` … exit code 2; queried 2026-09-30, output not
re-captured in the timestamped pass — the pull_request run above is the
authoritative excerpt, both runs share head 7bf10af and the same single
failure).

## Evidence: local reproduction on the pushed tree

command: bats --tap --filter "AC-028-48" scripts/tests/typed-judgment-integration.bats
exit: 1
at: 2026-09-30T12:58:07Z

```
1..1
not ok 1 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
# (in test file scripts/tests/typed-judgment-integration.bats, line 237)
#   `[ -z "$matches" ]' failed
```

command: git ls-files -z '*.md' | grep -zv '^(okf|config|specs)/' --perl-regexp | xargs -0 grep -nE 'TypeSafe'
exit: 0
at: 2026-09-30T12:58:08Z

```
docs/changes/028-typed-judgment-layer.md:21:A typed-judgment API (TypeSafe "System One" style: send state + typed
```

command: git rev-parse HEAD; git status --porcelain | wc -l
exit: 0
at: 2026-09-30T12:58:08Z

```
7bf10afd46a93b1907d98866d48e0270dad5c85a
0
```

This is a genuine tree defect, **not** a local-env artifact: it reproduces on
the exact pushed HEAD with a clean working tree, and it reproduces in CI on
both events. It is a fourth failure, independent of Adjudication B's three
env-caused local failures.

## Diagnosis (root cause, verified)

The test's scan helper (`scripts/tests/typed-judgment-integration.bats:46-50`)
is:

```
md_tracked_excluding() {
  git -C "$REPO_ROOT" ls-files -z '*.md' \
    | grep -zv '^(okf|config|specs)/' --perl-regexp \
    | xargs -0 grep -lE "$@" 2>/dev/null || true
}
```

It excludes `okf/`, `config/`, `specs/` — but **not `docs/changes/`**. The
exactly-one offending file is this archive one-pager: stage 5b's archive commit
`dba52a4` (`scripts/archive-spec.sh`) copied the original informal ask verbatim
into `docs/changes/028-typed-judgment-layer.md`, and that prose contains the
product name once (line 21, `TypeSafe "System One" style`). During phase 1 the
same content lived under `specs/028-typed-judgment-layer/` — inside the
exclusion — so AC-028-48 passed (it was `ok` in both attempt-1 and attempt-2
suite runs). Archiving moved the content out of the exclusion's reach; the
failure was **latent from the moment the test was written**, because every spec
archives to `docs/changes/` at 5b by design (docs/SPEC_PIPELINE.md §Archive in
the PR / §Definition of done item 3). First failing CI run: 36717188483 on the
archive commit `dba52a4` itself — consistent with this timeline.

Corroborating design precedent: docs/SPEC_PIPELINE.md already treats
`specs/*/` (live) and `docs/changes/*.md` (archived) as the same content in two
lifecycle states, excluding **both** from the traceability reference scan
("Both directories are ID *sources* only — each is excluded from the reference
scan, because scenario markdown and archive one-pagers quote IDs (including
illustrative ones) in prose"). AC-028-48's helper predates the archive and
missed the second state.

Note: AC-028-24 (line 73) uses the same helper with endpoint/model-id patterns
and passed in CI only because no archived prose contains such a literal — it
carries the identical latent blind spot. One helper fix covers both.

## Routing recommendation: **Coder (behavior)**

Not a Refactorer matter — no complexity/duplication/structure issue; the defect
is wrong scan-scope behavior in a test helper against the post-archive tree.
Recommended fix (option A): extend the exclusion in `md_tracked_excluding`
(`scripts/tests/typed-judgment-integration.bats:48`) to cover `docs/changes/`,
e.g. `^(okf|config|specs|docs/changes)/` — same rationale SPEC_PIPELINE.md uses
for the traceability scan (archive one-pagers quote spec prose verbatim). This
is not "fix the threshold": the scenario's intent (no product name in the
repo's live docs) is preserved; the archived pipeline artifact is spec-scope
content in its post-5b location, exactly like `specs/`.

Alternative (option B, human/orchestrator judgment): sanitize the product name
in `archive-spec.sh` output or in this one-pager. Rejected as primary because
it conflicts with the archive's verbatim-copy property (check 2 of
`check-scenario-traceability.sh` resolves IDs against the one-pager as the
post-archive authority; redacting archived prose weakens that source).

After the fix: PR Opener commits + pushes (re-triggering CI), then scoped
re-check — **round 2 re-verifies only the previously-failing checks** (the two
Self CI `Validate` runs at the new head; specifically `make test-scripts` green
and AC-028-48 `ok`), not the whole suite, per §Scoped re-verification.

## Round-1 telemetry

Appended via `bash scripts/record-gate-run.sh` (W5 mode-644 note stands) with
`SPEC_LOOP_COUNT=3 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=0` exported:
`specSlug` 028-typed-judgment-layer, `gatesFailed` ["test-suite"] (the CI
failure is the bats suite gate inside Self CI's Validate job), `outcome` fail,
`durationSec` measured (approximate: exact timestamped-evidence window plus the
~5 min of untimestamped opening queries/reads preceding it), warnings carrying
the diagnosis and the AC-028-24 shared-helper note. Recorded on branch
`spec/028-typed-judgment-layer`, not committed.

Telemetry line (appended to `runs.jsonl`, verbatim):

command: SPEC_LOOP_COUNT=3 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=0 bash scripts/record-gate-run.sh -record '<json>'
exit: 0
at: 2026-09-30T13:01:23Z

```json
{"specSlug":"028-typed-judgment-layer","gatesFailed":["test-suite"],"warnings":["phase2-round1: Self CI Validate failed on both events (run 36717384099 check 109893554694 pull_request; run 36717375700 check 109893527396 push) - AC-028-48 not ok: archive one-pager docs/changes/028-typed-judgment-layer.md:21 contains the product name; test helper md_tracked_excluding excludes ^(okf|config|specs)/ but not docs/changes/ - latent since authoring, triggered by stage-5b archive commit dba52a4; reproduced locally on clean HEAD 7bf10af; routed to Coder (option A: extend exclusion)","AC-028-24 shares md_tracked_excluding - same latent blind spot; one helper fix covers both","CI suite otherwise green: 224 ok / 1 not ok of 225; Adjudication-B env-caused local failures (AC-001-05, agent-env.selftest x2) did not occur in CI as predicted","W5 stands: record-gate-run.sh mode 644 - invoked via bash","durationSec approximate: timestamped evidence window + ~300s untimestamped opening queries/reads"],"durationSec":535,"outcome":"fail"}
```

Script output: `record-gate-run: appended record to /home/dbueno/projects/my-engineering-standards/runs.jsonl`
(runId `2fbab4a0-5259-4bca-8ccf-8917f9f9d3b3` generated by the script;
loopCount 3 / phase1Retries 1 / phase2Retries 0 taken from the exported env.)

## Round summary (phase 2)

| Round | Head | Result | Failing checks | Disposition |
|---|---|---|---|---|
| 1 | 7bf10af | **FAIL** | Validate 109893554694 (pull_request, run 36717384099), Validate 109893527396 (push, run 36717375700) — AC-028-48 | Route to Coder (option A above); fix round 1 of max 3 opens |

---

# Post-PR CI check (phase 2) — round 2 of max 3

Date: 2026-09-30. Verifier run: **attempt 4, phase 2, round 2** — SCOPED
re-verification per docs/SPEC_PIPELINE.md §Scoped re-verification: round 1
failed solely on Self CI `Validate` (both events), so only the two Self CI runs
at the new head are re-checked; unchanged gates' round-1 results stand without
re-execution. PR #73 (draft),
https://github.com/RexiAI/my-engineering-standards/pull/73, branch
`spec/028-typed-judgment-layer`, head `ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182`
(fix round 1: `cb06c54` helper regex fix + `ddc32e2` round-1 report addendum &
telemetry). Local HEAD parity confirmed (E7): same SHA, working tree clean.

Fix verification: `cb06c54` is exactly round 1's recommended option A —
`md_tracked_excluding` regex extended `^(okf|config|specs)/` →
`^(okf|config|specs|docs/changes)/` with the lifecycle-equivalence rationale in
the helper comment. The shared-helper blind spot noted for AC-028-24 in round 1
is covered by the same fix: `ok 163 AC-028-24` green in both CI events (E4/E5).

PR Review Agent passed round 1 and stands; the workflow nonetheless re-triggered
at the new head, so its re-run was polled to terminal state (never ruled on
while pending) and is success (E8). The check suite at this head is the same
three checks as round 1 — **no new checks appeared, none failing**.

## Round-2 verdict: **PASS** — phase-2 CI loop closes

| Check | Workflow | Event | Bucket | Run / check id |
|---|---|---|---|---|
| Review PR / Review PR | PR Review Agent | pull_request | **pass** | run 36720016949, check id 109902436028 |
| Validate | Self CI | pull_request | **pass** (round 1: fail) | run 36720016273, check id **109902429655** |
| Validate | Self CI | push | **pass** (round 1: fail) | run 36720011039, check id **109902412561** |

Previously-failing test, both events (verbatim from CI logs): `ok 190
AC-028-48: product name TypeSafe appears only in okf/ and config/ among
tracked md outside specs/`. pull_request run suite tally: **225 ok / 0 not ok
of 225** (round 1: 224/1), single TAP plan `1..225`, `make test-scripts` step
green.

## Evidence: post-PR CI check (phase 2, round 2) — previously-failing checks

command: gh pr checks 73 --repo RexiAI/my-engineering-standards --json name,state,bucket,workflow,link
exit: 0
at: 2026-09-30T13:18:11Z

```
[{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016949/job/109902436028","name":"Review PR / Review PR","state":"SUCCESS","workflow":"PR Review Agent"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016273/job/109902429655","name":"Validate","state":"SUCCESS","workflow":"Self CI"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720011039/job/109902412561","name":"Validate","state":"SUCCESS","workflow":"Self CI"}]
```

(An opening poll at ~13:13Z showed all three IN_PROGRESS — pending was not
ruled on; this terminal query is the ruling. Round-1 failing check ids for
contrast: 109893554694 / 109893527396.)

command: gh api repos/RexiAI/my-engineering-standards/commits/ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182/check-runs --jq '.check_runs[] | {id, name, status, conclusion, html_url}'
exit: 0
at: 2026-09-30T13:18:12Z

```
{"conclusion":"success","html_url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016949/job/109902436028","id":109902436028,"name":"Review PR / Review PR","status":"completed"}
{"conclusion":"success","html_url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016273/job/109902429655","id":109902429655,"name":"Validate","status":"completed"}
{"conclusion":"success","html_url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720011039/job/109902412561","id":109902412561,"name":"Validate","status":"completed"}
```

command: gh run list --repo RexiAI/my-engineering-standards --branch spec/028-typed-judgment-layer --json databaseId,workflowName,event,status,conclusion,headSha,url --jq '.[] | select(.headSha=="ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182")'
exit: 0
at: 2026-09-30T13:19:30Z

```
{"conclusion":"success","databaseId":36720016273,"event":"pull_request","headSha":"ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016273","workflowName":"Self CI"}
{"conclusion":"success","databaseId":36720016949,"event":"pull_request","headSha":"ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720016949","workflowName":"PR Review Agent"}
{"conclusion":"success","databaseId":36720011039,"event":"push","headSha":"ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182","status":"completed","url":"https://github.com/RexiAI/my-engineering-standards/actions/runs/36720011039","workflowName":"Self CI"}
```

Exactly three runs at this head — same workflow set as round 1; no new checks.

## Evidence: CI log confirmation — previously-failing test (both events)

command: gh run view 36720016273 --repo RexiAI/my-engineering-standards --log 2>&1 | grep -E "AC-028-48|AC-028-24|^[0-9]+:Validate.*1\.\.[0-9]+|not ok|make.*test-scripts" | head -20
exit: 0
at: 2026-09-30T13:15:52Z

```
2485:Validate	Run shell gate bats tests (spec 001 Track B)	﻿2026-09-30T13:14:10.4166437Z ##[group]Run make test-scripts
2486:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:10.4166816Z ^[[36;1mmake test-scripts^[[0m
2502:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:12.2369523Z ok 2 AC-001-02: Failing bats test fails the target (not ok)
2504:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:12.3039162Z ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
2506:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:13.2248703Z ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
2663:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:42.6374859Z ok 163 AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/
2690:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:43.3811504Z ok 190 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
```

(The only "not ok" substring in the grep is inside AC-001-02's passing test
*name*; there are zero failing TAP lines — see the tally below.)

command: gh run view 36720016273 --log > /tmp/opencode/r2-pr-full.txt; grep -cE "Z ok [0-9]+" /tmp/opencode/r2-pr-full.txt; grep -cE "Z not ok [0-9]+" /tmp/opencode/r2-pr-full.txt; grep -E "Z 1\.\.[0-9]+" /tmp/opencode/r2-pr-full.txt
exit: 0
at: 2026-09-30T13:17:30Z

```
225
0
2500:Validate	Run shell gate bats tests (spec 001 Track B)	2026-09-30T13:14:12.0015302Z 1..225
```

command: gh run view 36720011039 --repo RexiAI/my-engineering-standards --log 2>/dev/null | grep -E "AC-028-48|AC-028-24" | head -5
exit: 0
at: 2026-09-30T13:16:25Z

```
2650:Validate	UNKNOWN STEP	2026-09-30T13:14:26.4272338Z ok 163 AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/
2677:Validate	UNKNOWN STEP	2026-09-30T13:14:27.0855649Z ok 190 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
```

(Push-event run; `gh` labels some steps `UNKNOWN STEP` — step-attribution
artifact only, same job, same green result, run conclusion success.)

## Evidence: local reproduction on the pushed tree (scoped)

command: bats --tap --filter "AC-028-48" scripts/tests/typed-judgment-integration.bats
exit: 0
at: 2026-09-30T13:15:54Z

```
1..1
ok 1 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
```

(Round 1's identical local command returned `not ok 1` / exit 1 at head
7bf10af — the defect and its fix both reproduce locally.)

command: git rev-parse HEAD; git status --porcelain | wc -l
exit: 0
at: 2026-09-30T13:19:30Z

```
ddc32e2127a87f1b6ed2a41abfdb0757f2f2c182
0
```

## Evidence: PR Review Agent re-run at new head (polled to terminal)

command: timeout 540 gh run watch 36720016949 --repo RexiAI/my-engineering-standards --exit-status --interval 20; echo "watch_exit=$?"
exit: 0
at: 2026-09-30T13:16:56Z

```
watch_exit=0
Run PR Review Agent (36720016949) has already completed with 'success'
```

## Round-2 telemetry

Appended via `bash scripts/record-gate-run.sh` (W5 mode-644 note stands) with
`SPEC_LOOP_COUNT=4 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=1` exported:
`specSlug` 028-typed-judgment-layer, `gatesFailed` [] (scoped re-check of the
round-1 `test-suite` gate: pass), `outcome` pass. Recorded on branch
`spec/028-typed-judgment-layer`, not committed.

Telemetry line (appended to `runs.jsonl`, verbatim):

command: SPEC_LOOP_COUNT=4 SPEC_PHASE1_RETRIES=1 SPEC_PHASE2_RETRIES=1 bash scripts/record-gate-run.sh -record '<json>'
exit: 0
at: 2026-09-30T13:22:18Z

```json
{"specSlug":"028-typed-judgment-layer","gatesFailed":[],"warnings":["phase2-round2 scoped re-check: previously-failing Self CI Validate green on both events at head ddc32e2 (pull_request run 36720016273 check 109902429655; push run 36720011039 check 109902412561) - CI log ok 190 AC-028-48, suite 225 ok / 0 not ok of 225 (round 1: 224/1)","fix cb06c54 verified = round-1 option A (md_tracked_excluding regex extended to ^(okf|config|specs|docs/changes)/); AC-028-24 shared-helper blind spot covered by the same fix - ok 163 both events","PR Review Agent re-ran at new head and passed (run 36720016949 check 109902436028); same three-check suite as round 1 - no new checks, none failing; pending never ruled on","W5 stands: record-gate-run.sh mode 644 - invoked via bash","durationSec approximate: opening queries from ~13:13:00Z to telemetry timestamp"],"durationSec":558,"outcome":"pass","runId":"c7b7b474-2ec8-4d7e-9ef8-97a46d6354fc","loopCount":4,"phase1Retries":1,"phase2Retries":1}
```

Script output: `record-gate-run: appended record to
/home/dbueno/projects/my-engineering-standards/runs.jsonl` (runId generated by
the script; loopCount 4 / phase1Retries 1 / phase2Retries 1 taken from the
exported env.)

## Round summary (phase 2, updated)

| Round | Head | Result | Failing checks | Disposition |
|---|---|---|---|---|
| 1 | 7bf10af | **FAIL** | Validate 109893554694 (pull_request, run 36717384099), Validate 109893527396 (push, run 36717375700) — AC-028-48 | Routed to Coder (option A); fix round 1 applied (cb06c54) |
| 2 | ddc32e2 | **PASS** | none — Validate 109902429655 (pull_request, run 36720016273) and 109902412561 (push, run 36720011039) success; Review PR 109902436028 success; suite 225 ok / 0 not ok | Phase-2 CI loop **closed** after 1 of max 3 fix rounds; this addendum + telemetry remain uncommitted for the PR Opener to push |
