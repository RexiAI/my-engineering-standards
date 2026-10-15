# Ionic — Testing

Testing guide for the Ionic stack. The layered test strategy
(unit / acceptance / integration / e2e) and what each layer proves is
defined in [`../../docs/TESTING.md`](../../docs/TESTING.md) and inherited
here — this file covers what the official Ionic docs actually provide and
which tools apply to an Ionic + Angular repo.

## What Official Ionic Documentation Covers (Honest Assessment)

Unlike some stacks, Ionic **does** publish testing guidance, and it is
binding-specific:

- **Ionic Angular**: https://ionicframework.com/docs/angular/testing — a
  full page covering testing principles, unit testing with Jasmine
  (spies, `describe`/`it` structure), component/page tests with Angular
  `TestBed`, service and pipe tests, HTTP service tests with
  `HttpClientTestingModule`, and an end-to-end section.
- **Ionic React**: a testing section exists at
  https://ionicframework.com/docs/react/testing/introduction (seen in the
  docs sidebar and search results; not the binding this guide targets).
- **Ionic Vue**: https://ionicframework.com/docs/vue/testing exists in
  the docs sidebar. Out of scope here.

Two caveats, stated plainly:

1. The Angular page's **E2E section describes the Protractor-based
   scaffold** that older CLI-generated apps shipped (`protractor.conf.js`,
   page objects, `onCleanUp` config). Treat that section as historical
   structure guidance (page objects, dedicated e2e environment,
   data cleanup) — not as a current tool recommendation. E2E tooling for
   this repo is decided by [`../../docs/TESTING.md`](../../docs/TESTING.md)
   and [`../../skills/e2e-testing/SKILL.md`](../../skills/e2e-testing/SKILL.md).
2. There is **no framework-agnostic "Ionic testing" page** — guidance
   lives under each binding. For Ionic + Angular, the Angular toolchain
   (TestBed plus the Angular CLI test runner) is the test surface;
   Ionic-specific concerns are narrow and listed below.
3. **The Ionic Angular page predates Angular's current test defaults, so
   read its examples as structural, not as tool choices.** That page shows
   Jasmine-style `describe`/`it` with spies and `HttpClientTestingModule`.
   Angular v22's default runner for new CLI projects is **Vitest**
   (https://angular.dev/guide/testing), and the current HTTP testing API is
   `provideHttpClientTesting()` from `@angular/common/http/testing`
   (same page), not the NgModule-era `HttpClientTestingModule`. Adopt the
   Angular runner and APIs; take from the Ionic page only what is genuinely
   Ionic-specific — `componentOnReady`, page-lifecycle testing, and
   `provideIonicAngular()` in the TestBed setup.

Framework-level Angular testing standards (runner choice, coverage,
component harnesses, signals testing) are owned by
[`../angular/TESTING.md`](../angular/TESTING.md) — read it alongside this
file; nothing here overrides it. Where this file's description of the
upstream Ionic page and that file's mandated runner appear to disagree,
**`../angular/TESTING.md` wins.**

## Ionic-Specific Unit/Component Testing

### Wait for hydration with `componentOnReady`

Ionic components are lazy-loaded web components; asserting against the
DOM immediately after `detectChanges()` races hydration. The official
guide (https://ionicframework.com/docs/angular/testing §Waiting for
Components) requires the `componentOnReady` **helper exported from
`@ionic/core`** — not `el.componentOnReady()` directly, which throws on
custom-element builds used by standalone projects:

```ts
import { componentOnReady } from '@ionic/core';

it('renders the submit button', async () => {
  const button = fixture.nativeElement.querySelector('ion-button');
  await new Promise<void>((resolve) => componentOnReady(button, () => resolve()));
  expect(button.textContent).toContain('Submit');
});
```

Wait before any DOM assertion or accessibility check on an `ion-*`
element.

### Jest + standalone components

Ionic Angular standalone components ship as ES Modules; Jest needs them
transpiled. Official config from
https://ionicframework.com/docs/angular/build-options §Testing:

```json
"transformIgnorePatterns": ["<rootDir>/node_modules/(?!(@ionic/angular|@ionic/core|ionicons|@stencil/core|@angular/*)/)"]
```

(pnpm variant on the same page). Karma/Jasmine — the CLI-generated
default per https://ionicframework.com/docs/angular/testing — needs no
such transform.

### Mocking

Follow the official page's guidance
(https://ionicframework.com/docs/angular/testing §Using Mocks):

- Use your runner's spy API — under the mandated Vitest runner that is
  `vi.fn()` for from-scratch mocks and `vi.spyOn()` when a real object
  exists (it fails loudly on non-existent methods). The upstream Ionic page
  shows the Jasmine equivalents (`createSpyObj`, `spyOn()`); the concepts
  map 1:1, the import does not.
- Prefer `toHaveBeenCalledTimes(1)` over `toHaveBeenCalled()` for
  positive assertions; the reverse for negative ones.
- Services: instantiate directly with injected spy dependencies; pages
  and components are "just Angular components" — test them with standard
  `TestBed` component testing.
- HTTP: provide `provideHttpClientTesting()` from
  `@angular/common/http/testing` (https://angular.dev/guide/testing) —
  **not** the NgModule-era `HttpClientTestingModule` the upstream Ionic page
  still shows — then assert the request shape and drive the response. The
  request-interception pattern is Angular's, not Ionic's; follow
  https://angular.dev/guide/testing/services and
  [`../angular/TESTING.md`](../angular/TESTING.md).

### Capacitor plugins in unit tests

Capacitor plugin calls (`Preferences`, `Camera`, …) hit native bridges
that don't exist in a browser/Node test environment. The official Ionic
testing page does not cover this; wrap plugin access behind an injectable
service (repo architecture rule — services own I/O) and spy the service.
Web fallbacks exist for some plugins (e.g. Preferences falls back to
`localStorage` in a PWA context —
https://capacitorjs.com/docs/apis/preferences), but don't build tests
around the fallback: test your service, not the plugin.

## E2E Scope

Structure guidance that remains valid from the official page
(https://ionicframework.com/docs/angular/testing §End-to-end Testing):

- **Page objects** encapsulate per-page DOM access behind an API; a base
  page object holds shared wait/click/type helpers. Brittle selectors
  live in exactly one place.
- **Dedicated e2e environment**: a separate environment file
  (`environment.e2e.ts`) wired via `angular.json` `fileReplacements` and
  a `--configuration=test` e2e script, pointing at a test backend — never
  production data.
- **Data cleanup**: reset modified data to a known state after runs (the
  page shows a `purgeDatabase`-style endpoint called from test config).

The driver itself (browser automation vs agentic E2E vs device runs) and
CI wiring come from [`../../docs/TESTING.md`](../../docs/TESTING.md) and
[`../../skills/e2e-testing/SKILL.md`](../../skills/e2e-testing/SKILL.md).
For device-level E2E of the Capacitor binary, the official docs stop at
`npx cap run` / `npx cap build`
(https://capacitorjs.com/docs/basics/workflow) — no official Ionic/Capacitor
E2E device framework is published; choose per the repo E2E standard.

## Further Reading

- Layer definitions and gates: [`../../docs/TESTING.md`](../../docs/TESTING.md)
- Official Ionic Angular testing guide: https://ionicframework.com/docs/angular/testing
- Jest transform config: https://ionicframework.com/docs/angular/build-options
- Angular testing guide (referenced by the official Ionic page): https://angular.io/guide/testing
