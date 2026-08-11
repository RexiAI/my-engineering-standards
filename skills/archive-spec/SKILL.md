---
name: archive-spec
description: Post-merge cleanup for a finished spec. Writes a single one-pager to `docs/changes/NNN-slug.md` summarizing the spec, then removes `specs/NNN-slug/`. Use after the spec pipeline's PR has merged to `main` — never before; the PR reviewer still needs the spec folder open in the PR.
license: See repo root
allowed-tools: Bash(.standards/scripts/archive-spec.sh:*) Bash(./.standards/scripts/archive-spec.sh:*) Bash(git:*)
---

# When to use

After `spec/NNN-slug`'s PR has merged to `main`. The spec folder is no longer needed on main — its content lives in the code (acceptance tests), the PR (review), and now this one-pager.

# Invocation

Run from the repo root, after merge:

```bash
./.standards/scripts/archive-spec.sh NNN-slug
# e.g. ./.standards/scripts/archive-spec.sh 001-discount-system
```

The script stages both the new `docs/changes/NNN-slug.md` and the `git rm -r specs/NNN-slug/` and prints the commit message to run. **It does not commit or push.** That stays with the human, per this repo's AGENTS.md.

# What the script does

1. Reads `specs/NNN-slug/{10-tasks.md, 25-verification.md, 30-report.md}` and composes a one-page summary at `docs/changes/NNN-slug.md` containing:
   - Original ask (from `00-informal.md`'s first paragraph).
   - Task list (bullet summary).
   - Acceptance-scenario IDs (`AC-NNN-NN`).
   - Verification verdict.
   - Mutation / complexity report.
2. Stages the new file plus `git rm -r specs/NNN-slug/`.
3. Prints the commit message. Human runs `git commit` and `git push`.

# Why no agent owns this

The one-page summary is the only spec artifact that survives to `main`. Everything else in `specs/` was pipeline scratch. The human commits because the script *stages* but does not commit — same carve-out as every other commit in this repo per `AGENTS.md`.

# CI alternative

`.github/workflows/archive-spec.yml` runs this script automatically after a `spec/NNN-slug` PR merges. The skill here is the manual fallback for repos without that workflow.
