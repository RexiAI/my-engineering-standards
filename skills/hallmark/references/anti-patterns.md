# Anti-patterns — the named tells

The `hallmark audit` verb flags these by name. Every one of these is a signature of AI-generated UI. Seeing one is a problem; seeing two in the same view is a confirmation.

Each entry: the tell, why it reads as AI-generated, and the fix.

---

## Critical (ships as slop)

### The purple-gradient hero

A hero section with a background gradient from purple to blue or purple to pink, often with white centred text. This is the single most-recognised AI aesthetic.

**Fix.** Pick a single anchor hue. One accent. No gradient backgrounds on heroes. If you want warmth, tint the neutrals.

### Inter-everywhere

Inter (or Roboto, or Open Sans) used as both display and body, with no pairing face. A one-font page is a template page.

**Fix.** Pair a distinctive display face with a refined body face. See [`typography.md`](typography.md).

### The 3-column feature grid

Three equal columns, each with an icon above a two-line heading above a three-line body. Usually spanned full-width with 24px gap. Every LLM emits this.

**Fix.** Break the grid. Vary column widths. Mix card heights. Remove one card and use negative space. Move the icons inline, not above. Or drop the cards entirely and use typographic rhythm.

### Card-in-card

A bordered container with cards inside it. Or: a card containing another card containing a small "micro-card". Visual nesting with no semantic reason.

**Fix.** Pick one containment layer. Usually the outer one is the wrong one.

### The gradient headline

A headline with `background-clip: text` fill set to a linear gradient (usually purple-to-pink or blue-to-cyan). Signals "AI generated" faster than almost anything else.

**Fix.** Solid ink. If you want the headline to feel alive, use weight or italic or a display face — not a gradient fill.

### The side-stripe card

A card with a thick coloured border on one edge (usually left, 4–6px, purple or green). Very recognisable; very 2018-SaaS-AI.

**Fix.** Use a hairline border all around, or no border, or a small accent square beside the heading. Never an asymmetric thick stripe.

### Full-viewport centred hero

`min-height: 100vh` (or `100dvh`), everything centred, one short sentence, one big CTA. The default LLM landing page.

**Fix.** Let the hero be the height of its content. Bias left or right. Put more than a sentence in it.

### Pure black, pure white

`#000000` background or `#ffffff` surface. Both read as flat and synthetic.

**Fix.** Tint toward your anchor hue. See [`color.md`](color.md).

### Default-attractor sameness

Two consecutive Hallmark outputs in the same project use the same macrostructure. The first emitted left-margin numbered labels + huge serif + asymmetric spans (Specimen); the second did exactly the same. The page looks redesigned only because copy changed.

**Why it fails.** Hallmark's whole point is that two pages for two briefs feel like *different sites*, not colour-swaps of one template. Repeating a macrostructure across outputs is the structural fingerprint of templating, which is the AI tell Hallmark exists to defeat.

**Fix.** Before writing code, look in the project's CSS for a `/* Hallmark · macrostructure: <name> · ... */` stamp. If one exists, your pick must be a different macrostructure — categorically different where possible (a serif-led editorial macrostructure paired with a sans-led grid one, not two editorial variants). See [`macrostructures.md`](macrostructures.md) for the twenty-one named choices.

### Specimen fall-through

Producing the Specimen macrostructure (numbered left-margin labels like `01 — HELLO.` + huge serif display + asymmetric spans + hairline rules + typographic-only CTA + sometimes a hand-drawn SVG accent) when the brief did not explicitly request editorial / foundry / specimen energy. This is the single most-repeated Hallmark output, and it's the reason the skill felt like it had one shape.

**Why it fails.** Specimen is a beautiful pattern when the brief is editorial. Applied to a SaaS pricing page, a developer tool, an e-commerce site, or a personal app, it looks like the AI defaulted — because it did.

**Fix.** The Specimen macrostructure is one of twenty-one in [`macrostructures.md`](macrostructures.md), not a default. If the brief is vague, pick from the first ten in that file (Bento Grid, Long Document, Marquee Hero, Stat-Led, Workbench, Conversational FAQ, Manifesto, Photographic, Quote-Led, then Specimen). Reach for Specimen only when the brief explicitly says "editorial", "specimen sheet", "type foundry", or names the Specimen theme.

### The AI nav

Wordmark hard-left, 4–5 inline text links (`Features · Pricing · Docs · Blog · About`) centred or right-grouped, a CTA button hard-right, full viewport width, sticky on scroll, white background, 1 px hairline border-bottom. This is the most-recognised AI nav fingerprint — every LLM emits it because every SaaS site that fed the training data shipped it.

**Why it fails.** The shape is genre-blind: it lands the same on a wedding photographer's portfolio, a bakery, a B2B SaaS, and a manifesto. When the nav can't tell you what kind of site you're on, the page is templated.

**Fix.** Pick from the routing table in [`component-cookbook.md`](component-cookbook.md) § Navigation. The genre routes you to one of N5–N9: Floating pill (modern-minimal / atmospheric), Newspaper masthead (editorial), Brutal slab (playful), Terminal command (CLI), Edge-aligned minimal (luxury / quiet). Reach for N1 *only* when the page genuinely has 2 destinations and the routing table allows it. State the rationale in a one-line comment.

