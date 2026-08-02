# `hallmark audit`

Read the file(s) the user pointed at. For each finding, return:

- **Tell** — the named anti-pattern from [`anti-patterns.md`](../anti-patterns.md).
- **Where** — file path and line range.
- **Severity** — `critical` (ships as slop), `major` (looks AI-generated), `minor` (small taste issue).
- **Fix** — one-line concrete correction.

Group by severity. Do not edit. Do not redesign. End with a count: `N critical · M major · K minor`.

**Conditional loads for existing-project audits.** When the target is an existing codebase (has HTML, a framework, or production files — not a greenfield build), also load:
- [`../code-quality.md`](../code-quality.md) — semantic HTML, CSS hygiene, JS/build quality, `<head>` completeness. Append a **Code quality** section to the report.
- [`../strategic-omissions.md`](../strategic-omissions.md) — back navigation, active nav indicator, form validation, dead links, legal links, empty/loading/error states, 404 page. Append a **Strategic omissions** section.

For greenfield builds and component-scope audits, skip both — these files are irrelevant when there is no existing implementation to audit.

## Fix priority

When the audit report is used to guide a subsequent redesign or fix pass, apply findings in this order for maximum visual impact with minimum risk:

1. **Font swap** — biggest instant improvement, lowest risk. Replace browser-default or Inter-only stacks first.
2. **Colour palette cleanup** — remove oversaturated, mixed-temperature, or AI-gradient colours.
3. **Hover and active states** — makes the interface feel alive with minimal layout risk.
4. **Layout and spacing** — proper grid, max-width, consistent named-scale padding.
5. **Replace generic components** — swap cliché patterns (3-column grid, accordion FAQ, carousel testimonials) for modern alternatives.
6. **Add loading, empty, and error states** — makes the interface feel finished.
7. **Typography scale and spacing polish** — letter-spacing, line-height, orphan prevention, weight ladder.

Audit *also* checks structural fingerprint: if the page uses the AI template (centered hero, 3 equal feature cards, CTA, footer, with no asymmetry or surprise), flag it as a critical structural finding even if the visual treatment is fine.

**Stamp-vs-page check.** If the audited file contains a `/* Hallmark · macrostructure: <name> · ... */` stamp, verify the page actually matches that name. If the stamp says **Bento Grid** but the page is a centered single-column hero with a CTA, flag it as a critical structural finding: `stamp lies` — the stamp must reflect what shipped or be removed. This catches drift where a previous Hallmark run stamped one thing and a later edit pulled the page back toward the AI template.

**Genre-aware audit.** If the audited file's stamp names a genre (e.g. `genre: atmospheric`), apply the genre-scoped overrides from [`slop-test.md`](../slop-test.md) when grading. A radial-gradient background is a critical tell for editorial — but allowed for atmospheric. A pure-white paper is a tell for editorial — but allowed for modern-minimal. The audit verb must respect the genre the page declared.

**`design.md` audit.** If the project root has a `design.md` (or `DESIGN.md`), read it before grading. Then check every audited page against the system:

- **Theme drift.** Page uses tokens / fonts / accent that don't match `design.md`'s declared system → flag as `critical: design-system drift`. Per-page theme picks are slop on a system-managed project even if each page is internally fine.
- **Macrostructure family violation.** `design.md` says marketing pages use Marquee Hero or Stat-Led — the audited page is a Letter format → flag as `major: outside design.md family`.
- **Stamp mismatch.** The page's CSS stamp says `designed-as-app` but reads `design-system: design.md` and the page actually drifts from `design.md` → flag as `critical: stamp lies`. The stamp claims compliance the code doesn't deliver.
- **No stamp at all on a system-managed project** → flag as `major: missing system reference`. Every page on a `design.md` project must stamp its allegiance to the system.

Inversely, on a project *without* `design.md`, the standard diversification rule applies — flag pages that share macrostructure / theme with a previous Hallmark output as `minor: variety drift`.
