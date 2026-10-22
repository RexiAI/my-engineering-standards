# ADR 0012: Structural cleanliness rules and opt-in god-file enforcement

## Status

Proposed

## Context

A 2026-10-15 independent review of a spec-pipeline child repo (owner verdict:
the shipped code was "slop") produced 17 findings. Thirteen were repo-local
refactors; the recurring core was structural, not stylistic:

1. **Regex surgery on assembled HTML** in the render layer
   (`input.replace(/(<input\b[^]*?)>/, …)` to inject aria attributes) — markup
   reassembled after escaping, unlintable, duplicate id-derivation inside the
   same expression.
2. **A 436-line orchestration god-file** carrying stop-message prose and
   read-model assembly, flagged `SRP: possible god file` by
   `check-code-principles.sh` on *every* run — and ignored every run, because
   the gate classifies god-files as WARN for non-TSX languages. A WARN that
   recurs forever is noise; teams learn to skip the gate's output.
3. **Polymorphic success bodies**: one HTTP route answered two shapes under
   200 (stopped-state object vs data array) while sibling routes mapped the
   same condition to 503 — no single status contract per surface.
4. **The same report→message mapping copied five times** across CLI, JSON API
   and HTML form surfaces that share one service layer.

Two further review items were standards gaps rather than repo defects: the
gate's YAGNI check counts only production implementations (a port with a real
adapter plus a test fake reads as "one implementation"), and nothing caps
spec-provenance changelog prose in code headers.

Separately, the owner asked whether the standards should prescribe **NestJS**
("it now supports nest.js") so code comes out cleaner. Fact-check: NestJS
appears in upstream prose (`language-specific/javascript/PATTERNS.md` §NestJS
Backend Patterns, CODING_CONVENTIONS, DEPLOYMENT, CI_CD) but there is **no
TypeScript/NestJS language guide, template, or gate** even at upstream 1.36.1.
All thirteen refactor findings are framework-agnostic: they survive any
migration to NestJS, which would add ~30 transitive dependencies and a build
step to a loopback, single-operator, 16-route console for zero finding
reduction.

## Decision

1. **Rules now, in `docs/CODING_CONVENTIONS.md`** (§Structural cleanliness for
   web surfaces): no regex post-processing of assembled markup; HTTP
   boundaries return Results for expected failures with one status contract
   per surface; one shared mapper per report shape across surfaces.
2. **Opt-in blocking god-file enforcement**: `STRICT_GOD_FILE=1` promotes the
   general >400-lines/>15-methods god-file check from WARN to FAIL in
   `check-code-principles.sh`. Default unchanged (WARN) so no consumer goes
   red overnight; cleaned repos flip it in CI and keep it honest.
3. **Mechanical checks for rules 1 and 3 land later, as WARN heuristics**
   (regex-literal `.replace(` over markup-shaped variables in render
   directories; `throw` inside HTTP handler files for non-exceptional paths),
   promoted to FAIL only after the promotion criteria below.
4. **No framework prescription.** NestJS prose stays as the escalation path in
   `language-specific/javascript/PATTERNS.md` for multi-consumer services;
   loopback operator consoles stay stdlib by recorded decision.

## Promotion criteria (rules 1 and 3 heuristics, WARN → FAIL)

- Zero false positives across this repo's own tree and two consumer repos for
  30 days, evidenced by their CI logs;
- each heuristic ships a `--self-test`-style fixture proof in the gate's
  selftest, per the `check-ci-sweeper.sh` pattern;
- an escape-hatch comment marker (`// standards:allow-markup-surgery <reason>`)
  reviewed case-by-case, mirroring the `// ponytail:` convention.

## Alternatives considered

- **Promote god-file to FAIL for everyone now**: rejected — turns existing
  consumer code red; violates the repo's own WARN-means-review-hint contract
  (AGENTS.md §General Rules) without an adoption path.
- **Prescribe NestJS (or Express/Fastify) for web surfaces**: rejected — the
  findings are framework-agnostic; dependency and build-step cost is
  unjustified for loopback consoles; SECURITY.md §Dependency Management
  requires justifying each dependency, and a blanket prescription inverts
  that burden.
- **Leave everything as prose**: rejected — item 2 shows prose-plus-WARN
  produces permanently ignored findings; the opt-in FAIL gives cleaned repos
  a way to *stay* clean.

## Consequences

- Consumers get three citable rules for review and an adoption path for
  blocking enforcement.
- The gate grows one env-var branch; default output unchanged, so existing
  audit trails (spec-pipeline `25-verification.md` evidence blocks) keep
  comparing cleanly.
- The YAGNI test-fake blind spot and code-header provenance cap are tracked
  as follow-ups, not folded into this ADR's gate changes.

## Compliance

- `docs/CODING_CONVENTIONS.md` §Structural cleanliness for web surfaces.
- `scripts/check-code-principles.sh` `STRICT_GOD_FILE` branch (this ADR cited
  in-code).
- Follow-up issues: markup-surgery and boundary-throw heuristics with
  selftest fixtures; YAGNI test-dir implementation counting; header-provenance
  cap.
