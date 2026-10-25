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
