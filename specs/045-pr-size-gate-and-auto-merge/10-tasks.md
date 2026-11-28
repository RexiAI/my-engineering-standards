# 045 — PR size gate and review-gated auto-merge: tasks

Stage 1 output. Source: `specs/045-pr-size-gate-and-auto-merge/00-informal.md`.
Each task is one coherent implementation unit. Scenarios are in
`specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-NN-*.md`; the file
number matches the task number. Scenario IDs are `AC-045-<task>-<n>`.

## Conventions used by every task

- Shell scripts are bash with `set -euo pipefail`, executable, deterministic, and
  offline. Exit codes: `0` = evaluated / gate passes; `1` = gate fails (the
  finding is a real gate failure); `2` = usage or input error (the gate did not
  evaluate, so it must never report a pass).
- Reusable workflows declare `on: workflow_call`. Every caller pins the reusable
  workflow to a commit SHA (`@<sha>`), never a branch. The caller job names are
  exactly `pr-size` and `review-verdict`, because those strings are the required
  status-check contexts in `templates/branch-protection.md`.
- Merge authority is GitHub native auto-merge. The only merge command allowed is
  `gh pr merge --auto --squash`. `--merge`, `--rebase`, `--admin`, and direct
  merge API calls are forbidden. The pr-review agent never merges or approves.
- Changed lines = additions + deletions, after exclusions. Thresholds: `<= 200`
  auto-merge tier, `201–400` human-approval tier, `> 400` blocked.
- Override label: `size-override`. Settings, identical in every repo:
  repository Actions variable `PR_AUTOMERGE_MODE` (`report` when unset; exact
  `live` is the only value that arms a merge) and `MUTATION_REQUIRED` (`true`
  means the mutation report is a required check at this tier).
- The agent's machine-readable marker gains one line:
  `Review-Verdict: pass|findings` (see OPEN-2). `Reviewed-SHA: <sha>` is
  unchanged.

## Open questions (confirm at the human gate)

These are genuine gaps in the informal spec, not implementation choices. Each has
a conservative default recorded here so the Coder is not blocked; confirm or
amend before `/build` runs.

- **OPEN-1 — CODEOWNER resolution for `size-override`.** The informal says only a
  CODEOWNER may apply the label but does not define resolution when
  `.github/CODEOWNERS` is absent or uses team handles. Default: an individual
  `@user` handle in CODEOWNERS matching the label-event actor authorizes; a team
  handle (`@org/team`) does not authorize the script-level override; with no
  CODEOWNERS file, the repository owner authorizes. Deterministic and
  offline; over-restriction only blocks an automatic pass, never a human merge.
- **OPEN-2 — verdict token.** The informal says the "existing machine-readable
  marker is converted" into a check, but `Reviewed-SHA: <sha>` carries no verdict.
  Default: the agent emits exactly one `Review-Verdict: pass|findings` line
  immediately after `Reviewed-SHA`; values are case-sensitive; zero, multiple, or
  unknown values are malformed and fail closed. No inference from prose.
- **OPEN-3 — "auth/secret handling code".** No path list is given. Default
  exclusion patterns: path segment exactly `auth`, `authn`, `authz`, `secrets`,
  or `keys`; basename containing `auth`, `secret`, `credential`, `password`,
  `apikey`, `api_key`, or `token`; basename `.env` or `.env.*`. Over-exclusion is
  the safe direction (it blocks auto-merge only).
- **OPEN-4 — "major dependency bumps".** No deterministic detector is given.
  Default: any changed dependency manifest or lockfile excludes the PR from
  auto-merge. Manifests: `package.json`, `go.mod`, `pom.xml`, `build.gradle`,
  `build.gradle.kts`, `Cargo.toml`, `pyproject.toml`, `setup.py`, `setup.cfg`,
  `requirements.txt`, `requirements-*.txt`, `Gemfile`, `composer.json`,
  `*.csproj`, `mix.exs`, `pubspec.yaml`; lockfiles are the Task 2 list. This is a
  superset of major bumps; minor and patch bumps are also left to a human.
  Narrowing this later is a one-line rule change.
