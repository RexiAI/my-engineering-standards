# AC-045-12: Documentation

## AC-045-12-01 — AGENTS.md states the auto-merge rule
Given `AGENTS.md`
When its merge and PR rules are read
Then it states an automatic merge may occur only through GitHub native
auto-merge on a PR whose required checks are green
And it states the pr-review agent still never merges
And it states the PR-only and no-direct-push rule is unchanged

## AC-045-12-02 — GIT_WORKFLOW documents tiers and override
Given `docs/GIT_WORKFLOW.md`
When the PR size and auto-merge section is read
Then it states the 200 and 400 thresholds
And it states the `size-override` label and its CODEOWNER restriction
And it states branch protection must require `pr-size` and `review-verdict`

## AC-045-12-03 — CI_CD documents the workflows and settings
Given `docs/CI_CD.md`
When the size-gate and auto-merge section is read
Then it names `ci-pr-size-gate.yml`, `ci-pr-review-verdict.yml`, and
`ci-pr-auto-merge.yml`
And it names the `pr-size` and `review-verdict` contexts
And it states `PR_AUTOMERGE_MODE` defaults to `report` and `live` is opt-in
And it lists the exclusion classes
And it states the notification behavior

## AC-045-12-04 — Branch protection lists the contexts and prerequisites
Given `templates/branch-protection.md`
When the required-checks and auto-merge blocks are read
Then `pr-size` and `review-verdict` are listed as required contexts
And the block states `mutation` is required when `MUTATION_REQUIRED=true`
And it states `allow_auto_merge` must be enabled
And it keeps squash as the only merge strategy

## AC-045-12-05 — Behavior is identical in every wired repo
Given `docs/CI_CD.md` and `docs/GIT_WORKFLOW.md`
When the auto-merge text is read
Then it states there is no per-repo allowlist
And it states every repo that wires the workflows gets the same behavior

## AC-045-12-06 — The setting is documented once and no agent merge is described
Given the updated docs
When the auto-merge text is read
Then `PR_AUTOMERGE_MODE` is defined with both values and its default in one
place
And no doc describes a direct merge or a merge performed by an agent

## AC-045-12-07 — Review keys stay optional, the verdict check becomes required
Given `docs/CI_CD.md`
When the `PR Review Agent` section is read
Then it states the review API keys remain optional and are not required checks
And it states the `review-verdict` check is required when auto-merge is wired
