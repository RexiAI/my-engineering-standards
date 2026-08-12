# AC-017-01: CI-triage skill exists with the classify output format and the flake rule

## AC-017-01-01 — The skill file exists with repo-convention frontmatter (AC-001)
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it exists at `skills/ci-triage/SKILL.md`
And its frontmatter contains `name: ci-triage`
And it follows the repo's skill convention (`description`, `license`, `allowed-tools`)

## AC-017-01-02 — The failing-log read is grounded in this repo's CI
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it names the failing-log read `gh run view <RUN-ID> --log-failed` preceded by `gh run list --workflow "Self CI"`
And it names the workflow this repo actually runs, **Self CI**, and its single job `Validate`

## AC-017-01-03 — The classification output format is defined (AC-001)
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it defines a classification output that selects exactly one of the classes `flake`, `regression`, `infra`, `config`
And it requires the failing job/step and the evidence (log line, file:line, or step name) behind the classification

## AC-017-01-04 — The four classes have a decision guide
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it distinguishes the four classes `flake`, `regression`, `infra`, and `config`
And it states the flake criteria: seen before, intermittent, or passed on retry with no code change

## AC-017-01-05 — The flake rule forbids auto-fix (AC-001)
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it states a flake is classified as **Watch**
And it contains the phrase `never auto-fix`

## AC-017-01-06 — Infra and config are not code defects
Given `skills/ci-triage/SKILL.md` is created per task 1
When the file is read
Then it states infrastructure failures (runner OOM, registry down, secrets missing) and workflow-config failures are not code defects
And it routes them to escalation rather than a code fix
