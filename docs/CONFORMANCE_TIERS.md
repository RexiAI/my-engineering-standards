# Conformance Tiers

Not every rule in this repo applies to every project on day one. A solo MVP with no staging environment gains nothing from a weekly E2E-against-staging job, and forcing it produces either a rule that's silently ignored (which is how rules become wallpaper) or busywork that delays shipping. This document defines three tiers so a project can conform *fully* to a defined subset instead of *partially* to everything.

## The tiers

| Tier | Profile | Examples |
|---|---|---|
| `mvp` | Solo or small team, no staging environment, local or single-target deploy, one service | A project like this: no multi-service contracts to test, no on-call rotation to page, no dashboard budget |
| `production` | Deployed to a real environment with users, has a staging/prod split, may still be one service | Adds the operational rigor a live system needs regardless of team size |
| `multi-service` | Two or more services that talk to each other, or a team large enough that service boundaries matter | Adds cross-service contract and consistency guarantees that only matter once "the other side" is a different codebase |

Tiers are cumulative: `production` includes everything in `mvp`; `multi-service` includes everything in `production`.

## How to declare a tier

A project states its tier once, in its own `AGENTS_<PROJECT>.md` or equivalent project-specific instructions file:

```markdown
## Conformance tier: mvp
```

Every rule below that's tagged with a tier higher than the project's declared tier is **not a gap** — it's out of scope until the project graduates. A `production`-tier project that hasn't declared `multi-service` doesn't need to explain why it has no contract tests; the tier already says so.

## Tier assignments

Rules not listed here are `mvp` — the floor, not an exception.

| Rule | Tier | Where |
|---|---|---|
| Pact contract testing on every PR | `multi-service` | docs/CONTRACT_TESTING.md, docs/CI_CD.md §Contract Testing with Pact |
| Mutation testing (PiTest / Gremlins / Stryker) | `production` | docs/TESTING.md §Mutation Testing |
| Property testing (jqwik / testing/quick / fast-check) | `production` | docs/TESTING.md §Property Testing |
| ZAP DAST scan | `production` | docs/SECURITY.md §Vulnerability Scanning |
| Weekly E2E against a staging environment | `production` | docs/CI_CD.md §Weekly E2E Pipeline, docs/DEPLOYMENT.md |
| SonarQube/SonarCloud quality gate | `production` | docs/CI_CD.md, docs/DEPLOYMENT.md §Quality Gates |
| Saga/Outbox CI quality gates | `multi-service` | docs/SAGA_PATTERN.md, docs/OUTBOX_PATTERN.md — these patterns don't exist without a cross-service workflow to coordinate |
| Distributed tracing (OpenTelemetry, `traceparent` propagation) | `production` | docs/OBSERVABILITY.md — a single service still benefits from structured logging (`mvp`), but a trace only pays off once there's a second hop to correlate against |
| Full observability (9 required metrics, Grafana dashboards, SLOs, on-call paging) | `production` | docs/OBSERVABILITY.md |
| Circuit breaker + retry on every external client | `production` | docs/RESILIENCE.md — an `mvp` project should still time out (bare `http.Client{Timeout: ...}` is the `mvp` floor), but the breaker/backoff apparatus is `production` |
| Secrets manager (Vault/KMS/SSM) instead of `.env` | `production` | docs/SECURITY.md §Secrets Management — already tiered in the existing text ("small projects: `.env` files are fine") |
| Branch protection + mandatory reviewer approval | `production` | docs/GIT_WORKFLOW.md — an `mvp` solo project still uses branches and PRs (never push straight to `main`, see AGENTS.md), but "at least one reviewer approves" assumes a second person exists |

## What stays at `mvp` regardless of tier

These are never gated behind a higher tier — they're cheap enough, or risky enough, that "we'll add it later" is the wrong call at any size:

- Never commit secrets, credentials, or tokens (`.env` + `.gitignore` is the `mvp`-tier control, not an excuse to skip the control)
- Conventional commits, branch-per-change, PR before merge
- Unit tests for business logic
- Basic input validation at the boundary
- A `/health` endpoint
- Idempotent mutating endpoints (see docs/IDEMPOTENCY.md) — a retry storm doesn't care how big the team is

## Graduating

Moving from `mvp` to `production` (or `production` to `multi-service`) is itself worth an ADR (see `templates/ADR.md`): it's a real decision with real cost (new CI jobs, new infra, new on-call burden), not a checkbox. Update the tier declaration in the same PR that adds the first tier-gated capability.
