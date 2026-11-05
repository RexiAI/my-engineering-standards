# Architecture Decision Record (ADR)

## Title

Agent eval harness: hermetic oracle-sane probes in a top-level `evals/` package

## Status

Proposed

## Context

The spec pipeline's stages are prompts and shell gates, and nothing in this
repository measures whether a stage still does its job when its prompt changes.
A prompt edit can silently remove the `BLOCKED` stop path, or let a red gate
through, and every existing gate stays green because none of them exercises an
agent. The upstream course material on agent evaluation (task layout, oracle
sanity, reward contracts) describes the missing loop; this repository has no
`evals/` surface and no gate that proves a probe can fail.

The pipeline's own constraints bound the design: no new pipeline stage
(`docs/SPEC_PIPELINE.md §Stages`), no gate-threshold change, one append-only
telemetry file (`runs.jsonl`), and no `--auto` approval in headless runs. The
repository also has no root `LICENSE`, so upstream code cannot be vendored.

## Decision

1. **A new self-CI gate.** `scripts/check-agent-evals.sh` becomes a Validate-job
   gate in `.github/workflows/self-ci.yml` (with `--self-test`), exiting `0`
   clean, `1` on a finding, and `2` on a tooling failure — the same convention
   as `scripts/check-scenario-traceability.sh`.
2. **A top-level `evals/` package the pipeline never loads.** Task prompts,
   environments, verifiers, solutions, and manifests live under `evals/tasks/`;
   the runner and libraries live under `evals/runner/` and `evals/lib/`.
   `opencode.json`, `agents/`, `commands/`, and `docs/spec-pipeline/` must never
   reference `evals/`: the package is course material about the pipeline, not a
   part of it.
3. **Eval runs append to the existing `runs.jsonl`.** The record keeps the
   existing schema; `scripts/record-gate-run.sh` remains the only writer, and
   eval runs are separated by `specSlug: "eval-<task-id>"` with no schema
   change. A dedicated eval runs file and a new schema key were both rejected.
4. **The Specifier gains a `BLOCKED — <question>` ambiguity path.** When an
   informal spec cannot be turned into checkable acceptance criteria, the
   Specifier emits `BLOCKED — <question>`, writes neither `10-tasks.md` nor
   `20-acceptance/`, and stops. Autopilot converts the stop into the most
   conservative reversible default recorded in `45-decisions.md`.

The harness grades outcomes, never stage counts: spec 039's lite mode removes
stages and must not invalidate a probe. Each task's verifier writes exactly one
reward through `evals/lib/reward.sh`; the oracle runs the untouched environment
(want `0`) and the solution overlay (want `1`) with no agent and no network.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| A separate eval runs file | Clean separation from pipeline telemetry; no filter needed in `gate-stats.sh`. | A second data source contradicts the single-source requirement; the existing writer, schema, and stats tooling would need a parallel copy. |
| A new `runs.jsonl` schema key (`evalTask`) | Explicit separation; the writer passes unknown keys through. | Changes the schema for one consumer, needs a writer/validator change, and `gate-stats.sh` still counts the record unless separately filtered. |
| A hosted eval runner | Managed scheduling, dashboards, and model credentials. | Adds an external dependency, a credential surface, and a service this repository does not operate; self-CI has no model budget. |
| Vendoring the upstream course material | Faster start; proven task formats. | This repository has no root `LICENSE`, so upstream code cannot be relicensed or copied; only its patterns are reused. |
| `--auto` for the agent under test | One flag grants every permission. | Rejected by this repository's loop conventions; it is blanket approval, not a scoped grant. |

## Consequences

- A prompt or gate regression in a covered behavior now fails self-CI's Validate
  job through a probe that is proven able to fail (negative controls run in the
  same gate).
- Real-agent runs stay opt-in (`run-probes.sh --record` requires
  `EVAL_ALLOW_AGENT=1`) because self-CI has no model credentials; the hermetic
  oracle and negative-control paths run in CI. `--record` is documented as a
  local, credentialed action so probe coverage does not silently shrink.
