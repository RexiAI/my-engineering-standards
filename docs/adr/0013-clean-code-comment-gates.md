# ADR 0013: Clean Code comment hygiene and naming gates

## Status

Proposed

## Context

Clean Code Ch.4 ("Comments") is usually quoted for its bluntest line — a comment
is "always a failure" — but the same chapter then endorses a long list of
comment kinds and explains why each earns its place. Read as a blanket ban, the
chapter argues against the code it was written to protect. Read as it was
written, it draws a line between **endorsed** comments (intent, rationale,
warnings of consequence, legal headers, tool directives, public-API
documentation) and **forbidden** ones (commented-out code, redundant comments
that restate the next line, TODO/FIXME notes with no owner or issue reference,
section-divider banners, attribution comments such as `@author`).

`scripts/check-code-principles.sh` covers KISS, DRY, YAGNI, SOLID,
component-per-file and property tests. It does not look at comments at all, and
it does not look at naming — the two Clean Code chapters (Ch.2 "Meaningful
Names", Ch.4 "Comments") with the highest mechanical-detectability in this
repo's languages. Ch.7 ("Don't Return Null" / "Don't Pass Null") is the third:
its two shapes are cheap textual tests and its cost is paid at the call site.

Two facts constrain the design. First, this repo *relies* on comment kinds a
naive ban would delete: every shell script opens with `#!/bin/bash` plus a
usage/rationale header block; several carry `# shellcheck disable=` directives;
the pipeline's own convention embeds machine-readable `# ponytail:` and
`# standards:allow-` markers in source. A gate that flagged those would be
turned off within a day, and correctly so. Second, spec 011's
`AC-011-03-07` asserted that no `naming` gate exists — a gate-catalog change of
this kind therefore supersedes that assertion explicitly rather than silently
contradicting it.

`docs/GOVERNANCE.md §ADR Requirement` makes an ADR mandatory for any change to
the gate catalog before it merges. This is that ADR.

## Decision

Add three gates to `scripts/check-code-principles.sh`, taking the catalog from
six names to nine: `comments`, `naming`, `null-discipline`.

**`comments` — redundant-comment elimination, never a comment ban.** Two
blocking-class rules: `commented-out code` (two or more consecutive code-shaped
comment lines) and `comment restates the following line` (the comment's token
set is a subset of the next physical code line's token set). Three advisory
rules that are WARN in every mode and never emit FAIL: `TODO/FIXME without an
issue reference`, `section-divider comment`, `attribution comment`.

**The allowlist is part of the decision, not an afterthought.** A comment line
is skipped for every rule when it sits on one of the first five lines of the
file (shebang and header block); contains `shellcheck`, `noqa`, `type: ignore`,
`pragma`, `ponytail:`, `standards:allow-`, `SPDX-License-Identifier`,
`Copyright`, `Licensed under`, `@license`, or a URL (`http://`, `https://`);
sits in a `/** ... */` doc block immediately followed by a
`public`/`protected`/`export` declaration; or sits in a `///` run or Go `//`
run immediately followed by a public-API declaration (`pub`, `func <Upper>`,
`type <Upper>`). Suppression is per line or per doc block, never per file — a
violating comment at line 6 or later in an allowlisted file is still reported.

**Coverage.** The `comments` gate scans the eight existing extensions (`java`,
`go`, `ts`, `tsx`, `js`, `jsx`, `py`, `rs`) plus `*.sh`, with paths under
`docs/`, `specs/`, `agents/`, `templates/` and `node_modules/` excluded — prose
and agent prompts are not code, and a Markdown-shaped "comment" has no meaning
here. Block-comment syntax is parsed only for the C-family/Rust extensions;
shell and Python comments run from `#` to end of line.

**`naming`** applies the five advisory heuristics to the eight existing
extensions, non-test files only, and never to shell (positional parameters and
uppercase environment conventions make the heuristics noise): a
single-character identifier other than `i`/`j`/`k`/`_`, a noise word
(`Manager`, `Processor`, `Helper`, `Util`, `Data`, `Info`) in a type name, an
encoded (Hungarian) identifier prefix, a boolean flag parameter whose name does
not read as a predicate, and a function with more than three parameters.

**`null-discipline`** reports `return null` and a `null` literal passed as a
call argument. Comparisons, local assignments and ternary branches are not
reported. Java/JS/TS only — Python and Rust nullability semantics differ.

**Rollout is WARN-first.** All three gates are WARN by default so the change
cannot turn any consumer repo red on day one. `STRICT_CLEAN_CODE=1` — only the
literal value `1` — is the opt-in that promotes the two blocking-class comment
rules to FAIL; `--blocking comments` achieves the same through the existing
blocking-set mechanism, so `-BaseRef` blame semantics still apply (pre-existing
debt in a touched file stays WARN; a diff-overlapping or fully-added line
FAILs). `naming` and `null-discipline` are advisory-only and never emit FAIL,
whatever the blocking set or environment says. Findings in `.py`/`.rs` files
stay WARN even under `STRICT_CLEAN_CODE=1`, preserving ADR 0006 D6's warn
phase.

**Supersession.** This ADR supersedes spec 011's `AC-011-03-07` assertion that
no `naming` gate exists. That assertion is inverted (not deleted) in
`scripts/tests/check-code-principles-blame.sh`: `--blocking naming,complexity`
must run and report `naming` findings as WARN, while `test-delta` remains the
unknown-gate negative case.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| **A. Blanket comment ban ("a comment is always a failure")** | Trivial to implement and to state; no allowlist to maintain | Deletes exactly the comments the repo depends on: shebangs, `shellcheck` directives, usage header blocks, `ponytail:` and `standards:allow-` markers, licence headers, public-API doc blocks. Also misreads Clean Code Ch.4, which endorses those kinds. **Rejected** |
| **B. Delegate comments to a per-language linter** | Real parsers, no heuristic false positives | One more tool and config per language (nine extensions across five stacks), and no existing linter covers "comment restates the next line" in any of them. Breaks the gate's single-script, zero-config property (cf. ADR 0006 Alternative C). **Rejected** |
| **C. Ship all three gates blocking immediately** | Enforcement from day one | This repo alone carries thousands of shell comment lines; a blocking rollout would fail every consumer on the first standards bump with no remediation window — the failure mode ADR 0006 D6 exists to avoid. **Rejected** |
| **D. Three advisory gates, WARN first, opt-in `STRICT_CLEAN_CODE=1` (chosen)** | Cannot turn a tree red on day one; the strict switch is per-pipeline, not per-repo baked in; heuristics can be calibrated before promotion | The gates are advisory until someone opts in, so drift is only visible, not stopped; the comment heuristics are shape tests, not parsers |

## Consequences

**Easier:** comment hygiene and naming become reviewable and mechanically
reportable — the Reviewer no longer has to argue about a restating comment, and
the Verifier gets a gate it can cite. The catalog is still one script with one
`valid_gate` list, so `scripts/check-gate-consistency.sh` remains the single
source of truth, now at nine gates.

**Harder:** `check-code-principles.sh` grows by three analyzers and three
dispatch blocks, and the comment analyzer needs real cross-line context
(consecutive runs, the next physical line, doc-block spans), which the existing
single-line heuristics never did. Every consumer that hard-coded the gate count
or the valid-gate string must move in the same change:
`scripts/check-gate-consistency.sh` (count 6 → 9),
`scripts/tests/check-code-principles-blame.sh` (inverted `AC-011-03-07`,
nine-name expectations), `docs/CODING_CONVENTIONS.md` §Design Principles and
`skills/check-principles/SKILL.md`.

**Constrains:** adding a gate is still a catalog change and still needs an ADR
(`docs/GOVERNANCE.md §ADR Requirement`). `naming` and `null-discipline` are
permanently advisory unless a later ADR promotes them; `comments` promotion is
opt-in per run, not per repo.

**Accepted risk:** the shapes are heuristics. A prose comment ending in `)` or
an unusual assignment line can be misread as commented-out code; a
two-consecutive-line test is the mitigation. Calibration against real consumer
trees is the condition for ever making `comments` blocking by default.

## Compliance

- `scripts/check-code-principles.sh` — the three gates, the allowlist, the
  `STRICT_CLEAN_CODE=1` promotion, and the nine-name catalog/help text.
- `scripts/check-code-principles.selftest.sh` — one fixture group per rule
  (`comments-out-code`, `comments-restate`, `comments-advisory`,
  `comments-allowlist`, `naming-heuristics`, `null-discipline`), each asserting
  both directions: the violation fires at the documented severity and the
  near-miss/allowlisted control fires nothing.
- `scripts/check-gate-consistency.sh` — must exit 0 with nine gates, proving
  every error message, doc and test still agrees with `valid_gate`.
- `scripts/tests/check-code-principles-clean-code.bats` — the acceptance
  scenarios, one test per `AC-032-NN-MM`, picked up by `make test-scripts`.
- Contract tests that must stay green unchanged: cyclomatic complexity 7 still
  FAILs, complexity 6 still passes, and the six original gates report nothing
  new on their existing fixtures.
