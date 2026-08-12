# AC-017-03: The loop reacts to a failing CI run via a wired trigger

## AC-017-03-01 — The trigger is a workflow_run on Self CI (AC-002)
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then it exists at `.github/workflows/ci-sweeper.yml`
And it contains a `workflow_run` trigger on `types: [completed]`
And it names the watched workflow as **Self CI**

## AC-017-03-02 — The loop reacts only to failure and exits early when green (AC-006)
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then the job runs only when `github.event.workflow_run.conclusion == 'failure'`
And a green run is skipped as a no-op — the early exit when CI is green

## AC-017-03-03 — The failing-run context is passed to the sweep
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then the job captures the failing-run context from the `workflow_run` event: run id, `head_sha`, and `head_branch`
And it passes that context into the sweep invocation

## AC-017-03-04 — The sweep is invoked through the repo's agent tooling
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then it invokes a headless `opencode run` that loads `skills/ci-triage` and receives the failing-run context

## AC-017-03-05 — Permissions are least-privilege (AC-002)
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then the workflow declares `contents: read`, `actions: read`, and `issues: write` and no broader scope
And it does not grant merge, push-to-`main`, or tag-creation capability
And it contains no auto-merge step

## AC-017-03-06 — The activation constraint and readiness are documented
Given `.github/workflows/ci-sweeper.yml` is created per task 3
When the file is read
Then it notes the `workflow_run` trigger activates only after merging to `main`
And it notes that until spec 016 lands the loop runs report-only (L1) and must not auto-fix unattended
