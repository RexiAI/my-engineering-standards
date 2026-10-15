# Ionic — Patterns

Day-to-day app code patterns for Ionic + Angular. The entry point and
always-rules live in [`SKILL.md`](./SKILL.md); this file is the how. All
claims below cite the official docs they came from — the framework moves
fast (v9 at time of writing), so when a cited page disagrees with this
file, the cited page wins.

## Component Library Usage

- Ionic ships high-level building blocks — lists, cards, tabs, modals,
  toolbars, inputs, and more — catalogued at
  https://ionicframework.com/docs/components, with the per-component API
  reference at https://ionicframework.com/docs/api.
- **Standalone imports**: import each `Ion*` component used by a template
  from `@ionic/angular` and list it in the component's `imports` array;
  a missing import is a compiler error, which is the point
  (https://ionicframework.com/docs/angular/build-options).
- **Icons**: `IonIcon` renders by string name; register the SVG data with
  `addIcons({ logoIonic })` from `ionicons` — in the using component's
  constructor, or once in `app.component.ts` if the icon set is small
  (same page). Ionicons 7.2+ derives the string name from the import.
- **Overlays** (`ion-modal`, `ion-alert`, `ion-toast`, `ion-action-sheet`,
  `ion-popover`, `ion-loading`): in Angular these are presented
  imperatively via their controllers or declaratively in templates — see
  https://ionicframework.com/docs/angular/overlays. Their string
  properties accept plain text by default; custom HTML requires opting
  into `innerHTMLTemplatesEnabled` and sanitizing it yourself
  (https://ionicframework.com/docs/techniques/security).
- **Bootstrapping**: `provideIonicAngular()` plus
  `{ provide: RouteReuseStrategy, useClass: IonicRouteStrategy }` in
  `bootstrapApplication` providers; `provideIonicAngular()` is required
  even with no custom config
  (https://ionicframework.com/docs/angular/build-options).

## Lifecycle: Angular Events vs Ionic Page Events

Two layers run side by side (https://ionicframework.com/docs/angular/lifecycle):

| Hook | Fires | Use for |
|---|---|---|
| `ngOnInit` | Once, when the page component is freshly created | One-time init; data that never needs refresh on revisit |
| `ionViewWillEnter` | Every navigation to the page, before the transition starts | Reloading data per visit (watch for jank if it lands mid-animation) |
| `ionViewDidEnter` | Every navigation to the page, after the transition finishes | Heavier data loads; pair with a skeleton/loading indicator |
| `ionViewWillLeave` | Before the transition away begins | Cleanup that can't stay active off-screen (unsubscribes) |
| `ionViewDidLeave` | After the new page has fully transitioned in | Logic that shouldn't run while the page is visible |
| `ngOnDestroy` | Only when the page is popped off the stack | Final teardown |

Why the split exists: `<ion-router-outlet>` extends Angular's router
outlet and **keeps navigated-away pages in the DOM** (hidden) so state
and scroll position survive and back-navigation is smooth. Pages are
removed only when popped (back button/UI back). Consequence: `ngOnInit`
does *not* re-fire on revisit and `ngOnDestroy` does *not* fire on
navigate-away — the `ionView*` hooks cover those cases (same page).

- The hooks fire **only on router-mapped components**, never on child
  components they render (same page).
- Entry/leave *permission* logic is not a lifecycle hook: use Angular
  route guards (`CanActivate`/`CanDeactivate`); the old
  `ionViewCanEnter`/`ionViewCanLeave` were removed in Ionic 4 (same page).
- **OnPush caveat**: with plain-field state, the component hosting
  `ion-router-outlet`/`ion-tabs` and every component above it need eager
  change detection; routed pages themselves may be `OnPush` if state is
  signals or they call `markForCheck()`. Angular 22 defaults components
  to `OnPush` — see https://ionicframework.com/docs/angular/zoneless
  (caveat from https://ionicframework.com/docs/angular/lifecycle).

## Navigation & Routing

Routing is plain Angular Router configured for Ionic
(https://ionicframework.com/docs/angular/navigation):

- **Declarative**: `routerLink` on Ionic components requires importing
  the `IonRouterLink` directive (or `IonRouterLinkWithHref` for `<a>`);
  `routerDirection`/`routerAction` control transition style
  (https://ionicframework.com/docs/angular/build-options).
- **Imperative**: inject `Router` and call `navigate([...])`.
- **Lazy loading**: `loadChildren` (module routes) or `loadComponent`
  (standalone — the default for new code).
- **`LocationStrategy.historyGo()` only in linear flows.** It assumes a
  linear history and must not be used with tabs or nested outlets, where
  back behavior is non-linear (same navigation page).
- **Shared URLs over nested routes.** Nested routes (a child
  `ion-router-outlet`) are for tabs and little else; the docs strongly
  caution against nesting elsewhere. Prefer sibling routes sharing a URL
  prefix (`/dashboard`, `/dashboard/stats`) (same page).

### Tabs rules

Each tab is an **independent navigation stack** — unlike most web tab
implementations, which share one history (same page):

- Tab changes happen only by the user tapping the tab bar. A button in
  Tab 1 that routes into Tab 2 is a defect.
- A view reachable from several tabs (Settings, Account) is presented as
  an `ion-modal`, or the same component gets a route **per tab** — never
  a cross-tab route.

## Theming & CSS Custom Properties

From https://ionicframework.com/docs/theming/basics:

- Components are themed with **CSS custom properties (variables)** — the
  catalog is at https://ionicframework.com/docs/theming/css-variables;
  brand palettes and light/dark setup live at
  https://ionicframework.com/docs/theming/themes and
  https://ionicframework.com/docs/theming/dark-mode.
- The nine base colors (`primary`, `secondary`, `tertiary`, `success`,
  `warning`, `danger`, `dark`, `medium`, `light`) are each a *set* of
  properties including `shade` and `tint`. When overriding a color, set
  all related properties — the Color Generator
  (https://ionicframework.com/docs/theming/color-generator) computes them.
- **CSS Shadow Parts** style internals of Shadow DOM components where no
  variable exists: https://ionicframework.com/docs/theming/css-shadow-parts.
- Application-level structure and utility classes:
  https://ionicframework.com/docs/layout/structure and
  https://ionicframework.com/docs/layout/css-utilities (`ion-padding`,
  `ion-text-center`, …).

House rule: color/spacing decisions go through the variable layer
(`--ion-color-*`, component variables), never per-component hex values —
same spirit as the repo-wide CSS conventions in
[`../../docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md).

## Adaptive / Platform Styles

From https://ionicframework.com/docs/theming/platform-styles:

- Ionic has two **modes**: `ios` and `md`. Default mapping: platform
  `ios` → mode `ios`; platform `android` → mode `md`; everything else
  (`core`) → mode `md`. The mode is applied as a class on `<html>`
  (e.g. `<html class="md">`).
- **Mode ≠ platform**: the mode is overridable through global config
  (https://ionicframework.com/docs/developing/config) — e.g. force
  `ios` styling everywhere via `provideIonicAngular({ mode: 'ios' })`.
- Per-mode overrides use the mode class as an ancestor selector:

  ```css
  .ios ion-badge {
    text-transform: uppercase;
  }
  ```

  Global variables can be scoped the same way (`.ios { --ion-background-color: … }`).

This is Ionic's "Adaptive Styling": one codebase that looks native per
platform (https://ionicframework.com/docs). Don't fight it with
hand-rolled platform branches in components — style via mode selectors
and variables.

## Gestures & Animations

- **Gestures** (https://ionicframework.com/docs/utilities/gestures):
  framework-agnostic utility; in Angular create them via the injected
  `GestureController`. Gesture callbacks run **outside** NgZone by
  default — pass `runInsideAngularZone: true` (second arg to
  `create`) or wrap callbacks in `NgZone.run()` when they mutate
  component state. Configure `threshold`, `direction`,
  `gesturePriority`, `disableScroll` deliberately; call `destroy()` on
  teardown.
- **Animations** (https://ionicframework.com/docs/utilities/animations):
  in Angular create them via the injected `AnimationController`. Built on
  the Web Animations API with a CSS Animations fallback, so work runs off
  the main thread where possible. Animations are paused until `play()`;
  `play()` returns a Promise for chaining.
- **Gesture-driven animation**: the two utilities integrate —
  `progressStart`/`progressStep`/`progressEnd` scrub an animation from
  gesture deltas (animations page §Gesture Animations).
- Respect `prefers-reduced-motion` via CSS variables in keyframes
  (animations page §Preference-Based Animations).

## Performance

- **`trackBy` with `*ngFor`** over Ionic components — stable identity
  lets Angular update rows instead of recreating components
  (https://ionicframework.com/docs/angular/performance). Same intent as
  the modern `@for (item of items; track item.id)` control-flow syntax
  shown in https://ionicframework.com/docs/angular/navigation.
- **Long lists**: use the virtual scroll integration for very large
  collections — https://ionicframework.com/docs/angular/virtual-scroll.
- **Load heavy data in `ionViewDidEnter`, not `ionViewWillEnter`**, when
  mid-animation DOM churn causes jank; cover the delay with a skeleton
  screen or loading indicator (https://ionicframework.com/docs/angular/lifecycle).
- **Bundle size**: standalone imports tree-shake unused components out,
  but all Ionic components come from a single entry point, so used
  components land in the main bundle rather than per-route chunks
  (https://ionicframework.com/docs/angular/build-options §Code splitting).
  Don't import from `@ionic/angular/lazy` — it defeats tree-shaking.
- **Animate compositor-friendly properties** (`transform`, `opacity`);
  `height`/`width` animations trigger layout and paint and cause jank
  (https://ionicframework.com/docs/utilities/animations §Performance Considerations).

## Security Notes (component layer)

From https://ionicframework.com/docs/techniques/security — full policy in
[`../../docs/SECURITY.md`](../../docs/SECURITY.md):

- Ionic ships a basic built-in sanitizer for its own components; it is
  not comprehensive. Sanitize anything untrusted yourself — in Angular,
  rely on `DomSanitizer` defaults and don't mark values safe casually.
- Custom HTML in overlay components is **off by default**
  (`innerHTMLTemplatesEnabled: false`). Enabling it plus
  `IonicSafeString` is a deliberate, reviewed exception, never a default.
- For CSP environments, set the nonce via `setNonce()` from
  `@ionic/core/loader` before any Ionic component loads, and Angular's
  `ngCspNonce`/`CSP_NONCE` mechanisms for framework templates.
