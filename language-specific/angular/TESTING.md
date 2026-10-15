# Angular — Testing

Testing guide for the Angular stack. The layered test strategy
(unit / integration / component / E2E) and what each layer proves is
defined in [`docs/TESTING.md`](../../docs/TESTING.md) and inherited
here — this file covers the *runner*, the *Angular-specific APIs*, and
*what each layer looks like in an Angular repo*. Official reference:
https://angular.dev/guide/testing (CC-BY 4.0 — paraphrased).

## Runner: Vitest (Not Karma, Not Jest)

The official docs are explicit: **new Angular CLI projects use Vitest**
as the default unit test runner, with the `@angular/build:unit-test`
builder and `jsdom` for DOM emulation in Node.js (see
https://angular.dev/guide/testing). Do not assume Jest — the Angular
docs do not recommend it; and Karma/Jasmine is the *legacy* setup,
still supported but only relevant when migrating (see
https://angular.dev/guide/testing/migrating-to-vitest — the migration
is flagged experimental and requires the `application` build system).

| Concern | v22 reality | Source |
|---|---|---|
| Default runner (new projects) | Vitest + jsdom; `happy-dom` auto-detected if installed | https://angular.dev/guide/testing |
| Command | `ng test` (watch mode); CI single-run via `CI=true` or `--no-watch --no-progress` | https://angular.dev/guide/testing |
| Builder | `@angular/build:unit-test` in `angular.json` | https://angular.dev/guide/testing |
| Real-browser mode | Optional: Playwright (`@vitest/browser-playwright`) or WebdriverIO providers, `ng test --browsers=chromium` | https://angular.dev/guide/testing |
| Coverage | `ng test --coverage` → `coverage/` | https://angular.dev/guide/testing/code-coverage |
| Custom config | `runnerConfig` option; scaffold with `ng generate config vitest` (CLI overrides `test.projects`/`test.include`) | https://angular.dev/guide/testing |
| Global test providers | `providersFile` option (e.g. `provideHttpClientTesting()` for all tests) | https://angular.dev/guide/testing |

## Layer Mapping

| Layer | Tooling | Scope |
|---|---|---|
| Unit | Vitest via `ng test` | Services, pipes, pure functions, signal logic — no DOM |
| Component | Vitest + `TestBed` (jsdom) | Template + class together: rendering, inputs/outputs, events |
| Component (interaction) | Component harnesses | Robust UI interaction that survives markup changes |
| E2E | Playwright — house standard | Full flows against a running build (see below) |

- Test files are `.spec.ts` **next to the code under test** — not in a
  central `tests/` directory (see https://angular.dev/style-guide).
- E2E: the Angular testing docs cover unit/component layers and do not
  prescribe an E2E tool. This repo's standard for TS/Node web stacks
  applies: Playwright / agentic E2E per
  [`docs/TESTING.md`](../../docs/TESTING.md) §Agentic E2E and
  `skills/e2e-testing/SKILL.md` at the repo root.

## Service Tests (Unit)

`TestBed.inject()` resolves the service through DI; substitute
collaborators with test doubles when they hit the network or carry
complex state (see https://angular.dev/guide/testing/services):

```ts
import {TestBed} from '@angular/core/testing';
import {TaxCalculator} from './tax-calculator';

describe('TaxCalculator', () => {
  let service: TaxCalculator;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(TaxCalculator); // @Service() resolves without extra providers
  });

  it('adds tax', () => {
    expect(service.withTax(100)).toBe(121);
  });
});
```

Override dependencies with `TestBed.configureTestingModule({providers:
[{provide: Dep, useValue: fake}]})`. For HTTP-boundary tests use
`provideHttpClientTesting()` — the testing overview shows wiring it
globally through the `providersFile` option (see
https://angular.dev/guide/testing).

## Component Tests (TestBed)

The CLI generates this skeleton with every `ng generate component`
(see https://angular.dev/guide/testing/components-basics):

```ts
import {ComponentFixture, TestBed} from '@angular/core/testing';
import {Banner} from './banner';

describe('Banner', () => {
  let fixture: ComponentFixture<Banner>;

  beforeEach(async () => {
    TestBed.configureTestingModule({});
    fixture = TestBed.createComponent(Banner);
    await fixture.whenStable();
  });

  it('renders the title', () => {
    expect(fixture.nativeElement.textContent).toContain('Hello');
  });
});
```

Rules that fall out of the docs:

- **Do not re-configure `TestBed` after `createComponent()`** — the
  definition freezes (see https://angular.dev/guide/testing/components-basics).
- **Prefer `await fixture.whenStable()` over `fixture.detectChanges()`.**
  `TestBed` is zoneless by default (even when `zone.js` is loaded), and
  forcing `detectChanges()` hides missing change notifications that
  would break the real zoneless app. `TestBed` throws
  `ExpressionChangedAfterItHasBeenCheckedError` when a template value
  changed without a notification — fix the component (signals /
  `markForCheck`), not the test (see https://angular.dev/guide/zoneless).
- `TestBed.compileComponents()` is only required for components with
  `@defer` blocks (see https://angular.dev/guide/testing/components-basics).
- Query the DOM (`fixture.nativeElement`) and dispatch real events;
  scenario patterns (input/output binding, async, routing) are in
  https://angular.dev/guide/testing/components-scenarios.
- **Harnesses**: for reusable, implementation-agnostic interaction
  tests (especially over Angular Material components) use component
  harnesses (see https://angular.dev/guide/testing/using-component-harnesses).

## Forms Tests

- **Reactive forms** test synchronously through the `FormControl`
  model without rendering UI — set/query values directly on the
  control (see https://angular.dev/guide/forms §Testing).
- **Template-driven forms** require the async path: dispatch input
  events, then `await fixture.whenStable()` before asserting
  (see https://angular.dev/guide/forms).
- **Signal Forms** have a dedicated testing guide:
  https://angular.dev/guide/forms/signals/testing.

## Signals Tests

Signals are synchronous: read with `()`, write with `.set()`/
`.update()`, assert derived `computed()` values directly — no fixture
needed for pure signal/computed logic (see
https://angular.dev/guide/signals). `effect()` callbacks only run in a
reactive context (component rendering, `computed`, other effects); for
components, drive state changes through the fixture and settle with
`await fixture.whenStable()` as above.

## CI

- CI servers setting `CI=true` get non-interactive single-run mode
  automatically; otherwise pass `ng test --no-watch --no-progress`
  (see https://angular.dev/guide/testing).
- Coverage gating: `ng test --coverage`, thresholds per
  https://angular.dev/guide/testing/code-coverage. Conformance-tier
  cadence (which layers run per PR vs weekly) is defined in
  [`docs/TESTING.md`](../../docs/TESTING.md) and
  [`docs/CONFORMANCE_TIERS.md`](../../docs/CONFORMANCE_TIERS.md).
- Browser-mode tests run headed by default and headless when `CI` is
  set (see https://angular.dev/guide/testing).

## E2E

E2E runs the built app (`ng build` output or `ng serve`) and drives a
real browser. Per [`docs/TESTING.md`](../../docs/TESTING.md): E2E
verifies full user flows — auth, navigation, form submission against
real (or Dockerized-stub) backends — and stays out of the per-PR fast
loop unless the conformance tier says otherwise. Use the Playwright
stack from `skills/e2e-testing/SKILL.md` (repo root). Vitest browser
mode (`ng test --browsers=chromium`) is for DOM-fidelity *unit/component*
tests, not a replacement for E2E (see https://angular.dev/guide/testing).

## Further Reading

- Layer definitions & cadence: [`docs/TESTING.md`](../../docs/TESTING.md)
- Official testing guide index: https://angular.dev/guide/testing
- Debugging failing tests: https://angular.dev/guide/testing/debugging
- Karma → Vitest migration: https://angular.dev/guide/testing/migrating-to-vitest
