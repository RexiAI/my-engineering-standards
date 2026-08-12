# AC-015: check-audit-trail.sh wired at pipeline end

## AC-015-15 — The PR Opener runs the gate before opening the PR

Given the audit-trail gate exists as `scripts/check-audit-trail.sh`

When I read `agents/spec-pr-opener.md`

Then it instructs running `scripts/check-audit-trail.sh <slug>` before committing, pushing, and opening the PR

And it instructs stopping the pipeline without opening the PR when the gate exits non-zero

## AC-015-16 — Self-CI runs the gate when a spec folder is present

Given `.github/workflows/self-ci.yml` exists

When I read the workflow

Then it contains a step that runs `scripts/check-audit-trail.sh` for each present `specs/*/` directory

And the step exits 0 when no spec folder exists
