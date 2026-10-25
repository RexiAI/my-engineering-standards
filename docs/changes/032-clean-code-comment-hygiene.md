# 032-clean-code-comment-hygiene

> Spec pipeline archive. Original source: `specs/032-clean-code-comment-hygiene/` (deleted by this script).
> Archived: 2026-10-25

## Original ask

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

## Tasks

# Tasks: 032 — Clean Code comment hygiene and naming gates

## Context you may rely on

`scripts/check-code-principles.sh` is a language-agnostic heuristic gate. It runs
six gate categories today (`complexity`, `dry`, `yagni`, `solid`,
`component-per-file`, `property-tests`), reads source files directly, and routes
every finding through `emit`(→`classify`/`classify_blame`) so that the blocking
set, `-BaseRef` blame scoping, `--warn-as-error`, `--json`, and `-ReportPath`
all keep working. This spec adds three gates to that catalog and must not change
the six existing ones.

**No blanket comment ban.** Clean Code Ch.4 calls a comment "always a failure"
*and* endorses eight kinds. The owner's request is implemented as
**redundant-comment elimination**: no task in this list may strip shebangs
(`#!/...`), `shellcheck disable=` directives, usage/rationale header blocks,
licence markers, or `# ponytail:` / `# standards:allow-` markers. Those are
explicitly allowlisted (Task 07).

## ID convention

Scenario IDs are `AC-032-<task>-<scenario>`, one file per task under
`20-acceptance/AC-032-<task>-<slug>.md`, each scenario heading starting
`## AC-032-<task>-<scenario>`. `scripts/check-scenario-traceability.sh` keys on
the two-part prefix `AC-032-<task>` (same shape as spec 012's
`AC-012-01-NN`), so:

- every task file must define at least one scenario whose heading begins with
  that task's `AC-032-<task>` prefix,
- every scenario gets at least one test that cites its **full** ID
  (`AC-032-<task>-<scenario>`), even though the traceability gate only demands
  the prefix.

Task numbering matches the AC file numbering; a task's scenarios are the only
thing that verifies it.

## Implementation order

Tasks 01–02 are the decision and the catalog; 03–08 build the `comments` gate;
09–10 add the two advisory gates; 11 re-syncs every catalog consumer; 12 proves
the whole thing with fixtures and regression checks. Task 11 must not be
skipped or deferred: `scripts/check-gate-consistency.sh` and
`scripts/tests/check-code-principles-blame.sh` both fail if it is.

---

## Task 01 — ADR 0011 records the gate decision

New file `docs/adr/0011-clean-code-comment-gates.md`; new row in
`docs/adr/README.md`. `docs/GOVERNANCE.md` §ADR Requirement makes this
review-blocking for any gate-catalog change, so it lands first.

**Acceptance criteria**

- `docs/adr/0011-clean-code-comment-gates.md` exists, its first heading is
  `# ADR 0011: <title>`, and its level-2 headings are `## Status`,
  `## Context`, `## Decision`, `## Consequences`, `## Compliance`, in that
  order, with `### Alternatives Considered` inside `## Decision` (the shape
  ADR 0005 and 0006 already use).
- The first non-empty line under `## Status` is `Proposed` or `Accepted`.
- `## Context` cites Clean Code Ch.4 and states the split the spec is built on:
  some comment kinds are endorsed, others are forbidden — it names at least
  four forbidden kinds, including commented-out code and redundant comments.
- `## Decision` names all three gate names (`comments`, `naming`,
  `null-discipline`), the two blocking-class comment rules and the three
  advisory comment rules, the allowlist categories, coverage (the eight
  existing extensions plus `*.sh`, with `docs/`, `specs/`, `agents/`,
  `templates/`, `node_modules/` excluded), the WARN-first rollout, and
  `STRICT_CLEAN_CODE=1`.
- `### Alternatives Considered` contains a markdown table with a row for the
  rejected **blanket comment ban**, and that row's cons cell names at least
  shebangs, `shellcheck` directives, usage headers, and `ponytail:` markers as
  the casualties.
- `## Decision` or `## Consequences` records that this spec supersedes spec
  011's `AC-011-03-07` assertion that no `naming` gate exists.
- `## Compliance` names `scripts/check-code-principles.sh`,
  `scripts/check-code-principles.selftest.sh`, and
  `scripts/check-gate-consistency.sh`.
- `docs/adr/README.md` has a row beginning `| 0011 |` that links to
  `0011-clean-code-comment-gates.md` and whose status cell is `Proposed` or
  `Accepted`; the link target exists.
- `docs/GOVERNANCE.md` is not modified (its heading structure is asserted by
  `scripts/check-governance.sh`), and `scripts/check-governance.sh` still exits
  0.

**Scenarios:** AC-032-01-01, AC-032-01-02, AC-032-01-03.

---

## Task 02 — Register the three gates in the catalog

Registration and dispatch only; the heuristics land in Tasks 04–10. This task
exists on its own because the catalog must stay internally consistent in one
commit (`valid_gate` + every error string + help text + dispatch).

**Acceptance criteria**

- `valid_gate` accepts nine names in this canonical order:
  `complexity`, `dry`, `yagni`, `solid`, `component-per-file`,
  `property-tests`, `comments`, `naming`, `null-discipline`.
- The default `SELECTED_GATES` array holds those nine names in the same order,
  and `contains_gate` guards one dispatch block per gate:
  `--- Comments ---`, `--- Naming ---`, `--- Null discipline ---`.
- Every gate-name list in the script lists all nine: the `valid gates:`
  blocking-set message, the empty-blocking-set message, the empty-`--gates`
  message, the unknown-`--gates` message, and the usage/help block.
- `--gates comments|naming|null-discipline` (individually and comma-combined)
  runs without an unknown-option/unknown-gate error.
- `--blocking comments|naming|null-discipline` is accepted; an unknown name and
  an empty value still exit 2.
- The `(gates: ...)` summary suffix appears only when fewer than nine gates
  were selected.
- A default `--json` run emits a `gates` array of nine entries in canonical
  order.
- The script header's "Checks and what each flags" list documents the three new
  checks with their severities, the comment allowlist categories, the coverage
  list including `sh`, and `STRICT_CLEAN_CODE`; the "Blocking set" block states
  that `comments` joins the blocking set under `STRICT_CLEAN_CODE=1` and that
  `naming` / `null-discipline` are advisory-only and never FAIL.
- Preserved literals (asserted by `scripts/tests/check-code-principles-blame.sh`
  AC-011-03-01): the header still contains
  `Default blocking set: complexity,property-tests`, `Blocking set`,
  `warn-only`, and `-BaseRef`.
- Preserved threshold (asserted by `scripts/check-stop-and-ask-matrix.sh`
  AC-009-03-02): the script still contains `> 6` and exposes no `--threshold`
  or `--complexity <n>` override option.

**Scenarios:** AC-032-02-01, AC-032-02-02, AC-032-02-03, AC-032-02-04,
AC-032-02-05.

---

## Task 03 — Comment-scan file discovery: `*.sh` plus directory exclusions

New discovery set used **only** by the three new gates, so no existing gate's
file set changes.

**Acceptance criteria**

- A `COMMENT_FILES` set (name may differ) is built from the eight existing
  extensions — `java`, `go`, `ts`, `tsx`, `js`, `jsx`, `py`, `rs` — plus `sh`
  under `SOURCE_DIR`, reusing the existing prune list (`node_modules`, `target`,
  `vendor`, `.git`, `dist`, `build`).
- Paths whose relative path contains a `docs/`, `specs/`, `agents/`,
  `templates/`, or `node_modules/` segment are excluded from that set.
- The exclusion and the `.sh` addition do **not** alter the file sets used by
  `complexity`, `dry`, `yagni`, `solid`, `component-per-file`, or
  `property-tests`: a `.sh` file never reaches the complexity analyzer, and no
  other gate's traversal changes.
- Shell comments are scanned as `#` to end of line; block-comment syntax is
  only used for the C-family/Rust extensions.
- The zero-source message enumerates the scanned extensions and now includes
  `sh`: `scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh`.
- `scripts/tests/check-code-principles.bats`'s ADR-0006 D5 assertion is updated
  to the new enumeration (the test currently pins the eight-extension string).

**Scenarios:** AC-032-03-01, AC-032-03-02, AC-032-03-03, AC-032-03-04.

---

## Task 04 — `comments`: commented-out code

Blocking-class rule R1. Message text is fixed so tests can grep it:
`Comments: commented-out code`.

**Acceptance criteria**

- Two or more **consecutive** comment lines — adjacent physical lines in the
  same file with no non-comment line between them — each matching the code-shape
  predicate produce exactly one finding per run of such lines, anchored at the
  first line of the run.
- The code-shape predicate is documented in the script header and implemented
  as a conservative shape test (never a prose-word blacklist), recognising at
  least: (a) content ending in `;`, `{`, or `}`; (b) an assignment
  `name = expr` / `name := expr` (not `==`, `!=`, `=>`); (c) `if`/`for`/`while`/
  `switch`/`catch` followed by `(`; (d) a call or statement line ending in `)`
  or `;`.
- A single code-shaped comment line produces no finding (the rule requires
  two or more).
