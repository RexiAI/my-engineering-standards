# ADR 0021 — Make the pipeline's own gates fail safely and report truthfully

## Status

Accepted

## Context

Three defects surfaced while running the spec pipeline against v1.50.1 in a
Next.js child repo (spec 004). Each one is a case of a gate or a stage agent
producing a confident wrong answer rather than an honest one.

**1. The archive destroyed the evidence it was archiving.**
`scripts/archive-spec.sh` composes `docs/changes/NNN-slug.md` from scratch. The
pipeline's documented order is 5b (open PR) → phase 2 CI → 5c (deploy) → 5d
(archive), and stage 4 records post-PR CI evidence as the rounds happen. On spec
004 the evidence was written into the one-pager at 5b, then a re-archive at 5d
regenerated the file and wiped it minutes later. It survived only because a
Verifier recovered it verbatim from an earlier commit's blob. A gate that
silently deletes the record of its own gate runs is worse than no gate: the
audit trail reads complete while the content is gone.

**2. The design-principles gate never completed, and two specs did not notice.**
`check-code-principles.sh` ended its DRY analyzer with `| sort -rn | head -10`.
Under `set -euo pipefail`, `head` closing the pipe gives `sort` SIGPIPE and the
script exits **141** at the DRY section — before YAGNI, SOLID,
component-per-file, property-tests and (since v1.50.1) the clean-code gates ever
run. Separately `FIND_PRUNE`/`GREP_EXCLUDES` named `node_modules`, `target`,
`vendor`, `dist`, `build` but not `.next`, so Next.js build output was analysed
as source and produced three bogus cyclomatic-complexity FAILs against turbopack
runtime chunks.

The composition of the two matters: on a built Next.js repo the whole-tree run
died at 141 and the diff-scoped run also died at 141, so an operator reading
"design-principles PASS" was reading a verdict from a process that had stopped
early. The Verifier records the gate's exit code, and recorded the real 141 — but
the pipeline carried on, because the surrounding prose treats a non-zero exit
partly tolerated as a known defect.

**3. A stage agent reported a configuration defect that did not exist.**
`spec-deployer` treated an absent `VERCEL_TOKEN` as a configuration defect. Vercel's
Git integration builds the preview and publishes the deployment through the
`Vercel` commit status, the bot's PR comment payload, `vercel inspect` via the
CLI's stored session, and the immutable deployment URL — none of which need an
API credential. The stage had every signal it needed and still reported the
project's setup as broken.

## Decision

**Archive refuses to overwrite.** `archive-spec.sh` exits 1 when
`docs/changes/NNN-slug.md` already exists, explains that regenerating discards
appended content, points at `specs/NNN-slug/` as the home for content that
belongs in the archive, and accepts `--force` as the explicit replace signal.
Positional parsing stays strict: exactly one slug, optional `--force`; two
positional arguments remain a usage error.

**The DRY analyzer reads its input to completion.** `head -10` becomes
`awk 'NR<=10'`; a truncating consumer on a `pipefail` pipeline is the defect, not
the truncation. `.next`, `.nuxt`, `.output`, `coverage` and `.stryker-tmp` join
`FIND_PRUNE` and `GREP_EXCLUDES`: build output and caches are not source, and a
gate that scores them is scoring the wrong artefact.

**Preview verification needs no API credential.** `spec-deployer` resolves the
deployment from the Git-integration signals and proves identity by matching the
deployment's `githubCommitSha` to the PR head, because a branch alias can lag a
build and a 200 from a stale commit is a failure, not a pass. `DEPLOYMENT.md`
separates the two lanes: preview verification (no credential) and post-merge
production verification (`verify-production-deploy.sh`, which queries the Vercel
API and still records a missing or rejected token as a failure).

### Alternatives Considered

| Alternative | Pros | Cons |
|---|---|---|
| Archive appends instead of regenerating | Preserves anything added later | The one-pager would accumulate duplicates across re-runs; the composed sections would need their own replacement logic; the file stops being reproducible from `specs/` alone |
| Archive merges appended content after the generated body | Keeps both | Requires a reliable boundary between generated and appended content, which the script cannot infer; silently wrong more subtly than refusing |
| Keep `head -10`, drop `pipefail` for the analyzer | Minimal diff | Gives up `pipefail` for every gate in the file to fix one call site |
| Exclude `.next` by requiring repos to clean before gating | No script change | Pushes a script defect onto every consumer; the gate would be correct only if run in a particular order |
| Require `VERCEL_TOKEN` everywhere and keep the defect | One credential, one rule | Contradicts how the Git integration actually works, and reports a healthy project as broken — the highest-cost failure of the three |
| Keep the token requirement for stage 5c and treat it as a skip | No agent change | Turns a working lane into a silently skipped one |

## Consequences

- A re-archive of an already-archived spec now needs `--force`. Intentional; it
  is a behavioural change to a script whose contract said "ready to commit".
- The design-principles gate now runs to completion on a built Next.js repo:
  **exit 141 → exit 0**, 0 FAIL / 232 WARN on the repo this was found in. The
  232 WARNs are the v1.50.1 clean-code gates being WARN-by-default as designed;
  they are now visible for the first time, which is the point.
- Every "design-principles PASS" recorded before this ADR on a repo that had been
  built is a verdict from a process that stopped early. `check-code-principles.sh`
  exit codes of 141 in `25-verification.md` are that defect, not a flake.
- Stage 5c works on a connected Vercel project with no local credential, and its
  stale-build guard is now explicit rather than incidental.
- The post-merge production lane is unchanged: it still needs a credential and
  still fails loudly without one.

## Compliance

- `scripts/tests/archive-spec.bats` — usage paths, plus the refusal and
  `--force` paths.
- `scripts/tests/check-code-principles.bats` — DRY detection still fires when
  duplication exists (the fix must not have disabled the gate).
- `scripts/tests/check-code-principles-clean-code.bats` — the gates that were
  previously unreachable now run.
- `scripts/tests/ac-031-production-deploy.bats` AC-031-40 — a missing
  `VERCEL_TOKEN` still records a failure for the post-merge lane. Unchanged
  behaviour, explicitly asserted.
- `scripts/tests/ac-031-spec-deployer-agent.bats` — the stage-5c agent's
  permissions and prohibitions are unchanged; only its credential assumption and
  its stale-build proof are new.
- `scripts/check-pr-review.sh` ADR 0009 change-set guard — this record is the
  ADR that allows the `agents/spec-*.md` change in the same change set.
