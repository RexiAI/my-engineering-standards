# Setup — e2e framework one-time wiring

Read this once per repo before writing the first agentic E2E test. Everything
here is setup; test-writing lives in the `writing-tests` reference.

## Initialize

```bash
npx e2e init
```

`init` scaffolds `e2e.config.ts` at the project root and the `tests/**/*.e2e.ts`
glob. Replace the generated config with the repo's governance shape — the
worked example in `../assets/e2e.config.example.ts` demonstrates every rule
(env-sourced models, port-0 app launch, budgets, cache mode, telemetry opt-out).

## Node version

The framework requires **Node 24.8+ or 22.22.3+** (LTS line). Older runtimes
fail at launch; pin the version in the repo's engines field and CI image.

## Model connectivity — environment variables only

The actor model and the judge model are read from **environment variables**;
the config never hardcodes a model or provider id (a tracked file naming a
model is a standard violation — see the repo's `docs/SPEC_PIPELINE.md §Model
configuration` indirection for the same principle):

```bash
export E2E_AGENT_MODEL="<actor model id from your provider config>"
export E2E_JUDGE_MODEL="<judge model id from your provider config>"
```

Per-machine values belong in the gitignored env layer (direnv `.envrc` chain),
never committed. Note the framework does **not** load `.env` files — variables
must be present in the launching shell environment.

Verify connectivity with one trivial journey before writing real tests:

```bash
npx e2e run tests/smoke.e2e.ts
```

If the run exits 2 (configuration error), check that both variables are
exported in the shell that launches `npx e2e`.

## Telemetry opt-out — mandatory

Repo policy runs the framework with telemetry disabled. Export it in the same
environment layer as the model variables:

```bash
export E2E_TELEMETRY_DISABLED=1
```

CI runners and local direnv environments both set it; a run without it is a
policy violation even if it passes.
