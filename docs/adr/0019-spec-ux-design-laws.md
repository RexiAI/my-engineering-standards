# Architecture Decision Record (ADR)

## Title

Require Laws of UX to be enforced as checkable consequences in the spec-ux stage

## Status

Proposed

## Context

The `spec-ux` stage (1.5) produces `15-design.md` from the informal spec and the
task list, and is the only place in the pipeline where interface decisions are
made. It currently delegates entirely to the `design-taste-frontend` skill, which
governs *taste*: brief inference, dial values, anti-slop constraints, a
pre-flight checklist. What it does not provide is a vocabulary of established
usability principles, so a design spec can be internally coherent and still ship
interfaces that fight how people actually perceive and act — target sizes below
thumb reach, choice counts that overload, feedback that arrives after the user
has given up, important actions buried mid-list.

The operator asked for Laws of UX (lawsofux.com) to be enforced in this stage.
Taken literally as "cite the law", that is decoration: an agent can attach
"Jakob's Law" to any decision and satisfy it trivially. Taken as "each law must
yield a consequence a reviewer can check", it becomes enforcement — and it is
the only form worth building.

Two constraints shape the decision. First, the laws are heuristics with uneven
evidence: some (Fitts's, Hick's, Miller's) are grounded in decades of
experimental work; others (Peak-End, Zeigarnik, Aesthetic-Usability) are useful
framings with thinner empirical support and known counter-examples. Second, the
pipeline's frontend surface is currently empty — specs 001–005 are all CLI work,
so the stage has returned `SKIPPED` on every run. The change is therefore
low-risk today and must be justified for the future it enables rather than for
an immediate defect.

## Decision

The `spec-ux` stage must apply a named subset of Laws of UX to every frontend
task, and every cited law must carry a **checkable consequence**. Concretely:

1. `15-design.md` gains a required `## Design Laws` section. For each law
   applied to a frontend task it records: the law, where it applies, the
   concrete consequence for the implementation, and how a reviewer verifies it.
2. A law cited without a checkable consequence is a defect in the artifact, not
   a style preference. The pre-flight step must reject it.
3. Laws may be deliberately violated, but the violation must be stated with the
   reason and the compensating control (for example: a novel navigation model
   that knowingly departs from Jakob's Law, with an onboarding affordance that
   carries the learning cost).
4. A fixed core set applies to every frontend task unless the task has no such
   surface: Fitts's Law, Hick's Law, Miller's Law, Jakob's Law, Doherty
   Threshold, Tesler's Law, and the Gestalt grouping laws (Proximity, Common
   Region, Prägnanz). The remaining laws (Von Restorff, Serial Position, Peak-End,
   Zeigarnik, Goal-Gradient, Parkinson's, Aesthetic-Usability, Choice Overload,
   Pareto, Occam, Flow) are applied where the task's surface genuinely invokes
   them.
5. The stage must state which laws it judged inapplicable to a task, so a silent
   omission is distinguishable from a considered exclusion.

### Alternatives Considered

| Alternative | Pros | Cons |
|---|---|---|
| Cite the full Laws of UX catalogue per task | Maximum coverage; simple to state | Law-dump; unverifiable; encourages ritual citation over judgement; bloats `15-design.md` |
| Leave design judgement to the existing `design-taste-frontend` skill | No new surface; no maintenance | No usability vocabulary at all; taste and usability are different failure modes |
| Enforce laws via a new mechanical gate script | Deterministic | Design laws are not statically checkable from source; a gate would measure proxies (e.g. tap-target literals) and miss judgement |
| Require laws only on accessible/interactive components | Focused | Misses layout and pacing law applications (Miller, Serial Position, Goal-Gradient) |
| **Require a checkable consequence per cited law, with a fixed core set** | Enforceable at review; scales with task; forces reasoning | Requires the reviewer to read the consequences; a vague consequence can still slip through review |

## Consequences

- `15-design.md` grows by roughly 10–20 lines per frontend spec. CLI-only specs
  are unaffected because the stage returns `SKIPPED` before this section applies.
- The Verifier does not gain a mechanical gate from this: design laws remain
  review-enforced, and the ADR says so rather than implying otherwise.
- The stage now has an explicit standard to hold when a spec's design surface is
  contested, instead of appealing to taste alone.
- Law citations become auditable: a future reader can tell which principles were
  considered, applied, or deliberately departed from.

## Compliance

- `agents/spec-ux.md` carries the requirement, the core set, and the
  checkable-consequence rule; its output template includes `## Design Laws`.
- Review-enforced only. There is no mechanical gate, by design (see the rejected
  alternative above); `scripts/check-orchestration.sh` and
  `scripts/check-skills.sh` validate that the agent file and its references
  resolve, not that a given design honoured a law.
- The pre-flight step in `agents/spec-ux.md` must fail an artifact whose law
  entries lack a consequence or a verification method.

## Notes

- 2026-11-01: Decision recorded. Requested by the repository operator after spec
  005 (LinkedIn), as groundwork for a future frontend surface.
- 2026-11-01: Status set to Proposed; becomes Accepted on merge.
