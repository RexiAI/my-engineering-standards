---
name: ionic
description: Ionic Framework (v9) standards for Ionic + Angular apps — standalone components, Angular Router with ion-router-outlet, Ionic page lifecycle hooks (ionViewWillEnter/DidEnter), CSS-variable theming with ios/md adaptive modes, Capacitor for native, storage-and-secrets rules. Use whenever a child repo contains ionic.config.json or capacitor.config.*, imports @ionic/angular, or asks about ion-* components, Ionic pages/navigation, Capacitor sync/run/build, or shipping a web-first mobile app or PWA. Deep material lives in PATTERNS.md / NATIVE.md / TESTING.md.
license: See repo root
applyTo: "**/ionic.config.json, **/capacitor.config.*, **/src/**/*.ts"
---

# Ionic Standards

This is the entry point for the Ionic stack (primary binding in scope: **Ionic + Angular**). Repo-wide rules (conventional commits, layered testing, secrets handling, cyclomatic ≤6) are inherited from the root `AGENTS.md` and [`../../docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md) and are not restated here.

Ionic Framework is an open-source UI toolkit built on web standards — Web Components and Shadow DOM — which is why it is framework-agnostic. Official bindings are `@ionic/angular`, `@ionic/react`, `@ionic/vue`, plus a standalone script/CDN include (https://ionicframework.com/docs). Apps deploy natively through Capacitor (Cordova is legacy) or run in the browser as a PWA (same page). The UI toolkit is MIT-licensed; the documentation content (`ionic-team/ionic-docs`) is Apache 2.0 (same page) — this guide paraphrases and links, it does not copy.

Ionic + Angular projects read **both** this guide and [`../angular/SKILL.md`](../angular/SKILL.md). Angular-level rules (DI, signals, change detection, framework-wide testing) live there; Ionic-specific rules live here.

## Project Shape

- **Scaffold**: Ionic CLI — `ionic start myApp tabs --type angular`; dev server via `ionic serve` (https://ionicframework.com/docs/intro/cli). Project marker file: `ionic.config.json`.
- **Component model**: Angular **standalone components** with per-component `Ion*` imports. The NgModule/`IonicModule` approach is deprecated and will be removed in a future major release (https://ionicframework.com/docs/angular/build-options).
- **Angular window**: Ionic Angular v9 supports Angular 18–22 (https://ionicframework.com/docs/angular/overview, policy at https://ionicframework.com/docs/reference/support#ionic-angular).
- **Routing**: Angular Router + `<ion-router-outlet>` + `IonicRouteStrategy`; app bootstrap calls `provideIonicAngular()` (https://ionicframework.com/docs/angular/build-options).
- **Native**: Capacitor is the official cross-platform runtime (https://ionicframework.com/docs/angular/overview). Cordova is legacy — no new projects on it. Details in [`NATIVE.md`](./NATIVE.md).
- **Web/PWA**: the same codebase runs in the browser as a Progressive Web App (https://ionicframework.com/docs).
- **Appflow** (cloud builds, live updates) is a commercial service, explicitly **separate from the open-source framework** — never required, never presented as the default path (https://ionicframework.com/docs).

### Ionic or React Native?

This repo also standardizes React Native ([`../react-native/SKILL.md`](../react-native/SKILL.md)). Both ship iOS/Android apps from one codebase; the choice is factual, not stylistic:

- **Ionic** — the team and existing codebase are web/Angular; the app is content-, form-, and list-centric; serving the mobile web as a PWA from the same codebase matters; UI rendered as web components inside a Capacitor native container is acceptable. Native device access comes through Capacitor plugins behind a unified TypeScript API (https://ionicframework.com/docs/native).
- **React Native** — the team is on React and the app needs real native UI components and their rendering characteristics (heavy continuous gestures/animations bound to native views, camera- or graphics-centric screens). RN renders platform-native components, not a web view.

A child repo picks one stack. Cross-stack reuse happens in shared TypeScript services/utilities, not in UI components.

## Always-Rules

- **Import from `@ionic/angular`, never `@ionic/angular/lazy`.** The lazy entry point pulls in lazily-loaded code that interferes with tree-shaking (https://ionicframework.com/docs/angular/build-options). Register icon SVG data with `addIcons()` from `ionicons`, recommended in the component constructor (same page).
- **Per-visit page work goes in Ionic page lifecycle hooks, not `ngOnInit`.** `<ion-router-outlet>` keeps visited pages in the DOM: `ngOnInit` fires once per page creation, while `ionViewWillEnter`/`ionViewDidEnter` fire on every navigation to the page, and `ngOnDestroy` only fires when the page is popped (https://ionicframework.com/docs/angular/lifecycle). Cleanup that must run when a page leaves view belongs in `ionViewWillLeave`. These hooks fire only on router-mapped components, not their children (same page).
- **Navigation is Angular Router.** `CanActivate`/`CanDeactivate` guards replace the removed `ionViewCanEnter`/`ionViewCanLeave` (https://ionicframework.com/docs/angular/lifecycle). Each tab is its own navigation stack — never route programmatically from one tab into another; present shared views as `ion-modal` or duplicate the route per tab (https://ionicframework.com/docs/angular/navigation).
- **Theme with Ionic CSS custom properties; do not hardcode colors.** The nine base colors each carry `shade`/`tint` variants; component internals are styled via CSS variables and CSS Shadow Parts (https://ionicframework.com/docs/theming/basics).
- **Adaptive styling is on by default.** `ios` and `md` modes drive platform look (`ios` on iOS, `md` on Android and everywhere else); mode-specific overrides go through `.ios`/`.md` selectors, and mode ≠ platform (https://ionicframework.com/docs/theming/platform-styles).
- **Capacitor Preferences is not a secrets store.** It maps to `UserDefaults` (iOS) / `SharedPreferences` (Android) — unencrypted, cleared on uninstall (https://capacitorjs.com/docs/apis/preferences). Tokens and credentials require Keychain/Keystore-backed storage; the official OSS docs ship no first-party secure-storage plugin — see [`NATIVE.md`](./NATIVE.md) §Storage & Secrets for the sanctioned options.
- **No runtime `process.env`.** Web-layer config uses Angular environment files with `fileReplacements` in `angular.json` (the mechanism is shown in https://ionicframework.com/docs/angular/testing §Configuration). Native-layer config lives in `capacitor.config.*`, committed without secrets (https://capacitorjs.com/docs/config). Root `AGENTS.md` secrets rules apply unchanged.
- **Sanitize untrusted HTML.** Ionic includes a basic sanitizer; custom-HTML parsing in overlay components (`ion-alert`, `ion-toast`, …) is disabled by default via `innerHTMLTemplatesEnabled` — keep it off unless there is a reviewed need, and never globally disable `sanitizerEnabled` without one (https://ionicframework.com/docs/techniques/security).
- **Change detection**: routed pages may use `OnPush` only when their state is signal-based or they call `markForCheck()`; components hosting `ion-router-outlet`/`ion-tabs` (and everything above them) must not silently block updates — Angular 22 makes `OnPush` the default (https://ionicframework.com/docs/angular/lifecycle §Angular Life Cycle Events note, https://ionicframework.com/docs/angular/zoneless).
- **Tests**: the runner is **Angular's**, not Ionic's — Angular v22 defaults new CLI projects to Vitest (https://angular.dev/guide/testing), and [`../angular/TESTING.md`](../angular/TESTING.md) owns that decision. From the official Ionic Angular testing guide (https://ionicframework.com/docs/angular/testing) take only the Ionic-specific parts: Angular `TestBed` with `provideIonicAngular()`, and the `componentOnReady` helper from `@ionic/core` before any DOM assertion. That page's Jasmine/`HttpClientTestingModule` examples predate Angular's current defaults — see [`TESTING.md`](./TESTING.md) §What Official Ionic Documentation Covers. The layered strategy itself is inherited from [`../../docs/TESTING.md`](../../docs/TESTING.md).

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — components, lifecycle, navigation/routing, theming, adaptive styles, gestures/animations, performance.
2. [`NATIVE.md`](./NATIVE.md) — Capacitor workflow, plugins, storage & secrets, publishing, Ionic vs React Native at the native layer.
3. [`TESTING.md`](./TESTING.md) — what the official Ionic docs actually cover for testing, what they don't, and where the rest defers to.

## Adoption

Child repos opt in by adding `language-specific/ionic/SKILL.md` to their `opencode.json` `instructions` array — for Ionic + Angular repos, alongside `language-specific/angular/SKILL.md` and any other guides they use.
