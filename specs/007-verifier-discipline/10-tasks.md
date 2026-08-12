# Tasks — Verifier mechanical-transcription discipline

Formalization of `specs/007-verifier-discipline/00-informal.md`. Goal: harden
`agents/spec-verifier.md` and the two Verifier gate scripts
(`scripts/check-code-principles.sh`, `scripts/check-scenario-traceability.sh`)
with three rules the repo currently lacks:

1. **Script-is-authority** — the Verifier's verdict is a transcription of the
   gate script's exit code and JSON, never a judgment that overrides a
   deterministic gate.
2. **Missing/errored script = BLOCK, not pass** — a gate that fails to run is a
   tooling failure, never a green marked by reasoning about what the script
   "would have" checked.
3. **Scoped re-verification** — on a BLOCK fix, re-run only the failing gates,
   not the whole suite; combine with the prior full report.

## Grounded reality (verified against this repo)

- `agents/spec-verifier.md` defines checks 1, 2, 3, 3.5, 4, 5 (lines 42-76) and a
  report contract (`25-verification.md`, lines 80-88): each check is PASS/FAIL
  with the actual command and real output, the design-principles gate's exit code
  and every FAIL/WARN line verbatim, spot-check results, and an overall
  PASS/FAIL verdict. **It has no script-is-authority rule, no tooling-failure
  handling, and no BLOCK verdict.** A script that silently mis-runs would still
  be transcribed as the gate's verdict. There is no "re-verify only the failing
  gates" instruction anywhere in the file.
- `scripts/check-code-principles.sh` has flags `--tier mvp|production|multi-service`
  and `--warn-as-error` (lines 69-76) — double-dash kebab-case style — plus a
  positional `SOURCE_DIR`. Exit codes today: 0 = no FAILs, 1 = findings, 2 =
  unknown option (line 73). **It has no scoped/subset flag and no machine-readable
  output.** It runs five gate categories in sequence: Complexity/KISS, DRY, YAGNI,
  SOLID (SRP/OCP/LSP/ISP/DIP sub-checks), and Property-tests (lines 498-533).
  Because the script uses `set -euo pipefail` with `|| true` swallows on the
  tooling paths (e.g. `find` at lines 92-94, `xargs awk 2>/dev/null || true` at
  line 219), a missing tool such as `awk`/`find` is currently swallowed into a
  false PASS — exactly the "mark the gate green without checking" failure mode
  rule 2 forbids.
- `scripts/check-scenario-traceability.sh` has no flags at all — only positional
  `SPECS_DIR` / `SOURCE_DIR` (lines 30-31). It runs two checks: check 1 = every
  scenario heading in `specs/*/20-acceptance/` is referenced by a test (lines
  62-71); check 2 = every `AC-NNN-NN` reference in source/test files resolves to a
  real scenario heading (lines 75-83). Exit codes today: 0 = clean, 1 =
  violations (lines 87-92), with early exit 0 when there is nothing to check (no
  specs dir, lines 36-39; no scenario headings, lines 48-51). No scoped flag, no
  JSON.
- Neither script uses `jq` today. The informal spec's "missing jq" is an
  illustrative example carried verbatim into rule 2's text (see AC-001 and the
  open question).
- The informal spec's rule 1 says the verdict is "a transcription of the gate
  script's exit code and JSON". Neither script emits JSON today, so task 3/4 add a
  `--json` mode; otherwise the verbatim AC-001 text would reference a thing that
  does not exist.
- Sibling specs also touch these files: `008-remediation-budget` (Verifier BLOCK
  budget, scoped re-verification, modifies `spec-verifier.md`), `012-gate-selftests-telemetry`
  (adds `-ReportPath`/`-BaseRef` telemetry flags to the gate scripts and a
  selftest harness), `014-ci-failure-remediation` (post-PR CI loop). The flags
  added here (`--gates`, `--checks`, `--json`) do not collide with those, but the
  three specs must coordinate on `agents/spec-verifier.md` wording and the gate
  scripts' flag surface (see open questions).

## Tasks

### Task 1 — Verifier states script-is-authority and missing-script = BLOCK verbatim

Add rule 1 and rule 2 to `agents/spec-verifier.md` exactly as worded below, and
add BLOCK as a third report verdict.

