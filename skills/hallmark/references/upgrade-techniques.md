# Upgrade techniques

High-impact techniques for upgrading existing projects. Load this file during the Design flow (default verb) and `hallmark redesign` when the build is replacing or enhancing an existing page.

Pick **1–3 techniques per build**. Applying more than three in a single page adds noise and competes with the macrostructure's own rhythm. Each technique should feel inevitable for the brief, not assembled.

---

## Typography upgrades

### Variable font animation

Interpolate a variable font's `font-weight` (or `font-width` / `ital` axis) on scroll progress or hover. Text that starts at weight 300 and lands at 700 as the section enters the viewport reads as the type *arriving* rather than simply appearing.

**When to use.** Editorial briefs, studio pages, type-forward manifesto structures. The font must be a variable font with the axis you're animating; check the font's `@font-face` descriptor for `font-variation-settings` support.

**When NOT to use.** SaaS dashboards, form-heavy apps, any page where text animation would distract from task completion.

**Implementation sketch.**
```css
@property --weight {
  syntax: '<number>';
  inherits: false;
  initial-value: 300;
}
.hero__title {
  font-variation-settings: 'wght' var(--weight);
  transition: --weight 600ms var(--ease-out);
}
.hero__title.is-visible { --weight: 700; }
```
Toggle `.is-visible` via `IntersectionObserver` on the section entering the viewport.

---

### Outlined-to-fill text transition

Display text starts as a stroke outline (`-webkit-text-stroke`, `color: transparent`) and fills with solid ink on scroll entry or hero load. Creates a reveal moment without an opacity fade.

**When to use.** Hero headlines on editorial / atmospheric pages where a single large statement is the whole hero. Most impactful when the outline phase is visible for 1–2 seconds before filling.

**When NOT to use.** Body copy, any text smaller than `--text-3xl`, pages with multiple hero sections.

**Implementation sketch.**
```css
.hero__display {
  color: transparent;
  -webkit-text-stroke: 1px var(--color-ink);
  transition: color 500ms var(--ease-out);
}
.hero__display.is-visible {
  color: var(--color-ink);
  -webkit-text-stroke: 0;
}
```
`prefers-reduced-motion`: show filled state immediately, no transition.

---

### Text mask reveals

Large display typography acting as a clipping mask for a video or image behind it. The type itself becomes a window. High visual impact, appropriate for landing page heroes.

**When to use.** A brief where the product or brand has strong visual identity (food, travel, fashion, creative tools). The masked content should be slow-moving or still — fast video inside text masks is illegible.

**When NOT to use.** Long headlines (the window area is too small), pages that need the headline to be copy-selected, any context where the background imagery might cause the text to read at < 4.5:1 contrast.

**Implementation sketch.**
```css
.mask-hero {
  background: url('/hero.mp4') center / cover no-repeat;
  background-clip: text;
  -webkit-background-clip: text;
  color: transparent;
  font-size: clamp(4rem, 12vw, 10rem);
  font-weight: 900;
  line-height: 1;
}
```
Fallback: `@supports not (-webkit-background-clip: text) { color: var(--color-ink); }`.

---

## Layout upgrades

### Broken grid / asymmetry

Elements that deliberately ignore column structure — overlapping sections, elements bleeding off-screen, or cards offset by a calculated amount from the grid axis. Breaks the "every element has its row and column" flatness.

**When to use.** Any build that currently feels like a wireframe with copy. One asymmetric move per page is enough — a single hero image that bleeds past its column, a stat strip that overflows the container, a callout rotated 2°.

**When NOT to use.** Data-dense interfaces where grid alignment communicates relationships (tables, dashboards, calendars). Never break the grid when the grid *is* the meaning.

**Implementation sketch.**
```css
.feature-image {
  grid-column: 1 / 3;        /* spans two columns */
  margin-inline-end: -4rem;  /* bleeds past the container right edge */
  clip-path: inset(0);       /* clip at the container boundary if needed */
}
```

---

### Whitespace maximisation

Aggressive use of negative space to force focus on a single element. Sections with more padding than content, headlines surrounded by deliberate emptiness, a single phrase centred in a full viewport.

**When to use.** Luxury, editorial, or manifesto briefs. When the message is the product and the page should feel like a still moment. The technique replaces enrichment — no illustration needed when the whitespace *is* the composition.

**When NOT to use.** Feature-rich pages where the user needs to see multiple elements at once. Whitespace maximisation is a choice; it will feel wrong if the brief requires density.

**Implementation sketch.** Double the base section padding: `padding-block: var(--space-5xl) var(--space-4xl)` instead of `var(--space-2xl)`. Reduce the hero's content width to 50% of the container: `max-inline-size: 50ch` with `margin-inline: auto`.

---

### Parallax card stacks

Sections that `position: sticky` and physically stack over each other during scroll. Each section slides beneath the next one, creating a layered deck effect. More controlled than CSS `scroll-snap`; more semantic than `overflow: hidden` scroll hijacking.