### The AI footer

4 columns of links (Product · Company · Resources · Legal), social-icon row beneath, copyright line at the very bottom, faint 1 px top-border, neutral grey background. Standard SaaS footer, identical across thousands of pages.

**Why it fails.** Same as the AI nav — the shape is genre-blind. A bakery doesn't have a "Resources" column. An editorial page doesn't have a four-link "Legal". The footer should *close the page*, not catalogue its absent sitemap.

**Fix.** Pick from the routing table in [`component-cookbook.md`](component-cookbook.md) § Footers. Default to Ft1 Mast-headed, Ft2 Inline single line, Ft4 Dense colophon, Ft5 Statement, Ft6 Letter close, Ft7 Newsletter-first, or Ft8 Marquee scroll. Use Ft3 Index columns *only* on a genuine hub or docs root with a real sitemap — and even then, never with the social-icon row + tiny copyright tail.

### Aurora-blob background

Flowing organic mesh blobs in purple-to-pink-to-cyan, layered behind hero text. Looks "premium" until you've seen it on every Dribbble shot since 2022.

**Why it fails.** It's the 2022–2023 generated-design default. Audiences pattern-match this in milliseconds: AI template.

**Fix.** Solid surface. Or a subtle two-stop CSS gradient + SVG `<feTurbulence>` grain at < 0.1 opacity. See [`hero-enrichment.md`](hero-enrichment.md) E7 for the recipe.

### Floating-orb decoration

Ambient generic 3D spheres or blurred coloured circles drifting behind the hero, often added "for depth". They have no semantic role.

**Why it fails.** Generic 3D ambience is the new corporate-stock-photo. It implies "I needed something here, so I added something here."

**Fix.** Cut them. The hero doesn't need depth; it needs a strong typographic anchor.

### Sound-on autoplay

A hero video that auto-plays with audio. Browsers block it anyway, but intent matters: a video element shipped without `muted` is a video that wanted to shout at the user.

**Why it fails.** Hostile to the audience. Accessibility fail. SEO penalty. Browser blocked.

**Fix.** `<video autoplay muted loop playsinline>` — always all four. A separate audio toggle button if sound is genuinely useful.

### Lazy-loaded LCP

`loading="lazy"` on the hero image or hero video — the LCP element. The page waits to start downloading until the user scrolls to it, except they're already looking at it, so the page just sits there blank.

**Why it fails.** Tanks Largest Contentful Paint. Real-world data: lazy-loaded LCP images show p75 of 720 ms vs. 364 ms for preloaded — 2× slower, 4× more "poor" experiences.

**Fix.** `fetchpriority="high"` and `preload="metadata"` on the LCP element. Lazy-load only below-the-fold media.

---

## Major (looks AI-generated)

### Bounce and elastic easing

Buttons that bounce in, icons that wobble on hover. These easings were trendy a decade ago.

**Fix.** Exponential ease-out. See [`motion.md`](motion.md).

### Centred everything

Headline centred, body centred, button centred, section after section of centred columns.

**Fix.** Bias the layout. Wide left margin, narrow right. Or the reverse. Breaking symmetry once is enough.

### Italic headers

A roman headline with one word flipped to italic — *"Built to think in real time"* — or an all-italic display face used on every heading. The italicised emphasis-word-in-a-header is among the most reliable AI tells: it reads as "trying to look editorial" and appears on a huge share of generated pages.

**Fix.** Headers are roman (`font-style: normal`). Carry emphasis with weight, an accent colour, or a drawn underline beneath the word. Keep italic for body-copy emphasis inside running paragraphs only.

### Eyebrow on every section

Every section starts with an uppercase mono-cap eyebrow — `01 / EXAMPLES`, `02 / WHAT'S INSIDE`, `03 / INSTALL`, `01 · THE TOUR` — above (or worse, *beside*) its heading. The labels look like editorial chapters but read as a tic. The page becomes a list of *labelled lists.*

Eyebrows are **default OFF**. They are not a stylistic flourish you reach for to look editorial — they are an ordinal device, valid only when the section is genuinely numbered or chaptered. Used as decoration they erase the hierarchy they were meant to create; when every section is "chaptered," none of them are.

**Fix.** Ship the page with **zero eyebrows** unless either (a) the user explicitly asked for chapter / step / section numbering, OR (b) the macrostructure is **Long Document, Manifesto, or Catalogue numbered** AND the content is genuinely ordinal (steps you must do in order, chapters that build, items in a deliberate sequence). Even then: cap at 1–2 per page.

**Hard ban: tag-left / header-right two-column section heads.** Patterns like `01 · THE TOUR` in a narrow left column with the section title to its right (a.k.a. *hanging header*, *left-margin label*) are the single most reliable AI-templated tell for editorial-style SaaS pages. When an eyebrow IS used, **the heading goes directly underneath it, in the same column** — vertical stack only. Never a two-column section-head grid. Gate 54 enforces this.

