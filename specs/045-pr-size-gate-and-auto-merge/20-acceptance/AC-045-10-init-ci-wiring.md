# AC-045-10: Child-repo wiring through init-ci.sh

## AC-045-10-01 — Both flags are documented and parsed
Given `scripts/init-ci.sh`
When the usage line and flag parser are read
Then the usage line lists `[--with-pr-size-gate]` and `[--with-pr-automerge]`
And the parser sets `WITH_PR_SIZE_GATE_FLAG` and `WITH_PR_AUTOMERGE_FLAG`

## AC-045-10-02 — The size flag emits only the size job
Given a scratch child repository
When `init-ci.sh --with-pr-size-gate --platform github --backend go` runs
Then `.github/workflows/ci.yml` contains one `pr-size` job
And that job calls `ci-pr-size-gate.yml@<sha>` with the PR base and head SHAs
And it contains no `review-verdict` or `pr-automerge` job

## AC-045-10-03 — The auto-merge flag emits all three jobs
Given a scratch child repository
When `init-ci.sh --with-pr-automerge --platform github --backend go` runs
Then `.github/workflows/ci.yml` contains `pr-size`, `review-verdict`, and
`pr-automerge` jobs
And `pr-automerge` has `needs: [pr-size, review-verdict]`
And each job calls its reusable workflow at the same pinned SHA

## AC-045-10-04 — Both flags emit each job once
Given a scratch child repository
When `init-ci.sh --with-pr-size-gate --with-pr-automerge --platform github
--backend go` runs
Then `.github/workflows/ci.yml` contains exactly one `pr-size` job
And exactly one `review-verdict` job
And exactly one `pr-automerge` job

## AC-045-10-05 — The default output is unchanged
Given a scratch child repository
When `init-ci.sh --platform github --backend go` runs without either flag
Then `.github/workflows/ci.yml` contains no `pr-size`, `review-verdict`, or
`pr-automerge` job
And it contains no `PR_AUTOMERGE_MODE` text

## AC-045-10-06 — GitLab warns and emits nothing
Given a scratch child repository
When `init-ci.sh --with-pr-automerge --platform gitlab --backend go` runs
Then the command exits 0
And stdout warns that this is a GitHub Actions feature
And `.gitlab-ci.yml` contains no auto-merge or size-gate content

## AC-045-10-07 — Both platforms emits on GitHub and warns for GitLab
Given a scratch child repository
When `init-ci.sh --with-pr-size-gate --with-pr-automerge --platform both
--backend go` runs
Then `.github/workflows/ci.yml` contains the three jobs
And stdout warns that the GitLab side is not wired
And `.gitlab-ci.yml` contains no auto-merge or size-gate content

## AC-045-10-08 — The bootstrap catalog carries both capabilities
Given `scripts/capabilities.tsv`
When its rows are read
Then one row's `flag` is `--with-pr-size-gate` with `init_ci` carrying that
flag
And one row's `flag` is `--with-pr-automerge` with `init_ci` carrying that
flag
And both rows have `baseline=no`, `action=none`, and `files={ci}`

## AC-045-10-09 — Summary documents the setting and asks for no secret
Given `scripts/init-ci.sh`
When the post-generation summary for `--with-pr-automerge` is read
Then it names `PR_AUTOMERGE_MODE` with default `report` and opt-in `live`
And it states the branch-protection prerequisite
And it prompts for no new secret