- **OPEN-5 — notification timing.** "a comment on the merged PR" is read as a
  comment posted when the auto-merge decision is made, on that PR, before GitHub
  completes the asynchronous merge; the comment stays on the PR after it merges.
  One comment per `(head SHA, outcome)`, no post-merge second comment.

## Task 1 — Record ADR 0030 for the merge-authority reversal

Changes: `docs/adr/0030-pr-size-gate-and-review-gated-auto-merge.md`,
`docs/adr/README.md`.

Acceptance criteria:

- The ADR exists at the next free number (0029 is the current highest) and uses
  the section set from `templates/ADR.md` (`Title`, `Status`, `Context`,
  `Decision`, `Alternatives Considered`, `Consequences`, `Compliance`).
- `Status` is `Proposed` or `Accepted`.
- The Decision states: GitHub native auto-merge, gated by deterministic required
  checks, performs the merge; `agents/pr-review.md` remains read-only and never
  merges; the PR-only flow through branch protection and the ban on direct pushes
  to `main`/`master` are unchanged.
- The Decision states the distinction between `docs/SPEC_PIPELINE.md`
  §Autopilot mode's Never-list `no merge` (pipeline and autopilot agents never
  merge) and the repo-level GitHub setting (not an agent capability).
- The ADR records the narrow reversal: the pr-review scope lock's blanket
  `auto-merge` prohibition continues to bind the agent; it no longer forbids the
  repository's GitHub auto-merge configuration.
- `docs/adr/README.md` gains a row `| 0030 | [<title>](0030-pr-size-gate-and-review-gated-auto-merge.md) | <status> |` whose status matches the ADR's `Status` field.

## Task 2 — Size accounting: changed-line count and exclusions

Changes: `scripts/pr-size-gate.sh` (counting half).

Acceptance criteria:

- The script accepts `--numstat-file <path|->` and `--diff-file <path>`, or
  alternatively `--base <ref> --head <ref>` (it then obtains both inputs with
  `git diff --numstat` and `git diff`). It accepts `--format text|json` (default
  `text`).
- The count is the sum of additions + deletions over every included file in the
  numstat input. Binary entries (`-` in both columns) contribute `0` and do not
  error. Rename entries (paths containing `=>`, including brace form
  `src/{old => new}/f.ts`) are counted once, using the destination path for
  exclusion matching.
- Excluded classes, matched against the destination path:
  - lockfiles by exact basename: `package-lock.json`, `npm-shrinkwrap.json`,
    `yarn.lock`, `pnpm-lock.yaml`, `bun.lock`, `bun.lockb`, `go.sum`,
    `Cargo.lock`, `poetry.lock`, `Pipfile.lock`, `Gemfile.lock`,
    `composer.lock`, `mix.lock`, `pubspec.lock`, `pdm.lock`, `uv.lock`,
    `packages.lock.json`, `flake.lock`;
  - generated code by path: a `generated/` segment, `*.generated.*`, `*.g.dart`,
    `*.pb.go`, `*.pb.cc`, `*.pb.h`, `*_pb2.py`, `*_pb2_grpc.py`,
    `*.designer.cs`, `*.min.js`, `*.min.css`;
  - generated code by content: the diff file contains an added line (leading
    `+`) with `@generated`, `DO NOT EDIT`, or `Code generated by`;
  - snapshots: a `__snapshots__/` segment, or basename ending `.snap`,
    `.snapshot`, `.ambr`;
  - pure file deletions: the diff file marks the path with `deleted file mode`
    (or `+++ /dev/null`). A numstat line with `0` additions and non-zero
    deletions is **not** by itself a pure deletion — a file that only lost lines
    still counts those deletions.
- Output (text) contains at least one line `changed=<int>` and one line
  `excluded=<int>`; Task 3 adds the classification keys. JSON output carries the
  same keys.