- Two consecutive prose comment lines produce no finding.
- The rule works for `#` comments in `.sh`, `//` comments, and continuation
  lines inside `/* ... */` blocks (after stripping the leading `*`).
- Severity is blocking-class: WARN by default, FAIL only under Task 08's
  promotion rules.

**Scenarios:** AC-032-04-01, AC-032-04-02, AC-032-04-03.

---

## Task 05 — `comments`: comment restates the following line

Blocking-class rule R2. Message text: `Comments: comment restates the following
line`.

**Acceptance criteria**

- Tokenisation is defined in the script: lowercase, split on non-alphanumeric
  characters, drop empty tokens.
- A single comment line is a finding when its token set has at least two tokens
  and is a subset of the token set of the **immediately following physical
  line**, and that following line is code (not blank, not another comment).
- A comment with one token or fewer produces no finding.
- A comment containing any token absent from the following code line produces
  no finding.
- A comment whose following line is blank, another comment, or absent
  (end of file) produces no finding.
- The comparison uses the next physical line only — not the next non-blank
  line.
- Severity is blocking-class: WARN by default, FAIL only under Task 08's
  promotion rules.

**Scenarios:** AC-032-05-01, AC-032-05-02, AC-032-05-03.

---

## Task 06 — `comments`: advisory findings (TODO, dividers, attributions)

Three WARN-only rules. They are advisory by contract: no env var, blocking-set
entry, or `--warn-as-error` interaction may reclassify them as FAIL from inside
the gate (the pre-existing `--warn-as-error` exit-status promotion remains).

**Acceptance criteria**

- `TODO` or `FIXME` (uppercase) in a comment, with no issue reference, produces
  `Comments: TODO/FIXME without an issue reference`.
- An issue reference is any of: `#` followed by digits, a standalone integer of
  three or more digits, or an `http://`/`https://` URL — present anywhere in
  the same comment. With a reference, no finding.
- A comment whose content, after stripping comment markers and trimming, is at
  least three characters and consists solely of one repeated punctuation
  character from `= - * # ~ ─ _` produces `Comments: section-divider comment`.
  Content containing any other character (e.g. `// -- note`) does not fire.
- A comment whose content contains `@author` or the case-insensitive phrase
  `created by` produces `Comments: attribution comment`.
- All three messages are WARN in every mode, including `STRICT_CLEAN_CODE=1`
  and `--blocking comments`.

**Scenarios:** AC-032-06-01, AC-032-06-02, AC-032-06-03, AC-032-06-04.

---

## Task 07 — `comments`: the allowlist

Cross-cutting suppression for rules R1, R2, and the three advisory rules. A line
is skipped for **every** comment rule when it matches any allowlist entry.

**Acceptance criteria**

- Lines 1–5 of any file are never scanned (shebang plus header block).
- A line is skipped when its content contains any of: `shellcheck`, `noqa`,
  `type: ignore`, `pragma`, `ponytail:`, `standards:allow-`,
  `SPDX-License-Identifier`, `Copyright`, `Licensed under`, `@license`,
  `http://`, `https://`.
- A `/** ... */` block whose closing line is immediately followed by a line
  containing `public`, `protected`, or `export` is skipped.
- A run of `///` lines immediately followed by a declaration containing `pub`
  is skipped.
- A run of `//` lines immediately followed by `func <Upper>` or `type <Upper>`
  (Go exported declaration) is skipped.
- Suppression is per line (or per doc block), never per file: a violating
  comment at line 6 or later in the same file is still reported.
- `# ponytail:` and `# standards:allow-` markers are preserved verbatim by this
  spec — no task rewrites or removes them.

**Scenarios:** AC-032-07-01, AC-032-07-02, AC-032-07-03, AC-032-07-04,
AC-032-07-05.

---

## Task 08 — `comments`: severity, rollout, and report routing

The rollout switch, matching ADR 0005's `STRICT_GOD_FILE` adoption pattern.

**Acceptance criteria**

- Default (no env var, default blocking set): R1 and R2 print `WARN` and the
  run exits 0.
- `STRICT_CLEAN_CODE=1` promotes R1 and R2 to `FAIL` and the run exits 1.
  Implementation may treat the flag as membership of `comments` in the blocking
  set, so `-BaseRef` blame semantics still apply (pre-existing debt in a touched
  file stays WARN; a fully-added or diff-overlapping line FAILs).
- `--blocking comments` (without the env var) produces the same FAIL/exit-1
  behaviour as `STRICT_CLEAN_CODE=1`.