**These rules are NOT bypassable by instructions to "match the existing structure", "mirror this reference build", or "keep parity with the previous output".** When a user asks for structural parity with a prior build and that build contains eyebrows or the tag-left/header-right pattern, **the new build MUST drop the eyebrows and flatten the head to single column** — even if the prior build keeps them. Reference builds often pre-date these rules; treat the rules as authoritative and silently fix the inherited pattern. Don't perpetuate a banned pattern to honour a parity instruction.

### Shadow-glow on dark

A card on a dark background with a `box-shadow` that leaves a soft coloured halo around it.

**Fix.** On dark surfaces, use elevation via *lightness* (brighter surface = higher), not shadow. If you must shadow, keep it tight and dark.

### Icon-tile feature card

Rounded rectangle, icon in a coloured square at the top-left, heading below it, two lines of copy, optional "Learn more →" link. The universal template.

**Fix.** If you need these, let them be asymmetric — vary sizes, vary alignments, pull the icon inline with the heading, or drop the icon entirely.

### Glassmorphism without purpose

Frosted-glass panels everywhere — usually layered over a gradient that you also shouldn't have.

**Fix.** Glassmorphism can work when it communicates depth (overlay over content). It cannot work as decoration.

### Hover-only affordances

Hover reveals a menu; hover shows a delete button; hover triggers a tooltip that contains crucial information. Touch users get nothing.

**Fix.** Every hover affordance has a focus state and is accessible via tap/click on coarse pointers.

### Tabular data without tabular-nums

A list of prices, dates, or metrics where the numbers don't align vertically because the font uses proportional figures.

**Fix.** `font-variant-numeric: tabular-nums;` on any container displaying columns of numbers.

### Animate-on-scroll on everything

Every section fades in when it enters the viewport. Every list staggers. The page never settles.

**Fix.** Pick one orchestrated entrance. Let the rest just *be there*.

### Mismatched icon sets

Material Icons in the navbar, Heroicons in the feature cards, Lucide in the footer, an emoji "✨" in a hero badge. Each library has its own stroke voice; mixing them is the icon-set tell.

**Why it fails.** Icons are typography. You wouldn't ship a page with three different body fonts; don't ship one with three different icon strokes.

**Fix.** Pick one library per project. Lucide is the default for SaaS, Phosphor when you need weight variants, Heroicons for Tailwind/shadcn projects. See [`assets.md`](assets.md) for the canon.

### AI-illustration look

Smooth-mesh-blob characters with no joint articulation, mid-2010s "modern flat" stock poses, unmistakably-Midjourney compositions with the symmetric default lighting. Hand-drawn SVG humans (the "doodle person with one eye larger than the other") fall under this — corporate-doodle is the late-2010s Slack/Figma marketing template, and the audience reads it as AI immediately.

**Why it fails.** It reads as AI in milliseconds. The 2026 audience pattern-matches this faster than any other tell.

**Fix.** Hand-build the illustration in pure CSS or SVG (Tier A or B in [`hero-enrichment.md`](hero-enrichment.md)). If you must generate, use Nanobanana 2 or Recraft V4 with reference images, asymmetric crop, and grain post-processing — never raw output. See [`custom-craft.md`](custom-craft.md) Tier E.

### Invented metrics

A stat-led layout, comparison row, or proof bar carrying numbers the user never supplied — "10× faster", "saves 5 hours per week", "trusted by 50,000+ teams", "99.9 % uptime", "+47 % conversion". The model reached for a stat to fill a stat slot and made one up.

**Why it fails.** Audiences read invented stats as fast as they read invented testimonials. A page that lies on its proof bar can't be trusted on its claims either, and the AI tell is unmistakable: every fabricated number reads "this was generated, not written".

**Fix.** Three options, in order of preference: (1) replace the number with `—` and a labelled grey block ("metric to confirm" or "stat pending"); (2) ask the user for the real number and pause the run; (3) rebuild the section without the proof slot — a stat-led macrostructure with no real stats is the wrong macrostructure. The number-shaped hole is honest; the fabricated number is slop. *(Slop-test gate 46.)*

### Generic emoji as feature icon

A feature card, value prop, step number, or pricing tier with `✨` `🚀` `⚡` `🔥` `🎯` `✅` rendered as the primary icon. The "sparkle hero" badge with a `✨` glyph beside the eyebrow. Emoji standing in for an icon library because the model didn't pick one.

**Why it fails.** Emoji are typography of a sort, but they are not part of the page's typographic system — they're rendered by the OS and look different on every device, they break the icon's stroke voice (you've now mixed a Phosphor-style line icon with a Twemoji blob), and the choice is recognisably the AI default. Sparkle-emoji-as-AI-shortcut is the cliché of the 2024–2025 era.

**Fix.** Pick a single icon library and ship it ([assets.md](assets.md) names the canon). Or build a custom SVG mark. Or omit the icon entirely and lead with typography — most feature lists don't need icons. *(Slop-test gate 30.)*

### Re-drawn UI chrome

A fake browser bar (URL pill + traffic-light dots) wrapping a screenshot. A fake phone frame (rounded rectangle + notch + speaker slit) around a mobile mockup. A fake code-block window (mock title bar + close/minimise dots) wrapping a `<pre>`. A fake IDE chrome (file tabs + activity bar) around an editor screenshot. All hand-built in HTML/CSS or SVG.

