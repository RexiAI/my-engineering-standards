# Informal spec: Clean Code comment hygiene and naming gates

## The ask (owner's words, condensed)

"No more comments in methods, shell, and anywhere, because we need to follow the
Clean Code guide of Robert C. Martin. Avoid comments if the code is clear. Also
bring more features of that guide."

## The correction that defines this spec

Clean Code does **not** ban comments. It calls a comment "always a failure" *and*
lists eight kinds it endorses (Ch.4): legal headers, informative comments,
explanation of intent, clarification, warning of consequences, TODO with context,
amplification of something that looks redundant, and Javadoc on public APIs. It
forbids the rest: mumbling, redundant comments, misleading comments, mandated
comments, journal comments, noise, position markers, closing-brace comments,
attributions, commented-out code, nonlocal information, and function headers on
private code.

So the owner's intent is implemented as **redundant-comment elimination**, not a
blanket ban. A blanket ban would delete this repo's shebangs (51 files), its
`shellcheck disable` directives (8), its usage blocks that are the only record of
gate semantics, and its `# ponytail:` ceiling markers that
`okf/context-window-policy.md` requires.

## Current state (verified, not assumed)

- `docs/CODING_CONVENTIONS.md` line 108 already states the correct rule —
  "Comment the why, not the what". Nothing enforces it.
- `scripts/check-code-principles.sh` runs six gates (complexity, dry, yagni,
  solid, component-per-file, property-tests). None concerns comments or naming.
- That script scans `*.java`, `*.go`, `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.py`,
  `*.rs`. It does **not** scan `*.sh`, so "shell too" requires new file discovery
  and comment-syntax awareness.
- `scripts/*.sh` carries 3,281 comment lines out of 14,811 (22%). Most are usage
  and rationale headers, not noise — a FAIL-by-default rule would turn this
  repo's own CI red on day one.
- `docs/GOVERNANCE.md` §ADR Requirement: any change to the gate catalog requires
  an ADR before merge.

## Required behavior

1. **New `comments` gate in `scripts/check-code-principles.sh`.**
   - FAIL: commented-out code (two or more consecutive comment lines that parse
     as code, using a conservative shape test, not a prose-word test).
   - FAIL: a comment that restates the immediately following line (token-subset
     heuristic, trimmed of punctuation).
   - WARN: `TODO`/`FIXME` without an issue reference (`#123`, `NNN`, or URL).
   - WARN: section-divider comments (`// =====`, `# ----`) and attributions
     (`@author`, "Created by").
   - Allowlist: first five lines of a file (shebang + header), `shellcheck`,
     `noqa`, `type: ignore`, `pragma`, `ponytail:`, `standards:allow-`, licence
     markers, URLs, and doc-comment blocks attached to public API.
   - Coverage: the eight existing source extensions **plus** `*.sh`. Exclude
     `docs/`, `specs/`, `agents/`, `templates/`, `node_modules/`.

2. **New `naming` gate, WARN-only.**
   - Single-character identifiers outside loop counters (`i`, `j`, `k`, `_`).
   - Noise words in type/class names: `Manager`, `Processor`, `Helper`, `Util`,
     `Data`, `Info` (Clean Code Ch.2, "Make Meaningful Distinctions").
   - Encodings in identifiers (Hungarian prefixes, `strName`, `iCount`).
   - Boolean flag parameters (a `boolean` parameter named `is|has|can|should|with`).
   - More than three parameters on a function or method (Clean Code Ch.3:
     "Three arguments should be avoided where possible"). The existing gate
     already WARNs above six (`KISS_PARAMS`, `scripts/check-code-principles.sh`
     line 678), so the new rule is a stricter advisory at four, not a duplicate.

3. **New `null-discipline` gate, WARN-only.** Flag `return null` and explicit
   `null` arguments in non-test Java/JS/TS code (Clean Code Ch.7: "Don't Return
   Null", "Don't Pass Null"). Python/Rust semantics differ — exclude.

4. **Rollout matches ADR 0005.** All three new gates are WARN by default.
   `STRICT_CLEAN_CODE=1` promotes `comments` FAILs to blocking exit status, for
   this repo and for child repos that have cleaned up. No consumer goes red
   overnight.

5. **ADR required.** New `docs/adr/NNNN-clean-code-comment-gates.md` recording
   the taxonomy, the WARN-first rollout, and the blanket-ban alternative that was
   rejected with reasons.

6. **Gate-catalog consumers updated.** `valid_gate`, both "valid gates:" error
   strings, `scripts/tests/check-code-principles-blame.sh`,
   `docs/CODING_CONVENTIONS.md`, and `scripts/check-gate-consistency.sh` must
   agree; `scripts/check-code-principles.selftest.sh` (or the bats suite) gets
   fixtures proving each new gate bites and each allowlist entry does not.

## Out of scope

- Rewriting historical comments in this repo as part of this change. The gate
  reports findings; the file-by-file cleanup is follow-up work.
- Applying the gates to Markdown prose (`docs/`, `agents/`, `skills/`), which is
  a deliverable, not code.
- Any vendor or model configuration (a separate proposal, not this spec).

## Open questions

Resolved by the owner's delegate on 2026-10-23; override any of these at the
human gate before `/build`.

- OQ-1 (self-ci enforcement) — **Ruling: opt-in only.** No
  `STRICT_CLEAN_CODE=1` wiring in self-ci in this change. ADR 0005's adoption
  path is the precedent: ship WARN, let a cleaned repo opt in.
- OQ-2 (`return null` in TypeScript) — **Ruling: keep it, WARN-only.** Child
  repos without ESLint still need the signal; TypeScript's `strictNullChecks`
  does not cover JS files in the same tree.
- OQ-3 (shell naming) — **Ruling: no shell for the `naming` gate.** Positional
  parameters and uppercase env conventions make those heuristics noisy. Shell is
  in scope for `comments` only.
- OQ-4 (exclusion scope) — **Ruling: comments-gate file set only.** The
  `docs/ specs/ agents/ templates/ node_modules/` exclusions scope the new
  comment scan; existing gate discovery is unchanged. The comments gate gets a
  separate `find -prune` list, not a mutation of `FIND_PRUNE`.
- OQ-5 (warn-phase precedence) — **Ruling: ADR 0006 D6 wins.** `.py`/`.rs`
  findings stay WARN even under `STRICT_CLEAN_CODE=1`; language coverage phase
  is not something a new gate may silently promote.
- OQ-6 (parameter count) — **Ruling: corrected.** The earlier "FAILs above six"
  claim was wrong: `KISS_PARAMS` is a WARN (`check-code-principles.sh` line
  678). The 4-parameter `naming` WARN is intentional and not a duplicate.
- OQ-7 (`--require-language`) — **Ruling: keep five names.** No `shell` value.
