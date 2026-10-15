# Angular — Patterns

Deep material for the Angular stack; the entry point with always-rules
and commands is `SKILL.md` in this directory. Repo-wide design rules
(KISS/DRY/SOLID, cyclomatic complexity ≤6) live in
[`docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md) and
are not restated here. All claims below cite the official docs at
https://angular.dev/ (CC-BY 4.0 — paraphrased, not copied).

## Version Reality

- Current stable is **v22** (`^22.0.0`, released 2026-06-03). v21 and
  v20 are LTS; **v2–v19 are unsupported** — do not start or maintain
  projects on them (see https://angular.dev/reference/releases).
- Since v22 the cadence is **one major every 12 months** with 4–6
  minors; support per major is 24 months (12 active + 12 LTS). Before
  v22 it was a 6-month major cycle
  (see https://angular.dev/reference/releases).
- Update with `ng update`, **one major version at a time**
  (see https://angular.dev/update).
- v22 stabilized Signal Forms, async signals (`resource`), and Angular
  Aria (see https://angular.dev/events/v22).

## Signals (and Why Not the NgModule-Era Patterns)

Signals are the framework's reactivity foundation: they granularly
track where state is read so Angular can optimize rendering
(see https://angular.dev/guide/signals). The pre-signals toolkit —
`NgModule` wiring, ZoneJS-driven change detection, `BehaviorSubject`
state services, `*ngIf` structural directives — is superseded:

- **Writable**: `const count = signal(0)`; read by calling `count()`,
  write with `.set(v)` or `.update(v => v + 1)`. Expose read-only
  state with `.asReadonly()` — but note readonly does not prevent deep
  mutation of the value (see https://angular.dev/guide/signals).
- **Derived**: `computed(() => count() * 2)` — lazy, memoized, and
  dependencies are tracked dynamically (only signals actually read
  during derivation count).
- **Side effects**: `effect()` / `afterRenderEffect()` exist for
  bridging to non-reactive APIs only; prefer derivations
  (see https://angular.dev/guide/signals/effect — linked from the
  signals overview).
- **Untracked reads**: wrap incidental reads in `untracked()` so they
  don't become dependencies.
- **Async pitfall**: the reactive context is synchronous only — signal
  reads after `await` are not tracked. Read signals before the `await`
  (see https://angular.dev/guide/signals).
- **Dependent writable state**: `linkedSignal`
  (see https://angular.dev/guide/signals/linked-signal). **Async
  data**: `resource` (see https://angular.dev/guide/signals/resource).
- **RxJS interop** stays supported via `toSignal`/`toObservable`
  (see https://angular.dev/ecosystem/rxjs-interop).
- Custom equality: `signal(value, {equal: fn})`; default is
  `Object.is` referential equality.

State pattern: a `@Service()` holds private writable signals, exposes
`asReadonly()` copies, and mutates through intent methods — the
counter-service shape shown in the signals guide.

## Standalone Components (the Default)

- Components are standalone by default; consumers add them to the
  `@Component` `imports` array directly. `standalone: false` is a
  legacy marker (and was the default only before v19)
  (see https://angular.dev/guide/components).
- A component = class + template + CSS selector; template/styles are
  inline (`template`, `styles`) or side files (`templateUrl`,
  `styleUrl`), both relative to the component directory.
- **Signal-based member APIs**: `input()` / `input.required()`,
  `output()`, `model()` for two-way binding, and signal queries like
  `viewChild` (see https://angular.dev/guide/components/inputs,
  https://angular.dev/guide/components/outputs,
  https://angular.dev/guide/components/queries). Mark them `readonly`;
  keep template-only members `protected`
  (see https://angular.dev/style-guide).
- Lifecycle: use the hook interfaces (`implements OnInit`), and keep
  hook bodies thin — delegate to well-named methods
  (see https://angular.dev/guide/components/lifecycle,
  https://angular.dev/style-guide).
- NgModules remain documented under "Extended Ecosystem" purely for
  legacy apps (see https://angular.dev/guide/ngmodules/overview).

## Built-in Control Flow (`@if` / `@for` / `@switch`)

Replaces legacy `*ngIf` / `*ngFor` / `*ngSwitch`
(see https://angular.dev/guide/templates/control-flow):

- `@if (cond) { … } @else if (…) { … } @else { … }`; capture the
  condition result with `@if (expr; as alias)`.
- `@for (item of items; track item.id) { … } @empty { … }`:
  - **`track` is mandatory in practice** — track a unique id
    (`id`/`uuid`); `$index` only for static collections; tracking by
    item reference is a documented performance anti-pattern.
  - `@for` prioritizes view reuse (unlike `*ngFor`): same reference +
    changed property updates bindings instead of recreating DOM.
  - Context vars: `$count`, `$index`, `$first`, `$last`, `$even`,
    `$odd`, aliasable via `let`.
- `@switch` compares with `===`, no fallthrough; `@default never;`
  enables compile-time exhaustiveness checking on union types. Type
  narrowing needs a variable — assign a signal to a `@let` first
  (`@switch (state())` won't narrow).
- Also available: `@defer` for deferred blocks
  (see https://angular.dev/guide/templates/defer) and `@boundary`
  error boundaries (see https://angular.dev/guide/templates/error-boundaries).
- Style guide: prefer `[class.x]` / `[style.y]` bindings over
  `NgClass` / `NgStyle` (performance + readability)
  (see https://angular.dev/style-guide).

## Dependency Injection: `inject()` over Constructor Injection

- The style guide explicitly prefers the `inject()` function over
  constructor parameter injection: more readable with many
  dependencies, better type inference, plays well with
  `useDefineForClassFields`; an automatic migration exists
  (see https://angular.dev/style-guide,
  https://angular.dev/reference/migrations/inject-function).
- `@Service()` is shorthand for `@Injectable({providedIn: 'root'})` —
  a tree-shakable app-wide singleton, the recommended shape for most
  services (see https://angular.dev/guide/di).
- `inject()` works in field initializers, constructor bodies, and any
  **injection context** — including functional route guards and
  `runInInjectionContext` (see https://angular.dev/guide/di,
  https://angular.dev/guide/di/dependency-injection-context). It must
  be called synchronously — never after `await`.
- Injector hierarchy (element → component → route → environment)
  decides which provider wins; scope services with
  `providers: [...]` on components/routes when you need per-feature
  state (see https://angular.dev/guide/di/hierarchical-dependency-injection —
  linked from the DI guide sidebar).
- This maps onto the repo's layered architecture
  ([`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md)): components
  stay presentational, `@Service()` classes hold business logic, data
  access goes through `HttpClient`.

