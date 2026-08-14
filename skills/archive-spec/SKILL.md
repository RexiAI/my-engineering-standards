---
name: archive-spec
description: Archive a finished spec to `docs/changes/NNN-slug.md` and remove `specs/NNN-slug/`. Primary caller is the spec pipeline (stage 5b runs `scripts/archive-spec.sh` automatically inside the PR); this skill is the manual fallback for legacy specs already merged without an archive. Use only for finished specs (30-report.md present) — never mid-pipeline.
license: See repo root
allowed-tools: Bash(.standards/scripts/archive-spec.sh:*) Bash(./.standards/scripts/archive-spec.sh:*) Bash(git:*)
---

# When to use

Two cases:

1. **Legacy cleanup** — a spec PR merged before the archive-in-PR flow existed
   (or the bot never ran), leaving `specs/NNN-slug/` on `main`. Run this skill
   to move it to `docs/changes/`.
2. **Fallback** — if stage 5b failed to archive and the PR is blocked by the
   gate (`scripts/check-specs-archived.sh`).

Do **not** use mid-pipeline: `archive-spec.sh` refuses to archive a spec
without a `30-report.md` (i.e. not finished), and the PR reviewer still needs
the spec folder open in the PR.

# Invocation

Run from the repo root:

```bash
./.standards/scripts/archive-spec.sh NNN-slug
# e.g. ./.standards/scripts/archive-spec.sh 001-discount-system
```

The script stages both the new `docs/changes/NNN-slug.md` and the
`git rm -r specs/NNN-slug/` and prints the commit message to run. **It does not
commit or push.** That stays with the human, per this repo's AGENTS.md — except
inside the pipeline, where stage 5b (`spec-pr-opener`) commits it as part of the
spec PR per the `docs/SPEC_PIPELINE.md §Commit and push carve-out`.

# What the script does

1. Verifies the spec is finished: `specs/NNN-slug/30-report.md` must exist.
2. Reads `specs/NNN-slug/{10-tasks.md, 25-verification.md, 30-report.md}` and composes a one-page summary at `docs/changes/NNN-slug.md` containing:
   - Original ask (from `00-informal.md`).
   - Task list.
   - Acceptance-scenario IDs (`AC-NNN-NN`).
   - Verification verdict.
   - Mutation / complexity report.
3. Stages the new file plus `git rm -r specs/NNN-slug/`.
4. Prints the commit message. The human (or stage 5b) runs `git commit` and `git push`.

# Automated flow (normal path)

In the spec pipeline, stage 5b (PR Opener) runs this script automatically as its
final act, so the archive rides inside the spec PR and the merge lands `main`
with the spec already archived. The enforcement gate
`scripts/check-specs-archived.sh` (self-ci `validate` job, no `continue-on-error`)
fails any PR that would merge a finished spec without its archive — see
`docs/SPEC_PIPELINE.md §Archive in the PR` and `§Definition of done`.

# Why the script does not commit

The one-page summary is the only spec artifact that survives to `main`.
Everything else in `specs/` was pipeline scratch. The script *stages* but does
not commit — outside stage 5b, commits stay with the human per `AGENTS.md`.
