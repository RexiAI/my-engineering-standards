# 010-governance-trust-tiers

> Spec pipeline archive. Original source: `specs/010-governance-trust-tiers/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Governance document + trust tiers

Split governance from operations. Add docs/GOVERNANCE.md:

1. **Trust tiers.** T0 autonomous (reads, gates, Jira/Confluence read, Jira
   comment), T1 local write (edit, commit, local branch), T2 confirm (push, PR,
   Confluence publish, Jira transition — human-triggered), T3 forbidden (push to
   main, force-push, destructive infra). Each pipeline agent maps to a tier.
2. **Model-assignment discipline.** "Change the model only by editing the agent
   frontmatter AND the model table (AGENTS.md / opencode.json) in the same
   commit." Prevents the config drift observed this session.
3. **ADR requirement.** Any change to pipeline roles, gate catalog, or billing
   constraint must be recorded as an ADR (templates/ADR.md exists but is unused)
   before merging. Review-blocking otherwise.

## Acceptance criteria

- AC-001: docs/GOVERNANCE.md exists with the three sections.
- AC-002: each agent's trust tier is stated (frontmatter or table).
- AC-003: model assignments live in exactly one authoritative place (opencode.json)
  and the AGENTS.md table is a mirror with a conformance note.
- AC-004: ADRs are indexed; pipeline-role/gate changes require one.

## Tasks

# Tasks: Governance document + trust tiers

Formalizes `specs/010-governance-trust-tiers/00-informal.md` into an authoritative
`docs/GOVERNANCE.md` that splits governance from operations: trust tiers, the
model-assignment discipline, and the ADR requirement. Grounded in the real repo as
it stands today.

## Grounded reality (verified against this repo)

- **8 real pipeline agents** exist under `agents/`:
  `spec-pipeline`, `spec-specifier`, `spec-ux`, `spec-coder`,
  `spec-refactorer`, `spec-verifier`, `spec-mutation-runner`, `spec-pr-opener`.
  There is **no `agents/spec-architect.md`** — the "Architect" role was split into
  5a `spec-mutation-runner` + 5b `spec-pr-opener` (see git history, and
  `specs/006-orchestration-conformance` which already removed the last dangling
  `spec-architect` token from an agent body).
- **Config drift that motivated this spec (live today):** `opencode.json` still
  lists `spec-architect` (a model entry for a nonexistent agent) and omits
  `spec-mutation-runner` and `spec-pr-opener`. The `AGENTS.md` model table
  (`AGENTS.md:44-62`) mirrors that same stale 7-row list. `AGENTS.md:19` cites
  `agents/spec-architect.md` in the commit/push carve-out. Fixing that drift is
  **not** in scope here — it is an operational config change and, under the ADR
  rule this spec creates, would itself warrant an ADR. This spec only writes the
  governance document, the ADR index, and a conformance check.
- **Trust-tier mapping basis:** each agent's `permission` frontmatter, read from
  the real files (see Task 3). Where frontmatter is *broader* than the agent's own
  prose instructions, the table records the frontmatter-granted tier and notes the
  policy override.
- **Model authority:** `opencode.json` `agent.<name>.model` is what takes effect;
  per `docs/SPEC_PIPELINE.md §Model configuration`, shipped agents ship *without* a
  `model:` key precisely so `opencode.json` wins. The `AGENTS.md` table is a
  human-readable mirror (and adds the fallback-chain column, which only lives
  there). `docs/SPEC_PIPELINE.md:227-234` documents the strong/weak model split.
- **ADR location:** `docs/GIT_WORKFLOW.md §Architecture Decision Records (ADRs)`
  says ADRs live at `docs/adr/`, use `templates/ADR.md`, and follow the lifecycle
  Proposed → Accepted → Deprecated → Superseded. `templates/ADR.md` exists but is
  unused; `docs/adr/` does not exist yet.
- **Push/main rules:** `AGENTS.md:20` and `docs/GIT_WORKFLOW.md:10` forbid direct
  push to `main`/`master` with no exceptions. The only push-capable agent is
  `spec-pr-opener` (`git push*: ask`, stage 5b), under the carve-out in
  `docs/SPEC_PIPELINE.md §Commit and push carve-out`.
- **Test framework:** this repo has no JVM/Go/Node suite — its "tests" are the
  `scripts/check-*.sh` + Makefile pattern. Per the `specs/009-stop-and-ask-matrix`
  precedent, this spec therefore ships a shell check script (Task 6) that carries
  the `AC-010-NN` IDs for `scripts/check-scenario-traceability.sh`.

## Tasks

### Task 1 — Create `docs/GOVERNANCE.md` with the three sections

Create `docs/GOVERNANCE.md` at the repo root of the standards repo. The file must
open with a one-line statement that governance is separated from operations: the
operational mechanics live in `docs/SPEC_PIPELINE.md`, `docs/GIT_WORKFLOW.md`, and
`AGENTS.md`; this document states the non-negotiable governance constraints.

The file must contain exactly three top-level sections, in this order, with these
exact heading texts:

- `## Trust Tiers`
- `## Model-Assignment Discipline`
- `## ADR Requirement`