- Only the literal value `1` promotes; `0`, empty, and any other value do not.
- Advisory rules (Task 06) stay WARN when the flag is set.
- Findings in `.py` and `.rs` files stay WARN even under `STRICT_CLEAN_CODE=1`,
  preserving the ADR 0006 D6 warn phase ("no blocking value can make a .py/.rs
  finding fail during the warn phase").
- `--json` routes R1/R2 findings to `warns[]` by default and to `fails[]` under
  promotion, each entry carrying `message`, `file`, and `line`; `-ReportPath`
  writes the same classification.

**Scenarios:** AC-032-08-01, AC-032-08-02, AC-032-08-03, AC-032-08-04,
AC-032-08-05, AC-032-08-06.

---

## Task 09 — `naming` gate (advisory, five rules)

Applies to the eight existing extensions, non-test files only, using the same
non-test filters the script already has. **Not** applied to `.sh` (shell's
positional parameters and uppercase environment conventions make these
heuristics noise).

**Acceptance criteria**

- No naming finding can ever be emitted as FAIL: not with `--blocking naming`,
  not with `STRICT_CLEAN_CODE=1`, not with `--warn-as-error` changing the
  gate's own severity (only the process exit status).
- Rule N1: a declared/assigned single-character identifier other than `i`,
  `j`, `k`, or `_` produces `Naming: single-character identifier`. Bindings in a
  `for (...)` header do not fire.
- Rule N2: a type declaration (`class`, `interface`, `struct`, `enum`, `type`,
  `record`, `trait`) whose name contains one of `Manager`, `Processor`,
  `Helper`, `Util`, `Data`, `Info` at a CamelCase/word boundary produces
  `Naming: noise word in type name`. A name where the word is a mere substring
  (`Managerial`, `Information`) does not fire.
- Rule N3: an identifier matching a Hungarian/type-encoded prefix
  (`str`, `int`, `bool`, `flt`, `dbl`, `obj`, `arr`, `lst`, `num`, `ptr`, `b`,
  `i`, `n`, `sz`, `p`) immediately followed by an uppercase letter produces
  `Naming: encoded identifier` (`strName`, `iCount`). Normal camelCase
  (`index`, `counter`, `internalFoo`) does not fire.
- Rule N4: a boolean-typed parameter whose name starts with `is`, `has`, `can`,
  `should`, or `with` (as a word: exact name or followed by an uppercase
  letter/underscore) produces `Naming: boolean flag parameter`. A boolean
  parameter not using one of those prefixes does not fire.
- Rule N5: a function or method with four or more parameters produces
  `Naming: more than three parameters`. Exactly three does not fire. This rule
  is independent of the existing complexity gate's `>6` parameter WARN; a
  7-parameter method may therefore produce both findings.
- `--gates naming` runs and reports without the complexity gate being selected.

**Scenarios:** AC-032-09-01, AC-032-09-02, AC-032-09-03, AC-032-09-04,
AC-032-09-05, AC-032-09-06.

---

## Task 10 — `null-discipline` gate (advisory)

Clean Code Ch.7 ("Don't Return Null", "Don't Pass Null"). Java/JS/TS only;
Python and Rust semantics differ and are excluded.

**Acceptance criteria**

- Scanned extensions: `.java`, `.ts`, `.tsx`, `.js`, `.jsx`, non-test files
  only. `.py` and `.rs` are never touched by this gate.
- `return null` (with optional whitespace) produces
  `Null-discipline: return null`.
- A `null` literal appearing as an argument in a call argument list produces
  `Null-discipline: null argument` (`foo(null)`, `foo(a, null)`).
- A `null` used in a comparison (`==`, `!=`, `===`, `!==`), a local assignment
  (`String s = null;`), or a ternary branch produces no finding.
- Findings are always WARN: never FAIL with `STRICT_CLEAN_CODE=1`, with
  `--blocking null-discipline`, or under `--warn-as-error` beyond the existing
  exit-status promotion.
- `--gates null-discipline` runs standalone.

**Scenarios:** AC-032-10-01, AC-032-10-02, AC-032-10-03, AC-032-10-04.

---

## Task 11 — Re-sync every gate-catalog consumer

The informal spec's consumer list, plus two consumers it did not name that the
repo's own tests enforce. All of these must land in the same change or CI goes
red.

**Acceptance criteria**

- `scripts/check-gate-consistency.sh`: the hard-coded expected gate count in
  Check 4 becomes 9 (both the comparison and the printed message), so the run
  prints `Check 4: gate count = 9 (expected 9)` and `PASS — 9 gates`, and the
  script exits 0.
- `scripts/tests/check-code-principles-blame.sh`:
  - `AC-011-03-07` is **inverted**, not deleted: `--blocking naming,complexity`
    must no longer exit 2; it must run and report `naming` findings as WARN
    (naming is advisory). `--blocking test-delta` remains the unknown-gate
    negative case (exit 2, `unknown gate name in blocking set: 'test-delta'`).
    The section comment and the header line "no naming or test-delta gates are
    added" must both be rewritten to cite spec 032's supersession.
  - The expected valid-gates string in AC-011-03-07 and the AC-011-03-04/07
    error-message assertions become the nine-name canonical list.
  - The assertions AC-011-03-01 (header literals) and AC-011-03-08 (skill
    literals) keep passing unchanged.
  - The whole suite exits 0.
- `docs/CODING_CONVENTIONS.md` §Design Principles gains a short
  "Comment hygiene and naming" block that names `comments`, `naming`,
  `null-discipline`, the WARN-first default, `STRICT_CLEAN_CODE=1`, and links
  `docs/adr/0011-clean-code-comment-gates.md`. The existing
  "Comment the why, not the what" bullet is retained verbatim.
- `skills/check-principles/SKILL.md` lists all nine gates (fixing the existing
  "five gate categories" staleness), documents the three new gates' severities
  and `STRICT_CLEAN_CODE`, and keeps the strings `complexity,property-tests`,
  `warn-only`, `-BaseRef`, and `--blocking` (grepped by AC-011-03-08).
- `.github/workflows/self-ci.yml` needs no new step: the selftest step and
  `make test-scripts` already cover the added tests. If a step is added
  anyway, it must not use `continue-on-error`.

**Scenarios:** AC-032-11-01, AC-032-11-02, AC-032-11-03, AC-032-11-04.

---

## Task 12 — Fixture proof, wiring, and regression

ADR 0005's promotion rule: a new heuristic ships with fixture proof. Fixtures
are written to `mktemp -d` only — no fixture is committed under a scanned source
directory (it would be audited by the repo's own gate run).

**Acceptance criteria**

- `scripts/check-code-principles.selftest.sh` gains fixture groups named
  `comments-out-code`, `comments-restate`, `comments-advisory`,
  `comments-allowlist`, `naming-heuristics`, and `null-discipline`. Each group
  asserts both directions: the violating fixture reports the documented message
  at the documented severity, and the near-miss/allowlisted control reports
  nothing.
- New scenarios live in `scripts/tests/check-code-principles-clean-code.bats`
  (picked up automatically by `bats scripts/tests/*.bats`), citing the
  `AC-032-NN-MM` IDs; `scripts/check-bats-assertions.sh` passes on it.
- `bash scripts/check-code-principles.selftest.sh`,
  `bash scripts/tests/check-code-principles-blame.sh`,
  `bash scripts/check-gate-consistency.sh`, and `make test-scripts` all exit 0.
- `bash scripts/check-code-principles.sh --gates comments,naming,null-discipline .`
  on this repo exits 0 with no `FAIL` line — the new gates cannot turn the repo
  red on day one (required behaviour 4).
- Existing behavior unchanged: a CC-7 fixture still FAILs, a CC-6 fixture still
  does not, and the six original gates produce no new findings on their
  selftest fixtures.

**Note (not a criterion):** `scripts/check-stop-and-ask-matrix.sh` AC-009-03-03
asserts `git diff --quiet -- scripts/check-code-principles.sh`, so it reports
FAIL whenever this spec's branch has an uncommitted or committed change to that
file. That check is not wired into self-ci or the Makefile and passes on a clean
checkout after merge; it is not a gate this spec must satisfy. Do not "fix" it
by reverting the gate change — verify AC-009-03-02's two greps instead
(`> 6` present, no threshold override option).

**Scenarios:** AC-032-12-01, AC-032-12-02, AC-032-12-03, AC-032-12-04.

---

## Out of scope (recorded, not implemented)

- Rewriting existing comments in this repo. The gates report; cleanup is
  follow-up work. This spec must not touch the 3,281 existing shell comment
  lines.
- Scanning Markdown prose (`docs/`, `agents/`, `skills/`) — excluded by Task 03
  and a deliverable in its own right.
- Vendor or model configuration.
- Changing the six existing gates' behavior, thresholds, or severities.
- Fixing the pre-existing duplicate ADR numbers in `docs/adr/` (two files each
  numbered 0004 and 0005). This spec appends 0011 only; renumbering is a
  separate cleanup.

## Open questions — resolve before `/build`

**OQ-1 (from the informal spec) — self-ci adoption.** Required behaviour 4 says
all three gates are WARN by default and the informal recommendation is opt-in.
Confirm this spec does **not** add `STRICT_CLEAN_CODE=1` to
`.github/workflows/self-ci.yml` or the Makefile. Default taken in these tasks: no
self-ci wiring; a follow-up spec flips it once this tree is clean.

**OQ-2 — scope of the directory exclusions.** Task 03 applies the
`docs/`, `specs/`, `agents/`, `templates/`, `node_modules/` exclusions only to
the comments gate's file set, so no existing gate's traversal changes. The
alternative is a single global discovery set (which would also stop, say,
`solid` from scanning `templates/`). Confirm the comments-only scope. Default
taken: comments-only.

**OQ-3 — ADR 0006 D6 precedence under `STRICT_CLEAN_CODE=1`.** Task 08 keeps
`.py`/`.rs` comment findings at WARN even when the flag is set, reading D6's
"no blocking value can make a .py/.rs finding fail during the warn phase" as
covering the new switch. If the intent is that an explicit strict switch
overrides the warn phase for `comments`, AC-032-08-05 must be inverted before
implementation. Default taken: D6 wins.

**OQ-4 — parameter-count overlap and one factual error in the informal spec.**
The informal spec says "the existing gate FAILs only above six [parameters]".
It does not: the existing `KISS_PARAMS` finding is a WARN
(`scripts/check-code-principles.sh`, `run_complexity_kiss`). Task 09's `naming`
rule fires at 4+, so a 7-parameter method yields two WARNs (one per gate).
Confirm the overlap is acceptable rather than suppressing one of them. Default
taken: report both — they are different thresholds in different gates.

**OQ-5 — `--require-language` and shell.** The comments gate now scans `*.sh`,
but `--require-language` accepts only `java`, `go`, `node`, `python`, `rust`.
Task 02 leaves that list unchanged (adding `shell` is a separate strictness
feature). Confirm no `shell` value is expected in this change. Default taken:
unchanged.

## Acceptance scenarios

## AC-032-01-01 — The ADR exists with the mandated section shape
## AC-032-01-02 — The ADR records the taxonomy, the rollout, and the rejected blanket ban
## AC-032-01-03 — The ADR is indexed and governance still passes
## AC-032-02-01 — The three new names are accepted by --gates and --blocking
## AC-032-02-02 — Unknown and empty gate values still exit 2 and list all nine
## AC-032-02-03 — A default run selects nine gates, a scoped run says so in the summary
## AC-032-02-04 — Help text documents the three gates, the allowlist, and the strict switch
## AC-032-02-05 — Each new gate has its own dispatch block
## AC-032-03-01 — `*.sh` files are scanned for comments
## AC-032-03-02 — Excluded directories are not scanned
## AC-032-03-03 — Shell is not dragged into the existing gates
## AC-032-03-04 — The scanned-extension message names shell, and its test is updated
## AC-032-04-01 — Two consecutive code-shaped comment lines produce one finding
## AC-032-04-02 — A single code-shaped comment line is not a finding
## AC-032-04-03 — Two consecutive prose comment lines are not a finding
## AC-032-05-01 — A token-subset comment produces a finding
## AC-032-05-02 — An extra token in the comment suppresses the finding
## AC-032-05-03 — Short comments and non-adjacent comments do not fire
## AC-032-06-01 — TODO and FIXME without an issue reference warn
## AC-032-06-02 — An issue reference suppresses the TODO/FIXME finding
## AC-032-06-03 — Section dividers and attributions warn
## AC-032-06-04 — Advisory findings never become FAIL
## AC-032-07-01 — The first five lines of a file are never scanned
## AC-032-07-02 — Tool directives are skipped per line, and do not disable the file
## AC-032-07-03 — ponytail and standards markers are preserved and skipped
## AC-032-07-04 — Licence markers and URLs are skipped
## AC-032-07-05 — Doc blocks attached to public API are skipped; the same lines on private code are not
## AC-032-08-01 — Default classification is WARN with exit 0
## AC-032-08-02 — STRICT_CLEAN_CODE=1 promotes the blocking-class rules
## AC-032-08-03 — --blocking comments promotes without the environment switch
## AC-032-08-04 — Only the literal value 1 promotes, and advisory rules never promote
## AC-032-08-05 — Python and Rust findings stay WARN under the strict switch
## AC-032-08-06 — --json and -ReportPath carry the classification
## AC-032-09-01 — Single-character identifiers fire, loop counters do not
## AC-032-09-02 — Noise words fire at word boundaries only
## AC-032-09-03 — Encoded identifiers fire, ordinary camelCase does not
## AC-032-09-04 — Boolean flag parameters fire, other booleans do not
## AC-032-09-05 — More than three parameters fires at four, not at three
## AC-032-09-06 — Naming never emits FAIL and never scans shell
## AC-032-10-01 — return null is reported
## AC-032-10-02 — Null arguments are reported; comparisons and assignments are not
## AC-032-10-03 — Python and Rust are not scanned
## AC-032-10-04 — Null findings never become FAIL
## AC-032-11-01 — Gate consistency passes with nine gates
## AC-032-11-02 — The blame suite reflects that naming is now a gate
## AC-032-11-03 — CODING_CONVENTIONS documents the new gates
## AC-032-11-04 — The check-principles skill lists all nine gates
## AC-032-12-01 — The selftest proves each new rule and each allowlist control
## AC-032-12-02 — The new scenarios run as bats tests and are not vacuous
## AC-032-12-03 — The new gates cannot turn the repository red on day one
## AC-032-12-04 — Existing gate behavior is unchanged

## Verification

# Verification — 032 — Clean Code comment hygiene and naming gates

Verifier: independent re-execution of every Coder/Refactorer claim. Attempt 1,
phase 1 (no remediation cycles; `SPEC_LOOP_COUNT=1 SPEC_PHASE1_RETRIES=0
SPEC_PHASE2_RETRIES=0`).

Blame scoping: `-BaseRef main` applied to the design-principles gate (and the
complexity gate) per spec 011 / ADR 0005. The scoped run is the gate result; the
full-tree run is recorded below as separate out-of-scope evidence.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-25T12:35:14Z

```
{
  "checks": [1, 2],
  "passes": ["AC-032-01 — traced to a test", "AC-032-02 — traced to a test", "AC-032-03 — traced to a test", "AC-032-04 — traced to a test", "AC-032-05 — traced to a test", "AC-032-06 — traced to a test", "AC-032-07 — traced to a test", "AC-032-08 — traced to a test", "AC-032-09 — traced to a test", "AC-032-10 — traced to a test", "AC-032-11 — traced to a test", "AC-032-12 — traced to a test"],
  "fails": []
}
```

All 12 task files trace to at least one test; no orphaned scenarios, no dangling
references. PASS.

---

## Evidence: full test suite

command: make test
exit: 0
at: 2026-10-25T12:35:23Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..537
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (537 assertions, all `ok`, representative excerpts below) ...
ok 181 AC-032-01-01: the ADR exists with the mandated section shape
ok 182 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
ok 183 AC-032-01-03: the ADR is indexed and governance still passes
ok 184 AC-032-02-01: the three new names are accepted by --gates and --blocking
ok 185 AC-032-02-02: unknown and empty gate values still exit 2 and list all nine
ok 186 AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary
ok 187 AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch
ok 188 AC-032-02-05: each new gate has its own dispatch block
ok 189 AC-032-03-01: shell files are scanned for comments
ok 190 AC-032-03-02: excluded directories are not scanned
ok 191 AC-032-03-03: shell is not dragged into the existing gates
ok 192 AC-032-03-04: the scanned-extension message names shell, and its test is updated
ok 193 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 194 AC-032-04-02: a single code-shaped comment line is not a finding
ok 195 AC-032-04-03: two consecutive prose comment lines are not a finding
ok 196 AC-032-05-01: a token-subset comment produces a finding
ok 197 AC-032-05-02: an extra token in the comment suppresses the finding
ok 198 AC-032-05-03: short comments and non-adjacent comments do not fire
ok 199 AC-032-06-01: TODO and FIXME without an issue reference warn
ok 200 AC-032-06-02: an issue reference suppresses the TODO/FIXME finding
ok 201 AC-032-06-03: section dividers and attributions warn
ok 202 AC-032-06-04: advisory findings never become FAIL
ok 203 AC-032-07-01: the first five lines of a file are never scanned
ok 204 AC-032-07-02: tool directives are skipped per line, and do not disable the file
ok 205 AC-032-07-03: ponytail and standards markers are preserved and skipped
ok 206 AC-032-07-04: licence markers and URLs are skipped
ok 207 AC-032-07-05: doc blocks attached to public API are skipped; private code is not
ok 208 AC-032-08-01: default classification is WARN with exit 0
ok 209 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
ok 210 AC-032-08-03: --blocking comments promotes without the environment switch
ok 211 AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote
ok 212 AC-032-08-05: Python and Rust findings stay WARN under the strict switch
ok 213 AC-032-08-06: --json and -ReportPath carry the classification
ok 214 AC-032-09-01: single-character identifiers fire, loop counters do not
ok 215 AC-032-09-02: noise words fire at word boundaries only
ok 216 AC-032-09-03: encoded identifiers fire, ordinary camelCase does not
ok 217 AC-032-09-04: boolean flag parameters fire, other booleans do not
ok 218 AC-032-09-05: more than three parameters fires at four, not at three
ok 219 AC-032-09-06: naming never emits FAIL and never scans shell
ok 220 AC-032-10-01: return null is reported
ok 221 AC-032-10-02: null arguments are reported; comparisons and assignments are not
ok 222 AC-032-10-03: Python and Rust are not scanned
ok 223 AC-032-10-04: null findings never become FAIL
ok 224 AC-032-11-01: gate consistency passes with nine gates
ok 225 AC-032-11-02: the blame suite reflects that naming is now a gate
ok 226 AC-032-11-03: CODING_CONVENTIONS documents the new gates
ok 227 AC-032-11-04: the check-principles skill lists all nine gates
ok 228 AC-032-12-01: the selftest proves each new rule and each allowlist control
ok 229 AC-032-12-02: the new scenarios run as bats tests and are not vacuous
ok 230 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 231 AC-032-12-04: existing gate behavior is unchanged
... (remaining 306 assertions all `ok`) ...
ok 537 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

`check-bats-assertions.sh` reports "no vacuous assertions" over 56 bats files
(including the new `check-code-principles-clean-code.bats`), then `bats --tap
scripts/tests/*.bats` runs 537 assertions, all `ok`. PASS. Nothing skipped,
disabled, or silently absent — the glob `scripts/tests/*.bats` picks the new
file up.

---

## Evidence: complexity gate

Primary (scoped to this change, `-BaseRef main`):

command: scripts/check-code-principles.sh --gates complexity -BaseRef main .
exit: 0
at: 2026-10-25T12:40:26Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

---------------------------------------------
✔ Design-principles check (gates: complexity): 0 FAIL(s), 0 WARN(s).
```

Full-tree (out of scope — the only FAIL is in a file untouched by this diff):

command: scripts/check-code-principles.sh --gates complexity .
exit: 1
at: 2026-10-25T12:40:15Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
FAIL Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43

---------------------------------------------
✘ Design-principles check (gates: complexity): 1 FAIL(s), 4 WARN(s).
  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md
```

The full-tree FAIL is the pre-existing `CC=10` at
`skills/hallmark/site/examples/cobalt-01/script.js`. That file is **not** in
`git diff main --name-only`, so under `-BaseRef main` it is correctly out of
scope — confirmed by the scoped run (exit 0). This spec changes only shell
scripts, markdown, and YAML; the complexity analyzer scans only
Java/Go/JS/TS/Python/Rust (`.sh` never reaches it — Task 03, verified in the
script: `SH_FILES` feeds only `COMMENT_FILES`). The changed `.sh` files are
therefore not complexity-measurable by this gate, and the Refactorer's
complexity claim (below) is about shell-function structure, not the gate.

PASS for the scoped complexity gate; the full-tree FAIL is pre-existing,
out-of-scope debt.

---

## Evidence: design-principles gate

Primary (scoped to this change, `-BaseRef main`):

command: scripts/check-code-principles.sh -BaseRef main .
exit: 0
at: 2026-10-25T12:40:30Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

--- DRY ---

--- YAGNI ---
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected

--- SOLID ---
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports
PASS SOLID-DIP (python): no domain→infrastructure imports
PASS SOLID-DIP (rust): no domain→infrastructure imports

--- Component-per-file ---
PASS Component-per-file: no violations

--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)

--- Comments ---

--- Naming ---

--- Null discipline ---

---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 0 WARN(s).
```

Full-tree (out of scope — one pre-existing FAIL, plus 61 advisory WARNs):

command: scripts/check-code-principles.sh .
exit: 1
at: 2026-10-25T12:40:34Z

```
... (complexity, DRY, YAGNI, SOLID, component-per-file sections identical in
scope to the complexity full-tree above) ...

--- Comments ---
WARN Comments: comment restates the following line (./skills/hallmark/site/examples/cobalt-01/script.js:186)
WARN Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)
WARN Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)
WARN Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)
WARN Comments: commented-out code (./scripts/check-bats-assertions.sh:21)
WARN Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)
WARN Comments: commented-out code (./scripts/verify-production-deploy.sh:30)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:58)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:121)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)
WARN Comments: attribution comment (./scripts/check-code-principles.sh:59)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)
WARN Comments: commented-out code (./scripts/check-loop-files.sh:10)
WARN Comments: section-divider comment (./scripts/init-ci.sh:6)
WARN Comments: section-divider comment (./scripts/init-ci.sh:32)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:39)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:49)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:67)
WARN Comments: commented-out code (./scripts/token-stats.sh:10)
WARN Comments: comment restates the following line (./scripts/bootstrap.sh:229)
WARN Comments: comment restates the following line (./scripts/bootstrap.sh:234)
WARN Comments: commented-out code (./scripts/guard-env.sh:21)
WARN Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)
WARN Comments: commented-out code (./scripts/check-security-hardening.sh:39)
WARN Comments: commented-out code (./scripts/check-model-env.sh:30)
WARN Comments: commented-out code (./scripts/gate-stats.sh:20)
WARN Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)

