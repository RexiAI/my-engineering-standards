# AC-043: Eval package and pipeline isolation

## AC-043-05 — Top-level package with the documented contract
Given the repository root
When `evals/` is listed
Then `evals/README.md` and `evals/tasks/` exist
And the README documents the five-entry task layout
And it documents the single-reward contract, the `task.toml` keys, the two oracle directions, the runner invocation, and the `runs.jsonl` record mapping
And it states that no pipeline file may reference `evals/`

## AC-043-06 — The pipeline surface never references evals
Given `opencode.json`, `agents/*.md`, `commands/*.md`, and `docs/spec-pipeline/*.md`
When each is scanned for the literal string `evals/`
Then zero matching lines are found
And `opencode.json` contains no key or value naming `evals`

## AC-043-07 — The gate follows the established check-script conventions
Given `scripts/check-agent-evals.sh`
When it runs on a compliant tree
Then it exits 0
And on a finding it exits 1 and prints `FAIL AC-043-<NN> — <path>: <reason>`
And on a tooling failure it exits 2
And `--self-test` runs its fixture set
And it writes no file outside a `mktemp -d` directory

## AC-043-08 — A missing package fails the gate
Given a scratch root with no `evals/` directory
When `scripts/check-agent-evals.sh <scratch-root>` runs
Then it exits 1
And a failure line names `evals/`
And the script does not abort with a shell error such as `unbound variable` or `No such file or directory`

## AC-043-09 — A pipeline reference to evals fails the gate
Given a scratch root whose `agents/spec-coder.md` contains the string `evals/tasks`
When the gate runs against that root
Then it exits 1
And the failure line names `agents/spec-coder.md`