No other top-level `##` section may exist in the file. Content of each section is
specified by Tasks 2, 4, and 5 respectively (this task only requires the file and
the three headings to exist; a section may be temporarily skeletal, but every
section must already carry its Task's content by the end of that task).

Acceptance:
- `docs/GOVERNANCE.md` exists.
- It contains the three headings above, in the order given.
- It contains no other top-level `##` heading.
- Its opening paragraph states the governance/operations split and points at
  `docs/SPEC_PIPELINE.md` as the operational home.

Scenarios: `20-acceptance/AC-010-01-governance-doc.md`

### Task 2 — Trust Tiers section: define T0–T3

Populate the `## Trust Tiers` section with the four-tier model from the informal
spec. The tiers must be defined exactly as follows (capability lists are the
informal spec's, not abbreviated):

| Tier | Name | Capabilities |
|---|---|---|
| T0 | Autonomous | reads, gates, Jira/Confluence read, Jira comment |
| T1 | Local write | edit, commit, local branch |
| T2 | Confirm (human-triggered) | push, PR, Confluence publish, Jira transition |
| T3 | Forbidden | push to main, force-push, destructive infra |

The section must additionally state:
- T3 applies to **every** agent uniformly — no agent, under any circumstance, may
  push to `main`/`master`, force-push, or run destructive infra actions. This
  restates `AGENTS.md:20` / `docs/GIT_WORKFLOW.md:10` as a governance constraint.
- The only remote-write exception is the spec-pipeline carve-out: `spec-pr-opener`
  may push to a branch named `spec/NNN-slug` and open a **draft** PR, only after
  every configured quality gate is green, per `docs/SPEC_PIPELINE.md §Commit and
  push carve-out`.

Acceptance:
- The section contains the tier table above with all four rows and the exact
  capability lists.
- The section states T3 is universal (applies to all agents).
- The section names `spec-pr-opener` as the sole push-capable agent and ties it to
  the `spec/NNN-slug` + draft-PR + gates-green carve-out.

Scenarios: `20-acceptance/AC-010-02-trust-tiers.md`

### Task 3 — Trust Tiers section: agent-to-tier mapping table

Add to the `## Trust Tiers` section a table mapping every one of the 8 real
pipeline agents to a trust tier, derived from each agent's actual `permission`
frontmatter. The table must cover exactly these agents and tiers:

| Agent | Stage | Trust tier | Frontmatter basis (real) | Policy override (if any) |
|---|---|---|---|---|
| `spec-verifier` | 4 | **T0** | edit only `specs/*/25-verification.md` (`*: deny`); `git commit*`/`git push*` denied | none — reads, runs gates, writes only its report |
| `spec-specifier` | 1 | **T1** | edit `specs/**` allow, `*` deny; `git *` allow | none |
| `spec-coder` | 2 | **T1** | read denies only `00-informal.md`; `git push*` denied, other git allowed | prose says never commit/push — frontmatter would allow `git commit` |
| `spec-refactorer` | 3 | **T1** | read denies `specs/**`; `git push*` denied, other git allowed | prose says never commit/push — frontmatter would allow `git commit` |
| `spec-mutation-runner` | 5a | **T1** | read denies `00-informal.md`; `git commit*`/`git push*` denied | none — edits tests/report, no git write |
| `spec-pr-opener` | 5b | **T2** | read denies `00-informal.md`; `git push*` is `ask`; git commit allowed | none — the only push-capable agent |
| `spec-ux` | 1.5 | **T2 (frontmatter) / T1 (policy)** | read `*` allow; `git commit*` ask, `git push*` ask | prose says "Do not commit or push" — frontmatter permits push only on human confirmation |
| `spec-pipeline` | orchestrator | **T1 (policy)** | no `permission` block at all — opencode primary defaults grant full access | policy (its instructions) forbids commit/push; frontmatter imposes no restriction |

The table must state, per the informal spec, that each agent's tier is its highest
granted action class as read from its permission frontmatter, and that T3
prohibitions apply to all agents regardless of tier.

Acceptance:
- The table contains all 8 agent names above.
- `spec-verifier` → T0 and `spec-pr-opener` → T2 are present.
- No agent is mapped to T3 (T3 is the universal prohibition, not an assignment).
- The `spec-pipeline` row records the fact that it has no permission frontmatter
  (governance gap, not silently papered over).

Scenarios: `20-acceptance/AC-010-03-agent-tier-mapping.md`

### Task 4 — Model-Assignment Discipline section

Populate the `## Model-Assignment Discipline` section. It must state, in prose:

1. **Single authoritative source:** model assignments for the spec pipeline live in
   exactly one authoritative place — `opencode.json` (`agent.<name>.model`).
2. **Mirror:** the `AGENTS.md` model table (`AGENTS.md:44-62`) is a mirror of that
   source for humans and for the model-fallback plugin's documentation. It is not a
   second source of truth; only its fallback-chain column carries information
   (`opencode.json` has no such data) and must not be edited to reflect a primary
   model change without the `opencode.json` change landing in the same commit.
3. **Same-commit rule:** change a model only by editing `opencode.json` AND the
   `AGENTS.md` mirror table in the same commit. Never edit one without the other.
4. **Frontmatter rule:** agent files must not pin a `model:` key (per
   `docs/SPEC_PIPELINE.md §Model configuration` — a pinned `.md` model silently
   overrides `opencode.json`). If a child repo pins a model in frontmatter anyway,
   that edit must land in the same commit as the mirror table edit.
5. **Conformance note:** the section must close with an explicit conformance
   statement that violating the same-commit rule is a governance defect (a review
   blocker, same class as the ADR rule), because the drift observed this session
   (a model entry pointing at a nonexistent agent, `spec-architect`) is exactly
   what this rule exists to prevent.

Acceptance:
- The section names `opencode.json` as the single authoritative source.
- The section names the `AGENTS.md` table as a mirror with the same-commit rule.
- The section states agent frontmatter must not pin models.
- The section contains an explicit conformance note tying the rule to the observed
  `spec-architect` drift.

Scenarios: `20-acceptance/AC-010-04-model-discipline.md`

### Task 5 — ADR Requirement section + `docs/adr/` index

Populate the `## ADR Requirement` section and create the ADR index.

The section must state:
- Any change to **pipeline roles**, the **gate catalog**, or **billing
  constraints** must be recorded as an Architecture Decision Record before the
  change merges. This is **review-blocking**: a PR that changes one of these
  without an accompanying ADR cannot merge.
- ADRs are written from `templates/ADR.md`, live in `docs/adr/`, and follow the
  lifecycle in `docs/GIT_WORKFLOW.md §Architecture Decision Records (ADRs)`
  (Proposed → Accepted → Deprecated → Superseded).
- The section names `docs/adr/README.md` as the index of recorded ADRs.

Create `docs/adr/README.md` as the ADR index. It must:
- State that ADRs are indexed here, one per file, named `NNNN-slug.md`
  (zero-padded sequence + slug), per `templates/ADR.md`.
- Reference `templates/ADR.md` as the mandated template.
- Note that no ADRs are recorded yet (the index starts empty) and that the first
  ADR should itself document this governance split (per the rule, adding trust
  tiers and a model-discipline rule changes pipeline roles — a follow-up
  recommendation, not required by this spec).

Acceptance:
- The `## ADR Requirement` section states the review-blocking rule for pipeline
  role / gate catalog / billing changes.
- The section references `templates/ADR.md` and `docs/adr/`.
- `docs/adr/README.md` exists and references `templates/ADR.md`.

Scenarios: `20-acceptance/AC-010-05-adr-requirement.md`

### Task 6 — Add `scripts/check-governance.sh`

Add a mechanical conformance check matching the existing `scripts/check-*.sh`
style (`set -euo pipefail`, `FAIL`/`PASS` lines, exit 0 on compliance / 1 on
violation). It must verify, against the real repo:

1. `docs/GOVERNANCE.md` exists and contains exactly the three headings
   `## Trust Tiers`, `## Model-Assignment Discipline`, `## ADR Requirement` (and
   no other top-level `##` heading).
2. The Trust Tiers section defines T0–T3 with the informal spec's capability lists
   (grep for the four tier labels and the key capability terms).
3. The agent mapping table names all 8 real agents, with `spec-verifier` → T0 and
   `spec-pr-opener` → T2, and no agent assigned T3.
4. The Model-Assignment Discipline section names `opencode.json` as authoritative,
   the `AGENTS.md` table as mirror, and contains the same-commit rule.
5. The ADR Requirement section names `templates/ADR.md` and `docs/adr/`.
6. `docs/adr/README.md` exists and references `templates/ADR.md`.

The script must cite every scenario ID from `20-acceptance/` in its PASS/FAIL
output (e.g. `PASS AC-010-01-01 …`), so
`scripts/check-scenario-traceability.sh` resolves each scenario to this script.
The script must not modify any file.

Acceptance:
- `scripts/check-governance.sh` exists and is executable.
- Exit code 0 on the compliant repo state after Tasks 1–5.
- Each individual check FAILs (exit 1) when its corresponding artifact is broken
  (missing doc / missing heading / missing agent row / missing mirror note /
  missing ADR index).
- The script's output contains every `AC-010-NN-NN` ID from this spec.

Scenarios: `20-acceptance/AC-010-06-check-script.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 GOVERNANCE.md exists with the three sections | 1, 2, 4, 5 | `AC-010-01-governance-doc.md` (+ section files) |
| AC-002 each agent's trust tier is stated | 3 | `AC-010-03-agent-tier-mapping.md` |
| AC-003 model assignments in one authoritative place + mirror + conformance note | 4 | `AC-010-04-model-discipline.md` |
| AC-004 ADRs indexed; pipeline-role/gate changes require one | 5 | `AC-010-05-adr-requirement.md` |

## Open questions (need a human answer before /build)

1. **Model-table drift is out of scope — confirm.** `opencode.json` still lists
   `spec-architect` (nonexistent agent) and omits `spec-mutation-runner` /
   `spec-pr-opener`; `AGENTS.md:19` and the `AGENTS.md` model table repeat the
   stale `spec-architect`. Task 4's conformance note *describes* this drift but
   does not fix it. Fixing it is an operational config change that — under the ADR
   rule this spec creates — warrants its own ADR. Recommended: a follow-up spec +
   ADR. Confirm the governance doc should document, not fix.
2. **`spec-ux` tier.** Its frontmatter allows `git push*` on `ask` (→ T2 by the
   "highest granted action class" rule), but its instructions say never push. The
   table records T2 (frontmatter) / T1 (policy). Confirm the dual label reads
   right, or state a preferred single assignment.
3. **`spec-coder` / `spec-refactorer` commit latitude.** Frontmatter denies only
   `git push*`, so `git commit` is permitted by config while prose forbids it.
   Confirm recording this as a policy-override note (not tightening frontmatter in
   this spec).
4. **`spec-pipeline` has no permission block.** The governance table records this
   as a gap. Consider (separately) giving the orchestrator an explicit
   `permission` block denying commit/push — confirm that tightening is a follow-up,
   not part of this spec.
5. **Traceability vehicle.** Because this repo has no JVM/Go/Node suite, Task 6
   ships a shell check script to carry the `AC-010-NN` IDs, matching the
   `specs/009-stop-and-ask-matrix` precedent. Confirm that implementation choice.
6. **First ADR.** Per the new rule, creating GOVERNANCE.md changes pipeline roles
   and gates and could itself require an ADR. Task 5 recommends it as a follow-up.
   Confirm that's acceptable (this spec's PR is not self-blocked).
7. **AGENTS.md cross-reference.** Optionally add `docs/GOVERNANCE.md` to the
   `AGENTS.md` "Reading the Standards" list. Not required by any AC; include only
   if you want the doc discoverable from that index.

## Acceptance scenarios

## AC-010-01-01 — The governance document exists
## AC-010-01-02 — The document contains exactly the three required headings
## AC-010-01-03 — The three sections appear in the required order
## AC-010-01-04 — The document declares the governance/operations split
## AC-010-02-01 — The Trust Tiers section exists
## AC-010-02-02 — T0 is defined as autonomous reads, gates, and comments
## AC-010-02-03 — T1 is defined as local write
## AC-010-02-04 — T2 is defined as confirm, human-triggered
## AC-010-02-05 — T3 is defined as forbidden operations
## AC-010-02-06 — T3 applies to every agent uniformly
## AC-010-02-07 — The sole remote-write carve-out is named
## AC-010-03-01 — All 8 real agents appear in the mapping table
## AC-010-03-02 — spec-verifier is T0
## AC-010-03-03 — spec-pr-opener is T2
## AC-010-03-04 — No agent is assigned T3
## AC-010-03-05 — The tier is derived from actual permission frontmatter
## AC-010-03-06 — The spec-pipeline gap is recorded, not hidden
## AC-010-04-01 — The Model-Assignment Discipline section exists
## AC-010-04-02 — opencode.json is the single authoritative source
## AC-010-04-03 — The AGENTS.md table is a mirror
## AC-010-04-04 — The same-commit rule is stated
## AC-010-04-05 — Agent frontmatter must not pin models
## AC-010-04-06 — A conformance note ties the rule to the observed drift
## AC-010-05-01 — The ADR Requirement section exists
## AC-010-05-02 — Pipeline role, gate catalog, and billing changes require an ADR
## AC-010-05-03 — The requirement is review-blocking
## AC-010-05-04 — ADRs use the template and live in docs/adr/
## AC-010-05-05 — The ADR index exists and references the template
## AC-010-05-06 — The index records that no ADR exists yet
## AC-010-06-01 — The check script exists and is executable
## AC-010-06-02 — The script passes on the compliant repo
## AC-010-06-03 — The script fails when the governance document is missing
## AC-010-06-04 — The script fails when a required heading is missing
## AC-010-06-05 — The script fails when an agent row is missing from the tier table
## AC-010-06-06 — The script fails when the mirror note is missing
## AC-010-06-07 — The script fails when the ADR index is missing
## AC-010-06-08 — The script cites every scenario ID

## Verification

# Verification — spec 010 (governance-trust-tiers)

Verifier: stage 4, `agents/spec-verifier.md` discipline. Every check below was
re-executed for real; nothing is taken from Coder/Refactorer reports. Work is
uncommitted working-tree state on `main` (merge-base 3013d8d = HEAD):
`M AGENTS.md`, `?? docs/GOVERNANCE.md`, `?? docs/adr/`, `?? scripts/check-governance.sh`.
`00-informal.md` was not read at any point.

## 1. Scenario traceability — PASS (AC-010 scope clean; full-repo exit 1 known)

Command: `bash scripts/check-scenario-traceability.sh` → **exit 1**, 125 violations.

Full-repo failures are entirely the known mid-pipeline condition, none touching
AC-010:
- "defined but no test references it": AC-007-01..04, AC-008-01..05, AC-009-01..04,
  AC-011-01..02, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..16,
  AC-017-01..05, AC-018-01..08, AC-019-01..07 (sibling in-flight specs with no
  check script yet).
- "referenced in a test but no matching scenario heading": AC-001-01..06,
  AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04, AC-006-01..06,
  AC-016-01..05, AC-020-01..07, AC-021-01..08, AC-022-01..04 (archived/merged
  specs whose test-carriers persist in scripts but whose spec dirs are gone).

Scoped AC-010 result: **all six groups PASS** —
`PASS AC-010-01 .. AC-010-06 — traced to a test`, and **zero AC-010 FAIL lines**
in either direction. Additionally verified mechanically that every one of the 37
sub-IDs defined in `20-acceptance/` (AC-010-01-01 … AC-010-06-08) appears in
`scripts/check-governance.sh`'s output:

```
$ grep -ohE 'AC-010-[0-9]{2}-[0-9]{2}' specs/010-governance-trust-tiers/20-acceptance/*.md | sort -u | wc -l
37
$ scripts/check-governance.sh 2>/dev/null | grep -oE 'AC-010-[0-9]{2}-[0-9]{2}' | sort -u > /tmp/…; diff ids script → (empty)
ALL_37_SUBIDS_CITED_IN_SCRIPT_OUTPUT
```

Judgment: AC-010 scope is clean. The 37 sub-IDs are all defined **and** all cited;
the full-repo exit 1 is fully explained by sibling/archived specs and is not a
spec-010 defect.

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-governance.sh` | 0 | `SYNTAX_OK` |
| `scripts/check-governance.sh` (compliant repo) | 0 | 37 PASS lines + `✔ Governance check: every governance requirement verified.` |
| `scripts/check-governance.sh` × 5 negative fixtures (see §4) | 1 each | each FAILs naming the exact missing artifact |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `make validate-all` | 0 | `All validations passed.` (1 pre-existing WARN: skills/hallmark/SKILL.md body 562 lines >500 — unrelated to spec 010) |
| `make lint` | 0 | all JSON/YAML `[OK]`, `Done.` |

Representative compliant-run output (the script's full output is 37 PASS lines;
excerpt):

```
PASS AC-010-01-01 — docs/GOVERNANCE.md exists
PASS AC-010-01-02 — exactly the three required headings present, no other top-level ## heading
PASS AC-010-02-06 — T3 stated as universal: applies to every agent with no exceptions
PASS AC-010-03-02 — spec-verifier mapped to T0
PASS AC-010-03-03 — spec-pr-opener mapped to T2
PASS AC-010-04-06 — conformance note ties the same-commit rule to the observed spec-architect drift (governance defect)
PASS AC-010-05-05 — docs/adr/README.md exists, indexes one ADR per file, and references templates/ADR.md (AC-010-06-07 failure mode)
PASS AC-010-06-01 — scripts/check-governance.sh exists and is executable
PASS AC-010-06-02 — compliant repo passes all checks (exit 0)
```

Executable bit set (`-rwxr-xr-x` 755) — AC-010-06-01 satisfied. Script is
read-only: grep for `rm|mv|cp|>>|> ` finds only comment lines; no file is
modified by any run.

## 3. Complexity gate — PASS (all functions ≤6; some Refactorer numbers don't reproduce)

No shell complexity linter exists in this repo; measured with the standards'
own heuristic (`scripts/check-code-principles.sh` header: counts
if/for/while/case/&&/||/ternary per function), via awk over the script:

```
extract_section        CC=2
check_section          CC=2     (Refactorer claimed 2 — matches)
expect                 CC=6     (claimed 6 "by design" — matches; at the ≤6 limit)
expect_row             CC=5     (claimed 2 — does NOT reproduce)
check_failure_mode     CC=1     (claimed 2 — does NOT reproduce)
```

Every function is ≤6, so the cyclomatic-complexity rule holds — no gate
violation. Discrepancies recorded as self-report inaccuracy only:
- `expect_row` measured CC 5 (two `&&`/`||` guard expressions), not 2.
- `check_failure_mode` measured CC 1, not 2.
- Line count: `wc -l` = **416**, not the claimed 412 (445→412).
- "Top-level decisions ~25→~13": current top-level if/for decision statements
  measure **26**; the delta claim is unverifiable because the script is
  untracked (no pre-refactor version in git history).

None of these affect the actual gate outcome; flagging so the Architect does not
propagate the stale numbers into `30-report.md`.

## 3.5. Design-principles gate — PASS for spec 010 (pre-existing FAILs confined to ci/templates/*)

Command: `scripts/check-code-principles.sh` (default mode, repo root) → **exit 1**,
`5 FAIL(s), 17 WARN(s)`. Tier auto-detected: `Checking design principles in: . (tier: mvp)`.

Every FAIL and WARN line, verbatim:

FAILs:
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARNs (17):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Judgment: all 5 FAILs and all 17 WARNs reference files under `ci/templates/*`
(go-saga-lint.go, eslint-saga-rules/saga-compensation.js, archunit/*.java) — a
directory spec 010 does not touch (git status/diff confirm). **No FAIL or WARN is
attributable to spec 010.** The pre-existing exit-1 state is unchanged from
baseline. WARNs are review hints; flagged to the Architect, no pipeline stop
(per project instructions, a WARN alone does not stop unless it concerns the
changed files — none do).

## 4. Scenario-to-behavior spot check — PASS

Two scenarios checked by hand against the real artifacts, plus a live negative
fixture run.

**AC-010-02-07 (sole remote-write carve-out)** — scenario asserts: names
`spec-pr-opener` as the only push-capable agent; carve-out limited to
`spec/NNN-slug`; draft PR only after every configured quality gate is green.
`docs/GOVERNANCE.md:30-33` reads: "`spec-pr-opener` is the only push-capable
agent: it may push to a branch named `spec/NNN-slug` and open a **draft** PR,
only after every configured quality gate is green, per
`docs/SPEC_PIPELINE.md §Commit and push carve-out`." — matches on all three
assertions.

**AC-010-04-06 (conformance note)** — scenario asserts: explicit conformance
note; violating the same-commit rule is a governance defect; names the observed
`spec-architect` drift. `docs/GOVERNANCE.md:74-77` reads: "**Conformance note:**
violating the same-commit rule is a governance defect — a review blocker, same
class as the ADR rule. The drift observed in this repo (a model entry pointing
at a nonexistent agent, `spec-architect`) is exactly what this rule exists to
prevent." — matches.

Additional confirmation of the same kind: AC-010-03-06 (`spec-pipeline` gap row
records "no `permission` block at all", not papered over — GOVERNANCE.md:49),
AC-010-05-05/06 (ADR index exists, references `templates/ADR.md`, states "No
ADRs are recorded yet" — `docs/adr/README.md`), and the exact T0-T3 capability
rows from AC-010-02-02..05 (GOVERNANCE.md:19-22, byte-identical to Task 2's
table).

**Negative fixture (the check script really detects violations).** Built scratch
trees under /tmp/opencode (deleted after), ran the script against each with a
`ROOT` argument:

| Fixture | Broken state | Exit | FAIL line naming the artifact |
|---|---|---|---|
| f1 | no `docs/GOVERNANCE.md` (AC-010-06-03) | 1 | `FAIL AC-010-01-01 — docs/GOVERNANCE.md is missing (AC-010-06-03 failure mode)` |
| f2 | `## Trust Tiers` heading removed (AC-010-06-04) | 1 | `FAIL AC-010-01-02 — docs/GOVERNANCE.md is missing the '## Trust Tiers' heading (AC-010-06-04 failure mode)` |
| f3 | `spec-verifier` row removed from mapping (AC-010-06-05) | 1 | `FAIL AC-010-03-01 — mapping table omits agent \`spec-verifier\`` + `FAIL AC-010-03-02 — spec-verifier row missing or not mapped to T0` |
| f4 | authoritative-source statement removed (AC-010-06-06) | 1 | `FAIL AC-010-04-02 — section must name opencode.json (agent.<name>.model) as the single authoritative model source (AC-010-06-06 failure mode)` |
| f5 | no `docs/adr/README.md` (AC-010-06-07) | 1 | `FAIL AC-010-05-05 — docs/adr/README.md is missing (AC-010-06-07 failure mode)` |

Each fixture exits 1 and names the exact artifact the corresponding scenario
requires. The failure-mode mirror checks (AC-010-06-03..07) correctly FAIL in
the broken fixtures and PASS on the compliant repo — the mirroring logic is
genuine, not a hardcoded pass.

**Mapping-table basis vs real frontmatter.** All 8 rows of the agent mapping
(GOVERNANCE.md:42-49) were checked against `agents/*.md` frontmatter:
- spec-coder: read denies only `specs/*/00-informal.md`; `git push*: deny`, rest allow ✓
- spec-mutation-runner: `git commit*`/`git push*` denied ✓
- spec-pr-opener: read denies 00-informal.md + docs/changes/*.md; `git push*: ask` ✓
- spec-refactorer: read denies `specs/**`; `git push*: deny` ✓
- spec-specifier: edit `specs/**` allow, `*` deny; `git *: allow` ✓
- spec-ux: read `*` allow; `git commit*`/`git push*` ask ✓
- spec-verifier: edit only `specs/*/25-verification.md`; `git commit*`/`git push*` denied ✓
- spec-pipeline: **no `permission` block in the file at all** — the recorded gap is real ✓

## 5. No unaccounted behavior — PASS

The entire change set is four paths: `M AGENTS.md` (+1 line),
`docs/GOVERNANCE.md`, `docs/adr/README.md`, `scripts/check-governance.sh`.

- The `AGENTS.md` line adds `docs/GOVERNANCE.md` to the "Reading the Standards"
  list. This is exactly open question 7 in `10-tasks.md` ("Optionally add
  docs/GOVERNANCE.md to the AGENTS.md 'Reading the Standards' list. Not required
  by any AC; include only if you want") — sanctioned by the tasks doc, and it
  also satisfies the governance/operations-split intent (the doc is discoverable
  from the standards index). It breaks nothing: `check-orchestration.sh` (which
  validates `docs/` references in agents/commands/AGENTS.md) exits 0.
- `docs/GOVERNANCE.md` → Tasks 1-5; `docs/adr/README.md` → Task 5;
  `scripts/check-governance.sh` → Task 6. No other logic exists in the diff.
- The script is not vacuous: §4 proves five distinct broken states each produce
  a named FAIL and exit 1; its PASS lines are gated on real greps of real files
  (`expect()`/`expect_row()`/`check_section()` all read the target file at run
  time), and the AC-010-06-08 "all IDs cited" claim was verified mechanically
  (37/37). If a scenario were renamed in `20-acceptance/` without the script
  being updated, the traceability script's defined-but-untraced direction would
  catch the stale ID.

## mvp-tier claim (property-test / mutation skips) — CONFIRMED

- `find . -maxdepth 1 -name 'AGENTS_*.md'` → **0 files**. The conformance-tier
  auto-detection in `scripts/check-code-principles.sh` (grep of `AGENTS_*.md`
  for `Conformance tier:`) therefore resolves to the `mvp` default, confirmed in
  the gate run output: `(tier: mvp)`.
- Property tests: skipped at mvp — verified live: `Property tests: skipped
  (project tier is mvp — production+ required)` ×3.
- Mutation testing: skipped at mvp per `docs/SPEC_PIPELINE.md` conformance-tier
  table (Architect row: mutation `skip` for mvp). Consistent with the skips the
  prior stages assumed.

## Verdict

**PASS** — Architect may proceed.

Reasons, all verified by execution:
1. AC-010 scenario traceability clean (37/37 sub-IDs defined and cited; zero
   AC-010 failures; full-repo exit 1 fully explained by sibling/archived specs).
2. check-governance.sh: syntax-clean, exit 0 on the compliant repo, exit 1 with
   the correct named artifact on all five negative fixtures, executable, read-only.
3. check-orchestration.sh 0, make validate-all 0, make lint 0.
4. Complexity: every function ≤6 (expect=6 at limit by design; others 1-5);
   measured discrepancies in the Refactorer's reported numbers (expect_row 5 not
   2, check_failure_mode 1 not 2, 416 lines not 412, top-level decisions 26 with
   the 25→13 delta unverifiable) are noted for the Architect but do not violate
   the gate.
5. Design-principles gate exit 1 is entirely pre-existing `ci/templates/*`
   findings; nothing attributable to spec 010. WARNs flagged, not blocking.
6. Spot-checked scenarios' Given/When/Then match the real document content, and
   the mapping table's frontmatter-basis claims match the real agent files.
7. No unaccounted behavior; the one extra diff hunk (AGENTS.md cross-reference)
   is explicitly sanctioned by 10-tasks.md open question 7.
8. mvp tier confirmed (no AGENTS_*.md), so the property-test and mutation
   skips are correct.

## Quality gates

# Report — spec 010 (governance-trust-tiers)

Mutation Runner: stage 5a, `agents/spec-mutation-runner.md` discipline.

## Verifier's verdict (carried forward)

**PASS** — `specs/010-governance-trust-tiers/25-verification.md` exists and its
verdict is PASS. All eight verdict reasons verified by the Verifier's own
execution (traceability 37/37 AC-010 sub-IDs clean, negative fixtures, complexity,
design-principles gate, scenario spot-checks, mvp tier confirmed).

## Mutation score

**skipped — `mvp` tier**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate; at `mvp` the Architect row is `skip`. The repo is `mvp`
(no `AGENTS_*.md`, confirmed by the Verifier's auto-detection: `(tier: mvp)`).
No mutation tooling attempted — the changed code is a shell check script plus
markdown docs; no mutation tooling exists for shell in this repo regardless of
tier.

## Complexity summary

Carried from the Refactorer via the Verifier's independent re-measurement
(`scripts/check-code-principles.sh` heuristic, counted via awk over the script).
**All functions ≤ 6 — cyclomatic-complexity rule holds, no gate violation.**

| Function | CC | Note |
|---|---|---|
| `extract_section` | 2 | — |
| `check_section` | 2 | matches Refactorer's claim |
| `expect` | 6 | at the ≤6 limit, "by design"; matches |
| `expect_row` | 5 | **does not reproduce Refactorer's claimed 2** (two `&&`/`||` guard expressions) |
| `check_failure_mode` | 1 | **does not reproduce Refactorer's claimed 2** |

Verifier-recorded discrepancies, carried here so the PR Opener/Architect does
not propagate stale Refactorer numbers:
- `wc -l` = **416 lines**, not the claimed 412.
- Top-level if/for decision statements = **26**, not the claimed ~13; the
  25→13 delta claim is unverifiable because the script is untracked (no
  pre-refactor version in git history).

None of these affect the gate outcome; recorded as self-report inaccuracy only.

## Equivalent mutants

**None.** No mutation run was performed (mvp skip); no surviving mutants exist
to classify.

## Final test status

Re-run one final time after the skip (Verifier's PASS was independent of these
re-runs; re-confirmed on the exact working-tree state):

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-governance.sh` | 0 | `SYNTAX_OK` |
| `scripts/check-governance.sh` | 0 | 37 PASS lines + `✔ Governance check: every governance requirement verified.` |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `make validate-all` | 0 | `All validations passed.` (1 pre-existing WARN: skills/hallmark/SKILL.md 562 lines >500 — unrelated to spec 010) |
| `specs/010-governance-trust-tiers/25-verification.md` present | — | verdict **PASS** |

All green. Stage 5a complete; stage 5b (PR Opener) may proceed.
