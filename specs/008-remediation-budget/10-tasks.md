# Tasks — Bounded remediation budget

Formalization of `specs/008-remediation-budget/00-informal.md`. Goal: every
gate-failure loop in the spec pipeline is bounded — max 3 fix attempts per
phase, two independent phases (pre-PR and post-PR), exhaustion stops the
pipeline and escalates to the human with the failing gate IDs and last
evidence. This is a prompts/docs-only spec: it changes the pipeline's
prompts and documentation, and touches no new infrastructure.

## Grounded reality (verified against this repo)

- **The phase-1 loop lives in two places, and today it is not a loop.** Both
  `commands/build.md` (lines 11-18) and `agents/spec-pipeline.md` (lines
  20-30) describe the `/build` flow as: coder → refactorer → verifier →
  mutation-runner → pr-opener, with a **one-shot stop** on Verifier FAIL —
  "stop and relay its report; do not attempt to fix the failure yourself".
  There is no re-delegation back to Coder/Refactorer and no attempt cap. The
  bounded loop the informal spec describes must be written into these two
  files; that is where the budget becomes enforceable, not just documented.
- **`agents/spec-verifier.md` has no budget and no scoped re-verification.**
  Its "On failure" section (lines 90-94) says the human or "a re-run of
  Coder/Refactorer" re-triggers it — with no cap and no instruction to re-run
  only the failing gates on a re-trigger. The verifier's only edit permission
  is `specs/*/25-verification.md` (frontmatter lines 8-9), so recording a
  re-verification attempt index there needs no permission change.
- **`agents/spec-coder.md` and `agents/spec-refactorer.md` have no re-fix cap.**
  Neither prompt mentions re-fixing a Verifier BLOCK at all. The informal
  spec's loop names both as the fixers ("Verifier BLOCK → Coder/Refactorer"),
  so both need the "stop re-fixing after 3" language. AC-002 names only the
  Coder; the Refactorer's inclusion is implied by the loop description — see
  open question 3.
- **`agents/spec-mutation-runner.md` writes `30-report.md`** (description,
  lines 2 and 64-70) and is the only writer of it; `spec-pr-opener` reads it
  as its precondition and `scripts/archive-spec.sh` consumes it. The phase +
  attempt record (informal AC-004) must be added to the Report section of
  this prompt. The record can be carried from the verifier's `25-verification.md`
  attempt entries (task 2) — nothing about the report's other sections changes.
- **`docs/SPEC_PIPELINE.md` has no remediation-budget section.** The
  "Commit and push carve-out" (line 172) says "Any gate failure halts the
  pipeline. Nothing is committed." — that halt now means *after budget
  exhaustion*, so the new section must reconcile with that wording to keep
  the doc internally consistent. The artifact-layout line for `30-report.md`
  (line 57) says "mutation score, complexity, gate results" — it may also
  gain the remediation record, but the authoritative statement lives in the
  new section.
- **No "re-run until green" phrasing exists anywhere in agents/, commands/,
  or docs/ today** (verified by repo-wide grep). AC-003 only *adds* the
  prohibition; nothing needs to be removed.
- **Spec 014 (`specs/014-ci-failure-remediation/00-informal.md`, exists)
  implements the post-PR CI loop** and explicitly says "mirror the
  remediation-budget spec". 008 is the budget *policy* (both phases, both
  counters, exhaustion behavior, audit record); 014 is the phase-2 loop
  *mechanism* (query CI, read logs, fix-and-repush). 008 must document the
  phase-2 budget and the independent-counter rule, but must not build the
  CI-query machinery — that would duplicate 014. See open question 2.

## Tasks

### Task 1 — Document the remediation budget in `docs/SPEC_PIPELINE.md`