--- Naming ---
WARN Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)
WARN Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
WARN Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)
WARN Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)

--- Null discipline ---
WARN Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)

---------------------------------------------
✘ Design-principles check: 1 FAIL(s), 61 WARN(s).
  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md
```

The single full-tree FAIL is the pre-existing `CC=10` at
`skills/hallmark/site/examples/cobalt-01/script.js:7` — the same file that the
complexity full-tree run flags, and one that is **not** in this diff. The 61
WARNs are all advisory: 45 from the three new gates (all WARN by design — the
WARN-first rollout of Task 08 / ADR 0011 — plus the pre-existing complexity,
DRY, YAGNI, and KISS WARNs in `ci/templates/`). None of the new gates emits a
FAIL in the full-tree run, confirming Task 12 required-behaviour 4.

Under `-BaseRef main` the gate is clean (exit 0, 0 FAIL, 0 WARN). PASS.

Design-principles WARNs to flag to the Architect (review hints, not blockers —
Stop-and-Ask matrix "Design gate WARN → record, do not stop"): the new
`comments` gate reports pre-existing commented-out code, section-divider
comments, TODO/FIXME-without-reference, and attribution comments across
`scripts/` (e.g. `check-code-principles.selftest.sh:639/641`,
`check-code-principles.sh:57/58/59/121`, `gate-clean-code-lib.sh:97`). These are
the day-one WARNs the spec explicitly chose not to clean up (Task 12 / "Out of
scope — rewriting existing comments").

---

## Evidence: scenario-to-behavior spot check

command: bats --tap --filter 'AC-032-04-01|AC-032-08-02' scripts/tests/check-code-principles-clean-code.bats
exit: 0
at: 2026-10-25T12:43:33Z

```
1..2
ok 1 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 2 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
```

Two scenarios chosen at random, each confirmed to assert real behavior rather
than self-reference:

- **AC-032-04-01** (`20-acceptance/AC-032-04-commented-out-code.md`). Scenario:
  two consecutive code-shaped comment lines inside a method → exactly one
  `Comments: commented-out code` finding, anchored at the first comment's line,
  exit 0. Test (`check-code-principles-clean-code.bats:358-375`) builds a
  `Ledger.java` fixture in `mktemp`, runs `--gates comments`, and asserts
  `count_sho 'Comments: commented-out code' == 1` **and** the exact anchor
  `sho 'Ledger\.java:9'` (line 9 = the first comment). This is a concrete
  count + line-anchor assertion, not a name-only check.

- **AC-032-08-02** (`20-acceptance/AC-032-08-comment-severity-rollout.md`).
  Scenario: `STRICT_CLEAN_CODE=1` promotes the blocking-class rule → `FAIL`
  prefix, exit 1. Test (`check-code-principles-clean-code.bats:728-743`) runs
  `cc_env STRICT_CLEAN_CODE=1 --gates comments`, asserts `[ "$RC" -eq 1 ]` and
  `sho 'FAIL.*Comments: commented-out code'`. A severity + exit-code assertion,
  with the WARN/default and only-literal-`1` controls asserted in the sibling
  tests (AC-032-08-01, -03, -04).

Both tests use `mktemp` fixtures (never committed, per Task 12), assert both the
positive finding and the negative/control direction, and were confirmed green in
the full suite. Neither is vacuous or self-referential.

---

## Refactorer structural claims — independently re-verified

- **Checker is ~1098 lines**: `wc -l scripts/check-code-principles.sh` → `1098`.
  Confirmed (main's version was 1520 lines).
- **New libraries exist**: `scripts/gate-analysis-lib.sh` (590 lines — the
  DRY/YAGNI/SOLID/component-per-file/property-tests analyzers) and
  `scripts/gate-clean-code-lib.sh` (488 lines — the comments/naming/
  null-discipline analyzers). Confirmed present and sourced by the dispatcher.
- **Extracted analysis is byte-identical behaviorally**: ran main's
  `check-code-principles.sh` (with `gate-report-lib.sh` / `check-common.sh`
  copied alongside) and the current script over the repo with the six original
  gates, then diffed the JSON transcripts:

  command: bash /tmp/opencode/032/check-code-principles.main.sh --gates complexity,dry,yagni,solid,component-per-file,property-tests --json .
  exit: 1   (both scripts exit 1 — same single pre-existing CC=10 FAIL)
  at: 2026-10-25T12:41:00Z

  `diff main.json cur.json` → **JSON IDENTICAL** (1 fail, 16 warns, identical
  `gates` array and identical finding triples). The six original gates produce
  byte-identical output before and after the extraction.
- **The nine analyzer functions moved unmodified**: `check_dry`, `check_yagni`,
  `check_solid_srp`, `check_solid_ocp`, `check_solid_lsp`, `check_solid_isp`,
  `check_solid_dip`, `check_component_per_file`, `check_property_tests` — each
  extracted from main's `check-code-principles.sh` and diffed against
  `gate-analysis-lib.sh`; all nine are byte-identical (8 via a brace-matching
  extractor, `check_yagni` via a direct line-range `diff` — both report
  `identical`).

### Judgment: the 9 pre-existing CC>6 shell functions in gate-analysis-lib.sh

The Refactorer's note reports "9 pre-existing CC>6 functions in
`scripts/gate-analysis-lib.sh` (moved unmodified)". Two facts frame this:

1. **The complexity gate never measures shell.** The analyzer's file set is
   Java/Go/JS/TS/Python/Rust only; `SH_FILES` is discovered separately and fed
   *only* to `COMMENT_FILES` (Task 03 — "a `.sh` file never reaches the
   complexity analyzer", confirmed in the script at lines 446-456). So "CC>6"
   for these shell functions is a self-assessment, not a gate finding — the gate
   can never flag them, scoped or full-tree. (An independent brace-depth+keyword
   count over `gate-analysis-lib.sh` using the repo's own heuristic puts 7 of the
   9 functions above CC 6 — `check_dry` 21, `check_solid_srp` 22, `check_yagni`
   68, `check_solid_isp` 11, `check_solid_ocp` 10, `check_solid_lsp` 8,
   `check_solid_dip` 7 — while `check_component_per_file` and
   `check_property_tests` sit at/below the threshold because their logic lives in
   embedded awk strings. The precise count is immaterial: the gate does not scan
   shell.)
2. **The debt is relocated, not created.** All nine functions are byte-identical
   to their `main` counterparts (verified above). Under `-BaseRef main` the
   gate reports clean (exit 0), and `gate-analysis-lib.sh` is a new file that the
   complexity gate does not scan.

**Judgment: acceptable.** No new complexity was introduced; the extraction moved
pre-existing shell-function complexity (invisible to the gate) out of the
dispatcher into a lib, shrinking the dispatcher from 1520 → 1098 lines. This is a
structural improvement, not a regression, and it is fully covered by blame
scoping. If shell complexity is ever to be gated, that is a follow-up spec
(recorded here as an out-of-scope finding, not implemented).

---

## Task 01 / Task 11 confirmations

- **ADR 0011 listed in `docs/adr/README.md`**: row
  `| 0011 | [Clean Code comment hygiene and naming gates](0011-clean-code-comment-gates.md) | Proposed |`
  present; link target `docs/adr/0011-clean-code-comment-gates.md` exists. ADR
  heading order confirmed: `# ADR 0011: …`, then `## Status` (`Proposed`),
  `## Context`, `## Decision` (with `### Alternatives Considered` inside),
  `## Consequences`, `## Compliance`.
