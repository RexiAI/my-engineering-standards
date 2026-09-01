# 026 — CI/CD and agent-invocation security hardening

## Ask

An independent security review of this repo's own `.github/workflows/`,
`agents/pr-review.md`, and the headless-agent invocation plumbing found a set
of concrete issues, ranging from a working pwn-request (arbitrary code
execution from a fork PR with base-repo privileges) down to a documentation
nit. Fix every finding. This repo self-hosts its own CI/CD and agent
tooling and is consumed by child repos in production — a defect here ships
to every consumer.

## Findings (source: security review, cross-checked against GitHub's own
`pull_request_target`/pwn-request docs, the tj-actions/changed-files
incident writeups, and OWASP GenAI Top 10 2025)

1. **Critical — pwn request in `ci-sweeper.yml`.** The workflow triggers on
   `workflow_run` for `Self CI` (which itself triggers on `pull_request` from
   forks) with base-repo privileges (`issues: write`, secret access), checks
   out `github.event.workflow_run.head_sha` — the failing run's commit,
   potentially attacker-authored — and then executes
   `scripts/install-opencode.sh` from that checked-out tree, plus symlinks
   and loads `skills/` and `config/model.local.env.example` from it. A fork
   PR that makes Self CI fail (trivial) and replaces
   `scripts/install-opencode.sh` gets that replacement executed with the
   base repo's privileges.

2. **Critical — the PR-review agent's `permission` block never loads in
   CI.** `agents/pr-review.md`'s frontmatter documents a `permission` block
   (deny all edits, allow-list a handful of read-only `bash` commands) and
   claims it "enforces this in config, not just prose." But
   `ci-pr-review.yml` invokes the agent by
   `cat agents/pr-review.md | sed '/^---$/,/^---$/d'` — stripping the
   frontmatter — then feeds the remaining prose into a plain
   `opencode run "<prompt>"` call with no `--agent` flag (the comment states
   `--agent` is rejected because the agent's `mode` is `subagent`). The
   `permission` block is real in the committed file and inert in every
   actual CI run; the only live control is English text in a prompt.

3. **High — no defense against prompt injection via untrusted diff/log
   content.** Both agents (`pr-review`, and the ci-sweeper's `ci-triage`
   skill) consume attacker-influenceable content (a PR diff, CI log lines)
   with nothing telling the agent to treat that content as data rather than
   instructions.

4. **High — no integrity check on the opencode binary download.**
   `scripts/install-opencode.sh` (and a second, duplicated, drifted copy
   inline in `daily-triage.yml`) `curl`s a release tarball and executes it
   with no checksum verification.

5. **High — every third-party GitHub Action, and the two cross-repo
   `workflow_call` references to this repo's own reusable workflows, are
   pinned to a mutable ref** (`@v4`, `@master`, `@main`) instead of a commit
   SHA — the exact mechanism behind the tj-actions/changed-files
   supply-chain compromise.

6. **High — `ci-deploy-ssh.yml` has three separate production-facing
   issues:** `StrictHostKeyChecking=no` on every SSH/SCP call (no MITM
   protection against the production host at all); caller-controlled
   `inputs.app-dir` / `inputs.service-name` interpolated unsanitized into
   remote shell command strings; and `${{ secrets.* }}` interpolated
   directly into `run:` script bodies instead of passed through `env:`.

7. **High — the hardcoded-secrets gate has a bypass and a scope gap.**
   `scripts/check-no-hardcoded-secrets.sh`'s `is_ignored_rhs` treats *any*
   quoted assignment value as a safe placeholder — `TOKEN="the-actual-real-
   value"` passes clean, which is backwards: quoting is how a real literal
   is normally written in shell, not evidence it's a placeholder. The scan
   also only covers `agents/ commands/ scripts/ docs/`, not `.github/`,
   `config/`, `templates/`, or `ci/`.

8. **Medium — `ci-dependabot.yml` auto-merges `semver-minor` bumps, not just
   patch.** A minor bump is just as viable a malware-delivery vector as a
   patch (a compromised registry account ships whatever version it wants).

9. **Medium — `ci-toolchain-bump.yml` trusts remote JSON straight into
   `sed -i`** with no validation of the fetched version string's shape
   before it becomes part of a `sed` program.

10. **Medium — no cost ceiling on the `ci-sweeper` loop.** It reacts to
    every failing Self CI run (now scoped to same-repo runs only, per
    finding 1's fix) with no per-window invocation cap — `loop-budget.md`
    only covers the `daily-triage` loop today.

11. **Low — `config/agent.local.env.example` nudges toward a classic PAT**
    ("or reuse the fine-grained token above") for `GH_TOKEN`, when the
    fine-grained token it just described creating is already sufficient for
    every documented use.

## Out of scope

- Rewriting the spec pipeline itself (`agents/spec-*.md`) — none of the
  findings touch it.
- Adding a new SaaS security scanner or changing `ci-security.yml`'s
  CodeQL/Trivy tool choice — only the pinning of the actions that run them.
- Migrating `install-opencode.sh` to verify a maintainer *signature* (no
  signed-release mechanism exists upstream today) — a pinned SHA-256 is the
  achievable integrity control.
