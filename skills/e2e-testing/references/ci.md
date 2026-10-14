# CI wiring

Agentic E2E in CI is stricter than local by design: CI must be deterministic,
bounded, and reviewable from artifacts alone.

## The differences that matter

| Setting | Local | CI | Why |
|---|---|---|---|
| Workers | `cores/2` | 1 | shared runners thrash under parallel model-backed workers; 1 in CI keeps runs deterministic |
| Retries | 0 | 1 | local reruns are counted attempts by a human; CI tolerates exactly one infra flake (absorbs runner contention; a real failure still needs two consecutive fails) |
| Replay cache | `read-write` | `read-only` + `--strict-cache` | CI may reuse recorded decisions but must never silently re-decide — a cache miss in CI is a signal, not a refresh |
| `test.only` | allowed for debugging | rejected | a focused-only suite would report green while skipping the rest — CI fails the run with the `ONLY_IN_CI` marker |

The CI job overrides the local config for these values (single-worker,
replay cache in `read-only` mode, cache misses failing loudly via
`--strict-cache`), e.g.:

```bash
npx e2e run --strict-cache
```

with the CI config override setting workers to 1, retries to 1, and the
replay cache mode to `read-only`.

## GitHub Actions

Minimal shape (adjust checkout/setup to the repo's node version policy — Node
24.8+ or 22.22.3+):

```yaml
name: e2e
on:
  pull_request:

jobs:
  e2e:
    runs-on: ubuntu-latest
    env:
      E2E_TELEMETRY_DISABLED: "1"
      E2E_AGENT_MODEL: "${{ secrets.E2E_AGENT_MODEL }}"
      E2E_JUDGE_MODEL: "${{ secrets.E2E_JUDGE_MODEL }}"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "24"
      - run: npm ci
      # CI config override sets workers=1, retries=1, cache=read-only;
      # --strict-cache makes a replay-cache miss fail the run.
      - run: npx e2e run --strict-cache
      - name: Upload e2e artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: e2e-report
          path: |
            .e2e/report.json
            junit.xml
```

Notes on the snippet:

- Model ids arrive as **secrets/vars** — never commit a provider or model id;
  the job would fail this repo's model-wiring gate anyway.
- `if: always()` on the artifact upload — the report is most valuable on the
  runs that failed.
- Artifacts are `.e2e/report.json` (machine-readable run report) and
  `junit.xml` (for PR-comment and test-report tooling) — upload both.
- A `test.only` left in a committed journey makes the CI run exit with the
  `ONLY_IN_CI` failure marker — the local debugging escape hatch is rejected
  in CI on purpose.

## Cadence

Follow `docs/CI_CD.md` in the consuming repo for scheduling (per-push vs
weekly); this reference defines the how, that one defines the when.
