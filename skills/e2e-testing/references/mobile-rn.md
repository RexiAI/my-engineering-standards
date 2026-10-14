# React Native coverage

The web/browser journey model extends to native apps through the framework's
React Native scope: the `@e2e-dev/mobile` package.

## What it drives

- **iOS simulators** — journeys run against the app built into a booted iOS
  Simulator (Mac runners; CI needs an macOS runner or a scheduled job, same
  emulator-dependency caveat this repo already documents for Maestro in
  `docs/TESTING.md`).
- **Android emulators** — journeys run against the app installed on a booted
  Android emulator (headless-friendly on Linux runners).

The same golden rule, judge isolation, sessions/opaque-`Secret` login, and
never-sleep discipline apply — the act/assert verbs target the native
element tree instead of the DOM.

## Scope

`@e2e-dev/mobile` is the user-facing scope for RN child repos. Related kernel
and build-service packages (`@e2e-dev/kernel`, `@e2e-dev/eas`) exist —
mention-level awareness only here; an RN repo adopting this standard consumes
`@e2e-dev/mobile`.

## Cadence note

Native runs are emulator-dependent, so treat them like the repo's existing
Maestro guidance: scheduled/optional jobs, not per-push gates, unless the
runner fleet makes per-push realistic.