- Running twice on identical inputs yields byte-identical output. The script
  makes no network call and writes no file.
- Usage/input errors exit `2`; a successful count exits `0`.

## Task 3 — Size tiers, override label, and gate exit contract

Changes: `scripts/pr-size-gate.sh` (classification half).

Acceptance criteria:

- Tier mapping: `changed <= 200` → `tier=auto`; `201 <= changed <= 400` →
  `tier=human`; `changed > 400` with no effective override → `tier=blocked`.
- `automerge=true` only when `tier=auto`; `automerge=false` for `human`,
  `blocked`, and `override`.
- Exit code is `0` for `auto`, `human`, and `override`; `1` for `blocked`.
- Override inputs: `--label present|absent` (default `absent`),
  `--label-actor <login>`, `--repo-owner <login>`, `--codeowners <path>` (default
  `.github/CODEOWNERS`, then `CODEOWNERS`, then `docs/CODEOWNERS`; first existing
  file wins).
- An override is effective only when the label is present, the actor matches an
  individual `@user` token in the CODEOWNERS file, and the size is `> 400`. A
  team token (`@org/team`) never authorizes. With no CODEOWNERS file, the actor
  matching `--repo-owner` authorizes (OPEN-1).
- Effective override → `tier=override`, `override=authorized`, exit `0`,
  `automerge=false`. Unauthorized label on a `> 400` PR → `tier=blocked`,
  `override=unauthorized`, exit `1`.
- On a `<= 400` PR the label has no effect: the tier stays `auto`/`human` and
  `override=ignored`.
- Text output always contains exactly one line per key: `changed`, `tier`
  (`auto|human|blocked|override`), `automerge` (`true|false`), `override`
  (`absent|authorized|unauthorized|ignored`), `excluded`.

## Task 4 — Extend the pr-review output contract with a verdict

Changes: `agents/pr-review.md`, `docs/CI_CD.md` (marker sentence only; the full
section is Task 12).

Acceptance criteria:

- The output contract requires exactly one line `Review-Verdict: pass` when the
  review reports no findings and exactly one line `Review-Verdict: findings` when
  it reports one or more.
- The line is emitted after `Reviewed-SHA: <head sha>`; `Reviewed-SHA` keeps its
  current format and value (the early-exit step still consumes it).
- The prompt states the values are case-sensitive and that omitting the line, or
  emitting any other value, is a fail-closed failure for the workflow — never a
  silent pass.
- The scope lock still forbids `auto-merge`, approval, `describe`, `improve`,
  `auto-apply`, and push; the `permission` block still denies `edit` and `bash`.
- `scripts/check-pr-review.sh` still exits `0` with the updated agent file.

## Task 5 — Verdict parser and fail-closed required-check input

Changes: `scripts/pr-review-verdict.sh`.

Acceptance criteria:

- Usage: `scripts/pr-review-verdict.sh --head-sha <sha> --comments-file <path|->`.
  The comments file is the JSON from `gh pr view <n> --json comments`.
- The parser considers only comments whose body contains a line
  `Reviewed-SHA: <head-sha>` (exact SHA). It selects the latest such comment by
  comment order in the JSON. Comments for other head SHAs and comments without
  the marker are ignored.
- In the selected comment, exactly one `Review-Verdict:` line is required, with
  the value `pass` or `findings` after trimming trailing whitespace. Values are
  case-sensitive.
- Result mapping: `pass` → `verdict=pass`, exit `0`. `findings` →
  `verdict=findings`, exit `1`. No comment for the head → `verdict=missing`,
  exit `1`. Marker present but zero or multiple verdict lines, or a value other
  than `pass`/`findings` → `verdict=malformed`, exit `1`.
- The script prints exactly one `verdict=<value>` line and makes no network
  call. A usage error (missing or unknown argument) exits `2`.
- The script never treats an absent, empty, or malformed input as a pass.

## Task 6 — Auto-merge eligibility predicate

Changes: `scripts/pr-automerge-eligibility.sh`.

