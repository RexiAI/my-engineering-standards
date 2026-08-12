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