**Why it fails.** The user already has the chrome — their browser, their phone, their IDE all *are* chrome. Redrawing it in a page is like printing a photograph of a picture frame inside a real picture frame. The fakery is also bad: the URL is wrong, the dots aren't macOS dots, the notch is the wrong shape. Audiences pattern-match re-drawn chrome as "AI invented a UI that already exists" within a glance.

**Fix.** Use a real screenshot wrapped in `<figure>` (with a hairline border at most). For phone mockups, use a transparent-PNG device frame from a vendor or a real product photograph — never a CSS-drawn one. For code blocks, use the system `<pre>` with a typographic frame (top rule + label + bottom rule), not a faked window-chrome. The page's job is to show content, not to imitate the OS. *(Slop-test gate 47.)*

### Mid-render token improvisation

A theme is selected at the top of the run, but the artifact contains inline colour values (`#5b6cff`, `oklch(74% 0.18 245)`, `rgb(...)`) or `font-family` declarations that aren't drawn from the token block. Or: the artifact ships with the theme's token set *plus* one extra hex tucked into a hover state, a focus ring, or a single border. The model picked the theme, then drifted.

**Why it fails.** Token discipline is the difference between a system and a freestyle. Once a theme is locked, every colour and every font in the file must reference a named token (`var(--color-accent)`, `font-family: var(--font-display)`). Inline values are how cohesion erodes — by the third edit pass, the page has eight colours instead of three, and the editorial restraint that made the theme work is gone. Audiences don't see the inline value, but they feel the looseness.

**Fix.** Every colour and every font in the artifact must come through `var(--token-name)`. If you need a value that doesn't exist as a token, add it to the token block first (`--color-accent-warm: oklch(...)`) and then reference it. Inline OKLCH or one-off hex values mid-render are not allowed. *(Slop-test gate 48. See also [SKILL.md § Locked tokens](../SKILL.md).)*

### Wrap-to-two-lines clickable text

A button label, nav link, footer link, breadcrumb, or CTA reads on two lines because the viewport got narrow and the label was long. Visually, the affordance now looks broken — readers can't tell whether the line break is intentional. Worst case: the second line is one word ("free", "more", "started"), which reads as a styling error.

**Why it fails.** Clickable affordances are one-line objects. The reader scans the label, decides whether to click, moves on. A two-line label slows the scan, breaks the row's vertical rhythm (button height grows, sibling buttons stay the same), and signals "this page wasn't tested at this width". It's a responsive-discipline tell.

**Fix.** In order of preference: (1) shorten the label — *"Get started free" → "Start free"*; *"Read the documentation" → "Read docs"*. Most CTA labels are too long. (2) Set `white-space: nowrap` on the affordance and let the parent flex container reflow. (3) Drop a non-essential nav item at narrow widths via `hidden=until-found` or `display: none`. (4) Collapse the nav into a sheet/menu under a threshold. *Never* let a primary CTA or nav link wrap. *(Slop-test gate 49. See [responsive.md § Clickable text — never wraps](responsive.md).)*

### Lottie shortcut

Reaching for a LottieFiles community animation — the spinning logo, the checkmark draw, the loading spinner, the "loading dots" loop — when pure CSS or hand-built SVG would have produced it stronger and lighter.

**Why it fails.** Lottie pulls were an AI-tool shortcut throughout 2023–2024; the audience now reads them as one. The 50–500 KB JSON file plus the runtime cost is a tax on a job CSS does in zero bytes.

**Fix.** Build it custom. Spinning logo → CSS `@keyframes rotate`. Checkmark → SVG `stroke-dasharray` animated. Loading dots → CSS `@property` + `animation-delay`. Lottie is Tier F in the enrichment hierarchy — last resort, only for genuinely articulated character motion.

### Three.js for a still object

A WebGL hero where the 3D doesn't earn its place by being interactive. A stationary spinning thing the user can't touch, can't reorient, can't customise — just a model rotating because someone wanted "3D".

**Why it fails.** The 100–300 KB Three.js bundle, the model, the textures, the GPU work — all for a thing that could be a static photograph or an SVG.

**Fix.** If the user can't manipulate it, it doesn't justify Three.js. Use a still photograph or a hand-built SVG.

---

## Microinteraction tells

These are the named tells of AI-generated *motion*. See [`microinteractions.md`](microinteractions.md) for the full catalogue and recipes.

### `transition-all`

Every property animating, including ones that should be instant (visibility, focus rings).

**Fix.** Specify the properties. `transition: background-color var(--dur-short) var(--ease-out), transform 100ms var(--ease-out)`.

### Universal `hover:scale-105`

Every card lifts on hover, with no shadow change, no easing specified, no purpose.

**Fix.** Pick one signal per element. A 1px translate, or a colour shift, or an underline thickening — never all four.

### Bouncy overshoot easings on UI

`cubic-bezier(0.34, 1.56, 0.64, 1)` and friends on buttons, modals, tooltips. Tasteless throwback.