Add a section (e.g. `## Remediation budget`, placed after "Commit and push
carve-out" so it reads as the continuation of the halt rule) that states the
policy the informal spec requires. No other doc changes.

Acceptance criteria:
- The section names **Phase 1 — Pre-PR loop** (local gates and design gates;
  a Verifier BLOCK hands back to Coder/Refactorer) and states its budget is
  **max 3**.
- The section names **Phase 2 — Post-PR loop** (CI gates, after the push)
  and states its budget is **max 3**, with the counter **independent of
  Phase 1**.
- The section states that exhausting either budget stops the pipeline, emits
  the failing gate IDs and the last evidence, and escalates to the human.
- The exact string `re-run until green is forbidden phrasing` appears
  verbatim in the section (informal AC-003 requires the verbatim phrase).
- The section states that on a BLOCK the Verifier re-runs **only the failing
  gates** (scoped re-verification), not the whole suite.
- The section states that `30-report.md` records which phase and attempt
  count each BLOCK was resolved at, so budget exhaustion is auditable.
- The section reconciles with the "Commit and push carve-out" wording
  (docs/SPEC_PIPELINE.md:172, "Any gate failure halts the pipeline") so the
  doc reads consistently: a gate failure triggers remediation up to the cap,
  and only the post-exhaustion stop is the halt the carve-out describes.
- The section describes the *policy* for Phase 2 only — it must not specify
  CI-query or log-reading mechanics (that is spec 014's territory).
- No other sections of the file change beyond this addition and, if the
  Coder chooses, the `30-report.md` artifact-layout line (line 57).

Scenarios: `20-acceptance/AC-008-01-remediation-budget-doc.md`

### Task 2 — Encode the budget and scoped re-verification in `agents/spec-verifier.md`

Update the Verifier prompt so the budget and the scoped re-verification rule
are part of its instructions.

Acceptance criteria:
- The prompt states the Verifier stops relaying BLOCKs after **3** per phase
  (phase-1 cap): it must not expect or accept a 4th re-verification of the
  same BLOCK.
- The prompt states that on a re-trigger it performs **scoped re-verification**:
  it reads its prior `25-verification.md`, re-runs only the gates that
  previously failed, and records per-gate results for just those gates.
- The prompt requires recording the **re-verification attempt index and
  phase** in `25-verification.md` on every re-verification, so the attempt
  count is auditable and `30-report.md` (task 5) can carry it forward.
- The prompt's "On failure" section keeps "stop the pipeline / do not fix
  anything yourself" but reflects the cap: the final BLOCK report names the
  failing gate IDs and the last evidence, and states the phase-1 budget is
  exhausted (this is what the orchestrator escalates verbatim).
- The verifier's frontmatter is unchanged — no permission changes; the
  existing `edit: specs/*/25-verification.md` allowance already covers the
  attempt-record write.
- The prompt does not gain "re-run until green" or any equivalent
  open-ended re-run phrasing.

Scenarios: `20-acceptance/AC-008-02-verifier-budget.md`

### Task 3 — Encode the re-fix cap in `agents/spec-coder.md` and `agents/spec-refactorer.md`

Add the bounded re-fix rule to both fixer prompts.

Acceptance criteria:
- `agents/spec-coder.md` states the Coder stops re-fixing after **3** attempts
  per BLOCK: on the 3rd fix that still fails, it does not accept another
  re-fix request, and hands back with the failing gate IDs and the last
  evidence for escalation.
- `agents/spec-refactorer.md` states the same cap for structural re-fixes:
  max 3 per BLOCK, exhaustion = report and do not accept further re-fix
  requests.
- Neither prompt changes its frontmatter or permission rules.
- Neither prompt gains "re-run until green" or any equivalent open-ended
  re-run phrasing.
- The existing "do not commit or push" constraints in both prompts are
  unchanged.

Scenarios: `20-acceptance/AC-008-03-fixer-budget.md`

### Task 4 — Make the Phase-1 loop bounded in `commands/build.md` and `agents/spec-pipeline.md`

Replace the one-shot stop-on-FAIL with a bounded loop, in both the `/build`
command and the orchestrator prompt. These are the files that actually run
the loop, so this task is where the budget is enforced.

Acceptance criteria:
- Both `commands/build.md` and `agents/spec-pipeline.md` describe a bounded
  phase-1 loop: on a Verifier BLOCK, re-delegate the failing fix back (Coder
  for behavior failures, Refactorer for structural/complexity failures), then
  re-invoke the Verifier for scoped re-verification — up to **3** cycles.
- Both files state that on the 3rd BLOCK the pipeline stops, relays the
  failing gate IDs and the last evidence from `25-verification.md` verbatim,
  and escalates to the human; there is no 4th re-delegation.
- Neither file contains "re-run until green" phrasing.
- Stage-5 agents (mutation-runner, pr-opener) still run only after a Verifier
  PASS — which, under the budget, may now be a post-remediation PASS.
- The phase-1 loop language must not contradict the phase-2 budget: the files
  acknowledge (at most one sentence) that a separate post-PR CI loop exists
  with its own independent max-3 budget, but they do not implement that loop
  (spec 014's territory).
- No new files, agents, or infrastructure are introduced.

Scenarios: `20-acceptance/AC-008-04-orchestrator-loop.md`

### Task 5 — Record phase + attempt count in `30-report.md` via `agents/spec-mutation-runner.md`

Add the remediation record to the report the Mutation Runner writes.

Acceptance criteria:
- The Report section of `agents/spec-mutation-runner.md` (lines 64-70)
  requires a **remediation record** in `30-report.md`: for each BLOCK that
  occurred during the run, the phase (1 or 2) and the attempt count at which
  it was resolved; or an explicit `none` when no BLOCK occurred.
- The prompt instructs the Mutation Runner to carry the record forward from
  `25-verification.md` (the verifier's attempt-index entries from task 2) and
  from the orchestrator's loop summary — not to invent or guess it.
- The prompt states that if no `25-verification.md` attempt information is
  present, the record says so rather than fabricating a phase/attempt.
- No other Report section items change (verifier verdict, mutation score,
  complexity summary, equivalent mutants, final test status all stay).
- The frontmatter and the stage-5a responsibilities ("does not commit, push,
  or open PRs") are unchanged.

Scenarios: `20-acceptance/AC-008-05-report-remediation-record.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 docs document both phases, max-3 budgets, independent-counter rule | 1 | `AC-008-01-remediation-budget-doc.md` |
| AC-002 spec-verifier.md and spec-coder.md encode the budget | 2, 3 | `AC-008-02-verifier-budget.md`, `AC-008-03-fixer-budget.md` |
| AC-003 "re-run until green is forbidden phrasing" verbatim in pipeline docs | 1 | `AC-008-01-remediation-budget-doc.md` |
| AC-004 30-report.md records phase + attempt count | 1 (policy), 5 (implementation) | `AC-008-01-remediation-budget-doc.md`, `AC-008-05-report-remediation-record.md` |

## Open questions (need a human answer before /build)

1. **How are the acceptance scenarios tested?** This spec changes only
   markdown prompts/docs, and its scenarios assert file *content* (e.g. "the
   file contains the string ..."). This repo's existing test surface is shell
   checks (`scripts/check-orchestration.sh`, `make validate-refs`) wired into
   self-ci. Options: (a) add a small `scripts/check-remediation-budget.sh`
   (grep-based content assertions) wired into `.github/workflows/self-ci.yml`
   — the traceability gate then has real tests, mirroring spec 006; or (b) no
   script, tests assert via the repo's existing harness. Option (a) is new
   infrastructure, which the informal spec says to avoid unless implied —
   but the pipeline's traceability gate requires scenario IDs cited by real
   tests, and grep-asserting a docs change is the repo's established pattern.
   My recommendation: (a). Confirm before `/build`.
2. **Boundary with spec 014 (`014-ci-failure-remediation`).** 014 (informal,
   present) will implement the post-PR CI loop mechanics and says "mirror the
   remediation-budget spec". Confirm 008 defines budget *policy* for both
   phases plus the phase-1 prompt changes and the `30-report.md` record, and
   that 014 lands the phase-2 loop *mechanism* — and that 008 should land
   first (014 depends on its language).
3. **Refactorer inclusion.** Informal AC-002 names `spec-verifier.md` and
   `spec-coder.md` only, but the loop description explicitly routes BLOCKs to
   "Coder/Refactorer". Task 3 extends the cap to `spec-refactorer.md` on that
   implication. Confirm that is the intended reading; drop it if the budget
   is meant to apply only to the Coder.
4. **Who owns the attempt counter.** The informal spec says the verifier
   "stops relaying BLOCKs after 3" — either the orchestrator stops
   re-invoking it (counter in build.md/spec-pipeline.md, verifier just
   records the index) or the verifier itself refuses a 4th invocation. My
   recommendation: orchestrator-owned counter (task 4) with the verifier
   recording the index (task 2) — otherwise the verifier has no reliable way
   to know its attempt number without state. Confirm.
5. **Exhaustion leaves no `30-report.md`.** If phase 1 exhausts its budget,
   mutation-runner and pr-opener never run, so `30-report.md` is never
   written — the audit trail for *exhaustion* lives in the verifier's final
   `25-verification.md` BLOCK report plus the orchestrator's escalation
   summary. Informal AC-004 covers the "resolved at phase/attempt" record;
   exhaustion is a different artifact. Confirm that split is acceptable, or
   say the orchestrator should write a minimal `30-report.md` on exhaustion.
