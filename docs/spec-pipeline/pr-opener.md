# PR Opener stage file (stages 5b and 5d)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Commit and push carve-out.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before running the audit-trail gate.

## Lite mode

A `lite` run has no Mutation Runner: `30-report.md` records `Pipeline mode: lite`
and `skipped (lite)` for each skipped stage, which is the green signal — see
`docs/spec-pipeline/lite-mode.md`. The Verifier PASS precondition is unchanged.

## Archive in the PR

The `specs/NNN-slug/` folder is pipeline scratch. It belongs on the PR branch
for review, not on `main` — committed specs drift into a graveyard of "what we
thought then" that future maintainers read instead of the actual code, and the
information barrier (`docs/spec-pipeline/rationale.md`, §The information
barrier) is harder to reason about when the spec is reachable from `main` to
anyone with read access.

`scripts/archive-spec.sh NNN-slug` writes a single one-pager to
`docs/changes/NNN-slug.md` containing the original ask, task list,
acceptance-scenario IDs, verification verdict, and the mutation/complexity
report, then `git rm -r specs/NNN-slug/`. **Stage 5d (the Archiver) runs this as
the pipeline's genuinely final act, inside the spec PR — after stage 5c's deploy
verification** — so the merge commit itself carries the archive: `main` lands with
`docs/changes/NNN-slug.md` present and `specs/NNN-slug/`
absent. Other than the post-merge production verification lane
(`docs/spec-pipeline/post-pr-loops.md`, §Production deploy verification
(post-merge), spec 031), nothing runs after the merge; there is no post-merge
cleanup step.

Enforcement: `scripts/check-specs-archived.sh` (wired into the `validate` job of
`.github/workflows/self-ci.yml`, no `continue-on-error`) fails any PR that would
merge a *finished* spec — one with a `30-report.md` — without its
`docs/changes/NNN-slug.md` archive. The check is index-aware (`git ls-files`), so
untracked local scratch under `specs/` is not policed.

`archive-spec.sh` refuses to archive a spec that is not finished (no
`30-report.md`), so stage 5d cannot run it early; for legacy specs merged before
this flow existed, a human can still run it manually post-merge — the script
stages both moves and prints the commit message to run. It does not commit or
push — outside stage 5d, that stays with the human, like every other commit in
`AGENTS.md`.

This is the only spec artifact that survives to `main`: a one-pager per
merged feature, not seven files per feature.

The acceptance scenarios survive
in the test files as `AC-NNN-NN` IDs (the traceability check requires this
anyway, `docs/spec-pipeline/rationale.md §Why no scenario mutation`); the
verification verdict and mutation
score survive in the one-pager; the original prose does not, because what the
code actually does is the source of truth.

`archive-spec.sh` copies the `## AC-NNN-NN` headings verbatim into the
one-pager, and `check-scenario-traceability.sh` check 2 resolves each test
reference against whichever source is authoritative **for that spec number**:

| Spec number NNN | Authority for check 2 |
|---|---|
| `specs/NNN-*/` exists (in flight) | `specs/*/20-acceptance/*.md` |
| `docs/changes/NNN-*.md` exists (archived) | that one-pager |
| neither exists | out of scope — skipped, not a finding |

That pairing is what makes the paragraph above true: archiving deletes
`specs/NNN-slug/` while the tests keep citing its IDs, so without the archive
as a second ID source every merged spec would permanently dangle its own IDs
and check 2 could never pass again in a repo that has archived even one spec.
Scoping to in-flight specs alone has the mirror problem — a spec's IDs stop
being validated the moment it merges, so a later typo in one of its citations
is never caught. The skip in the third row is what keeps the check quiet about
references it has no authority to judge: negative-case fixture IDs such as
`AC-999-99`, and self-citations for specs archived before this convention
existed.

Both directories are ID *sources* only — each is excluded from the reference
scan, because scenario markdown and archive one-pagers quote IDs (including
illustrative ones) in prose.