**Fix.** Reserve overshoots for genuine physical interactions (drag-and-drop release). For UI state, use `--ease-out` from `motion.md`.

### Animated hover gradients

Background gradient slides through colour space on hover.

**Fix.** Cut. Or pick one colour shift, instant.

### Cursor follower dots

A trailing dot that lags behind the pointer.

**Fix.** Cut.

### Auto-rotating carousels with no pause

WCAG 2.2.2 failure.

**Fix.** Manual advance only, or pause-on-hover-and-focus, or autoplay disabled by default.

### Celebratory success toasts

"Done!" when the user just saved a thing they can see was saved.

**Fix.** Silent success. Toasts only for failures, async actions whose effect isn't visible, and explicit confirmations the user will need.

### Confirmation dialogs for reversible actions

"Are you sure you want to delete this?" before a one-row delete.

**Fix.** Optimistic delete + 5–10s Undo toast. Reserve the modal for irreversible destructive actions, and even then, type-the-name confirmation, not click-OK.

### Tooltips with the same delay on hover and focus

Both delay 800ms.

**Fix.** Hover delay 800–1000ms. Focus delay 0ms. Different intents, different timing.

### Focus rings that animate in

The ring fades in over 200ms — keyboard users have no indicator at the start of the transition.

**Fix.** Focus rings appear instantly. Always. Don't transition `outline` or `box-shadow` when the element gains focus.

### Toasts that shift layout

New toast pushes content down; dismissed toast lets it spring back.

**Fix.** Stack at a viewport corner, fixed positioning. Existing toasts don't move when a new one arrives.

### Universal scroll-triggered fade-up

Every section fades in on intersection. The page never settles.

**Fix.** One orchestrated entrance on first load. After that, content is just there.

### Spinners that flash

A spinner appears for 50ms while a fast action completes.

**Fix.** Either delay-show the spinner (150ms before showing) or enforce a minimum visible duration (300ms once shown). Skeletons over spinners when the layout is known.

---

## Minor (small taste issues)

### Straight quotes

`"Hello"` and `'word'` in rendered text. A sign nothing was proof-read.

**Fix.** Curly quotes: `"Hello"`, `'word'`.

### Double-hyphen dashes

`--` in body copy where an em-dash belongs.

**Fix.** `—` (U+2014).

### Three periods instead of ellipsis

`...` in body copy.

**Fix.** `…` (U+2026).

### Placeholder names

"Jane Doe", "John Smith", "Example User".

**Fix.** Plausible placeholder names reflecting the audience, or pull from a seeded faker. "Maya Okonkwo", "Sam Tan", "Elena Ruiz".

### Startup-cliché product names

"Acme", "Nexus", "Pulse", "Unleash", "Seamless", "Supercharge".

**Fix.** Name the thing concretely. If it's a demo, use a domain-specific placeholder — "Maple Weekly", "Ridgeline Inventory" — not abstract startup bingo.

### `z-index: 9999`

Arbitrary large z-values.

**Fix.** Use the six-level named scale. See [`layout-and-space.md`](layout-and-space.md).

### Every section padded the same

Top padding, bottom padding, horizontal padding — all equal across every section.

**Fix.** Vary. Tighten one, expand another.

### 100vw widths

`width: 100vw` on anything. Breaks on scrollbar-visible desktops.

**Fix.** `width: 100%` with container padding.

---

## Surface and depth tells

These are distinct from the colour-palette tells above — they're about the *tactile* quality of surfaces, not hue selection.

### Oversaturated accent

An accent colour with chroma so high (effectively > 80% of maximum sRGB gamut for its hue angle) that it reads as screaming — neon buttons, eye-burning highlight strips, badge backgrounds that overpower the surrounding text.

**Why it fails.** Oversaturation signals "I maxed out the colour picker." The 2026 web has moved to restrained, slightly desaturated accents that *coexist* with neutrals rather than fighting them. High-chroma accents are fine for a single 3–5% accent footprint (gate 23 already enforces footprint); they're a tell when used on interactive elements where the saturated surface competes with the label.

**Fix.** Pull chroma down so the accent reads as a considered choice. In OKLCH, for most warm hues aim C ≤ 0.18–0.22; for cool hues C ≤ 0.15–0.20. Verify against gate 41 (button text ≈ button fill) after desaturating — the pairing may need a new `--color-accent-ink`. See [`color.md`](color.md).

### Mixed warm and cool grays

Surface and text neutrals that mix a warm-tinted gray (`oklch(92% 0.005 80)`) with a cool-tinted gray (`oklch(92% 0.006 250)`) in the same palette. Often introduced when the model picks a "warm" paper but reaches for a pre-baked "gray-500" for muted text.

**Fix.** Every neutral — paper, paper-2, rule, ink-2, muted — must be tinted with the *same* anchor hue. If `--color-paper` is oklch(96% 0.008 80), then `--color-ink-2` is oklch(52% 0.010 80), not oklch(52% 0.010 250). See [`color.md` § Neutral discipline](color.md).

### Generic box-shadow

`box-shadow: 0 4px 12px rgba(0,0,0,0.12)` — pure-black, low-opacity shadow regardless of the surface hue. Reads as lifted from a CSS tutorial.