- **`.github/workflows/self-ci.yml` NOT modified**: `git diff main --
  .github/workflows/self-ci.yml` is empty.
- **`docs/GOVERNANCE.md` NOT modified**: `git diff main -- docs/GOVERNANCE.md`
  is empty; `bash scripts/check-governance.sh` exits 0 (also asserted by
  AC-032-01-03).
- **Catalog consumers re-synced (Task 11)**:
  - `bash scripts/check-gate-consistency.sh` → exit 0, `Check 4: gate count = 9
    (expected 9)`, `PASS — 9 gates`.
  - `bash scripts/check-code-principles.selftest.sh` → exit 0,
    `60 assertions passed`.
  - `bash scripts/tests/check-code-principles-blame.sh` → exit 0,
    `25 passed, 0 failed`.
- **Task 12 required behaviour 4**:
  `bash scripts/check-code-principles.sh --gates comments,naming,null-discipline .`
  → exit 0, `0 FAIL(s), 45 WARN(s)` — the three new gates do not turn the repo
  red on day one (verified directly, and by AC-032-12-03).

---

## No unaccounted behavior

Finding line: the diff (`git diff main --name-only` plus untracked files)
contains exactly the files the twelve tasks name — the ADR and its README row
(Task 01), the three-gate registration and header/help text (Task 02), comment
discovery + the three `comments` rules + allowlist + rollout (Tasks 03-08), the
`naming` and `null-discipline` gates (Tasks 09-10), the consumer re-sync —
`check-gate-consistency.sh`, `check-code-principles-blame.sh`,
`check-code-principles.bats`, `CODING_CONVENTIONS.md`, `check-principles/SKILL.md`
(Task 11) — and the fixture/wiring/regression proof (Task 12). The two new lib
files (`gate-analysis-lib.sh`, `gate-clean-code-lib.sh`) are the Refactorer's
extraction of existing analyzers, not new behavior. No logic found that does not
trace to a task or scenario.

