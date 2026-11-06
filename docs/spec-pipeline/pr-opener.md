# PR Opener stage file (stages 5b and 5d)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Commit and push carve-out.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before running the audit-trail gate.

Deliverable: a draft PR on `spec/NNN-slug` (5b), then the archive commit (5d).

## Lite mode

A `lite` run has no Mutation Runner: `30-report.md` records `Pipeline mode: lite`
and `skipped (lite)` per skipped stage (see `docs/spec-pipeline/lite-mode.md`).
The Verifier PASS precondition is unchanged.

## Archive in the PR

`scripts/archive-spec.sh NNN-slug` writes a one-pager to
`docs/changes/NNN-slug.md` (original ask, tasks, scenario IDs, verdict,
mutation/complexity report) and `git rm -r`s `specs/NNN-slug/`.
**Stage 5d runs it as the pipeline's final act, inside the PR, after
stage 5c's deploy verification**, so the merge commit carries the archive.

Enforcement: `scripts/check-specs-archived.sh` (`validate` job of
`.github/workflows/self-ci.yml`, no `continue-on-error`) fails a PR merging
a *finished* spec (one with a `30-report.md`) without its archive; `git ls-files`-based,
so untracked scratch is ignored.
`archive-spec.sh` refuses a spec with no `30-report.md`; a human can still run it
post-merge for legacy specs.

`archive-spec.sh` copies the `## AC-NNN-NN` headings verbatim, and
`check-scenario-traceability.sh` check 2 resolves each reference against the
source authoritative **for that spec number**:

| Spec number NNN | Authority for check 2 |
|---|---|
| `specs/NNN-*/` exists (in flight) | `specs/*/20-acceptance/*.md` |
| `docs/changes/NNN-*.md` exists (archived) | that one-pager |
| neither exists | out of scope — skipped, not a finding |

## Stage 5b — commit, push, open the draft PR

Only after `30-report.md` is green; every step is a gate.

1. **Credentials first.** `$GITHUB_TOKEN` and `$GH_TOKEN` both non-empty
   (direnv → `config/agent.local.env`; never a prompt literal). Missing → report
   and stop.
2. **Audit-trail gate (mandatory), without `--require-deploy`**:
   `scripts/check-audit-trail.sh NNN-slug`. Stage 5c writes `40-deploy.md` only
   after the PR exists, so a *missing* one is tolerated here while a malformed one
   still fails. Non-zero → report; commit, push, and PR nothing.
3. **One conventional commit per task** in `10-tasks.md`, on the current branch,
   which must be `spec/NNN-slug` — never `main`/`master`. Before every commit
   review `git status` and stage ONLY task-named files plus `specs/NNN-slug/` —
   never `git add .`, `git add -A`, or `git add specs/`.
4. **Push the branch.**
5. **Open the PR as a draft** (`.github/PULL_REQUEST_TEMPLATE.md` when present),
   body linking `10-tasks.md` and `30-report.md`. Do not archive here — stage 5c
   needs the folder.
6. **After opening**, append a `PR:` line with the URL and a commit count to
   `30-report.md`, commit as `docs(spec): record PR URL and commit count for
   NNN-slug`, and push — 5d carries them into the archive.

## Stage 5d — archive, then push the archive commit

Invoked again after stage 5c wrote `40-deploy.md` with `PASS` or a skip.

1. **Preconditions.** `40-deploy.md` exists with a verdict. A
   `Phase-3 budget exhausted` marker plus `Verdict: ESCALATED` means the pipeline
   STOPPED before you — `docs/spec-pipeline/deployer.md` routes it to the human;
   do not archive. A frontend repo's absent `40-deploy.md` fails step 2.
2. **Audit-trail gate (mandatory), with `--require-deploy`**:
   `scripts/check-audit-trail.sh --require-deploy NNN-slug`, the final gate.
   Non-zero ⇒ report and stop; do not archive, do not push.
3. **Archive**: `scripts/archive-spec.sh NNN-slug`. Do **not** read the generated
   archive or anything under `docs/changes/` or `specs/NNN-slug/` — the step is
   mechanical. If it refuses (no `30-report.md`), report and stop.
4. **Commit scope**: only `docs/changes/NNN-slug.md` and the removed spec paths;
   commit as `docs(changes): archive NNN-slug`.
5. **Pre-push gate (mandatory)**: `scripts/check-specs-archived.sh` must exit 0.
   If it flags another finished spec, archive that one and re-run; if it cannot
   reach 0, report and do not push.
6. **Push the branch**, so the pushed head never carries an unarchived spec.

