# AC-019-02: The triage skill has a tight output format and the never-guess rule (AC-002)

## AC-019-02-01 — The skill exists with house-style frontmatter and scoped tools
Given `skills/loop-triage/` is the loop's skill directory
When `skills/loop-triage/SKILL.md` is read
Then it exists with `name`, `description`, `license`, and `allowed-tools` frontmatter
And `allowed-tools` grants read/glob/grep, `Bash(gh:*)`, and edit/write scoped only to `STATE.md`, `loop-run-log.md`, and `loop-budget.md`
And `allowed-tools` includes no commit or push tool

## AC-019-02-02 — The skill declares itself the L1 report-only loop
Given the loop is the L1 entry loop per 016 readiness levels
When the skill's "When to use" section is read
Then it states this is the L1 report-only triage loop referencing `docs/LOOP_ENGINEERING.md §Readiness levels`

## AC-019-02-03 — The output format names every real triage source
Given the triage must cover open PRs, specs, CI, and open questions
When the skill's output-format section is read
Then it defines sections titled `OPEN PRS NEEDING ACTION`, `SPECS AWAITING BUILD OR STUCK`, `CI HEALTH`, `UNRESOLVED OPEN QUESTIONS`, `AMBIGUOUS — NEVER GUESS`, and `ACTION_REQUIRED: yes|no`
And `OPEN PRS NEEDING ACTION` derives from `gh pr list --state open` plus `gh pr checks <n>` with check states pass/fail/pending/absent
And `SPECS AWAITING BUILD OR STUCK` derives from the `specs/` file scan and names the gate (awaiting `/spec`, awaiting `/build`, verifier FAIL, architect FAIL, open questions)
And `CI HEALTH` derives from `gh run list --workflow self-ci.yml` and calls out any red on a feature branch
And absent checks are never reported as green

## AC-019-02-04 — The never-guess rule is stated verbatim
Given the informal spec requires ambiguous items to be surfaced, never guessed
When the skill's `AMBIGUOUS — NEVER GUESS` section is read
Then it states verbatim: anything ambiguous is surfaced to the human, never guessed
And each ambiguous entry states what is known and what a human must decide

## AC-019-02-05 — The report-only (L1) rule is stated verbatim
Given week one is report-only
When the skill's report-only section is read
Then it states verbatim: no code change, no PR, no merge — in week one the loop only reports

## AC-019-02-06 — The skill defines the run's output contract
Given every run must write state and notify correctly
When the skill's output section is read
Then it instructs writing outcomes to `STATE.md` and appending one `loop-run-log.md` JSON entry with the 016 fields
And it instructs creating or updating the `Daily Triage` issue via `gh`, signed `Loop Engineering — Daily Triage`, only when `ACTION_REQUIRED: yes`