Acceptance criteria:

- Usage: `--size-tier <auto|human|blocked|override>`,
  `--review-verdict <pass|findings|missing|malformed>`, `--changed-files
  <path|->` (newline-separated paths), `--mode <report|live>`.
- Output text contains exactly one line per key: `eligible` (`true|false`),
  `action` (`merge|comment_only|none`), `reason`, `exclusions` (space-separated
  `rule:path` list, or `none`).
- Rules are evaluated in this fixed order, first match wins: size tier not
  `auto` (`reason=size_human|size_blocked|size_override`); review verdict not
  `pass` (`reason=review_not_pass`); excluded path (`reason=excluded_path`);
  mode `report` (`eligible=true`, `action=comment_only`,
  `reason=report_only`); otherwise `eligible=true`, `action=merge`,
  `reason=all_green`.
- Exclusion rules, checked against every changed path, in this order:
  - `gate_surface`: prefix `.github/workflows/`, prefix `agents/`,
    `scripts/check-*`, or exact `opencode.json`;
  - `auth_secret`: the OPEN-3 pattern set;
  - `db_migration`: a `migrations/`, `migrate/`, or `alembic/` segment, a
    `db/migrate/` segment, a basename matching `^V[0-9]+__.*\.sql$`, or a
    basename matching `^[0-9]{3,}[-_].*\.sql$`;
  - `dependency_manifest`: the dependency manifests and lockfiles named in
    OPEN-4.
- In `report` mode with no other failure, the output is `eligible=true`,
  `action=comment_only`, `reason=report_only` (the "would have auto-merged"
  case). In `live` mode with no failure it is `action=merge`.
- A missing required argument, an unknown argument, or an out-of-domain value
  exits `2` and prints no `eligible=` line. A successful evaluation exits `0`,
  including an ineligible result.
- The script accepts no repository name/slug and no per-repo allowlist input;
  identical inputs produce identical output in any repository.

## Task 7 — Required-check workflows: `pr-size` and `review-verdict`

Changes: `.github/workflows/ci-pr-size-gate.yml`,
`.github/workflows/ci-pr-review-verdict.yml`.

Acceptance criteria:

- Both are `on: workflow_call` reusables. `ci-pr-size-gate.yml` takes
  `pr-number`, `base-sha`, `head-sha`, `base-ref`; `ci-pr-review-verdict.yml`
  takes `pr-number`, `head-sha`.
- `ci-pr-size-gate.yml` job `size` obtains the PR diff and numstat, reads label
  presence with `gh pr view --json labels`, reads the actor of the most recent
  `size-override` labeled event from the issue timeline (not `github.actor`),
  passes `--label`, `--label-actor`, `--repo-owner`, and `--codeowners`, and
  fails the job when the script exits `1`.
- `ci-pr-review-verdict.yml` job `verdict` fetches the PR comments with
  `gh pr view --json comments` and fails the job when the parser exits non-zero
  (missing, malformed, a marker for a different head, or `findings`).
- Both workflows use only the standards repository's scripts at the pinned
  reusable-workflow revision; neither checks out or executes code from the PR
  head. Neither uses `pull_request_target`.
- Permissions are read-only (`contents: read`, `pull-requests: read`, plus
  `issues: read` for the timeline); no `*: write` permission, no secret input, no
  comment, merge, or push step.
- The override path is exercised on a `labeled` event: applying `size-override`
  re-runs the size job, and an authorized override turns a `> 400` failure into
  a passing job with `tier=override` and `automerge=false`.

## Task 8 — Auto-merge workflow: decision, report-only default, live arming

Changes: `.github/workflows/ci-pr-auto-merge.yml`,
`.github/workflows/pr-automerge.yml`.

Acceptance criteria:

- `ci-pr-auto-merge.yml` is `on: workflow_call` with `pr-number`, `base-sha`,
  `head-sha`, `base-ref`; job `automerge`.
