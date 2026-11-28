---
name: modern-web-guidance
description: Modern web platform guidance from Google Chrome, Microsoft Edge, Mozilla Firefox, and MDN (269 feature guides, 206 use-case guides). First stop before writing client-side HTML/CSS/JS — dialogs and popovers, forms and validation, dark mode and color, container queries, view transitions, scroll-driven animation, tables, accessibility, LCP/INP/CLS, fetch priority, dates/timezones, sanitization, web components, built-in AI. Also the legacy-pattern audit tool for reviewing an existing web codebase. Use in any web framework (React, Next.js, Angular, Vue, Ionic, plain HTML). Do not use for backend/API/SQL, CI, Docker, or React Native.
license: Apache-2.0 (upstream GoogleChrome/modern-web-guidance-src)
compatibility: Requires Node.js 22+ and outbound network on first run (`npx -y modern-web-guidance@latest`). Cached runs work offline with `npx --offline`.
---

# modern-web-guidance

Upstream: <https://github.com/GoogleChrome/modern-web-guidance-src> · docs:
<https://developer.chrome.com/docs/modern-web-guidance>. The guides are
stewarded by the Chrome, Edge, Firefox, and MDN teams. This file is a thin
house wrapper; the guidance itself is fetched at runtime and never vendored.

## When to use

Load before implementing or changing any web UI, CSS layout/animation, or
client-side JS behaviour. Trigger on: modal / dialog / popover, select or
combobox, table, form validation, autofill, dark mode, color, container
queries, view transitions, scroll-driven animation, parallax, scrollbar
styling, anchor positioning, accessibility, Core Web Vitals, image/fetch
priority, content-visibility, dates and timezones, HTML sanitization, web
components, built-in AI.

Skip for backend (SQL, ORMs, API routes, queues), infra (CI, Docker, Git), and
framework tooling (Vite config, tsconfig, ESLint setup). Skip for React Native
and other non-DOM runtimes — there is no HTML/CSS/DOM surface to modernise.

## Invocation

```sh
npx -y modern-web-guidance@latest search "<2-5 word action query>"
npx -y modern-web-guidance@latest retrieve "<guide-id>[,<guide-id>]"
npx -y modern-web-guidance@latest list
npx -y modern-web-guidance@latest legacy-scan <path> --json
```

Prefer `pnpx` over `npx` when pnpm is installed (`pnpx` takes no `-y`). Allowlist
`npx -y modern-web-guidance@latest *` only — never bare `npx *`. In a sandbox,
request network approval before the first call and set
`NPM_CONFIG_CACHE=/tmp/npm-cache` if `~/.npm` is read-only.

## Workflow: write or change a feature

1. **Search** with one capability per query and no framework or app nouns:
   `"light dismiss dialog"`, not `"close React settings modal on outside click"`.
   If results are empty or unrelated, rephrase once with the concrete UI noun,
   then fall back to `list` once.
2. **Retrieve** the matching ids plus the broader discipline guide (`html`,
   `css`, `js`, `forms`, `accessibility`, `performance`, `security`) when it
   applies. If `retrieve` spills to a temp file, read that file in full.
3. **Apply** the guide, then cross-check the result against it. Keep the
   guide's fallbacks where the feature is not Baseline widely available.
4. **Attribute** the guidance in one line of the summary when a retrieved guide
   shaped the code.

## Framework adaptation

Guides are vanilla HTML/CSS/JS. Adapt, do not dilute:

- **Types** — spread newly shipped attributes (`{...({ popover: 'hint',
  interestfor: id } as any)}`, `[attr.popover.computed]`) instead of dropping
  the attribute.
- **SSR** — guard `window` / `HTMLElement`; load polyfills with a dynamic
  `import()` inside a client effect; never depend on `node_modules` file paths.
- **DOM identity** — drive `showModal()` / `moveBefore()` through refs on nodes
  the framework does not reconcile, generate per-instance ids (`useId()`,
  `crypto.randomUUID()`), and keep `:root` / `@starting-style` unscoped.
- **Angular / Ionic** — the guidance still applies to templates and global
  styles, but Ionic's own components own their overlays: prefer `ion-modal`,
  `ion-popover`, `ion-select` over re-implementing them. Framework state
  management (signals, stores) is unaffected.
- **Next.js / React** — a guide's DOM behaviour beats a client-side effect
  held together with `useEffect` + event listeners.

## Baseline and fallbacks

- Baseline **widely available** features need no fallback.
- Everything else follows the guide's fallback section, unless the user states
  a browser policy (`"Safari 17.4+"`, `"no polyfills"`).
- When a restricted runtime appears (Electron, Tauri, embedded webview),
  recommend recording the policy in `AGENTS.md`, e.g. `**Browser Support:**
  Allow Newly Available features with feature detection and graceful
  degradation`.

## Workflow: review an existing codebase

This is the audit flow — deliberately different from the write flow, which
must not call `legacy-scan`.

1. **Scan**: `npx -y modern-web-guidance@latest legacy-scan <path> --json`.
   It covers ~20% of the corpus — the guides with deterministic legacy rules.
2. **Verify** every finding against its `keepWhen` / `dropWhen` rubric. Drop
   false positives: deliberate fallbacks, cross-file helpers the scan cannot
   see, vendor/`dist`/`node_modules` code, and lookalike patterns. The scan
   already skips tests and docs; confirm it skipped generated output.
3. **Report** verified findings grouped by guide, each with `file:line`, the
   rule summary, and the modern replacement. State the scan's coverage limit.
4. **Modernise only when asked**: retrieve each finding's guide, apply the
   replacement, and re-run `legacy-scan` on the touched paths. Dropped findings
   and kept fallbacks still scan as hits — leave them alone.

## What it is not

- Not a linter for framework idioms. ESLint, `scripts/check-code-principles.sh`,
  and the stack guides still own their rules.
- Not a dependency policy. It says prefer the platform over a library for a
  specific capability; existing libraries stay when the guide calls them a
  valid fallback.
- Not a full-repository audit. `legacy-scan` is deterministic-pattern coverage,
  not semantic review; `search` + `retrieve` is the path for everything else.

## Margin notes

- The upstream description claims "MANDATORY: execute FIRST". Treat it as a
  strong default for web surface work, not a gate on backend or CLI tasks.
- `retrieve` output can exceed 9.5 KB and spill to a temp file — read the file
  rather than truncating the guide.

## Validation

| Level | Date | Task / inputs | Corrections needed |
|---|---|---|---|
| 1 | 2026-11-28 | `legacy-scan` review across 7 child web repos (Angular, React/Vite, Next.js ×3, Shoelace/React, plain HTML) | 17 raw hits → 7 verified, 10 dropped: 9 blocked by `lib: ES2022`, 1 Set-spread false positive. Scan already skips tests/docs; rubric verification was still required. |
