# Mutation Runner stage file (stage 5a)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Remediation budget.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract) for the
`30-report.md` evidence-block format.

Deliverable: `specs/NNN-slug/30-report.md`; the evidence-block format is in the
audit contract named above.

## Bounded runs

Mutation testing is bounded and scoped (ADR 0028). The unbounded form — whole-tree Stryker,
then a retry loop with no stopping rule — is a release activity, not a spec stage, and it was
observed to dominate a run while proving nothing about the change under review.

- **Scope**: the change surface, only. `scripts/run-mutation.sh --base <ref>` passes
  `--since <ref>` to Stryker, so the project's `mutate` globs and the diff intersect.
- **Cache**: `--incremental` with a stable incremental file, so a re-run tests only
  mutants whose source or killing tests changed.
- **Budget**: a wall-clock cap (default 900 s, `MUTATION_BUDGET_SECONDS`). On expiry
  the partial report is kept and the exit code is 124 — the stage records a scoped
  score and stops; it never hangs.
- **Two passes, then stop**: one scope pass, at most one targeted survivor pass
  (`--only <survivor files>`). Two runs are the whole budget for one spec; there is
  no loop that retries until the score passes.
- **Read before re-running**: an existing `reports/mutation/mutation.json` is evidence.
  If the change surface has not moved, consume it; do not start another scope pass.
- **Whole tree** (`--all`) is pre-release, never stage 5a.

The report must label the score **scoped** (with the file list and the
no-coverage count) or **whole-tree**, and never present one as the other. If the
score is still below the threshold after the survivor pass, record it and BLOCK;
do not spin.

## Full suite, one final time

The Verifier already ran the full suite; your mutation-killing tests are new code
it never saw, so the suite must be shown green again — not necessarily executed
again. The decision is mechanical:

1. **Mutation testing itself always runs.** Nothing in this section shortens or
   reuses it: no path skips, reuses, or truncates the mutation run.
2. After the mutation-kill work, run
   `scripts/test-run-reuse.sh --check specs/NNN-slug/25-verification.md`.
3. **Exit 0 (`REUSE <hash>`) → reuse the Verifier's run.** Execute no test command.
   The suite already ran, on this exact tree. The `30-report.md` final-test-status
   row carries the Verifier's `command:`, `exit: 0`, and `at:` values
   **verbatim** — the run did happen, then — plus one extra line:
   `reused-from: 25-verification.md §Evidence: full test suite (test-run hash <hash>)`.
4. **Exit 1 (`RERUN <reason>`) → run the suite yourself**, through
   `scripts/agent-test-summary.sh --run <log-path> -- <real command>` (the shape
   is `docs/spec-pipeline/verifier.md §Test-log capture`). Record your own
   `command:` / `exit:` / `at:` plus the post-run `Test-run hash:` from
   `scripts/test-run-reuse.sh --print-hash`. The Verifier's
   tree-changed-during-run rule applies unchanged: if a hash taken before the run
   differs, add the finding line `tree-changed-during-run` naming both hashes and
   record the post-run one. No `reused-from:` line is written in this branch.
5. **The fail-safe direction is a redundant run, never a skipped one.** Reuse is
   granted only on an exact hash match against the current worktree, so a stale,
   absent, or unreadable record can only cost a re-run. The fingerprint excludes
   `25-verification.md` and `runs.jsonl`: without that, writing the record would
   change the hash and `REUSE` could never be reached.
