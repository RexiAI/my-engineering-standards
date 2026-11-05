# AC-041: Mechanical-stage model and effort guidance

Applies to Task 6.

## AC-041-45 — Guidance section names every mechanical stage

Given `docs/spec-pipeline/model-config.md`
When it is read
Then it contains the heading `## Mechanical-stage model and effort guidance`
And it contains one table row for each of `spec-deployer`, `spec-pr-opener`,
`spec-mutation-runner` and `spec-pipeline`
And each row states the work shape, the capability class, and the preferred effort
setting

## AC-041-46 — The effort-location finding is recorded

Given the guidance section
When it is read
Then it states that `effort` is set on provider model options in `opencode.json`,
so it applies to every stage using those model ids
And it states that `config/model.local.env.example` sets model ids only and
contains no `effort` key

## AC-041-47 — The verified per-agent lever is recorded

Given the guidance section
When it is read
Then it documents `agent.<name>.options.effort` resolving into
`agent.<name>.request.body.effort`
And it names `opencode debug config` as the verification command
And it states that an agent without `options` resolves to no `request.body` key

## AC-041-48 — No model id or provider id appears in the section

Given the guidance section
When searched for `qwen`, `bailian`, `anthropic`, `deepseek` and `glm`
Then no match exists
And no model-identifier token (`[a-z0-9-]+/[a-z0-9.-]+`) appears other than the
`<provider>/<model-id>` placeholder
And the two concrete file paths this scenario's sibling (AC-041-49) requires are
permitted, not violations: `config/model.local.env` and
`config/model.local.env.example`
And any other slash-form token is a violation

Scope (resolves the AC-041-48 / AC-041-49 conflict): this rule bans literal
model and provider **identifiers**. Concrete repository paths are file
references, and the two named above are mandatory content of the section. The
bare-whole-file ban is Task 1's rule (AC-041-01…08), scoped to
`docs/CODING_CONVENTIONS.md` references in `agents/spec-*.md` and `commands/*.md`
— it does not apply to config paths here. So the permitted token set is exactly
`{<provider>/<model-id>, config/model.local.env, config/model.local.env.example}`.

## AC-041-49 — Shipped defaults are unchanged by this spec, and the decision is recorded

Given the tree after Task 6
When `git diff --quiet 4dbf164 -- config/model.local.env.example opencode.json`
runs
Then it exits 0 — this spec modifies neither file
And `sha256sum config/model.local.env.example opencode.json` still prints
`194765aea7d621ba6014a38bc7503e7ca1df3b29e081edbb0e094b9a36a2e62f` and
`49ecd5edc66d3de16a9227fa0eb32d6cf2baf808fd50c19bcd15715832008ce3`
And the guidance section records the decision not to ship a per-stage default, with
the per-machine route (`config/model.local.env` plus a restart, no commit)

Invariant, stated exactly: **unchanged by this spec**, not "equal to a fixed
historical literal". The two values above are the base tree's bytes at
`4dbf164`; they are pinned so that editing either file on this branch fails the
scenario. If the base branch moves and its pre-spec bytes change, the diff
assertion stays the primary check and both literals move with the new base.
