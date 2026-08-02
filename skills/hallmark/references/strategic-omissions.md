# Strategic omissions — what AI typically forgets

`hallmark audit` loads this file when reviewing existing projects. These are features that AI assistants almost never include by default because they require thinking about the user's *journey through the product* rather than the page's visual surface. Each omission turns a polished-looking UI into a frustrating one.

---

## Navigation completeness

### No "back" navigation

Dead-end pages — detail views, success screens, error screens, confirmation pages — with no way to return to the previous context. The user is stranded.

**Why it fails.** The browser's back button handles *some* of this, but not reliably (multi-step flows, modal routes, post-redirect-get patterns). A page that ends a user's journey without giving them a forward or backward option reads as unfinished.

**Fix.** Every non-root page needs at least one of: a `<nav aria-label="Breadcrumb">` showing the path back, a visually prominent "← Back to [parent]" link as the first element in `<main>`, or a contextual "Done" / "Return to dashboard" CTA that closes the loop. On success screens, always offer "Do another" and "Go back to overview".

### No active-page indicator in navigation

Navigation links that look identical whether or not the user is on that page. Users lose context about where they are in the site.

**Fix.** Style the current-page link with `aria-current="page"` (for server-rendered pages) or a matching active class (for SPAs). The visual treatment: typically a fill or underline on the link itself, NOT a bolded version of the same link (weight shifts are too subtle). For icon-only navs, add an indicator pip or an inset border.

---

## Accessibility foundations

### Missing skip-to-content link

*(Covered in [`code-quality.md`](code-quality.md) § HTML structure — skip-to-content link. Cross-reference only.)*

### No visible focus indicator in custom UI

Custom-styled interactive elements (buttons, cards with click handlers, custom selects, tab strips, sliders) that remove the native focus ring (`outline: none`, `outline: 0`) without replacing it. Keyboard users have no navigation indicator.

**Fix.** Never use `outline: none` without a replacement. Use `:focus-visible` to provide a ring only when keyboard-navigating (not on mouse click): `outline: 2px solid var(--color-focus); outline-offset: 2px`. The ring must achieve ≥ 3:1 contrast against its background (WCAG 1.4.11 Non-text Contrast).

---

## Form completeness

### No client-side form validation

Form fields that accept empty submission, or show a generic "required" browser tooltip with no visual inline error state. Users don't know which fields failed or why.

**Fix.** Validate on submit (and optionally on blur for format-sensitive fields like email). Show inline error messages in a helper-text slot beneath each field: `<p id="email-error" role="alert" class="field-error">Please enter a valid email address.</p>`. The `<input>` carries `aria-describedby="email-error"` and `aria-invalid="true"` when invalid. The helper-text slot is always reserved (`min-height: 1lh`) to prevent layout jump when the error appears — see slop-test gate 39.

### Dead `#` links on interactive elements

`<a href="#">`, `<button onclick="return false">`, or `<button disabled>` styled as primary CTAs. Buttons that appear clickable but do nothing.

**Fix.** Link to the real destination, implement the real handler, or mark the element as `disabled` with proper styling (opacity + cursor: not-allowed). An interactive element that does nothing is a trust violation — the first time a user clicks it, they lose confidence in the rest of the page. *(Slop-test gate 59.)*

---

## Legal and compliance

### No legal links

A production-facing page with no link to a privacy policy, terms of service, or cookie policy. Many jurisdictions require these to be accessible from every page.

**Fix.** Footer must include at minimum: Privacy policy link, Terms of service link (or Terms of use). For EU/UK audiences: Cookie policy link + a compliant consent mechanism. These links live in the footer regardless of the footer's archetype — even Ft2 (inline single line) can carry them as the rightmost items.

### No cookie consent (where required)

A page that sets non-essential cookies (analytics, advertising pixels, personalisation) without user consent, on audiences in jurisdictions where consent is legally required (EU GDPR, UK GDPR, CCPA opt-out, etc.).

**Fix.** Add a first-visit consent banner with: a clear description of what cookies are set and why, an "Accept all" and a "Decline" option (minimum — granular controls preferred), and a persistent "Manage cookies" link in the footer. Store consent in `localStorage` keyed by domain. Do NOT fire analytics or advertising scripts until consent is granted. Design the banner as a `<aside>` fixed to the viewport bottom, z-index `--z-above-all`, with full keyboard access and an ARIA live region announcement.

---

## Error surfaces

### No custom 404 page

The default server or framework 404 page, which is either a blank white screen with "404 Not Found" or the framework's generic error template. A dead end with no brand, no navigation, no help.

**Fix.** Design a branded 404 page that includes: the site's nav (so the user can go somewhere useful), a short, direct message ("This page doesn't exist"), a suggested action ("Go home" or "Search"), and optionally a humorous or on-brand illustration. The 404 page is often the first page a new visitor sees after a broken link — it's a brand moment, not an afterthought.

### No empty states

A dashboard, list view, search results page, or data table that shows nothing — a blank area or a spinner that never resolves — when there's no data to display.

**Fix.** Design a composed "getting started" or "nothing here yet" view for every data-bearing surface. Elements: an illustration or icon (optional), a headline explaining the situation ("No projects yet"), a single CTA that helps the user escape the empty state ("Create your first project"). Empty states are onboarding surfaces — they're the page's best opportunity to explain what value is waiting once the user acts.

### No loading states

Interactive surfaces that freeze, go white, or show a low-quality spinning circle during data fetching. The user can't tell if the app is working or broken.

**Fix.** For every async operation that touches a UI surface:
- **Short operations (< 300ms):** no visible indicator needed. Use a 150ms delay before showing any loader to prevent flicker.
- **Operations 300ms–2s:** replace the content area with a skeleton loader that matches the layout shape (grey rounded blocks at the correct proportions). Never a generic centred spinner.
- **Operations > 2s:** skeleton + a "This is taking longer than expected" inline note after 5s.
- **Form submissions:** disable the submit button and replace its label with "Saving…" or a minimal inline spinner inside the button. Re-enable on completion.

---

## Reporting format

When `hallmark audit` checks strategic omissions, append a **Strategic omissions** section to the report:

```
Strategic omissions
· [severity] Omission name — file (or "missing file")
    why it matters (one line)
    → minimum fix (one line)
```

Severity scale: `critical` (legal requirement or user-journey blocker), `major` (trust or accessibility impact), `minor` (polish gap).
