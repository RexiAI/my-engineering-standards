# Code quality — the implementation tells

`hallmark audit` loads this file when reviewing existing projects. These are not visual design tells — they are implementation-layer failures that signal "AI-assembled" as reliably as a gradient hero. Each one makes the codebase harder to maintain and often causes visual bugs in production.

---

## HTML structure

### Div soup

A page built entirely from `<div>` and `<span>` with no semantic elements. No `<nav>`, no `<main>`, no `<article>`, no `<aside>`, no `<section>`, no `<header>`, no `<footer>`.

**Why it fails.** Screen readers can't announce landmark regions. Search engines can't determine the page's structural hierarchy. Headings and landmarks that should be implicit become invisible. Every LLM defaults to divs because they're safe and generic; semantic HTML requires knowing what the content *is*.

**Fix.** Replace structural divs with their semantic equivalent:
- Top-of-page navigation → `<nav>` with `aria-label="Primary"`
- Page content wrapper → `<main>`
- Self-contained content unit → `<article>`
- Supporting content → `<aside>`
- Thematic grouping → `<section>` with an accessible heading
- Page-level header / footer → `<header role="banner">` / `<footer>`
- Page region banners (cookie, alert) → `<aside>` or `<div role="region" aria-label="...">` based on content

### Missing alt text on meaningful images

`<img src="..." alt="">` or `<img src="..." alt="image">` on images that carry meaning — product screenshots, team portraits, diagram illustrations, icon-adjacent explanatory images.

**Fix.** Describe the content and function: `alt="Dashboard showing weekly revenue trend from January to March 2026"`. Empty `alt=""` is correct only for purely decorative images that add no information (CSS-art fallback, a thematic background pattern). `alt="image"` is never correct — it restates the element type, which the screen reader already announces.

### Missing skip-to-content link

No `<a class="skip-link" href="#main-content">Skip to content</a>` as the first focusable element in `<body>`. Keyboard-only users must tab through the entire navigation on every page load before reaching main content.

**Fix.** Add a visually-hidden skip link that becomes visible on `:focus-visible`. Target a `#main-content` id on `<main>`. CSS:

```css
.skip-link {
  position: absolute;
  top: -100%;
  left: var(--space-sm);
  padding: var(--space-xs) var(--space-sm);
  background: var(--color-accent);
  color: var(--color-accent-ink);
  font-weight: 600;
  z-index: var(--z-above-all);
}
.skip-link:focus-visible { top: var(--space-xs); }
```

---

## CSS quality

### Inline styles mixed with classes

`style="color: red; margin-top: 20px"` on elements that also carry class names, or elements where the styling should be in the project's styling system. Inline styles can't be overridden by media queries, can't be themed, can't be tracked.

**Fix.** Move all styling to the project's styling system (CSS classes, Tailwind utilities, CSS custom properties). Inline styles are acceptable only for dynamic values that must be set at runtime (e.g. `style="--offset: ${computedOffset}px"` for a JS-driven animation origin) — and even then the property name should be a custom property consumed by the stylesheet, not a raw CSS property.

### Hardcoded pixel widths

`width: 320px` or `max-width: 1200px` hard-coded per-element without a system token. Breaks at non-anticipated viewport widths and can't be maintained consistently.

**Fix.** Use relative units and named tokens:
- Container max-width → `--container-max: 72rem` (one token, used everywhere)
- Element widths → `%`, `ch`, `fr`, `min-content`, `max-content`, `fit-content`
- Only exception: `min-width` on interactive touch targets (44px minimum — this *is* a fixed value per WCAG 2.5.5)

### Arbitrary z-index values

`z-index: 9999`, `z-index: 999`, `z-index: 1000`, `z-index: 50000`. Stack context becomes undebuggable when every component authors its own z value.

**Fix.** Named six-level scale (from [`layout-and-space.md`](layout-and-space.md)):
```css
--z-below:     -1;    /* backgrounds, decorative elements behind content */
--z-base:       0;    /* normal document flow */
--z-raised:    10;    /* floating labels, slightly elevated cards */
--z-sticky:   200;    /* in-page sticky elements (section heads, tables of contents) */
--z-sticky-nav: 300;  /* page-level nav / banner */
--z-overlay:  400;    /* modals, drawers, command palettes */
--z-above-all: 999;   /* skip links, toast stack */
```

### `transition-all` (or `transition: all`)

Animates every CSS property including ones that should be instant (layout, opacity during tab switch, focus-ring appearance). Causes unexpected visual artefacts and performance issues.

**Fix.** Always specify the properties: `transition: background-color var(--dur-short) var(--ease-out), transform 100ms var(--ease-out)`. See [`motion.md`](motion.md).

---

## JavaScript / build quality

### Import hallucinations

`import { nonExistentFunction } from 'real-library'` — a function, hook, or export that does not exist in the listed package. The model used a plausible-sounding API name without verifying it against the library's documentation.

**Why it fails.** Ships a runtime error (or, worse, a TypeScript error that was ignored) in the first build. These are the most embarrassing AI-generated bugs because they prove the code was never run.

**Fix.** Before importing anything, verify the export exists in the library's `package.json` `exports` field or its published type definitions. If the project has TypeScript, treat all `ts` errors as build failures, not warnings. If you can't verify, use a well-known API and note it explicitly in a comment.

### Commented-out dead code

Large blocks of `// old approach` commented code left in production files. Adds noise, confuses future editors ("is this commented out temporarily or permanently?"), and often contains outdated logic that contradicts the live code.

**Fix.** Delete it. Version control is the safety net; dead code doesn't need to live in the file. If the code might return, leave a one-line `// TODO: reconsider <feature> — removed <date> because <reason>` and nothing else.

---

## HTML `<head>` quality

### Missing meta tags

`<head>` that contains only `<title>` and `<meta charset>`. Missing: description, Open Graph, Twitter Card, viewport (on mobile-targeted pages), canonical URL.

**Fix.** Minimum required for any page that will be shared or indexed:

```html
<meta name="description" content="One to two sentences. Specific, no clichés.">
<meta property="og:title" content="Same as <title>, or a social-optimised variant">
<meta property="og:description" content="Same as description, or a pull quote">
<meta property="og:image" content="https://example.com/og-image.png">  <!-- 1200×630 -->
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<link rel="canonical" href="https://example.com/this-page/">
```

For mobile-targeted pages: `<meta name="viewport" content="width=device-width, initial-scale=1">`.

For apps with a branded icon: `<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">`.

---

## Reporting format

When `hallmark audit` checks code quality, append a **Code quality** section to the report after the visual/structural findings:

```
Code quality
· [severity] Tell name — file:line
    why it matters (one line)
    → fix (one line)
```

Severity scale for code quality: `critical` (runtime failure or accessibility blocker), `major` (maintainability/SEO impact), `minor` (hygiene).