- `runs.jsonl` now also carries eval records. `scripts/gate-stats.sh` counts them
  in the pipeline failure rate until a follow-up spec filters the `eval-` prefix;
  this is a known, accepted limitation of choosing no schema change.
- The hermetic gate is read-only: it never starts `opencode`, never uses the
  network, never writes `runs.jsonl`, and keeps every fixture in `mktemp`.
- The following are explicitly out of scope for this decision and this change:
  generic coding benchmarks; mining or consuming the appended eval records (a
  later spec owns the miner); vendored upstream code; Modal, Opik, Kitaru,
  third-party sandbox backends (the plain Docker boundary in §Notes is not a
  sandbox backend), and hosted runners; token/context rules (spec 041); and
  filtering eval records out of `scripts/gate-stats.sh` (follow-up).

## Compliance

- `scripts/check-agent-evals.sh` enforces package structure and isolation, the
  task/manifest contract, the single-reward contract, oracle sanity in both
  directions, the static runner contract, the hermetic probe suite, the ADR
  index row, and the self-CI step. `--self-test` proves each check fails closed.
- `.github/workflows/self-ci.yml` runs the gate and its self-test in the
  Validate job, with no `continue-on-error` and `permissions: contents: read`.
- `bash scripts/check-governance.sh` keeps this ADR index row review-blocking.
- `bash scripts/check-scenario-traceability.sh` keeps every AC-043 scenario
  wired to a bats test.

## Notes

- 2026-11-05: Decision recorded.
- 2026-11-05: **Isolation model (phase-1 remediation).** The probe workspace is
  a detached `git worktree` whose parent is a scratch `git init` repository
  seeded from the task's `environment/` under the eval temp root — never a
  worktree of the source repository. The worktree's common directory therefore
  lives inside the eval temp root: no shared common directory with the source,
  no inherited `origin`, and no `git rev-parse --git-common-dir` path back to
  the source. The agent runs under `env -i` with `PATH`, fresh
  per-run `HOME`/`TMPDIR` temp directories, `GIT_CEILING_DIRECTORIES` set to
  the temp root's parent, and a `GIT_ALLOW_PROTOCOL` value that names no real
  protocol (so no git transport, `file` included, is allowed); no host `HOME`,
  `XDG_CONFIG_HOME`, `GIT_DIR`, `GIT_WORK_TREE`, `GIT_CONFIG_*`, `EVAL_*`, or
  source-root variable is passed. The deny-list is removable by a same-UID
  agent (unset it or pass `-c protocol.file.allow=always`), so the snapshots
  below remain the detection backstop.
  The source repository's refs, reflog, `git status --porcelain`, and local
  config are snapshotted before and after every probe; any difference is an
  environment `block` (`isolation-breach`), never a `pass`.
  `evals/probes/isolation/control.sh` is the hermetic negative control: a stub
  attempts `git push origin`, an explicit-path push, and a write outside the
  workspace, and the run must fail closed.
  **Limitation:** this is detection plus link removal, not a full filesystem
  sandbox. Writes to arbitrary paths outside both the workspace and the source
  repository are not observed; the guarantee is scoped to the source
  repository, which is the repository the probes must never reach. A stronger
  mount-namespace sandbox is deliberately not a runtime dependency — if one is
  adopted later, it must be optional so the hermetic suite stays portable, and
  a probe must still fail closed when the sandbox is unavailable.