**Fix.** Tint shadows toward the element's background hue. On a warm-paper surface, `box-shadow: 0 4px 20px oklch(70% 0.04 80 / 0.18)`. On dark surfaces, use *elevation by lightness* (brighter surface = higher) instead of shadow. See [`layout-and-space.md` § Depth and elevation](layout-and-space.md).

### Inconsistent lighting direction

Cards in the same group casting shadows at different angles: one has shadow-bottom-right, its neighbour has shadow-bottom-center, a third has no shadow at all.

**Fix.** Declare one shadow token per elevation level and reuse it everywhere. The light source is always above and slightly behind the viewer — `box-shadow: 0 2px 8px <tinted>` is the one voice.

### Random dark section inversion

An otherwise light-mode page contains one dark-background section (`background: #111` or similar) inserted mid-page with no system rationale — a "dark CTA block" or "dark testimonials strip" that was copy-pasted from a design tutorial.

**Why it fails.** Dark-section inserts signal a page assembled from disconnected components, not designed as a cohesive whole. Audiences read the inversion as a "look, I can do dark mode" gesture. The section's text often reads at low contrast because the model applied dark background but forgot to flip the text tokens.

**Fix.** Commit to one mode for the page. If contrast between sections is needed, use a slightly darker band of the same hue family (`--color-paper-3`, oklch 82% vs oklch 96%) — never a sudden jump to near-black in a light page. If the brief genuinely calls for an inverted section (e.g. a full-bleed statement block), make it a deliberate system-level token (`--color-section-dark: oklch(18% 0.012 <anchor-hue>)`) and ensure all child text tokens flip to `--color-paper`. *(Slop-test gate 58.)*

### Empty flat sections with no visual depth

A section that is just text on a plain same-colour background — no rule, no texture, no subtle gradient, no image — sitting between two other sections that also do the same thing. The page reads as a wireframe with copy pasted in.

**Fix.** Every section earns its separation. Options in order of effort: (1) vary the background by one step on the paper scale (`--color-paper-2` on alternating sections); (2) open the section with a full-bleed image at low opacity (picsum or real asset); (3) add a single CSS `<feTurbulence>` grain layer at < 0.08 opacity; (4) introduce a deliberate section ornament (a rule, a numeral, a drawn SVG motif). Section rhythm IS the design on text-heavy pages — flat monotony is the failure state, not just a stylistic gap.

---

## Layout tells

### `height: 100vh` (not `100dvh`)

`min-height: 100vh` on full-screen sections. On mobile browsers (especially iOS Safari), the 100vh unit includes the browser chrome height, causing the section to overflow below the visible area or produce a jarring height jump when the toolbar disappears on scroll.

**Fix.** Always `min-height: 100dvh` for viewport-filling sections. `dvh` = dynamic viewport height; it updates as the browser toolbar shows/hides, so the section always fills exactly the visible area. Polyfill with `min-height: -webkit-fill-available` for older Safari if the audience requires it.

### Complex flexbox percentage math

`flex: 0 0 33.333%` calculations for multi-column structures. Fragile at non-integer widths, breaks on padding-box vs content-box disagreements, collapses mysteriously when gap is added.

**Fix.** Use CSS Grid for any layout with more than two columns or any layout where alignment between rows matters. Flexbox is for one-dimensional flows; Grid is for two. `grid-template-columns: repeat(3, minmax(0, 1fr))` is clearer, more robust, and handles gap natively.

### Cards of equal height forced by flexbox

A card row where `align-items: stretch` (the flex default) forces all cards to the height of the tallest card, resulting in either awkward empty space or bloated card bodies on short-content cards.

**Fix.** Allow variable heights unless the cards genuinely share a data type that benefits from alignment. If equal height IS needed (e.g. a pricing table), use Grid with `grid-auto-rows: 1fr` and ensure the *meaningful* elements (CTAs, prices) are pinned to the bottom with inner flex containers.

### Uniform border-radius on everything

Every element — cards, buttons, inputs, images, tags, modals, code blocks — uses the same `border-radius: 8px` (or 12px, or 16px, or 0.75rem). The page feels stamped, not designed.

**Fix.** Vary radius by element type: tight on inner elements (tags, chips: 4px), medium on cards (8–12px), softer on modals and full-bleed sections (16–24px), pill on standalone badges (`border-radius: 100vmax`). The named scale lives in [`layout-and-space.md`](layout-and-space.md) `--radius-*` tokens.

### No overlap or depth — elements sit flat

Every element has its own row in document flow. No image bleeds into the section above. No stat strip overlaps the hero bottom. No card's shadow touches its sibling. The layout looks like a wireframe grid.

**Fix.** Introduce one intentional overlap: a hero callout that bleeds 40px into the first section, an image that escapes its container via negative margin, a featured card that's 1.5× taller than its row and overflows the grid. One deliberate violation of flat flow reads as design; zero violations reads as template.

### Symmetrical vertical padding

`padding-block: 80px` everywhere — top and bottom padding identical on every section. Optically, equal padding makes sections look like they're floating rather than resting.