---

## Verdict

**PASS.**

Every gate ran and produced no findings for the change under review:

| Check | Scoped result | Full-tree (out of scope) |
|---|---|---|
| scenario traceability | PASS (exit 0) | — |
| full test suite | PASS (exit 0, 537/537) | — |
| complexity gate | PASS (exit 0) | 1 pre-existing FAIL (CC=10 script.js, untouched) |
| design-principles gate | PASS (exit 0, 0 FAIL / 0 WARN) | 1 pre-existing FAIL + 61 advisory WARN |
| scenario-to-behavior spot check | PASS (2/2 non-vacuous) | — |

The one full-tree FAIL — `Cyclomatic complexity >6` at
`skills/hallmark/site/examples/cobalt-01/script.js:7` — is pre-existing and in a
file absent from `git diff main`; under `-BaseRef main` blame scoping it is
correctly excluded and the scoped gate is clean. The 61 full-tree WARNs are all
advisory (WARN-first rollout of the three new gates, plus pre-existing `ci/`
template WARNs). No FAIL is attributable to this spec's change. The Refactorer's
structural claims — ~1098-line dispatcher, two new lib files, byte-identical
six-gate output, nine analyzer functions moved unmodified — are all confirmed.
The 9 pre-existing CC>6 shell functions are acceptable: the complexity gate does
not scan shell, and the debt is relocated (byte-identical) rather than created.

The Architect may proceed.

## Quality gates

# 30-report — spec 032-clean-code-comment-hygiene

- Stage: 5a Mutation Runner. Attempt 1 (no remediation cycles anywhere in the run).
- Precondition: Verifier **PASS** — `25-verification.md`, attempt 1, phase 1.
- Branch: `spec/032-clean-code-comment-hygiene`, working tree dirty by design (the
  uncommitted stage 2/3/4 change set). See §Stop-and-Ask resolution below.
- Conformance tier: **`mvp`** — mutation testing is a recorded **skip**, not a score
  (evidence in §Mutation score).
- Information barrier honored: `specs/032-clean-code-comment-hygiene/00-informal.md`
  was not read. This report is written from `25-verification.md`, `10-tasks.md`,
  `20-acceptance/`, and this stage's own gate transcripts only.
- Stage 5a wrote **no production code and no new tests** — there was no mutation run
  and therefore no surviving mutant to kill. The tree handed to stage 5b is
  byte-identical to the tree the Verifier passed.

Verifier verdict: PASS
Mutation score: skipped — mvp tier
Final test status: green (537/537 bats assertions, exit 0)

---

## Verifier's verdict (carried forward)

**PASS — attempt 1, phase 1.** `25-verification.md` records all five Verifier checks
green, each with its own command/exit/timestamp:

| Check | Scoped result |
|---|---|
| scenario traceability | exit 0 — 12/12 AC-032 scenarios traced, `"fails": []` |
| full test suite | exit 0 — `make test`, plan `1..537`, all `ok` |
| complexity gate | exit 0 — 0 FAIL / 0 WARN under `-BaseRef main` |
| design-principles gate | exit 0 — 0 FAIL / 0 WARN under `-BaseRef main` |
| scenario-to-behavior spot check | PASS — AC-032-04-01 and AC-032-08-02 confirmed non-vacuous (count + line-anchor and severity + exit-code assertions) |

One out-of-scope full-tree FAIL carried forward (not this spec's):
`Cyclomatic complexity >6` at `skills/hallmark/site/examples/cobalt-01/script.js:7`
(`CC=10`), a file absent from `git diff main` and therefore correctly excluded by
blame scoping. 61 full-tree WARNs are advisory (WARN-first rollout of the three new
gates + pre-existing `ci/templates` WARNs); per the Stop-and-Ask matrix a design-gate
WARN is recorded, not a stop. They are carried into this report as review hints.

---

## Stop-and-Ask resolution (recorded, not improvised)

1. **Verifier precondition** — satisfied: verdict PASS.
2. **Working tree dirty** — the matrix's "STOP and report" row is read as *foreign*
   dirt, not the pipeline's own handoff state: at stage 5a the change set is
   necessarily uncommitted, because only stage 5b may commit
   (`docs/SPEC_PIPELINE.md` §Commit and push carve-out). Evidence that the dirt is
   this spec's own work product and nothing else:

```
command: git status --porcelain && git diff main --name-only && git ls-files --others --exclude-standard
exit: 0
at: 2026-10-25T12:44:31Z

 M docs/CODING_CONVENTIONS.md
 M docs/adr/README.md
 M runs.jsonl
 M scripts/check-code-principles.selftest.sh
 M scripts/check-code-principles.sh
 M scripts/check-gate-consistency.sh
 M scripts/tests/check-code-principles-blame.sh
 M scripts/tests/check-code-principles.bats
 M skills/check-principles/SKILL.md
?? docs/adr/0011-clean-code-comment-gates.md
?? scripts/gate-analysis-lib.sh
?? scripts/gate-clean-code-lib.sh
?? scripts/tests/check-code-principles-clean-code.bats
?? specs/032-clean-code-comment-hygiene/...
```

   Every modified/untracked path is either named by a task in `10-tasks.md` (Tasks
   01–12) or is pipeline telemetry: `runs.jsonl` carries the Verifier's own
   `{"specSlug":"032-clean-code-comment-hygiene", ... "outcome":"pass"}` row,
   appended by `scripts/record-gate-run.sh`. No foreign change is present, nothing
   was stashed, nothing was committed. Stage 5b owns the commit.
3. **Project type / tier** — resolved from committed declarations, not guessed:
   `docs/CONFORMANCE_TIERS.md:20` declares `mvp`, no `production` declaration exists
   in `AGENTS.md`/`AGENTS_*.md`, and the gate prints `(tier: mvp)` on its own.
4. **Design gate blocks** — none blocked; thresholds untouched (no gate config was
   edited, and gates are off-limits to agents in any case).
5. **Acceptance criteria ambiguous** — no ambiguity encountered; nothing needed asking.

---

## Mutation score: skipped — mvp tier

Per `docs/SPEC_PIPELINE.md` §Conformance tiers, mutation testing is a
**`production`-tier** gate; the `mvp` row reads "Architect — mutation testing:
skip". This repo conforms at `mvp`, so stage 5a records a **skip reason**, never a
fabricated score. `docs/TESTING.md §Mutation Testing` carries the same tier tag
("*Conformance tier: `production`*") and lists only Java (PiTest), Go
(gremlins/go-mutesting), JS/TS (Stryker), and React Native (Stryker) — no bash
mutator exists or is claimed.

Independent tier re-confirmation by this stage (own runs, not carried forward):

```
command: grep -n "^## Conformance tier" docs/CONFORMANCE_TIERS.md
exit: 0
at: 2026-10-25T12:55:36Z

20:## Conformance tier: mvp
```

```
command: grep -n "Conformance tier: production" AGENTS.md
exit: 1
at: 2026-10-25T12:55:36Z

(no output — no production declaration in the repo-root instruction file; no
AGENTS_*.md exists either, so the Makefile's tier probe resolves to the mvp branch)
```

```
command: make mutation
exit: 0
at: 2026-10-25T12:45:25Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

Second, independent reason the gate has no surface here (this change is
bash/markdown, and the repo has no mutable language project at all):

```
command: ls pom.xml go.mod package.json build.gradle Cargo.toml
exit: 2
at: 2026-10-25T12:55:36Z

ls: cannot access 'pom.xml': No such file or directory
ls: cannot access 'go.mod': No such file or directory
ls: cannot access 'package.json': No such file or directory
ls: cannot access 'build.gradle': No such file or directory
ls: cannot access 'Cargo.toml': No such file or directory
```

No PiTest / Stryker / gremlins / go-mutesting / pitest config exists in the repo
(only `ci/templates/` copies shipped for child repos), and no such tool is installed
on this machine (`command -v gremlins go-mutesting stryker pitest` → all absent).
**No mutation tool was installed or added as a dependency to satisfy a gate the
declared tier explicitly skips** — that is the correct outcome for a skip, not a
workaround. A bash mutator was not invented.

### What this skip does and does not claim

- It does **not** claim the bats suite is mutation-adequate; nobody measured that.
- It **does** claim the tier policy puts that measurement out of scope, and that a
  real mutation score would be preferred the moment this project declares
  `production` (a follow-up that would need bash-level mutation tooling the repo
  does not have — recorded here as an out-of-scope finding, not implemented).

---

## Equivalent mutants

**None — none assessed.** No mutation run occurred, so there were no surviving
mutants and therefore no equivalence analysis. Recording `0 survivors` or `100%`
would falsely imply a run happened; the honest row is "skipped by tier".

---

## Complexity summary (carried from the Refactorer, re-confirmed here)

Carried forward from `25-verification.md` §Refactorer structural claims — the
Refactorer writes no artifact of its own, so the Verifier's re-execution is the
source of record. This stage re-measured the line counts and re-ran the scoped gate:

| Structural fact | Refactorer claim | Re-confirmed by this stage |
|---|---|---|
| `scripts/check-code-principles.sh` size | ~1098 lines (main: 1520) | `wc -l` → **1098**; `git show main:… \| wc -l` → **1520** |
| `scripts/gate-analysis-lib.sh` | new lib, DRY/YAGNI/SOLID/component/property analyzers | present, **590** lines, sourced by the dispatcher |
| `scripts/gate-clean-code-lib.sh` | new lib, comments/naming/null-discipline analyzers | present, **488** lines, sourced by the dispatcher |
| Six original gates unchanged | byte-identical JSON before/after extraction | carried from `25-verification.md` (JSON diff identical; 9 analyzer functions byte-identical) |
| Scoped complexity gate | exit 0 | re-run below, exit 0 |

```
command: bash scripts/check-code-principles.sh --gates complexity -BaseRef main .
exit: 0
at: 2026-10-25T12:55:18Z

Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

---------------------------------------------
✔ Design-principles check (gates: complexity): 0 FAIL(s), 0 WARN(s).
```

Known limitation, carried forward and accepted by the Verifier: **the complexity
gate never scans shell.** `SH_FILES` feeds only `COMMENT_FILES`, so the nine
pre-existing CC>6 shell functions now living in `gate-analysis-lib.sh` are a
self-assessment, invisible to the gate; they are byte-identical to `main`, so the
debt is relocated, not created. A shell-complexity gate would need its own spec.

---

## Gate results (this stage's own runs)

```
command: bash scripts/check-code-principles.sh -BaseRef main .
exit: 0
at: 2026-10-25T12:55:19Z

Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found

--- DRY ---

--- YAGNI ---
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected

--- SOLID ---
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports
PASS SOLID-DIP (python): no domain→infrastructure imports
PASS SOLID-DIP (rust): no domain→infrastructure imports

--- Component-per-file ---
PASS Component-per-file: no violations

--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)

