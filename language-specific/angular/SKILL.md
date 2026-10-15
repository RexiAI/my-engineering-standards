---
name: angular
description: Angular v22 standards — signals-first state, standalone components as the default, built-in control flow (@if/@for/@switch), inject() DI, OnPush + zoneless change detection, hybrid rendering (SSR/SSG), reactive & Signal Forms, Vitest testing; PATTERNS.md / TESTING.md pointers. Use whenever a child repo uses Angular (angular.json, ng serve/build/test, or @angular/* dependencies).
license: See repo root
applyTo: "**/angular.json, **/src/**/*.ts, **/src/**/*.html"
---

# Angular Standards

Entry point for the Angular stack. Repo-wide rules (conventional
commits, layered testing, secrets handling, cyclomatic complexity ≤6)
are inherited from the root `AGENTS.md` and
[`docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md) and
are not restated here.

## Project Shape

- **Version**: Angular v22 (`^22.0.0`, released 2026-06-03). As of v22
  the major release cycle is 12 months (previously 6), with a 24-month
  support window per major: 12 months active + 12 months LTS
  (see https://angular.dev/reference/releases). v21 and v20 are LTS;
  v2–v19 are unsupported.
- **Toolchain compatibility** for v22: Node.js `^22.22.3 || ^24.15.0
  || ^26.0.0`, TypeScript `>=6.0.0 <6.1.0`, RxJS `^6.5.3 || ^7.4.0`
  (see https://angular.dev/reference/versions).
- **Build system**: Angular CLI with the `application` build system
  (`@angular/build`), the default for new projects
  (see https://angular.dev/guide/testing/migrating-to-vitest).
- **Bootstrap**: standalone — `bootstrapApplication(App, {providers:
  [provideRouter(...), provideHttpClient(), ...]})`. NgModules are
  legacy; new apps do not create them
  (see https://angular.dev/guide/components).
- **Change detection**: zoneless is the default since v21
  (see https://angular.dev/guide/zoneless) and `OnPush` is the default
  strategy since v22
  (see https://angular.dev/best-practices/skipping-subtrees).
- **Language**: TypeScript `strict: true`, extending the house TS
  conventions in
  [`docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md).
- **Docs home**: https://angular.dev/ (current stable); pre-release
  docs live at https://next.angular.dev
  (see https://angular.dev/reference/releases).

## Commands

| Command | What it does |
|---|---|
| `ng serve` | Dev server with watch mode |
| `ng build` | Production build |
| `ng test` | Unit/component tests — Vitest in watch mode (see https://angular.dev/guide/testing) |
| `ng test --no-watch --no-progress` | Single-run tests for CI (auto-detected when `CI=true`) |
| `ng test --coverage` | Coverage report into `coverage/` |
| `ng generate component <name>` | Scaffold component + template + styles + `.spec.ts` |
| `ng add @angular/ssr` | Add hybrid rendering (SSR/prerender) to an existing project |
| `ng update @angular/cli @angular/core` | Update — one major version at a time (see https://angular.dev/update) |

## Project Structure

Per the official style guide (https://angular.dev/style-guide): all UI
code in `src/`, grouped by **feature area** (never by code type — no
`components/`, `services/`, `directives/` directories), one concept per
file, tests next to the code under test.

```
├── angular.json               # CLI workspace config (build/test targets)
├── tsconfig.json              # Strict TS config
└── src/
    ├── main.ts                # Bootstrap entry (style guide: main.ts directly in src/)
    ├── index.html
    ├── styles.css
    └── app/
        ├── app.ts             # Root component (kebab-case file, class name matches)
        ├── app.config.ts      # provideRouter / provideHttpClient / provideClientHydration
        ├── app.routes.ts      # Route table (lazy loadComponent / loadChildren)
        ├── app.routes.server.ts   # Per-route RenderMode (SSR projects only)
        ├── app.config.server.ts   # Server providers (SSR projects only)
        └── checkout/          # Feature area, not a type folder
            ├── checkout-page.ts
            ├── checkout-page.html
            ├── checkout-page.css
            ├── checkout-page.spec.ts   # Test lives beside code-under-test
            └── cart.service.ts         # @Service() business logic
```

## Always-Rules

- **Standalone components are the default.** Components are standalone
  by default; import dependencies in the `@Component` `imports` array.
  Do not create new NgModules — the NgModule guide is now filed under
  "Extended Ecosystem" for legacy apps
  (see https://angular.dev/guide/components).
- **Signals first for state.** `signal()` / `computed()` / `effect()`
  are the reactive foundation; component inputs/outputs use the
  signal-based `input()` / `output()` / `model()` APIs
  (see https://angular.dev/guide/signals).
- **Use the built-in control flow.** `@if` / `@for` / `@switch` in new
  templates; never write new `*ngIf` / `*ngFor` / `*ngSwitch`. `@for`
  requires a `track` expression on a unique id
  (see https://angular.dev/guide/templates/control-flow).
- **Prefer `inject()` over constructor parameter injection** — the
  official style-guide recommendation
  (see https://angular.dev/style-guide).
- **Keep zoneless and OnPush.** Do not re-add
  `provideZoneChangeDetection` or opt components into `Eager`/`Default`
  change detection without a documented reason; notify via signals,
  `markForCheck`, or `AsyncPipe`
  (see https://angular.dev/guide/zoneless).
- **Style-guide naming.** kebab-case file names matching the class
  (`user-profile.ts` → `UserProfile`), `.spec.ts` for tests,
  `readonly` on `input()`/`output()`/`model()`/query properties,
  `protected` for template-only members
  (see https://angular.dev/style-guide).
- **Forms**: Signal Forms (stable in v22) or reactive forms for
  anything non-trivial; template-driven only for simple cases
  (see https://angular.dev/guide/forms, https://angular.dev/events/v22).
- **Vitest is the test runner.** It is the CLI default for new
  projects; do not start new projects on Karma/Jasmine
  (see https://angular.dev/guide/testing). Details in
  [`TESTING.md`](./TESTING.md).
- **HTTP through `HttpClient`** with `provideHttpClient()`; the generic
  type argument is an assertion, not runtime validation
  (see https://angular.dev/guide/http/making-requests).
- **Server-safe code under hybrid rendering.** Browser-only work goes
  in `afterNextRender`/`afterEveryRender`; use the `DOCUMENT` token,
  not global `document`; no `isPlatformBrowser` branching in templates
  (hydration mismatch) (see https://angular.dev/guide/ssr).
- **Secrets and security**: root `AGENTS.md` rules apply; see
  [`docs/SECURITY.md`](../../docs/SECURITY.md) and
  https://angular.dev/best-practices/security (XSS, SSRF, transfer
  cache header leakage).
- **Layering**: components → services → `HttpClient` mirrors the
  controller → service → repository rule in root `AGENTS.md` and
  [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md). Business logic
  lives in `@Service()` classes, never in components or templates
  (see https://angular.dev/style-guide §Keep components focused on
  presentation).

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — signals, standalone components,
   control flow, DI, change detection, forms, routing, HTTP, SSR.
2. [`TESTING.md`](./TESTING.md) — Vitest runner, TestBed component
   tests, service tests, harnesses, coverage, CI, E2E (inherits the
   layered strategy from [`docs/TESTING.md`](../../docs/TESTING.md)).
3. [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) — layered
   architecture as it maps onto Angular.
4. [`docs/SECURITY.md`](../../docs/SECURITY.md) — repo-wide security
   rules that apply to Angular services and config loading.

## Adoption

Child repos opt in by adding `language-specific/angular/SKILL.md` to
their `opencode.json` `instructions` array, alongside any other
language-specific guides they use.

**CI already exists — do not write a new one.** `ci/gitlab/frontend/ci-angular.yml`
ships `.angular-unit`, `.angular-lint`, `.angular-build` and `.angular-docker`
on Node 22 with `npm ci`. It is deliberately runner-agnostic: `.angular-unit`
runs `npm run test:ci --if-present || npm test`. Satisfy the Vitest mandate
above by wiring the child repo's `test:ci` script to
`ng test --no-watch --no-progress` — `ng test` auto-detects `CI=true` and drops
into single-run mode, and the explicit flags are the documented fallback
(https://angular.dev/guide/testing). Include the file from the child's
`.gitlab-ci.yml` and extend the hidden jobs; there is no `child-ci-angular.yml`
template yet.