- Before deciding, the job independently re-runs the size script and the verdict
  parser (it does not trust the sibling jobs' artifacts): tier must be `auto` and
  verdict must be `pass`, or the job stops without arming.
- The job calls `pr-automerge-eligibility.sh` with the mode from
  `vars.PR_AUTOMERGE_MODE`. Only the exact value `live` arms; unset, empty,
  `report`, or any other value is report-only.
- Live mode issues `gh pr merge --auto --squash` only when eligibility prints
  `eligible=true` and `action=merge`. Report mode never runs a merge command.
- The job fails closed (no arm) when the repository setting `allow_auto_merge` is
  false, checked with `gh api repos/{owner}/{repo} --jq .allow_auto_merge`.
- The workflow contains no repository-name allowlist condition (no
  `github.repository ==`, no `github.repository_owner ==`, no literal repo slug)
  and no `pull_request_target`.
- Permissions: gate and decision jobs read-only; only the arming step's job has
  `contents: write` and `pull-requests: write`. No `actions: write` or
  `id-token: write`.
- Caller trigger `.github/workflows/pr-automerge.yml`: `pull_request` types
  `[opened, synchronize, reopened, ready_for_review, labeled]`; job `pr-size`
  calls `ci-pr-size-gate.yml@<sha>` with the event's base/head SHAs; job
  `review-verdict` calls `ci-pr-review-verdict.yml@<sha>`; job `pr-automerge`
  calls `ci-pr-auto-merge.yml@<sha>` and has `needs: [pr-size,
  review-verdict]`. All three jobs are pinned to the same commit SHA.
- The comment post is idempotent: a comment carrying
  `<!-- pr-automerge: <outcome>:<head-sha> -->` already on the PR suppresses a
  duplicate post for the same outcome and head.

## Task 9 — Human notification

Changes: `scripts/pr-automerge-notify.sh` (called by Task 8's workflow).

Acceptance criteria:

- Usage: `--outcome <armed|would-merge|blocked-exclusion>`,
  `--size-tier <auto|human|blocked|override>`,
  `--review-verdict <pass|findings|missing|malformed>`,
  `--exclusions <none|list>`, `--codeowners-file <path|none>`,
  `--repo-owner <login>`, `--head-sha <sha>`. Prints the comment body to stdout;
  exit `0`.
- Mentions: every distinct individual `@user` handle in the CODEOWNERS file is
  mentioned; when the file is absent or contains no individual handle, the body
  mentions `@<repo-owner>`. Team handles are not invented or expanded.
- `armed` body states that auto-merge is armed and that the merge waits for the
  required checks (`pr-size`, `review-verdict`, CI, and `mutation` when the tier
  requires it), and states the size tier and review verdict.
- `would-merge` body states that the PR "would have auto-merged", names
  report-only mode, and states the size tier and review verdict.
- `blocked-exclusion` body names each matching exclusion rule and path and says
  a human must review and merge the PR.
- The body ends with `<!-- pr-automerge: <outcome>:<head-sha> -->`.
- The body contains no secret, token, API key, or value read from an environment
  secret; the script is offline and deterministic.

## Task 10 — Child-repo wiring through `init-ci.sh` and the bootstrap catalog

Changes: `scripts/init-ci.sh`, `scripts/capabilities.tsv`.

Acceptance criteria:

- Usage line lists `[--with-pr-size-gate]` and `[--with-pr-automerge]`; the flag
  parser sets `WITH_PR_SIZE_GATE_FLAG` and `WITH_PR_AUTOMERGE_FLAG`.
- `--with-pr-size-gate` emits one GitHub job `pr-size` that calls
  `ci-pr-size-gate.yml@${STANDARDS_PIN}` with the PR event's base/head SHAs.
- `--with-pr-automerge` emits `review-verdict` (calls
  `ci-pr-review-verdict.yml@${STANDARDS_PIN}`), `pr-automerge` (calls
  `ci-pr-auto-merge.yml@${STANDARDS_PIN}`, `needs: [pr-size, review-verdict]`),
  and the `pr-size` job; each job is emitted once when both flags are given.
- A run with neither flag emits no `pr-size`, `review-verdict`, or
  `pr-automerge` content and no new setting text.
- `--platform gitlab` with either flag prints a warning that these are GitHub
  Actions features, emits nothing into `.gitlab-ci.yml`, and exits `0`;
  `--platform both` emits on GitHub and warns for GitLab.
- No new secret is prompted for; the summary documents
  `PR_AUTOMERGE_MODE` (`report` default, `live` opt-in) and the one-time
  branch-protection prerequisite.
- `scripts/capabilities.tsv` gains one row per flag with `id`, `label`,
  `category`, `stack=ci`, `flag`, `baseline=no`, `action=none`, `files={ci}`,
  and `init_ci` carrying the flag.

## Task 11 — Self-hosting and self-CI

Changes: `scripts/check-pr-size-gate.sh`, `.github/workflows/self-ci.yml`,
`scripts/tests/pr-size-gate.bats`, `scripts/tests/pr-review-verdict.bats`,
`scripts/tests/pr-automerge-eligibility.bats`,
`scripts/tests/pr-automerge-notify.bats`.

Acceptance criteria:

- `scripts/check-pr-size-gate.sh` is executable and read-only. It checks the
  artifacts this spec introduces (scripts exist and are executable, workflows
  exist with the required caller job names and SHA pins, the agent verdict
  contract is present, docs/settings statements exist, `init-ci.sh` flags exist),
  cites the AC-045 IDs it enforces, exits `0` on the compliant tree, and exits
  `1` on a scratch copy with a required artifact removed (the self-test
  covers a representative removal).
- `.github/workflows/self-ci.yml` runs `check-pr-size-gate.sh` and the four bats
  files; a failure of any is a failed Validate job.
- This repository has the self-hosted PR trigger `pr-automerge.yml` with the
  three caller jobs, pinned to the same commit SHA as the reusable workflows.
- This repository's auto-merge is report-only by default: no committed
  `PR_AUTOMERGE_MODE=live`, and the workflow treats the unset variable as
  `report`.
- `scripts/check-scenario-traceability.sh --spec 045-pr-size-gate-and-auto-merge`
  exits `0`: every AC-045 heading has a matching test name, and every AC-045
  reference resolves.

## Task 12 — Documentation

Changes: `AGENTS.md`, `docs/GIT_WORKFLOW.md`, `docs/CI_CD.md`,
`templates/branch-protection.md`.

Acceptance criteria:

- `AGENTS.md` gains a rule that an auto-merge may occur only through GitHub
  native auto-merge on a PR whose required checks are green, that the
  pr-review agent still never merges, and that the PR-only / no-direct-push rule
  is unchanged.
- `docs/GIT_WORKFLOW.md` has a section documenting the 200/400 tiers, the
  `size-override` label and its CODEOWNER restriction, and the auto-merge
  prerequisite (branch protection requires `pr-size` and `review-verdict`).
- `docs/CI_CD.md` has a section documenting all three reusable workflows, the
  `pr-size` and `review-verdict` contexts, `PR_AUTOMERGE_MODE` (`report` default,
  `live` opt-in), the exclusion classes, and the notification behavior.
- `templates/branch-protection.md` lists `pr-size` and `review-verdict` among
  required status checks and adds an "auto-merge prerequisites" block: required
  checks include `mutation` when `MUTATION_REQUIRED=true`, the repo setting
  `allow_auto_merge` is enabled, and squash merge remains the only strategy.
- The docs state that behavior is identical in every repo that wires the
  workflows and that there is no per-repo allowlist.
- The docs define `PR_AUTOMERGE_MODE` values and default once, and do not
  describe any direct merge or agent-performed merge.
- The `docs/CI_CD.md` §PR Review Agent section states that the review API keys
  remain optional (not required checks) while the `review-verdict` check is
  required when auto-merge is wired, so the two statements do not contradict.