Acceptance criteria:
- `agents/spec-verifier.md` contains, verbatim (same words, same order, same
  punctuation as quoted here), the script-is-authority rule:

  > The script is the authority. The Verifier's verdict is a transcription of the
  > gate script's exit code and JSON, never a judgment that overrides it. If its
  > own reading of a diff disagrees with a deterministic gate, the gate wins.

- `agents/spec-verifier.md` contains, verbatim, the missing/errored-script rule:

  > A missing/errored script is a BLOCK, not a pass. If check-code-principles.sh
  > or check-scenario-traceability.sh fails to run (missing file, jq absent,
  > non-zero for a reason other than a finding), the Verifier reports a tooling
  > failure — it must not mark the gate green by reasoning about what the script
  > "would have" checked.

- The report section of `agents/spec-verifier.md` defines three verdicts, not
  two: **PASS** (gate green), **FAIL** (gate ran and produced findings), and
  **BLOCK** (gate could not run, or exited non-zero for a reason other than a
  finding). Both FAIL and BLOCK stop the pipeline; BLOCK's report line names the
  tooling failure explicitly. The verdict transcription comes from the gate's
  exit code and its output — for the two script gates, this is
  `scripts/check-code-principles.sh` and `scripts/check-scenario-traceability.sh`
  with the exit code and JSON/output reproduced, not paraphrased.
- No other behavioral change: checks 1-5 (and 3.5) keep their current order,
  commands, and semantics. This task only adds the two rules and the BLOCK
  verdict to the prompt.

Scenarios: `20-acceptance/AC-007-01-verifier-script-authority.md`

### Task 2 — Verifier documents scoped re-verification for BLOCK fixes

Document, in `agents/spec-verifier.md`, that a BLOCK fix is re-verified by
re-running only the failing gate(s), and that the re-run is a delta appended to
the existing report.

Acceptance criteria:
- `agents/spec-verifier.md` contains a "scoped re-verification" instruction
  stating: when a BLOCK (or FAIL) is fixed, re-run only the gate(s) that blocked,
  not the whole suite. "Gate" here means one of the Verifier's checks (1,
  traceability; 2, test suite; 3, complexity linter; 3.5, design-principles; 4,
  spot check; 5, no-unaccounted-behavior). For the script-backed gates, use the
  script's scoped flag to narrow further where the script supports it.
- It states that a one-line fix must not re-run every scan: the unchanged gates'
  prior results stand; only the failing gate(s) are re-executed.
- It documents the scoped flags available to the Verifier for this purpose:
  `--gates` on `scripts/check-code-principles.sh` (re-run only the failing
  principle category) and `--checks` on
  `scripts/check-scenario-traceability.sh` (re-run only the failing traceability
  check). If a gate is a single whole script with no subset, the whole script is
  re-run — that is still scoped relative to the full suite.
- It states that the re-verification result is appended to the existing
  `specs/NNN-slug/25-verification.md` under the gate it belongs to, preserving
  the prior full run's content (the report is the combined full run + delta, not
  a rewrite), and that the overall verdict reflects the re-run.

Scenarios: `20-acceptance/AC-007-02-verifier-scoped-rereverify.md`

### Task 3 — `check-code-principles.sh`: `--gates` scoped flag, `--json`, tooling-failure exit code

Extend `scripts/check-code-principles.sh` so the Verifier can re-run a single
gate category, get machine-readable output to transcribe, and never get a false
PASS from a swallowed tooling failure.

Acceptance criteria:
- New `--gates <comma-list>` flag in the script's existing double-dash kebab-case
  style (same parser as `--tier` / `--warn-as-error`). Gate names, matching the
  five categories the script already runs: `complexity` (CC + KISS), `dry`,
  `yagni`, `solid` (all five SOLID sub-checks as a unit), `property-tests`. Only
  the listed gates run; the summary reflects the subset.
- `--gates` combines freely with `--tier`, `--warn-as-error`, and the positional
  `SOURCE_DIR` without conflict.
- Unknown gate name or empty value → message to stderr, exit 2 (the script's
  existing unknown-option exit code).
- New `--json` flag: prints a single JSON object to stdout describing the run —
  at minimum `{ "tier": …, "gates": […], "fails": [ { "message": …, "file": …,
  "line": … } ], "warns": [ … ] }` with the same findings the human-readable
  output reports, and exits with the same code as the non-JSON run. Human-readable
  output is unchanged when `--json` is absent.