## Change Detection: OnPush Default, Zoneless Default

- **Zoneless is the default since v21** — nothing to enable. Do not
  call `provideZoneChangeDetection`; remove `zone.js` from `polyfills`
  and from dependencies in zoneless apps
  (see https://angular.dev/guide/zoneless).
- **`OnPush` is the default strategy since v22.** Change detection runs
  for a subtree when inputs change (compared with `Object.is`), an
  event handler in it runs, or `markForCheck` fires (signals read in
  templates and `AsyncPipe` mark automatically)
  (see https://angular.dev/best-practices/skipping-subtrees,
  https://angular.dev/guide/components/advanced-configuration).
- Zoneless compatibility rules (see https://angular.dev/guide/zoneless):
  - Notify via signals, `markForCheck`, `ComponentRef.setInput`, or
    bound listeners — mutating a plain object reference triggers
    nothing.
  - `NgZone.onStable` / `onMicrotaskEmpty` never emit in zoneless apps;
    use `afterNextRender` / `afterEveryRender` or `MutationObserver`.
  - SSR serialization waits on the `PendingTasks` service; wrap async
    work that must land in the rendered page with `taskService.run(...)`.
  - Reactive-forms model updates (`setValue`, `patchValue`) do not
    schedule change detection by themselves — connect `valueChanges`
    to `markForCheck()` or mirror into signals.
  - Debug aid: `provideCheckNoChangesConfig({exhaustive: true})`
    throws when a binding updates without a notification.

## Forms

Three documented approaches (see https://angular.dev/guide/forms):

| Approach | When |
|---|---|
| **Signal Forms** (stable in v22, requires v21+) | New signal-based apps — type-safe, schema validation, automatic two-way binding |
| **Reactive forms** | Existing apps already on `FormGroup`; synchronous, immutable, testable without DOM |
| **Template-driven** | Simple forms only (signup boxes); async data flow, harder to test |

- Signal Forms live in `@angular/forms/signals`:
  `import {form, FormField, required, email} from '@angular/forms/signals'`,
  with the `FormField` directive in the component `imports`
  (see https://angular.dev/guide/forms/signals/overview). The docs'
  own guidance: Signal Forms suit new signal-built apps; reactive
  forms remain a solid choice for existing apps. Comparison:
  https://angular.dev/guide/forms/signals/comparison.
- Reactive forms: build the model in the class (`FormGroup` /
  `FormControl` from `ReactiveFormsModule`), bind with
  `[formControl]`; the form model is the source of truth; data flow is
  synchronous; validators are plain functions
  (see https://angular.dev/guide/forms/reactive-forms,
  https://angular.dev/guide/forms).

## Routing & Lazy Loading

- Provide the router with `provideRouter(routes)` in `app.config.ts`;
  routes are a `Routes` array (see https://angular.dev/guide/routing,
  https://angular.dev/guide/routing/define-routes).
- **Lazy loading**: `loadComponent: () => import('./feature/page')`
  for components, `loadChildren: () => import('./feature/routes')`
  for child route trees. Loaders run inside the route's injection
  context, so `inject()` works inside them
  (see https://angular.dev/guide/routing/loading-strategies).
- Official guidance: eagerly load primary landing pages, lazy-load the
  rest; avoid deeply nested multi-level lazy loading (waterfall of
  chunk requests) (see https://angular.dev/guide/routing/loading-strategies).
- Guards are functional (`canActivate: () => inject(Auth).check()` —
  the guard-injection-context example is in the DI guide); see
  https://angular.dev/guide/routing/route-guards. For route data, the
  docs now offer resource-based fetching alongside classic resolvers
  (see https://angular.dev/guide/routing/data-fetching-with-resources).

## HTTP Client

- `provideHttpClient()` at bootstrap; inject `HttpClient` into
  services. Methods (`get`, `post`, …) return RxJS `Observables` —
  each subscription fires a new request
  (see https://angular.dev/guide/http,
  https://angular.dev/guide/http/making-requests).
- **The generic type is an assertion, not validation** — `HttpClient`
  does not verify the response shape (docs mark this CRITICAL). Treat
  boundaries per [`docs/SECURITY.md`](../../docs/SECURITY.md);
  validate untrusted payloads at the service boundary.
- Typed request/response, interceptors (functional style), and
  testing utilities are first-class
  (see https://angular.dev/guide/http/interceptors).
- Under SSR, `GET`/`HEAD` responses are transfer-cached into the
  initial HTML and reused during hydration (auth/cookie requests and
  `no-store` responses excluded); server response bodies are capped at
  1 MB by default (`maxResponseBodySize`)
  (see https://angular.dev/guide/ssr).

## SSR / Hybrid Rendering & Hydration

- Apps ship CSR by default; hybrid rendering mixes **Server (SSR)**,
  **Client (CSR)**, and **Prerender (SSG)** per route. New projects:
  `ng new --ssr`; existing: `ng add @angular/ssr`. By default the
  whole app is prerendered plus a server file is generated;
  `outputMode: "static"` in `angular.json` produces a fully static
  site (see https://angular.dev/guide/ssr).
- Declare render modes in `app.routes.server.ts` as a `ServerRoute[]`
  (`RenderMode.Server` / `.Client` / `.Prerender`) and wire with
  `provideServerRendering(withRoutes(serverRoutes))`. Prerendered
  parameterized routes enumerate paths via `getPrerenderParams`
  (build-time only; `inject()` allowed, no `await` before it).
  Fallback for non-prerendered paths: `PrerenderFallback.Server`
  (default) / `.Client` / `.None` (see https://angular.dev/guide/ssr).
- Node server: `AngularNodeAppEngine` from `@angular/ssr/node`
  (Express example in the guide); non-Node: `AngularAppEngine` with
  Web-standard `Request`/`Response` (see https://angular.dev/guide/ssr).
- **Server-compatible components**: no `window`/`document`/`navigator`
  globals — browser-only code goes in `afterNextRender` /
  `afterEveryRender`; inject the `DOCUMENT` token; request/response
  come from the `REQUEST` / `RESPONSE_INIT` / `REQUEST_CONTEXT` tokens
  (null during CSR/SSG/build). Prefer platform-specific provider
  overrides (`useClass` in `app.config.server.ts`) over
  `isPlatformBrowser` checks, and never branch on platform inside
  templates — hydration mismatch
  (see https://angular.dev/guide/ssr).
- Server-side `useValue` providers persist across requests — use
  `useFactory` for per-request values.
- Hydration: `provideClientHydration()` reuses server-rendered DOM;
  incremental hydration is documented at
  https://angular.dev/guide/hydration and
  https://angular.dev/guide/incremental-hydration.
- SSR security (SSRF, allowed hosts):
  https://angular.dev/best-practices/security.

## Style-Guide Distillate (Application Code)

From https://angular.dev/style-guide — the full guide is authoritative:

- kebab-case file names matching the TS identifier
  (`user-profile.ts` → `UserProfile`); same base name for
  `.ts`/`.html`/`.css`; `.spec.ts` beside the code under test.
- `src/` for all UI code; `main.ts` bootstraps; organize by feature
  area, not by code type; one concept per file; avoid `utils.ts` /
  `helpers.ts` catch-alls.
- Group injected deps, inputs, outputs, and queries at the top of the
  class, before methods; keep components presentational — extract
  validation rules and transformations.
- Name event handlers for what they do (`saveUserData()`, not
  `handleClick()`); complex template logic moves into `computed()`.
