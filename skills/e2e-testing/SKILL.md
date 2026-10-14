---
name: e2e-testing
description: Write, run, and debug agentic end-to-end tests with the TesterArmy e2e framework (reference implementation pinned to v0.17.0) — act/expect journeys judged by a model, replay cache, bug bash mode, CI wiring, and React Native coverage. Use when a user says "write an e2e test", "run the e2e suite", "agentic e2e", "bug bash this flow", "e2e in CI", or when working in a TS/Node or React Native child repo under the e2e standard in docs/TESTING.md.
license: See repo root
compatibility: Requires Node 24.8+ or 22.22.3+ and the e2e framework at the pinned version; browser and app targets run locally or in CI.
---

# When to use

Use this skill when a TypeScript/Node or React Native repo under this
standard needs **end-to-end tests that express user intent** — an agent acts
through the real UI and a separate judge asserts the outcome — or when an
existing agentic E2E suite must be run, debugged, bounded, or wired into CI.

Typical triggers:

- "Write an e2e test for the login journey."
- "Run the e2e suite against this build / debug the failing journey."
- "Bug-bash this flow — probe it for regressions before we release."
- "Wire agentic e2e into GitHub Actions for this repo."
- "Drive the app on an iOS simulator / Android emulator."

For repo-wide test layering see `docs/TESTING.md`; the agentic E2E standard
lives here. This skill is **not** for unit, integration, or contract tests —
those layers keep their own tooling.

# Invocation

The framework ships as the `e2e` package; invoke it through npx. The reference
implementation for everything in this skill is **e2e v0.17.0**:

```bash
npx e2e init                       # scaffold config + tests/ glob
npx e2e run tests/login.e2e.ts     # one file, absolute path preferred
npx e2e run                        # full suite
npx e2e bug-bash                   # exploratory regression hunt (bounded — see bug-bash reference)
```

Config is `e2e.config.ts` at the project root. A worked example covering every
governance rule below is in `assets/e2e.config.example.ts`.

# What it does

This skill is the entry point; depth lives one level down in `references/`:

| Topic | Read |
|---|---|
| One-time setup, Node version, model env-var indirection, telemetry opt-out | [references/setup.md](references/setup.md) |
| Writing journeys — the golden rule, judge isolation, params/unique, sessions & opaque secrets, waitFor/extract | [references/writing-tests.md](references/writing-tests.md) |
| Running & debugging — single-file runs, failures artifacts, exit codes, budgets, replay cache | [references/running-debugging.md](references/running-debugging.md) |
| Bug bash — persona cap, per-persona bounds, the ASSERTION_FAILED confirmation gate | [references/bug-bash.md](references/bug-bash.md) |
| CI wiring — workers, retries, `test.only` rejection, read-only replay cache, artifacts | [references/ci.md](references/ci.md) |
| React Native scope — `@e2e-dev/mobile`, simulators/emulators | [references/mobile-rn.md](references/mobile-rn.md) |

The framework's core verbs are `agent.act(...)`, `agent.assert(...)`,
`agent.waitFor(...)`, and `agent.extract(...)` — natural-language actions
executed against the real app, assertions judged by a separate model.

## The golden rule

**Every `act` must be followed by an `expect` / `agent.assert`** before the
next `act`. An act with no assertion is an unverified step: the run cannot
prove anything happened, so the suite silently drifts. Treat this as an
invariant, not advice.

## Secrets and sessions

Credentials go through the framework's opaque `Secret` path — `credentials.user(...)` hands a secret handle to the login flow without the test body (or the model) ever seeing the value. Never inline or hardcode credentials in test files, in `e2e.config.ts`, or in any tracked file.

## Stability warning

The reference implementation is **pre-1.0** (pinned `e2e` v0.17.0): the public
API may change between minor versions. Pin the version in the child repo's
lockfile, and re-validate this skill's references after any bump — an API may
change shape without warning before 1.0.

## Telemetry

Set up with telemetry opted **out**: `E2E_TELEMETRY_DISABLED=1` in the
environment that launches runs (documented in `references/setup.md`). Treat
this as mandatory repo policy, not a suggestion.

# What it is not

- **Not a unit/integration/contract test tool** — those layers are unchanged
  (`docs/TESTING.md`).
- **Not a sleep-loop framework** — never sleep; use `agent.waitFor` (see
  `references/running-debugging.md`).
- **Not an unbounded loop** — runs are bounded by budgets (default and
  per-agent); bug bash is bounded by persona caps and per-persona
  `--max-steps`/`--timeout`. There is no "keep going until it passes" mode:
  every re-run is a counted attempt.
- **Not a credentials store** — it is not a place to paste tokens, API keys,
  or passwords; only opaque `Secret` handles belong in tests.
- **Not a model registry** — model ids for the actor and the judge come from
  environment variables (`references/setup.md`); nothing in a tracked file
  names a provider or model.

# Exit codes

`npx e2e run` propagates:

| Code | Meaning |
|---|---|
| 0 | all runs green (verified against `.e2e/report.json`, not assumed) |
| 1 | one or more journeys failed |
| 2 | configuration error (bad config, unreadable env) |
| 3 | budget exceeded (model calls / actions / timeout) |
| 4 | environment failure (app launch, target unreachable) |
| 130 | interrupted (SIGINT) |

Read `.e2e/failures/` and `.e2e/report.json` after **every** run — ground
truth first, verdict second. Details in `references/running-debugging.md`.
