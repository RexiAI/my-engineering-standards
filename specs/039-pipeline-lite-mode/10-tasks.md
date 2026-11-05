# 039 — Pipeline lite mode: tasks

Lite mode runs Coder → Verifier → PR Opener and skips Refactorer, Mutation
Runner, UX Designer, and Deploy Verifier. Selection is mechanical (explicit
token or deterministic classifier), logged in `45-decisions.md`, overridable by
the human, and refused on conformance tier `production`.

## Open questions (must be answered before `/build`)

- **Q1 — size threshold N (BLOCKED).** The informal spec says "<N lines
  changed" without a value, and also mentions "docs-only, single script".
  Exactly which mechanical inputs decide `lite`? Proposed default, pending human
  confirmation: `lite` iff every path named in `10-tasks.md` is under `docs/`,
  `specs/`, or is a `*.md` file, OR the spec names exactly one file under
  `scripts/`; and the summed acceptance-scenario count is ≤ 5. Scenarios in
  AC-039-02 are written against these named inputs and must be re-pinned if Q1
  changes them.
- **Q2 — tier scope (BLOCKED).** The informal spec forbids lite on tier
  `production`. Does the refusal also apply to `multi-service` (a superset of
  `production` gates per `docs/CONFORMANCE_TIERS.md`)? Scenarios currently
  refuse `production` only; AC-039-03-03 is marked pending Q2.
- **Q3 — tier source.** Which file/command yields the repo's tier for the
  classifier? If undetectable, the Stop-and-Ask matrix default (`mvp`) applies —
  but defaulting to `mvp` could permit lite on an undeclared production repo.
  Scenarios assume: undetectable tier ⇒ lite refused (conservative). Confirm.

## Task 1 — Lite trigger detection script

`scripts/lite-trigger.sh` (plus `.ps1` twin if the repo convention requires one)
answers: did the human request a mode explicitly?

- Exit/stdout contract: prints exactly one of `lite`, `full`, `auto`.
- Any single argv element equal to `lite` case-insensitively ⇒ `lite`.
- Any single argv element equal to `full` case-insensitively ⇒ `full`.
- Both present ⇒ non-zero exit, stderr names the conflict, prints nothing on stdout.
- Neither ⇒ `auto`.
- Whole-token match only: `--lite`, `lite-mode`, `mylite` do not match.
- Commands and agents must call this script; no re-implementation of the match
  (grep-checkable: no other file matches the token comparison).

## Task 2 — Deterministic size/surface classifier

`scripts/classify-spec-size.sh specs/NNN-slug` prints `lite` or `full` and one
`Reason:` line on stdout.

- Inputs are only files inside the spec folder (`10-tasks.md`, `20-acceptance/`);
  no network, no model call, no clock dependence.
- Same input files ⇒ byte-identical output across runs.
- Rule per Q1 (pending). `full` whenever any rule input is missing or unparsable.
- Missing spec folder ⇒ non-zero exit with stderr message.

## Task 3 — Tier guard

Lite is never selected on tier `production`.

- Resolved mode is `full` whenever the detected tier is `production`, even if
  the human passed `lite`; the refusal is reported (stderr) and recorded.
- Undetectable tier ⇒ `full` (per Q3, pending).
- `mvp` tier ⇒ mode follows Task 4 resolution.
- Guard lives in one script (resolution in Task 4); no agent re-implements it.

## Task 4 — Mode resolution and decision logging

`scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]` combines Task 1–3
and writes one entry to `specs/NNN-slug/45-decisions.md` using the existing
six-line format (`Condition:`, `Options:`, `Chosen:`, `Why:`,
`Reversibility:`, `At:`) via `scripts/autopilot-decisions.sh` or the same format.

- Precedence: tier guard > explicit human token (Task 1) > classifier (Task 2).
- Explicit `full` overrides a classifier `lite`; explicit `lite` overrides a
  classifier `full` (human override), subject to the tier guard.
- `Chosen:` is `lite` or `full`; `Why:` names the deciding input
  (`tier`, `argument`, or `classifier` + its `Reason:`).
- Exactly one entry appended per invocation; existing entries untouched.
- Writes only inside `specs/NNN-slug/`.

## Task 5 — `/build` stage selection in lite mode

`commands/build.md` (and orchestration wiring it references) runs stages per the
resolved mode.

- `lite`: stages run in order Coder → Verifier → PR Opener (5b) → Archiver (5d).
  Refactorer, Mutation Runner, UX Designer, Deploy Verifier are not invoked.
- `full`: stage list unchanged from current behaviour.
- PR Opener precondition in lite: requires Verifier PASS; `30-report.md` records
  `Pipeline mode: lite` and lists skipped stages with `skipped (lite)`; the
  mutation section reads `skipped (lite)` rather than missing, so the "report
  green" check still passes.
- `scripts/check-orchestration.sh` exits 0 after the change.

## Task 6 — Verifier hard gates unchanged in lite

- In lite mode the Verifier still runs: full test suite, secrets scan
  (`scripts/check-no-hardcoded-secrets.sh`), `scripts/check-code-principles.sh`
  (FAIL blocks), scenario traceability.
- A FAIL from any of these yields Verifier FAIL and the pipeline STOPs per the
  Stop-and-Ask matrix; no PR opened.
- Remediation budget rules unchanged.

## Task 7 — Documentation and ADR

- New ADR `docs/adr/NNNN-pipeline-lite-mode.md` from `templates/ADR.md`, status
  `Proposed`, listed in `docs/adr/README.md`.
- `docs/SPEC_PIPELINE.md` gains a `## Lite mode` section stating: trigger tokens,
  classifier script, precedence, tier refusal, skipped stages, retained gates,
  `45-decisions.md` logging, and a link to the ADR.
- `docs/SPEC_PIPELINE.md §Conformance tiers` table gains a lite column or note.
- `scripts/check-orchestration.sh` and `scripts/check-skills.sh` exit 0.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Q1: small = only docs/, specs/, *.md, or exactly one scripts/ file, AND <=5 scenarios.
- Q2: lite refused on `multi-service` too.
- Q3: unknown tier => lite refused.
