# AC-015: check-audit-trail.sh gate behavior

## AC-015-07 — A complete spec folder exits 0

Given `specs/<slug>/` contains non-empty `10-tasks.md`

And `specs/<slug>/20-acceptance/` contains a non-empty `AC-*.md` with at least one `## AC-NNN-NN` heading

And `specs/<slug>/25-verification.md` exists and is non-empty

And `specs/<slug>/30-report.md` exists and is non-empty

And `25-verification.md` records real evidence for every contract check

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits 0

## AC-015-08 — No spec folder exits 0

Given no `specs/<slug>` folder exists

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits 0 and prints that there is nothing to check

## AC-015-09 — Missing 10-tasks.md exits non-zero

Given a `specs/<slug>` folder with no `10-tasks.md`, or an empty `10-tasks.md`

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero

## AC-015-10 — Missing or empty 20-acceptance exits non-zero

Given a `specs/<slug>` folder with no `20-acceptance/` directory, or one whose `AC-*.md` files are all empty or contain no `## AC-NNN-NN` heading

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero

## AC-015-11 — Missing or empty 25-verification.md exits non-zero

Given a `specs/<slug>` folder with no `25-verification.md`, or an empty one

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero

## AC-015-12 — Missing or empty 30-report.md exits non-zero

Given a `specs/<slug>` folder with no `30-report.md`, or an empty one

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero

## AC-015-13 — A present-but-empty 15-design.md exits non-zero

Given a `specs/<slug>` folder containing a zero-byte `15-design.md`

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero

## AC-015-14 — A verifier report without per-check evidence exits non-zero

Given a `specs/<slug>` folder whose `25-verification.md` exists but a contract check lacks a recorded `command:`, `exit:`, `at:` timestamp, or non-empty output

When `scripts/check-audit-trail.sh <slug>` runs

Then it exits non-zero