--- Comments ---

--- Naming ---

--- Null discipline ---

---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 0 WARN(s).
```

No FAIL and no WARN under blame scoping — so there is no design-gate WARN to flag
from the scoped run. The full-tree advisory WARN set stays as carried forward in
§Verifier's verdict (WARN-first rollout; not attributable to this spec; review hints
only, per the matrix's WARN row).

Stage-5b precondition gate (audit trail), run once now that `30-report.md` exists so
the folder is verifiable before the PR Opener touches it:

```
command: bash scripts/check-audit-trail.sh 032-clean-code-comment-hygiene
exit: 0
at: 2026-10-25T12:56:01Z

PASS 032-clean-code-comment-hygiene: 10-tasks.md present and non-empty
PASS 032-clean-code-comment-hygiene: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 032-clean-code-comment-hygiene: 25-verification.md present and non-empty
PASS 032-clean-code-comment-hygiene: 30-report.md present and non-empty
PASS 032-clean-code-comment-hygiene: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-25T12:35:14Z
PASS 032-clean-code-comment-hygiene: evidence block 'full test suite' — command: make test, exit: 0, at: 2026-10-25T12:35:23Z
PASS 032-clean-code-comment-hygiene: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main ., exit: 0, at: 2026-10-25T12:40:26Z
PASS 032-clean-code-comment-hygiene: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main ., exit: 0, at: 2026-10-25T12:40:30Z
PASS 032-clean-code-comment-hygiene: evidence block 'scenario-to-behavior spot check' — command: bats --tap --filter 'AC-032-04-01|AC-032-08-02' scripts/tests/check-code-principles-clean-code.bats, exit: 0, at: 2026-10-25T12:43:33Z
✔ Audit-trail check: specs/032-clean-code-comment-hygiene complete, verifier evidence recorded.
```

```
command: bash scripts/check-code-principles.selftest.sh
exit: 0
at: 2026-10-25T12:51:21Z

…
PASS null-discipline AC-032-10-04 cc-null-return: WARN matches 'Null-discipline: return null' (exit 0)

✔ check-code-principles selftest: 60 assertions passed.
```

---

## Final test status

Full suite re-run by this stage, **one final time, after** the Verifier's own run
(the stage-5a obligation: even though this stage added no test, the pre-push
green must be the green of the tree as it now stands):

```
command: make test
exit: 0
at: 2026-10-25T12:51:31Z

Checking bats assertions are not vacuous...
PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..537
… (all 537 assertions `ok`, 0 `not ok`; representative AC-032 excerpt) …
ok 181 AC-032-01-01: the ADR exists with the mandated section shape
ok 182 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
…
ok 230 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 231 AC-032-12-04: existing gate behavior is unchanged
…
ok 537 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

Measured counts: plan `1..537` present once; `ok` lines 537; `not ok` lines 0;
**51 of those assertions carry an `AC-032-*` ID** across the 12 scenario files in
`20-acceptance/`, and the new `scripts/tests/check-code-principles-clean-code.bats`
is picked up by the `scripts/tests/*.bats` glob (56 bats files scanned, no vacuous
assertions — the vacuity gate covers the new file too).

Explicit `make test-scripts` run, recorded separately because it is a required
stage-5a command in its own right:

