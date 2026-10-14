# Running and debugging E2E runs

## Run one file at a time

Debugging means small blast radius. Run a single journey file, by absolute
path when possible, instead of the whole suite:

```bash
npx e2e run tests/login.e2e.ts
```

(`npx e2e run tests/<file>` is the shape; omit the path only when you intend
to run everything.) Re-runs are counted attempts under the remediation
budget — see `docs/SPEC_PIPELINE.md §Remediation budget` in this repo.

## Read the failures artifacts first

After every run — pass or fail — read the ground truth before judging the
result:

- `.e2e/failures/` — per-failure captures (final state, judge reasoning,
  traces). Open these before touching the test.
- `.e2e/report.json` — machine-readable run report: which journeys ran, which
  failed, budget consumption per run. Exit code plus these two artifacts are
  the verdict; a terminal's colored "done" line is not.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | green — verified against `.e2e/report.json` |
| 1 | one or more journeys failed |
| 2 | configuration error (bad config, missing model environment variables) |
| 3 | budget exceeded (model calls / actions / timeout hit) |
| 4 | environment failure (app launch failed, target unreachable) |
| 130 | interrupted (SIGINT) — a partial run, never a pass |

## Budgets — the inner bound

Every run is bounded by budgets: a **default** budget in `e2e.config.ts` and
an optional **per-agent** override (actor vs judge can carry different caps).
The dimensions are model calls, actions, and timeout. Budget exhaustion exits
3; it is a bound working as designed, not a flake to be raised and retried.
When a budget trips, shrink the journey or split it — the fix is the test,
not the number.

## The never-sleep rule

Never sleep to wait for the app. Fixed sleeps are forbidden in this standard —
they are the slowest way to be the least reliable. Wait for the observable
condition instead:

```ts
await agent.waitFor("the confirmation banner is visible");
```

## Replay cache modes

The replay cache reuses prior model decisions against unchanged app states, so
reruns get fast and deterministic. Configure one of three modes:

| Mode | Behavior | Use |
|---|---|---|
| `read-write` | reuse prior decisions, record new ones | local development (default posture) |
| `read-only` | reuse prior decisions only; a miss is a failure | CI — see the ci reference |
| `off` | no reuse; every decision is fresh | investigating cache-induced drift |

Add `--strict-cache` when a cache miss must fail the run loudly instead of
degrading silently:

```bash
npx e2e run --cache read-only --strict-cache
```