**When to use.** Feature showcase sections with 3–5 distinct panels. Each panel should have its own visual weight and stand alone before being covered. Most effective on desktop; degrade gracefully to static sections on mobile.

**When NOT to use.** Sections with long-form copy (the user can't control reading speed). Any content the user might need to re-read (use a proper scroll or accordion instead).

**Implementation sketch.**
```css
.sticky-section {
  position: sticky;
  top: 0;
  min-height: 100dvh;
  z-index: var(--z-raised);
}
/* Each subsequent section gets a higher z-index so it stacks on top */
.sticky-section:nth-child(2) { z-index: calc(var(--z-raised) + 1); }
.sticky-section:nth-child(3) { z-index: calc(var(--z-raised) + 2); }
```
`@media (prefers-reduced-motion: reduce)`: remove `position: sticky`, restore normal block flow.

---

### Split-screen scroll

Two halves of the screen that slide in opposite directions on scroll, or one half that stays fixed while the other scrolls. Creates strong visual contrast between content types (e.g. a static image left + scrolling text right).

**When to use.** Detailed feature explanation alongside a persistent product image. Biographical pages (portrait stays, text scrolls). Process pages (diagram fixed, steps scroll).

**When NOT to use.** Mobile — split-screen collapses to a single-column on narrow viewports, so the technique must degrade cleanly.

**Implementation sketch.**
```css
.split-layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  align-items: start;
}
.split-layout__sticky {
  position: sticky;
  top: var(--space-lg);
  max-height: calc(100dvh - var(--space-lg) * 2);
  overflow: clip;
}
@media (max-width: 48rem) {
  .split-layout { grid-template-columns: 1fr; }
  .split-layout__sticky { position: static; }
}
```

---

## Motion upgrades

### Smooth scroll with inertia

Decouple scrolling from the browser default for a heavier, cinematic feel. Requires a JS scroll library (Lenis, Tempus) — don't reach for this if the project is `motion-cut` (no motion library installed).

**When to use.** Atmospheric, editorial, or luxury pages where the scroll *itself* is an experience. Dev-tool or SaaS pages with dense interactive content — avoid (inertia scroll interferes with precision tasks).

**When NOT to use.** Motion-cut projects, dashboards with sticky tables, any page with `scroll-snap`, infinite scroll feeds. Check for `prefers-reduced-motion` and disable entirely — inertia scroll is a vestibular hazard.

**Implementation sketch (Lenis).**
```js
import Lenis from 'lenis';
const lenis = new Lenis({ lerp: 0.08, duration: 1.2 });
const raf = (time) => { lenis.raf(time); requestAnimationFrame(raf); };
requestAnimationFrame(raf);
```

---

### Staggered entry

Elements cascade in with slight delays, combining Y-axis translation with opacity fade. Never mount everything at once.

**When to use.** First-viewport elements (hero headline + lede + CTA), card grids when all cards are in the first scroll. Creates rhythm without animation complexity.

**When NOT to use.** Below-fold content that the user won't see for several seconds — stagger delay compounds, and a card that takes 600ms to appear in the middle of scrolling reads as lag.

**Implementation sketch.**
```css
.stagger-item {
  opacity: 0;
  transform: translateY(16px);
  transition: opacity 400ms var(--ease-out), transform 400ms var(--ease-out);
  transition-delay: calc(var(--index, 0) * 80ms);
}
.stagger-item.is-visible { opacity: 1; transform: none; }
```
Set `style="--index: 0"` on the first item, `--index: 1` on the second, etc. Maximum 5 items in a stagger; beyond 5, drop the delay and let them enter together.

`@media (prefers-reduced-motion: reduce)`: remove `transform`, keep opacity fade only at `≤ 150ms`.

---

### Spring physics on interactive elements

Replace linear easing with spring-based motion for hover and active states — a natural, weighty feel that linear transitions lack. Use CSS `linear()` (Chrome 113+) for zero-JS spring curves.

**When to use.** Buttons, cards with hover states, drag handles, tab indicators — anywhere interactive feedback should feel physical.

**When NOT to use.** UI state changes that need predictability (loading spinners, progress bars, form validation indicators). Springs feel playful; reserve them for exploratory interactions.

**Implementation sketch (CSS-only spring via `linear()`).**
```css
--ease-spring: linear(
  0, 0.009, 0.035 2.1%, 0.141, 0.281 6.7%, 0.723 12.9%,
  0.938 16.7%, 1.017, 1.077, 1.121, 1.149 24.3%, 1.159,
  1.163 27.8%, 1.148 34%, 1.018 48.2%, 0.976, 0.951 58.6%,
  0.941 60.7%, 0.939 66.3%, 0.954 72.8%, 1.001 86.6%, 1
);
.card { transition: transform 500ms var(--ease-spring); }
.card:hover { transform: translateY(-4px); }
```

---

### Scroll-driven reveals

Content entering through expanding masks, wipes, or SVG path draw-on, tied to scroll progress. Requires the CSS Scroll-driven Animations API (Chrome 115+, progressive enhancement).

**When to use.** Timelines, process steps, feature lists where the sequence matters. The animation communicates order, not just presence.

**When NOT to use.** Content the user needs to read before scrolling (the reveal hides it). Any animation that could obscure the primary CTA.

**Implementation sketch (clip-path wipe).**
```css
@keyframes reveal-wipe {
  from { clip-path: inset(0 100% 0 0); }
  to   { clip-path: inset(0 0 0 0); }
}
.reveal-on-scroll {
  animation: reveal-wipe linear both;
  animation-timeline: view();
  animation-range: entry 10% entry 60%;
}
@media (prefers-reduced-motion: reduce) {
  .reveal-on-scroll { animation: none; }
}
```

---

## Surface upgrades

### True glassmorphism

Go beyond `backdrop-filter: blur(16px)`. Add a 1px inner border and a subtle inner shadow to simulate edge refraction:

```css
.glass-panel {
  backdrop-filter: blur(16px) saturate(180%);
  background: oklch(100% 0 0 / 0.08);
  border: 1px solid oklch(100% 0 0 / 0.14);
  box-shadow:
    inset 0 1px 0 oklch(100% 0 0 / 0.20),  /* top edge refraction */
    0 8px 32px oklch(0% 0 0 / 0.12);        /* drop shadow */
}
```

**When to use.** Dark-background atmospheric pages, floating UI panels over blurred imagery. Only when there is actual content behind the panel for the blur to reveal — glassmorphism on a plain colour background is decoration without function.

**When NOT to use.** Light-mode pages (contrast is insufficient). Any panel that must achieve reliable 4.5:1 text contrast — backdrop content changes the effective background colour.

---

### Spotlight borders

Card borders that illuminate under the cursor, using a CSS `@property` custom property and a `radial-gradient` centred on the pointer position. Zero JS required (pointer tracking via CSS custom properties set by a tiny inline event listener).

**When to use.** Feature cards, pricing tiers, interactive gallery items on dark or mid-tone pages. Adds interactivity without changing the card's layout or content.

**When NOT to use.** Cards with meaningful hover-state changes already (lift, background shift). Stacking effects competes — pick one signal per element.

**Implementation sketch.**
```css
.spotlight-card {
  --mx: 50%;
  --my: 50%;
  background:
    radial-gradient(
      200px circle at var(--mx) var(--my),
      oklch(100% 0.01 var(--accent-h) / 0.06),
      transparent 100%
    ),
    var(--color-paper-2);
  border: 1px solid transparent;
  background-clip: padding-box, border-box;
  background-origin: padding-box, border-box;
}
```
```js
card.addEventListener('mousemove', (e) => {
  const r = card.getBoundingClientRect();
  card.style.setProperty('--mx', `${e.clientX - r.left}px`);
  card.style.setProperty('--my', `${e.clientY - r.top}px`);
});
```

---

### Grain and noise overlays

A fixed, `pointer-events: none`, full-viewport grain layer using an SVG `<feTurbulence>` filter. Breaks digital flatness without adding visual complexity.

**When to use.** Any page that reads as too clean or too digital. Especially effective on pure-surface atmospheric or editorial pages. Apply at < 0.07 opacity so the grain reads as texture, not static.

**When NOT to use.** Pages with many small UI components — grain at small sizes creates visual noise that competes with micro-copy. Disable in `prefers-reduced-motion` if the SVG filter causes GPU repaint.

**Implementation sketch.**
```html
<svg class="grain-overlay" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
  <filter id="grain">
    <feTurbulence type="fractalNoise" baseFrequency="0.65" numOctaves="3" stitchTiles="stitch"/>
    <feColorMatrix type="saturate" values="0"/>
  </filter>
  <rect width="100%" height="100%" filter="url(#grain)" opacity="0.055"/>
</svg>
```
```css
.grain-overlay {
  position: fixed;
  inset: -50%;
  width: 200%;
  height: 200%;
  pointer-events: none;
  z-index: var(--z-above-all);
  mix-blend-mode: overlay;
}
```

---

## Selection guide

When choosing techniques for a build, ask three questions:

1. **Does the technique serve the brief's tone, or is it decoration?** Variable font animation on a legal-tech pricing page is decoration. Whitespace maximisation on the same page might be perfect.

2. **Does the technique degrade cleanly on `prefers-reduced-motion` and on mobile?** Every technique above includes a note on degradation. If you can't implement the degradation path, don't use the technique.

3. **Does it compound with the macrostructure?** A parallax card stack inside a Bento Grid macrostructure fights itself — both are competing for the user's spatial attention. Staggered entry inside a Stat-Led page amplifies the macrostructure's rhythm. Pick techniques that amplify, not compete.
