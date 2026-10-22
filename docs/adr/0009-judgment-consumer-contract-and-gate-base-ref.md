# Judgment consumer contract and AC-024-01-12 base-ref semantics

## Title

Judgment consumer contract (criteria shape, backend-aware credential gate) and
the AC-024-01-12 change-set gate: shallow-clone base ref plus the
documented-pipeline-change semantics

## Status

Accepted

## Context

The typed-judgment layer (ADR 0004, ADR 0005) has two consumers in the shipped
pipeline surface: `skills/ci-triage/SKILL.md` and `agents/spec-ux.md`. Both
prompt their agent to call `scripts/typed-judgment.sh` with a Choice question.
Two defects made the fast-path silently dead, and fixing them exposed a third
problem in the gate that is supposed to protect this surface:

1. **Request shape.** The judgment API's OpenAPI schema types the criteria
   field of a Choice question as an object keyed by the option names (an array
   for Score, object-or-null for Noul). `agents/spec-ux.md` still carried the
   pre-#94 shape — criteria as a flat string plus a separate options array.
   A string criteria is rejected with HTTP 422, which the wrapper reports as
   exit 10 — the same code as "not configured" — so the failure is silent.
   PR #94 fixed the ci-triage skill and documented the shape contract in the
   wrapper header; `agents/spec-ux.md` carried the same defect unfixed.

2. **Credential gate.** `agents/spec-ux.md` demanded both `JUDGMENT_API_URL`
   and `JUDGMENT_API_KEY` be set and non-empty before using the fast-path,
   but `scripts/typed-judgment.sh` (per ADR 0005) requires only the URL when
   `JUDGMENT_BACKEND` is local — the local backend serves open and needs no
   key. A consumer stricter than the script it calls silently skips a working
   fast-path on every local-backend machine.