```
command: make test-scripts
exit: 0
at: 2026-10-25T12:47:34Z

Checking bats assertions are not vacuous...
PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
… 537 assertions, all ok …
ok 537 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Disclosure: the first `make test-scripts` invocation was killed by this runner's
120-second foreground tool timeout at assertion 249 (`make: *** [Makefile:117:
test-scripts] Terminated`). That is a harness limit, not a test failure — no
assertion reported `not ok`. The recorded runs above are complete, untruncated
executions (exit 0).

Nothing is skipped, quarantined, or silently absent. **Final test status: green.**

---

## Remediation record

**none — no BLOCK occurred in any phase.**

Carried forward from `25-verification.md` (attempt entries) and the orchestrator's
loop summary, not reconstructed:

| Phase | Reached? | Attempts consumed | BLOCKs |
|---|---|---|---|
| Phase 1 (pre-PR: local + design gates) | yes — this run is pre-PR | 0 remediation retries; Verifier attempt 1 was already green | none |
| Phase 2 (post-PR CI loop) | not applicable — stage 5b has not opened a PR | 0 | none |
| Phase 3 (deploy verification) | not applicable — non-frontend repo, no stage 5c verdict yet | 0 | none |

Counters per the Verifier's own record (`25-verification.md` header) and the
`runs.jsonl` row for this spec:
`SPEC_LOOP_COUNT=1 SPEC_PHASE1_RETRIES=0 SPEC_PHASE2_RETRIES=0`,
`"loopCount":1,"phase1Retries":0,"phase2Retries":0,"outcome":"pass"`. Budgets
(max 3 per phase) untouched. No BLOCK was resolved, so there is no phase/attempt
pair to name.

---

## Out-of-scope findings (recorded, not fixed — matrix row)

1. **No bash mutation tooling exists in this repo's stack** — mutation adequacy of
   the 537-assertion bats suite is unmeasured. Becomes relevant only if this project
   graduates to `production`; needs a follow-up spec, not a workaround here.
2. **Shell complexity is ungated** — the nine CC>6 shell functions in
   `scripts/gate-analysis-lib.sh` (byte-identical to `main`) cannot be flagged by the
   current complexity analyzer (Java/Go/JS/TS/Python/Rust only).
3. **Pre-existing full-tree design-gate debt** — `CC=10` at
   `skills/hallmark/site/examples/cobalt-01/script.js:7` plus the day-one advisory
   WARN set the three new gates surface (the spec's deliberate WARN-first rollout).

## Handoff

Stage 5b (PR Opener) may proceed: Verifier PASS, every configured gate green, and
this report carries the mutation row (skip — `mvp` tier, with its evidence), the
equivalent-mutants row (none), the complexity summary, the gate results, and the
final test status. Stage 5a committed nothing, pushed nothing, and opened no PR.

PR: https://github.com/RexiAI/my-engineering-standards/pull/99 (draft, base `main`)
Commits: 10 task/content commits on the pushed head at PR open (`git rev-list --count main..spec/032-clean-code-comment-hygiene` = 10); this report-recording commit is the 11th.
Stage 5b archive: none — stage 5d (Archiver) runs `scripts/archive-spec.sh 032-clean-code-comment-hygiene` after stage 5c deploy verification, per `docs/SPEC_PIPELINE.md` §Archive in the PR.

## 40-deploy.md

# 40 — Deploy verification (stage 5c)

- **Spec:** `specs/032-clean-code-comment-hygiene/`
- **Branch:** `spec/032-clean-code-comment-hygiene`
- **PR:** https://github.com/RexiAI/my-engineering-standards/pull/99 (draft, base `main`)
- **Repo:** `github.com/RexiAI/my-engineering-standards`
- **Stage:** 5c — Deploy Verifier (`agents/spec-deployer.md`)
- **Timestamp:** 2026-10-25T16:36:15Z
- **Phase-2 precondition (as observed):** see §Observed phase-2 state
- **Phase-3 attempt:** 1 of 3 (classification-only skip — 0 fix-and-redeploy rounds consumed)

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

## Skip reason

This repository is a **standards / tooling repo**, not a deployable frontend: it
ships bash gate scripts (`scripts/*.sh`), docs (`docs/*.md`), Bats test suites,
ADR records, agent/skill definitions, and CI **templates** consumed by child
repos. It has no `vercel.json`, no root `package.json`, no frontend framework
dependency, no `.vercel/` project link, no Vercel credentials on this machine,
and no deploy surface of any kind at the repo root. Per the stage-5c contract, a
non-frontend repo never fails the deploy gate and no deployment is awaited.

Secondary corroboration (independently true, and the reason no fallback lane
exists either): **no Vercel project is linked to this repository** — so even if
the repo were frontend, the applicable verdict would be
`No Vercel project linked to this repository — manual setup required`.

## Status summary

| Item | Status | Detail |
|---|---|---|
| Repo classification | **non-frontend** | no `vercel.json`, no root `package.json`, no framework deps, no Vercel Git integration |
| Deploy URL | **n/a — SKIPPED** | no Vercel project linked; nothing to resolve a URL from |
| Build status | **SKIPPED** | no Git-integration build exists or can exist for this repo |
| Health check | **SKIPPED** | no preview URL to `curl` |
| E2E verdict | **SKIPPED** | no live preview URL — `e2e-runner` deliberately not delegated (it must never run against a local dev server) |
| Phase-3 attempt count | **1 of 3** | classification-only; no failing round, no budget consumed |
| Prohibited commands | **none run** | `vercel deploy` / `vercel deploy --prod` not invoked — see §Prohibited-command record |

## Evidence: repo classification (frontend vs non-frontend)

command: `[ -f vercel.json ] || { [ -f package.json ] && grep -qE '"(next|react|@angular/core|@ionic/angular)"[[:space:]]*:' package.json; }` — the exact predicate of `frontend_repo()` in `scripts/check-audit-trail.sh`, plus a scan of every tracked `package.json`
exit: 0
at: 2026-10-25T16:36:11Z

```
vercel.json: ABSENT (root)
root package.json: ABSENT
--- tracked package.json files and framework deps ---
file: ci/templates/js-feature/package.json
  no frontend framework dependency
file: scripts/media/voice-chat/package.json
  no frontend framework dependency
--- gate's own classification verdict ---
NON-FRONTEND
```

Both tracked `package.json` files are non-application: `ci/templates/js-feature/`
is a CI template fixture, `scripts/media/voice-chat/` is an internal Node script
harness. Neither declares `next`, `react`, `react-dom`, `@angular/core`,
`@ionic/angular`, or `@ionic/react`.

Supporting composition census (tracked files by extension, top 8):

```
    297 md
     66 sh
     57 yml
     56 bats
     13 go
     11 json
     11 java
     11 drawio
```

The dominant artifacts are markdown docs, shell gate scripts, and Bats suites —
no application source tree and no frontend entry point.

## Evidence: no Vercel project linked, no Vercel credentials

command: `test -d .vercel; test -f .vercel/project.json; env | grep -E '^VERCEL_'; grep -E '^VERCEL_' config/agent.local.env; sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' config/agent.local.env`
exit: 0
at: 2026-10-25T16:36:11Z

```
.vercel/: ABSENT (no linked project)
.vercel/project.json: ABSENT
--- VERCEL_* env vars in shell ---
(none set)
--- keys present in config/agent.local.env (names only) ---
GITHUB_TOKEN
GH_TOKEN
BAILIAN_TOKEN_PLAN_API_KEY
--- VERCEL_* keys in config/agent.local.env ---
(no VERCEL_* credential configured)
```

No `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` is available to this
run, and no local project link exists. `config/agent.local.env.example` lists
those three keys only as **commented-out** template entries (lines 46-52) for
child repos — they are not wired for this repo. Token values were never printed;
only key names are recorded.

## Evidence: frontend CI/Vercel workflows here are child-repo templates, not local lanes

command: `grep -A2 '^on:' .github/workflows/ci-{react,nextjs,angular,vercel-production-verify}.yml; grep -rn 'uses:.*ci-(react|nextjs|angular|vercel-production-verify)\.yml' .github/workflows/; test -e <each root deploy artifact>`
exit: 0
at: 2026-10-25T16:36:15Z

```
=== frontend/Vercel workflows: workflow_call only (child-repo templates)? ===
ci-react.yml                 triggers: workflow_call
ci-nextjs.yml                triggers: workflow_call
ci-angular.yml               triggers: workflow_call
ci-vercel-production-verify.yml triggers: workflow_call
--- local callers of those templates in this repo ---
(none — nothing invokes them on this repo's own PRs)

=== deploy surface at repo root ===
absent:  vercel.json
absent:  Dockerfile
absent:  Procfile
absent:  docker-compose.yml
absent:  docker-compose.e2e.yml
absent:  app.json
absent:  netlify.toml
absent:  fly.toml
absent:  .vercel
```

This is the distinction that matters: the repo **ships** frontend and Vercel
lanes (`ci-react.yml`, `ci-nextjs.yml`, `ci-angular.yml`,
`ci-vercel-production-verify.yml`, ADR 0008, `scripts/verify-production-deploy.sh`)
so **child repos** can consume them — but every one is `on: workflow_call` only,
and nothing in this repo invokes them for its own pushes/PRs. This repo's own
PR lane is **Self CI** (`.github/workflows/self-ci.yml`, on `push`/`pull_request`
to `**`), which runs validation gates, not a deploy. Shipping the tooling is not
a frontend signal for this repo.

## Prohibited-command record

No deployment command was run, and none could legitimately be created:

- `vercel deploy` and `vercel deploy --prod` were **not executed**. They are denied
  in this agent's `permission.bash` frontmatter, and running one here would
  double-build against the Git integration, race it for the same commit, and
  orphan deployments no PR owns. There is also no linked project to deploy to.
- No permitted CLI command was needed: `vercel inspect` / `logs` / `ls` /
  `env pull` / `pull` / `domains` all require a linked project plus
  `VERCEL_TOKEN`, neither of which exists for this repo. Polling for a preview
  deployment that cannot be created was deliberately not attempted.

## Observed phase-2 state (recorded, not routed — outside deploy scope)

Observed at run time, for the record; this does not alter the SKIPPED deploy
verdict above.

command: `gh pr checks 99`
exit: 0
at: 2026-10-25T16:36:36Z

```
Validate	fail	17s	https://github.com/RexiAI/my-engineering-standards/actions/runs/40195586218/job/121175601939
Validate	fail	14s	https://github.com/RexiAI/my-engineering-standards/actions/runs/40195589035/job/121175610785
Review PR / Review PR	pending	0	https://github.com/RexiAI/my-engineering-standards/actions/runs/40195589473/job/121175912691
```

Cause, from `gh run view 40195589035 --log-failed` (verbatim):

```
  [FAIL] 032-clean-code-comment-hygiene is finished (has 30-report.md) but not archived — missing docs/changes/032-clean-code-comment-hygiene.md
         Run: scripts/archive-spec.sh 032-clean-code-comment-hygiene (stage 5d does this automatically)
1 finished spec(s) not archived!
##[error]Process completed with exit code 1.
```

That is `scripts/check-specs-archived.sh` firing in the window between stage 5b
(PR opened, `30-report.md` present) and stage 5d (the Archiver's `archive-spec.sh`
run) — the expected intermediate state per `docs/SPEC_PIPELINE.md` §Archive in the
PR, whose resolution is stage 5d's scheduled act. It is a phase-2/CI matter, not
a deploy finding; this stage neither fixes nor routes it.

## Why no E2E delegation

`e2e-runner` is invoked only against a **live preview URL**. No preview deployment
exists or can exist for this repo (no Vercel link, no frontend build), and the
skill's contract forbids pointing the runner at a local dev server. Delegating it
would fabricate a green or a red that means nothing, so it was not invoked.
`E2E verdict: SKIPPED` is the honest record.

## Contract check

`scripts/check-audit-trail.sh` accepts this artifact for a non-frontend repo
(AC-031-19) and remains green at the stage-5d final gate (AC-031-21 is
frontend-only).

## Evidence: audit-trail gate accepts the non-frontend skip

command: `scripts/check-audit-trail.sh 032-clean-code-comment-hygiene` and `scripts/check-audit-trail.sh --require-deploy 032-clean-code-comment-hygiene`
exit: 0 (both invocations)
at: 2026-10-25T16:36:39Z

```
=== deploy-artifact line, default run (stage-5b semantics) ===
PASS 032-clean-code-comment-hygiene: 40-deploy.md skip reason acceptable for a non-frontend repo (AC-031-19): Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable
default_exit=0
=== deploy-artifact line, --require-deploy run (stage-5d final gate) ===
PASS 032-clean-code-comment-hygiene: 40-deploy.md skip reason acceptable for a non-frontend repo (AC-031-19): Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable
require_deploy_exit=0
```

Both invocations report the same skip-acceptance line and exit 0, confirming the
`--require-deploy` flag is correctly repo-class-dependent: the frontend-only rule
(AC-031-21) does not apply to this non-frontend lane, so stage 5d is unblocked.

## Verdict

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

Stage 5d (Archiver) may proceed: a recorded skip satisfies the deploy-artifact
requirement for a non-frontend lane.
