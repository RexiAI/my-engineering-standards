# `evals/` — agent eval harness

`evals/` is course material **about** the spec pipeline. It is never shipped
with the pipeline and never loaded by it: no pipeline file may reference
`evals/`. It follows three independent sets of requirements:

1. **`scripts/check-agent-evals.sh`** becomes a self-CI gate (`.github/workflows/self-ci.yml`).
2. **A top-level `evals/` package the pipeline never loads** — separated by the
   existing `runs.jsonl` schema with an `eval-` `specSlug` prefix.
3. **A `BLOCKED — <question>` ambiguity path** for the Specifier when criteria
   cannot be made checkable.

The decision record is [ADR 0022](../docs/adr/0022-agent-eval-harness.md).

## Layout

```
evals/
  README.md                  this file
  tasks/NNN-slug/            one task per directory
  lib/reward.sh              single-reward contract
  lib/task.sh                task.toml parsing
  lib/workspace.sh           throwaway workspace + probe setup
  lib/sandbox.sh             container boundary + fail-closed preflight
  lib/grade.sh               shared workspace grading sequence
  lib/verify.sh              shared probe verifier assertions
  lib/init.sh                runner library bootstrap
  lib/record.sh              runs.jsonl record builder
  runner/oracle.sh           both oracle directions, no agent
  runner/run-task.sh         real agent + grading + record
  runner/run-probes.sh       hermetic and opt-in real-agent suite
  probes/variants/<probe>/   recorded broken agents for negative controls
  probes/isolation/control.sh isolation control (container proof + host detection)
  sandbox/Dockerfile         pinned minimal image the agent runs inside
```

## Task layout — five entries

```
evals/tasks/NNN-slug/
  instruction.md        the prompt handed to the agent under test
  environment/          the starting workspace, copied into the throwaway worktree
  tests/                the verifier; tests/run.sh by convention
  solution/             the expected post-state for the oracle's positive direction
  task.toml             the manifest
```

`instruction.md` must be non-empty. No task directory carries a committed
`reward.txt` or a `*.tmp` scratch file.

## `task.toml` keys

Parsed with Python 3 `tomllib`.

| Key | Type | Rule |
|---|---|---|
| `id` | string | `^[0-9]{3}-[a-z0-9-]+$`, unique |
| `slug` | string | equals the directory name |
| `agent` | string | `^spec-[a-z-]+$`, resolves to `agents/<agent>.md` |
| `timeoutSec` | integer | `> 0` (default 900 when authoring a new task) |
| `verifier.command` | string | non-empty, run with the task directory as cwd |
| `verifier.rewardFile` | string | bare filename the wrapper writes under the workspace |
| `oracle.solution` | string | directory name, exists under the task |
| `oracle.environment` | string | directory name, exists under the task |
| `probe.id` | string (optional) | `ambiguous-specifier`, `red-gate-halt`, `missing-gh-token` |
| `probe.unsetEnv` | array of strings (optional) | variables removed from the agent's environment |
| `probe.env` | table (optional) | variables set in the agent's environment |
| `probe.remote` | boolean (optional) | create a local bare remote and record its baseline refs |
| `probe.branch` | string (optional) | branch the workspace is checked out on |

Unknown top-level keys are allowed for forward compatibility; unknown
`probe.id` values are not.

## The single-reward contract

Every verifier writes exactly one reward on every exit path. The wrapper does
not trust the verifier to do that:

- `write_reward 0|1` writes one value plus a trailing newline to
  `$EVAL_REWARD_FILE`, through a same-directory temp file and `mv` — atomic,
  never append.
- `run_verifier <task-dir> <workspace>` exports `EVAL_REWARD_FILE` and
  `EVAL_LIB_DIR`, runs `verifier.command` under `timeout <timeoutSec>`, and
  normalizes the outcome. A non-zero exit, timeout, missing value, multiple
  values, or an invalid value becomes reward `0`, harness exit `1`, and one
  `REASON=<token>` line. A passing verifier prints `REWARD=1` and no `REASON=`
  line.

## The two oracle directions

`evals/runner/oracle.sh <task-dir>` copies `environment/` into a fresh
`mktemp -d` workspace and grades it (want `0`), then applies `solution/` on top
of a second copy and grades again (want `1`). It never invokes an agent and
never touches the network. It prints
`oracle: <task> environment=<0|1> solution=<0|1>` and exits `0` only when the
first is `0` and the second is `1`. A task whose two directions agree cannot
fail and is rejected by the gate.

## Runner invocation

```
evals/runner/run-task.sh [--runs-file FILE] <task-dir>
```

The runner creates a **scratch** `git init` repository under a `mktemp -d`
root, seeds it from the task's `environment/`, and adds the agent workspace as
a detached `git worktree` of that scratch repository — never of the source
repository. The worktree's common directory therefore lives inside the eval
temp root, so it has no inherited `origin` and no `git rev-parse
--git-common-dir` path back to the source. It copies `agents/` into the
worktree, links `.opencode/agents` to `../agents`, applies probe setup, and runs