**Fix.** Asymmetric padding. A section that transitions from a lighter band to a darker one needs more padding above (visual "breath before the shift") and less below. As a default rule: `padding-block-start` at ~70% of `padding-block-end`. Use `--space-section-top` and `--space-section-bottom` as separate tokens. See [`layout-and-space.md`](layout-and-space.md).

### Dashboard always-left-sidebar

Every dashboard or admin layout defaults to: left sidebar with nav icons, top header with avatar, main content area right. Same shape as Notion, Linear, and every AI-generated dashboard since 2022.

**Fix.** Consider the content's actual navigation needs. A top-nav dashboard (`<header>` + `<main>`) works for shallow hierarchies. A floating command menu (N4 or N13) replaces the sidebar for power users. A collapsible rail that collapses to icons only is the minimum viable differentiation. The sidebar pattern is valid — but choosing it without considering alternatives is the tell.

### Buttons not bottom-aligned in card groups

In a row of cards with varying content lengths, the CTA button floats at different vertical positions because the card body is a simple block, not a flex container.

**Fix.** Every card that contains a CTA is a flex column: `display: flex; flex-direction: column`. The content area above the button gets `flex: 1` so it expands to fill available space. The button sits flush to the card bottom regardless of content length above it.

### Feature lists starting at different vertical positions

In pricing tables or comparison cards, the "What's included" list starts at wildly different Y positions because title blocks and price blocks vary in height.

**Fix.** Use a CSS grid with explicit named rows, or apply `min-height` to the title and price blocks so they occupy a fixed space regardless of content. All lists then start at the same row. Alternatively, use CSS Grid's subgrid (`grid-row: span 1` per block, then `grid-template-rows: subgrid` on the card) if browser support allows.

### Inconsistent vertical rhythm in side-by-side elements

Two cards, columns, or panels placed next to each other share conceptually equivalent elements (a title, a description, a price, a button) but those elements don't align horizontally because each column's content length differs.

**Fix.** CSS Grid subgrid, or the min-height approach above. The principle: any element that has a semantic peer in a sibling column should align baselines with it. Users scan left-right — misaligned peers break the scan.

### Mathematical alignment that looks optically wrong

An icon centred mathematically in its circle container but appearing to sit high because the icon's SVG viewBox has extra whitespace at the bottom. A button whose label looks low because the font's descender depth pushes the text up. A number badge that looks left-shifted because the digit "1" is narrow.

**Fix.** After mathematical centering, apply 1–2px optical corrections: `margin-top: -1px` on the icon, `padding-bottom: 1px` on the button label, `padding-left: 1px` on single-digit badges. Document each correction with a comment: `/* optical centre — compensates for descender depth */`.

---

## Typography tells

### Only 400 and 700 weights

A project that uses Regular and Bold and nothing between. Body copy is 400, headings are 700, and every intermediate level — subheadings, labels, meta text — is also one of these two.

**Fix.** Introduce Medium (500) for metadata and labels, SemiBold (600) for subheadings and strong UI elements. The four-weight ladder (400/500/600/700) allows six distinct levels of emphasis without reaching for italic or size.

### All-caps subheaders everywhere

Section labels, category pills, metadata spans — all `text-transform: uppercase` across the whole page. The page reads as shouting.

**Fix.** All-caps is a register, not a default. Reserve it for one type role (e.g. the eyebrow label — and only when eyebrows are enabled, see §Eyebrow on every section). For other label contexts, try: sentence case at a slightly smaller `font-size` with positive tracking, or small-caps via `font-variant-caps: small-caps`, or a weight shift (500 vs 400) with no transform.

### Orphaned words

The last line of a heading or body paragraph contains a single word ("efficiency.", "today.", "here."), making the text block read as ragged and unresolved.

**Fix.** `text-wrap: balance` on headings; `text-wrap: pretty` on body copy (supported in Chrome 117+, Firefox 121+). For older browsers, manually insert a `&nbsp;` between the last two words of important headings. Orphans on hero headlines are a critical tell; orphans in body copy are minor.

### Missing letter-spacing adjustments

Display-size text using the body font's default tracking (zero or near-zero). Large type optically spaces more than body text, so zero tracking at 60–90px feels loose and unresolved.

**Fix.** Apply negative tracking to display and headline text: `-0.02em` to `-0.04em` at `--text-display`, scaling toward zero as size decreases. Apply zero or slight positive tracking (+0.04em to +0.08em) to small-caps labels and uppercase metadata. See [`typography.md`](typography.md) for the per-scale table.

---

## Component tells

### Rocketship / shield icon clichés

"Launch" illustrated by 🚀 or a literal rocket SVG. "Security" by a shield. "Speed" by a lightning bolt. "Data" by a bar chart. "Integration" by a plug icon. These pairings are the icon-vocabulary equivalent of "Elevate your workflow" — the model reached for the most obvious metaphor.

**Fix.** Pick the less obvious icon for the concept. "Launch" → a cursor with a motion trail, or an upward arrow with a numeral, or no icon and a bold typographic numeral. "Security" → a fingerprint, a keyhole, a wax seal. Iconography should make the user pause for a half-second and understand — the pause confirms it wasn't the first, most automatic choice.