- Exit-code contract becomes: 0 = no FAILs; 1 = at least one FAIL (or a WARN with
  `--warn-as-error`); 2 = the script could not perform its check for a
  non-finding reason (missing tool such as `awk`/`find`/`xargs`, unusable source
  scan, or usage error). The current `|| true` swallows on the tooling paths are
  removed or hardened so a missing tool cannot turn into exit 0. The existing
  "no source files — nothing to check" case stays exit 0.
- Default behavior with no `--gates` / `--json` is byte-for-byte the current
  behavior (all five gates, human output, exit 0/1), so nothing else regresses.

Scenarios: `20-acceptance/AC-007-03-principles-scoped-flag.md`

### Task 4 — `check-scenario-traceability.sh`: `--checks` scoped flag, `--json`, tooling-failure exit code

Extend `scripts/check-scenario-traceability.sh` so the Verifier can re-run a
single traceability check, get machine-readable output, and never get a false
PASS from a swallowed tooling failure.

Acceptance criteria:
- New `--checks <list>` flag (its two checks are named by number: `1` = every
  scenario heading is traced to a test, `2` = every test-referenced ID resolves
  to a real heading). Only the listed checks run. The existing positional
  `SPECS_DIR` / `SOURCE_DIR` arguments keep working.
- New `--json` flag: prints a single JSON object with `passes` and `fails`
  entries mirroring the human output, and exits with the same code as the
  non-JSON run. Human-readable output unchanged when `--json` is absent.
- Exit-code contract becomes: 0 = clean; 1 = findings (orphaned scenario or
  dangling reference); 2 = could not perform the check for a non-finding reason
  (tooling failure or usage error). The existing "nothing to check" early exits
  (no specs dir, no scenario headings) stay exit 0.
- `--checks` and `--json` combine with each other and with the positional
  arguments; unknown check number or empty list → stderr message, exit 2.
- Default behavior with no new flags is the current behavior.

Scenarios: `20-acceptance/AC-007-04-traceability-scoped-flag.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 script-is-authority + missing-script = BLOCK verbatim | 1 | `AC-007-01-verifier-script-authority.md` |
| AC-002 scoped re-verification documented in spec-verifier.md | 2 | `AC-007-02-verifier-scoped-rereverify.md` |
| AC-003 gate scripts support a `-Gates`-style scoped flag | 3 + 4 | `AC-007-03-principles-scoped-flag.md`, `AC-007-04-traceability-scoped-flag.md` |

## Open questions (need a human answer before /build)

1. **`--json` is a new capability the informal spec implies but no script has.**
   Rule 1 says the verdict transcribes "the gate script's exit code and JSON",
   and AC-001 requires that text verbatim — but neither gate script emits JSON
   today. Tasks 3/4 add `--json` so the verbatim rule is grounded in a real
   artifact. If you'd rather not add JSON output, AC-001's verbatim text must
   drop "and JSON" and the transcription contract reverts to "exit code and
   output lines" (what spec-verifier.md already requires). My recommendation:
   keep `--json` — it makes the transcription discipline mechanically checkable
   and gives `25-verification.md` a stable, diffable transcript.
2. **Exit-code 2 (could-not-run) is a new contract on both scripts.** Today a
   swallowed tooling failure (e.g. missing `awk`) passes silently because of the
   `|| true` paths. Rule 2 says "non-zero for a reason other than a finding" is a
   BLOCK, but the scripts must actually emit a distinguishable code for the
   Verifier to act on. Task 3/4 define 0/1/2 and harden the swallows. Confirm the
   Verifier treats exit 2 (and any non-0/1) as BLOCK and exit 1 as FAIL.
3. **Cross-spec coordination.** `008-remediation-budget` and `012-gate-selftests-telemetry`
   also edit `agents/spec-verifier.md` and the gate scripts (008: BLOCK budget +
   scoped re-verification wording; 012: `-ReportPath`/`-BaseRef` flags). The
   flags proposed here do not collide, but the verifier-prompt wording and the
   script flag surface are shared seams — these specs should land in the same
   batch or be reviewed together so the wording is consistent.
4. **"missing jq" is carried verbatim though neither script uses jq.** It is an
   illustrative example in the informal rule text, and AC-001 demands the text
   verbatim, so it stays. Confirm you're happy for spec-verifier.md to cite
   "missing jq" as an example tooling failure even though the two named scripts
   do not depend on jq.