- 2026-11-05: **Container boundary (phase-1 remediation, attempt 3).** Detection
  and link removal were not enough: the Verifier derived the source root from an
  ancestor `/proc/<pid>/cmdline`, read the source `origin`, and pushed to it
  while the run still recorded `pass`. Environment scrubbing cannot close a
  same-UID process-tree channel, so the agent now runs under a real container
  boundary. `evals/sandbox/Dockerfile` pins `debian:bookworm-slim` by digest and
  installs only `git` and `ca-certificates`; `make eval-sandbox` builds it once,
  tagged by the base digest's short SHA. `evals/lib/sandbox.sh` runs the agent
  with `--rm --init --cap-drop=ALL --security-opt no-new-privileges
  --pids-limit 256 --memory 1g --user <uid>:<gid>`, working directory `$WT`, and
  exactly two mounts: `$TMP_ROOT:$TMP_ROOT` (same absolute path, so the host-side
  detached worktree resolves inside the container) and
  `$OPENCODE_BIN:/usr/local/bin/opencode:ro`. It never uses `--privileged`,
  never mounts the Docker socket, the host `$HOME`, or the source repository.
  `HOME`/`TMPDIR` live inside the temp root, and the environment is the existing
  allow-list: no `GH_TOKEN`, `GITHUB_TOKEN`, proxy, SSH-agent, or `GIT_*` value.
  The model key is the one deliberate pass-through, because a real-agent turn
  needs the LLM and that key grants no repository access.
  **Network split.** A real-agent `--record` run keeps the default bridge (it
  must reach the model) but has no GitHub credential and no source mount. The
  isolation control runs with `--network none`: the hostile stub can neither
  resolve DNS nor reach an HTTPS remote. The asymmetry is inherent — the LLM is
  reachable, the source is not, and no credential that can write the source
  exists in either mode.
  **Fail closed.** `sandbox_preflight` runs before any workspace or temp root is
  created. When Docker is absent, the daemon is unreachable, or the pinned image
  is not built, `run-task.sh` and the isolation control exit 2 with an
  `environment-block`/`sandbox-unavailable` line and append no record. There is
  no silent host fallback. `EVAL_SANDBOX=none` exists only for hermetic unit
  tests: it must be set explicitly, runs a stub on the host, and its output says
  `sandbox=none ... not-isolated` so it never claims the container guarantee.
  **Snapshot hardening.** `snapshot_repo_state` now also covers packed refs,
  remote-tracking refs (`for-each-ref`), `git status --porcelain --ignored`,
  `info/exclude`, and hook files. Gitignored source writes are unreachable in
  the default mode because the source is not mounted at all; the control proves
  it by attempting a write to the baked-in source path from inside the
  container and requiring failure. The snapshot remains as the fail-closed
  detection layer for the explicit host mode.
  **Residual limitation:** real-agent `--record` probes need Docker plus the
  model key and are not run by hermetic CI; CI runs the host-mode detection
  control only. Container isolation is a process/filesystem boundary, not a
  network policy for the LLM endpoint: the agent can reach whatever the bridge
  allows, which is why no GitHub credential is present.
- 2026-11-05: **Overlay verification and limitation.** The human-chosen default
  (Q3) is a per-run `opencode.json` overlay in the throwaway workspace granting
  `edit`/`bash` allow plus the existing deny list. Verified against the pinned
  opencode binary (`v1.18.18`): a project-level `opencode.json`
  `agent.<name>.permission` overlay **merges only keys the agent's markdown
  frontmatter does not define**. When the agent markdown defines
  `permission.edit` (it does for `spec-pipeline`, `spec-specifier`, and
  `spec-pr-opener`), the markdown value wins and the overlay cannot widen it.
  The runner still writes the overlay because it supplies absent keys (for
  example `bash` for `spec-pipeline`) and satisfies the selected option, but
  the probes do not depend on a broadened `edit` grant. Probe outcomes are
  graded from workspace state and the transcript only; probe 1 can still write
  under `specs/` through the agent's existing `specs/**` allow, and probes 2
  and 3 assert the halting and refusing outcomes rather than requiring a
  successful edit. This is the documented fallback (c) — transcript-and-outcome
  probes — recorded here so the weaker guarantee is not mistaken for a
  permission-isolation proof.
