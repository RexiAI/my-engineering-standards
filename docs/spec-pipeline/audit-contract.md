# Audit contract, evidence, and definition of done (shared)

Shared reference for every stage that writes evidence. Read it from the stage
file that names it; the index is `docs/SPEC_PIPELINE.md`.

## Audit contract

Every pipeline stage leaves a specific, machine-checkable trace behind, in the
artifact the index's §Artifact layout already defines — no new spec-folder artifacts. An
artifact may assert anything, but the assertion is only as good as the evidence
recorded with it. This section is that contract; `scripts/check-audit-trail.sh`
enforces it mechanically at pipeline end (see §The gate below).

### What each stage leaves behind

| Stage | Evidence artifact(s) | What it must record |
|---|---|---|
| Specifier | `10-tasks.md` + `20-acceptance/` | Task acceptance criteria and scenario IDs (`AC-NNN-NN`) |
| Coder | the tests in the project suite carrying `AC-NNN-NN` IDs | Leaves no report artifact — the build/test commands it ran and their exit codes are re-recorded by the Verifier in `25-verification.md` |
| Refactorer | gates re-run by the Verifier | The gates it applied (complexity, duplication, property tests) with before/after measurements — re-recorded by the Verifier; the complexity summary is carried into `30-report.md` |
| Verifier | `25-verification.md` | Per check: the exact command, its real output, its exit code, and a timestamp |
| Mutation Runner | `30-report.md` | Mutation score (or skip reason), equivalent mutants, final test status |
| PR Opener | `30-report.md` | PR URL and commit count, appended after the PR opens |
| Deploy Verifier | `40-deploy.md` | Deploy URL, build status (pass/fail/skip), health check status, E2E verdict (pass/fail/skip), timestamp, phase-3 attempt count, verdict (PASS/FAIL/ESCALATED/SKIPPED) |

The Coder and Refactorer deliberately leave no report artifact. Their claims
become auditable not because they write them down, but because the Verifier
re-executes every claim and records the command and exit code in
`25-verification.md` — a claim that was never re-run is a gap in the audit
trail, and the gate fails the folder for it.

### The five Verifier checks

`25-verification.md` must record evidence for the five runnable Verifier checks:

1. scenario traceability
2. full test suite
3. complexity gate
4. design-principles gate
5. scenario-to-behavior spot check

The "no unaccounted behavior" skim is not a runnable check: it is recorded as a
finding line, not as a command.

### Machine-readable rule

Machine-readable evidence (gate-script output, CI query, deploy check) is
recorded with an ISO-8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`, i.e.
`date -u +%Y-%m-%dT%H:%M:%SZ`) as raw output or exit code — never as a prose
paraphrase. The timestamp is pinned to UTC so the gate can verify the format
deterministically.

### Evidence block format

In `25-verification.md`, each of the five checks carries one evidence block: a
`## Evidence: <check name>` heading, three marker lines, then the raw output.
Worked example:

```
## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-08-15T10:00:00Z

Scenario IDs found: 16
Scenario traceability check: every scenario traced, every reference resolves.
```

- `command:` — the exact command as run.
- `exit:` — the command's exit code.
- `at:` — when it ran, in `YYYY-MM-DDTHH:MM:SSZ`.
- everything after the markers — the raw output, verbatim (or a representative
  excerpt for very long output), never a paraphrase.

The design-principles gate's exit code and every FAIL / WARN line must be kept
verbatim. `30-report.md` uses the same block style for its machine-readable
rows (mutation score, final test status) plus the `PR:` line appended by the PR
Opener.

### The gate

`scripts/check-audit-trail.sh <slug>` verifies the folder is complete
(`10-tasks.md`, `20-acceptance/` with a scenario heading, `25-verification.md`,
`30-report.md`, and `15-design.md` when present — a zero-byte `15-design.md` is
a failure) and that `25-verification.md` records evidence for all five checks.
It exits 0 only when both hold, and is a no-op when the folder does not exist.
The PR Opener runs it before pushing; self-ci runs it for every spec folder
carrying a `30-report.md` — the pipeline's finished signal, the same
convention as the archive gate (`docs/spec-pipeline/pr-opener.md`,
§Archive in the PR). In-flight folders
without `30-report.md` are skipped: their pipeline finishing is outside the
job's control and must not fail CI. A finished-but-incomplete spec still
fails the gate — the step never hands the script an unfinished folder.

`--require-deploy` splits the deploy-artifact rule by stage (ADR 0010;
implements the upgrade path spec 031's gate comment documented). Stage 5b (the
PR Opener) runs the gate **without** the flag, pre-push: a *missing*
`40-deploy.md` in a frontend repo is tolerated there, because stage 5c (the
Deploy Verifier) can only write it after the PR opens — while a present-but-
empty or malformed artifact still fails, preserving AC-031-19's guarantee.
Stage 5d (the Archiver, same agent) runs the gate **with** `--require-deploy`
as the pipeline's final gate, where a missing frontend `40-deploy.md` exits
non-zero (AC-031-21) at the stage where it can actually be satisfied.
Non-frontend behavior is flag-independent.


## Definition of done

A spec pipeline run is done when all of the following hold — mechanically, not
aspirationally:

1. **Every stage reported green.** Coder suite green; Refactorer structure
   clean; Verifier PASS (`25-verification.md`); Mutation Runner GREEN
   (`30-report.md`); Deploy Verifier green or skipped (`40-deploy.md`).
2. **`specs/NNN-slug/30-report.md` exists.** This is the *finished* signal —
   both `archive-spec.sh` (refuses to archive without it) and the enforcement
   gate (`check-specs-archived.sh`) key off it.
3. **Draft PR open** on `spec/NNN-slug`, body linking `10-tasks.md` and
   `30-report.md`.
4. **`40-deploy.md` present** with a verdict or a recorded skip reason — the
   Deploy Verifier's artifact (stage 5c); frontend lanes carry a verdict,
   non-frontend lanes carry the skip reason.
5. **Gate green.** `scripts/check-specs-archived.sh` (self-ci `validate` job, no
   `continue-on-error`) passes — a finished spec can never merge without its
   archive.
6. **Stage 5d (the Archiver) ran `scripts/archive-spec.sh` as the pipeline's
   final act.** The PR carries `docs/changes/NNN-slug.md` and no longer contains
   `specs/NNN-slug/`.

The pipeline finishes at the moment stage 5d (the Archiver) runs the archive as
its final act and pushes the archive commit — after stage 5c's deploy
verification, never before. The merge commit itself lands
`main` with the spec already archived. After the merge, the production deploy
verification lane runs against the live system for Vercel-linked frontend repos
(`docs/spec-pipeline/post-pr-loops.md`, §Production deploy verification
(post-merge)) — apart from that lane, what
happens after merge — release tagging (Semantic Release) and human review of the
diff — remains out of scope for the pipeline.