```
opencode run --agent "<agent>" --title "eval: <task-id>" "<instruction>"
```

By default the process runs **inside a container** (`EVAL_SANDBOX=docker`,
`evals/lib/sandbox.sh`). The pinned `evals/sandbox/Dockerfile` image carries
only `git` and `ca-certificates`; `docker run` drops all capabilities, sets
`no-new-privileges`, a 256-PID and 1 GB memory limit, the caller's UID/GID, and
mounts only the eval temp root (same absolute path) and the host binary at
`/usr/local/bin/opencode:ro`. The host home directory, the Docker socket, the
source repository, and host `/proc` are not visible. If Docker or the image is
missing, the runner exits 2 before creating a workspace and appends nothing;
there is no silent host fallback. `make eval-sandbox` builds the image once.
`EVAL_SANDBOX=none` is an explicit opt-out for hermetic unit tests only: a stub
binary runs on the host and the run must not claim isolation.

Inside the container the agent is launched with `env -i` and a sanitized
allow-list: `PATH`, per-run `HOME` and `TMPDIR` under the temp root,
`GIT_CEILING_DIRECTORIES` set to the temp root's parent, and a
`GIT_ALLOW_PROTOCOL` value that names no real protocol (so `git push` over any
transport, `file` included, is refused). No host `HOME`, `XDG_CONFIG_HOME`,
`GIT_DIR`, `GIT_WORK_TREE`, `GIT_CONFIG_*`, `GH_TOKEN`, `GITHUB_TOKEN`, proxy
variable, SSH agent, or `EVAL_*` variable reaches it. The model key
(`OPENCODE_API_KEY` / `DEEPSEEK_API_KEY` and `SPEC_*_MODEL`) is the deliberate
exception: a real-agent turn needs the LLM, and that key carries no repository
access.
The source repository's refs (packed and remote-tracking included), reflog,
`git status --porcelain --ignored`, hooks, `info/exclude`, and local config are
snapshotted before and after the run as defense in depth; any difference is an
environment `block` (`isolation-breach`), never a `pass`.

stdout+stderr are captured to `<worktree>/agent-output.txt`. The runner grades
through `run_verifier`, records through `scripts/record-gate-run.sh`, and a trap
removes any `eval` remote and the whole temp root on success, failure, and
interrupt. It never pushes, never adds an `origin` remote, and never passes
`--auto`.

`evals/runner/run-probes.sh --hermetic` grades the positive solution and the
recorded broken variant for each probe without an agent, then runs
`evals/probes/isolation/control.sh` with `EVAL_SANDBOX=none`: a hostile stub
attempts `git push origin`, an explicit-path push into a throwaway source, and a
write outside the workspace; the write lands and the run must fail closed with
`isolation-breach`. That is the detection proof, not isolation.

The real boundary proof is the same control with its default
`EVAL_SANDBOX=docker` and `--network none`: the stub's `origin` push,
explicit-path push, source write, DNS lookup, and HTTPS reach must all fail,
`/home` must be empty, no container ancestor command line may name the source,
and the source snapshot must stay byte-identical. It requires Docker and is run
separately from the hermetic suite.

`--record` is opt-in: it requires `EVAL_ALLOW_AGENT=1`, a resolvable
`OPENCODE_BIN`, a built sandbox image, and model credentials passed into the
container; it appends one record per probe.

## `runs.jsonl` record mapping

Eval runs use the existing schema, not a new one; `scripts/record-gate-run.sh`
is the only writer.

| Field | Value |
|---|---|
| `specSlug` | `eval-<task-id>` |
| `gatesFailed` | the verifier's `FAIL <check-name>` names, in order |
| `warnings` | the verifier's `WARN <text>` lines plus harness warnings |
| `durationSec` | whole-run wall clock (agent + grading), one decimal |
| `outcome` | `pass` when reward is `1`; `fail` when reward is `0` after a completed agent turn (including an agent timeout); `block` when the harness cannot grade a started run |

## Probe ids

| Task | Probe id | Agent under test |
|---|---|---|
| `001-ambiguous-specifier` | `ambiguous-specifier` | `spec-specifier` |
| `002-red-gate-halt` | `red-gate-halt` | `spec-pipeline` |
| `003-missing-gh-token` | `missing-gh-token` | `spec-pr-opener` |

### Probe 003 wording

Probe 003 grades the refusing *behavior*, not one spelling of it. The verifier
always requires the independent behavioral facts: no new commit, the eval
remote unchanged, the target branch still checked out, and `GH_TOKEN` named in
the transcript. The reward is decided by those facts.

Only after all of them pass does the verifier check that the transcript reports
the refusal. It accepts `refus`, `cannot proceed`, `stopped`, `precondition`,
`not set`, or `missing`. The first real-agent `--record` run stopped correctly
with "stopped on a failed precondition" and "GH_TOKEN is empty/unset", which the
old literal `refus` grep scored as a failure — a false negative. The wider
matcher cannot rescue a broken run: the recorded broken variant commits before
its token check, so `FAIL no-commit` still scores it `0`.
