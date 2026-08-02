# Branch Protection Settings

Recommended configuration for the `main` branch on GitHub and GitLab.
Apply these settings to every child repo. No direct pushes to `main` — ever.

## GitHub

Configure via **Settings → Branches → Add branch protection rule** for pattern `main`,
or apply programmatically with the GitHub API / `gh` CLI:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["unit-test","lint"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false
```

### Minimum settings (all tiers)

| Setting | Value | Why |
|---|---|---|
| Require a pull request before merging | ✅ enabled | No direct push to main |
| Require approvals | ≥ 1 (`production`+) / 0 self-approve (`mvp`) | Code review gate |
| Dismiss stale pull request approvals when new commits are pushed | ✅ enabled | Re-review after changes |
| Require status checks to pass before merging | ✅ enabled | CI must be green |
| Require branches to be up to date before merging | ✅ enabled | No stale merges |
| Require conversation resolution before merging | ✅ enabled | All feedback addressed |
| Do not allow bypassing the above settings | ✅ enabled (enforce admins) | Admins not exempt |
| Allow force pushes | ❌ disabled | History immutable |
| Allow deletions | ❌ disabled | Main cannot be deleted |

### Recommended repo settings (merge strategy)

Under **Settings → General → Pull Requests**:

| Setting | Value |
|---|---|
| Allow merge commits | ❌ disabled |
| Allow squash merging | ✅ enabled (default) |
| Allow rebase merging | ❌ disabled |
| Automatically delete head branches | ✅ enabled |

Squash-only keeps `main` history linear and makes Semantic Release commit analysis reliable.

### GitHub Rulesets (alternative to branch protection rules)

For organisations, GitHub Rulesets (`Settings → Rules → Rulesets`) are the modern
alternative. Apply the same settings above at the organisation level so every new repo
inherits them automatically.

---

## GitLab

Configure via **Settings → Repository → Protected Branches** for branch `main`:

| Setting | Value |
|---|---|
| Allowed to merge | Developers + Maintainers |
| Allowed to push and merge | No one (blocks all direct pushes) |
| Allowed to force push | ❌ disabled |
| Code owner approval | ✅ enabled (`production`+ tier) |

### Minimum merge request settings

Under **Settings → General → Merge requests**:

| Setting | Value |
|---|---|
| Merge method | Squash commits (Fast-forward preferred) |
| Squash commits when merging | Require |
| Pipelines must succeed | ✅ enabled |
| All discussions must be resolved | ✅ enabled |
| Delete source branch by default | ✅ enabled |

### GitLab API (programmatic)

```bash
curl --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --data "name=main&push_access_level=0&merge_access_level=30&allow_force_push=false&code_owner_approval_required=true" \
  "https://gitlab.example.com/api/v4/projects/{id}/protected_branches"
```

---

## Tier differences

| Setting | `mvp` | `production`+ |
|---|---|---|
| Required approvals | 0 (self-merge OK) | ≥ 1 other reviewer |
| Code owner review | optional | recommended |
| Enforce admins | ✅ always | ✅ always |
| No direct push | ✅ always | ✅ always |

The "no direct push" rule applies at **every tier**. Solo `mvp` projects still use
short-lived branches and PRs — the difference is only in who reviews.