3. **Gate that never ran.** The AC-024-01-12 content contract in
   `scripts/check-pr-review.sh` guards that the shipped spec-pipeline agent
   surface (`agents/spec-*.md`) does not change silently. Its change-set half
   computed the touched files with `git diff --name-only origin/main HEAD`,
   falling back to `HEAD^`. Under `actions/checkout`'s default
   `fetch-depth: 1` (self-ci), `origin/main` does not exist and neither does
   `HEAD^`: the change set came out empty and the clause passed **vacuously on
   every PR ever run**. Fixing the resolution makes the spec-ux.md edits above
   hit the clause for real — and the clause as originally worded ("no change
   ever") would block the very defect fix it is supposed to police.

Additionally, the wrapper normalized per-question `usage` only from inside each
answer object; the local backend returns usage at the response top level, so
telemetry recorded `usage: 0` for every live local call.

## Decision

1. **Criteria-shape contract, both consumers.** `agents/spec-ux.md` sends the
   criteria field as a JSON object keyed by the option names (run / skip /
   ambiguous), mirroring the shape ci-triage adopted in PR #94. The options
   array is retained: the API ignores unknown keys, and the AC-028-32b content
   contract pins `"options":["run","skip","ambiguous"]` in the shipped prompt.

2. **Backend-aware credential gate.** The spec-ux fast-path gate requires
   `JUDGMENT_API_URL` always and `JUDGMENT_API_KEY` only when the backend is
   not local — the identical rule `scripts/typed-judgment.sh` applies and the
   wording ci-triage carries since PR #94.

3. **AC-024-01-12 change-set semantics (content-contract amendment).** The
   guard's intent is that the shipped pipeline surface — which child repos
   consume as a `.standards/` submodule — must not change *silently*. The
   amendment keeps that intent and makes the check real:
   - Base ref resolves in shallow clones: prefer an exported
     `GITHUB_BASE_SHA` (the pull_request payload base), else a `--depth=1`
     fetch of `GITHUB_BASE_REF` diffed against the fetched tip, else
     `origin/main` in a full clone. **When no base can be resolved the check
     FAILs loudly; a check that cannot determine the change set must not
     report PASS.**
   - A change set that touches `agents/spec-*.md` **passes** when the same
     change set also adds or modifies a `docs/adr/*.md` record — a deliberate,
     documented pipeline change — and still **fails** when undocumented.
   - The change set is the base-to-working-tree diff plus untracked paths, so
     in-progress (uncommitted) work is evaluated honestly while CI's clean
     checkout behaves identically to base-to-HEAD.

   This is a content-contract amendment with justification, following the
   house precedent: `AC-010-05-06` was amended when the first ADR landed
   (recorded inline in `scripts/check-governance.sh`), and spec 031 amended
   `AC-024-01-12`'s roster count the same way. The tests encoding the old
   behavior (`scripts/tests/check-pr-review.bats`,
   `scripts/check-pr-review.selftest.sh`) are extended — not deleted — to pin
   all three outcomes: undocumented spec-agent change fails, documented one
   passes, unresolvable base fails loudly.

4. **Top-level usage fallback.** The wrapper's normalization uses the response
   top-level `usage` object (`{total_tokens}` or `{input_tokens,
   output_tokens}`) for every question when the per-answer object carries
   none. Per-answer usage still wins; hosted responses without top-level
   usage normalize exactly as before.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Drop the AC-024-01-12 change-set clause once base resolution works | simplest | deletes a guard that exists precisely to protect the child-repo surface; undocumented changes become legal |
| Keep "never touch agents/spec-*" absolute | strictest | blocks every intentional pipeline fix (this one included) — the guard becomes change-hostile rather than change-documented |
| `fetch-depth: 0` in self-ci instead of base-ref resolution | one-line workflow change | full-history fetch on every run; still passes vacuously whenever the clone is shallow for any other reason; the script stays fragile |
| Fail-open (pass) when base unresolvable | keeps push runs green | restores exactly the silent-vacuous pass this fix exists to eliminate |

## Consequences

- The spec-ux fast-path works on local-backend machines without a key, and a
  malformed (string) criteria payload can no longer survive in a shipped
  prompt.
- AC-024-01-12 becomes a live gate: pipeline-surface edits now require an ADR
  in the same change set. Every future intentional agent change costs one ADR
  row — that friction is the point; silent submodule-surface changes were
  passing unguarded for the entire life of the check.
- Push-event CI runs with no base ref available fail loudly on this clause
  until `GITHUB_BASE_REF`/`origin/main` resolution exists; loud beats the old
  silent-vacuous behavior.
- Telemetry from local calls carries a real token figure.

## Compliance

- `scripts/typed-judgment.sh` header documents the per-type criteria shapes
  and the top-level usage fallback; `scripts/tests/typed-judgment.bats` pins
  the usage shapes (top-level input/output, top-level total_tokens,
  precedence, hosted absence).
- `scripts/tests/typed-judgment-integration.bats` pins the shipped prompt
  content (AC-028-32b options array; AC-028-38 gate wording including
  `JUDGMENT_API_KEY`, `JUDGMENT_API_URL`, `unchanged`).
- `scripts/check-pr-review.sh` AC-024-01-12 enforces the amended change-set
  semantics; `scripts/tests/check-pr-review.bats` and
  `scripts/check-pr-review.selftest.sh` carry hermetic fixtures for the
  pass/fail/loud-fail outcomes.
- Live verification against the running local backend for both consumer
  payloads (exit 0, non-zero usage) is recorded in the PR's verification
  evidence.

## Notes

- 2026-10-22: Decision recorded. Supersedes nothing; amends the content
  contract of `AC-024-01-12` (change-set half only — the roster half is
  unchanged), which gains a documented-change escape hatch: a change set that
  touches `agents/spec-*.md` is accepted only when a `docs/adr/*.md` change
  accompanies it.
- 2026-10-22: Base resolution refined after CI showed the first form failing on
  the `push`-event run of `Self CI`. `GITHUB_BASE_REF` is exported only for
  `pull_request` events, and at `fetch-depth: 1` there is no `HEAD^` either, so
  a push event has no base *by definition*. The clause is therefore reported
  **not applicable** on a non-`pull_request` CI event, with the reason printed,
  while a `pull_request` event with no resolvable base still **fails loudly**.
  The distinction matters: skipping a clause that cannot apply to this event is
  honest, whereas the pre-fix behaviour — an empty change set passing silently
  on the very event that does have a base — was the vacuity this ADR exists to
  remove. Both paths are pinned by hermetic tests that control
  `GITHUB_EVENT_NAME` explicitly, because CI exports it and a test that does not
  pin it would assert different things locally and in CI.
- `AC-029-74` is deliberately **not** amended. It asserts the working tree
  equals `HEAD` for the two consumer files; that holds again as soon as this
  change is committed, so spec 029's delta contract survives intact and needs
  no escape hatch. An amendment was drafted and then reverted for that reason —
  adding one would have weakened a contract that was not actually in the way.
- References: ADR 0004 (typed-judgment layer), ADR 0005 (local backend serves
  open — the credential-gate rule), PR #94 (ci-triage precedent for both the
  criteria shape and the gate wording).