### Pill-shaped "New" / "Beta" badges

A small pill badge with rounded ends (`border-radius: 100vmax`) containing "New" or "Beta" in a bright accent colour, placed before or after a nav link or feature name. Present on > 50% of AI-generated product pages.

**Fix.** Try: a square flag (`border-radius: 2px`); a plain text label with positive tracking and a muted colour (no pill background at all); a superscript numeral; or an inline dot. The pill is the tell, not the badge concept.

### Accordion FAQ as default

A FAQ section implemented as a list of accordion drawers — click to expand, click to collapse. The default choice for any "Questions and Answers" brief, regardless of how many questions there are or how long the answers are.

**Fix.** For fewer than 6 questions: a side-by-side two-column list (questions left, answers right, no interactivity needed). For 6–12: progressive disclosure inline (the answer expands beneath its question without a border/drawer chrome). Accordions are appropriate for long, reference-style FAQs (12+) or FAQs with rich content inside each drawer. For a marketing FAQ with 4 questions and two-sentence answers, the accordion is friction.

### 3-card carousel testimonials with auto-advance

Three testimonial cards in a carousel, auto-advancing on a timer, with dot indicators below.

**Fix.** Static masonry wall (3–6 testimonials, varying heights, no interactivity). Or a single large rotating quote with a manual-advance control (no timer). Or embedded social posts (screenshot/iframe). The carousel auto-advance is both a WCAG 2.2.2 failure (gate 18) and a design tell.

### Avatar circles exclusively

Every person — team members, testimonials, user profiles, review authors — displayed in a `border-radius: 50%` circle crop.

**Fix.** Mix in squircles (`border-radius: 24%–30%`, which approximates the superellipse) or rounded squares (`border-radius: 12px` on a square container). Circles are fine for small avatars (< 40px); for large profile pictures, a squircle reads as more considered.

### Light/dark toggle always sun/moon

The theme toggle is always a sun icon / moon icon switch, often an animated SVG morph between them.

**Fix.** Prefer system-preference detection by default (`prefers-color-scheme`) — most users don't need a manual toggle. When a toggle is needed: a simple text label ("Light / Dark"), a segmented control with three options (Light / System / Dark), or a settings-page control. The sun/moon morph is the 2022–2023 frontend Twitter meme; audiences have pattern-matched it as "AI-assembled UI".

### Modals for everything

Confirmation dialogs, simple forms, detail views, image previews, settings panels — all implemented as centred modals over a dimmed backdrop.

**Fix.** Match the interaction pattern to the content. Inline editing: edit directly in place. Side-over / drawer panel: for forms and detail views that need space. Expandable section: for confirmations that are reversible (Undo is better than "Are you sure?"). Full-page route: for complex multi-step flows. Reserve the modal for genuinely interruptive, blocking content: destructive confirmation (type-the-name, not click-OK), OAuth/payment flows, critical error states.

---

## Iconography tells

### Inconsistent icon stroke widths

Icons from the same library at different sizes with the stroke width unscaled: Heroicons `20` (1.5px stroke) next to Heroicons `24` (1.5px stroke) displayed at the same rendered size. Or: icons from two different size variants of the same library mixed freely.

**Fix.** If the library has size variants (Heroicons 16/20/24, Phosphor Regular/Light/Bold), pick one size variant and use it everywhere. At a given rendered size, all icons should share the same visual weight (stroke width ÷ glyph size = constant).

### Missing favicon

No `<link rel="icon">` in `<head>`. The browser tab shows a generic globe icon.

**Fix.** Always include a favicon. Minimum: a 32×32 ICO or PNG. Preferred: SVG favicon for crisp rendering at all DPIs + a PNG fallback. If the project has no logo, use a text-initial monogram: `<svg>` with a single letter in the brand display font.

---

## Content tells

### AI copywriting clichés

Headlines or body copy containing: "Elevate", "Seamless", "Unleash", "Next-Gen", "Game-changer", "Delve", "Tapestry", "In the world of…", "Revolutionize", "Supercharge", "Transform your workflow", "Unlock the power of", "Best-in-class", "Take it to the next level".

**Fix.** Write plain, specific language. Name what the thing does, not what it feels like. "Save 2 hours on weekly reporting" beats "Revolutionize your productivity." If the user supplied copy with clichés, flag them individually — do not silently delete user copy, but note each one and offer a replacement. See [`copy.md`](copy.md).

### Fake round numbers

Metrics like `99.99%`, `50%`, `100k users`, `$100.00` as placeholder stats. Round numbers read as invented.

**Fix.** Use organic, messy data for placeholders: `47.2%`, `$99`, `12,400 users`, `+1 (312) 847-1928`. Or use the honest placeholder strategy from gate 46: `—` with a labelled grey block. Never invent a stat and display it as if it were real.

---

## How `hallmark audit` should report

For each finding:

```
[severity] Tell name — file:line
  why it's a tell (one line)
  → fix (one line)
```

Then:

```
Summary — N critical · M major · K minor
Verdict — [ships as slop | reads as AI-generated | close, fix the minors]
```
