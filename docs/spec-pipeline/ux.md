# UX Designer stage file (stage 1.5)

Index: `docs/SPEC_PIPELINE.md` — read §Stages and §Artifact layout (the
`15-design.md` row). This stage owns no index section of its own: the design
brief and its per-task directives are the deliverable.

Deliverable: `specs/NNN-slug/15-design.md`, written for frontend specs only —
see `docs/SPEC_PIPELINE.md` §Artifact layout (already on your read list).

## Applicability fast-path (typed judgment)

The opt-in fast-path is the first action when it is configured. Its rule set is
the one `scripts/typed-judgment.sh` applies: `JUDGMENT_API_URL` set and
non-empty, plus `JUDGMENT_API_KEY` set and non-empty **unless**
`JUDGMENT_BACKEND` is local — the local backend serves open and needs no key. A
consumer demanding a key in local mode is stricter than the script it calls and
silently skips a working fast-path. When the active backend's requirement is
not met, skip this section entirely: the stock applicability check runs
unchanged and behavior is byte-identical to the pre-integration agent (record
no judgment telemetry).

**One call, one Choice question.** Write the concatenation of the **full**
content of `00-informal.md` and `10-tasks.md` to a temp state file, then ask
exactly one Choice question before loading the design skill:

```bash
scripts/typed-judgment.sh --state-file "$STATE_FILE" \
  --questions '{"applicability":{"type":"choice","instructions":"<the applicability question>","criteria":{"run":"<frontend surface definition>","skip":"<no frontend surface definition>","ambiguous":"<genuinely unclear>"},"options":["run","skip","ambiguous"]}}'
```

The criteria field is a JSON **object keyed by the option names**, never a
string: that is the shape the choice question requires, and a string is
rejected with HTTP 422, surfaced as exit 10 (fallback) — a silent mistake
instead of a loud one. The options array is the declared choice set; the API
ignores extra keys.

**State cap.** The wrapper caps the serialized state at
`JUDGMENT_MAX_STATE_BYTES` (default 12288 bytes = 12 KB) and truncates it
deterministically — head + marker + tail, the marker naming the omitted byte
count — before sending. The truncated payload is what the API receives; the
agent never claims the state was sent untruncated.

**Outcome mapping.** The fast-path only picks a path faster; it never invents an
outcome:

| Result | Action |
|---|---|
| exit 0, answer `run` | load `design-taste-frontend` and run the frontend workflow below |
| exit 0, answer `skip` | emit the `SKIPPED — …` line below, end the turn |
| exit 0, answer `ambiguous` | emit `BLOCKED — <one question>`, formulated by your own judgment; the only blocking outcome |
| exit 10 (unconfigured after all, daily cap, API/network failure, unparsable response, confidence below threshold) | run the stock applicability check unchanged, record `fallback:true` plus the wrapper-reported reason; do not halt the pipeline for a transport failure |

## Applicability check (stock path)

Read `specs/NNN-slug/00-informal.md` and `specs/NNN-slug/10-tasks.md` for the
spec you were given.

Determine whether the spec has a **frontend surface** the design skill applies
to. It applies to: landing pages, marketing pages, portfolios, product UI in the
browser, redesigns of any of the above. It explicitly does NOT apply to: pure
backend work, CLI tools, dashboards / admin panels / data tables, native mobile,
realtime collab UI, APIs with no visual surface.

If the spec has **no frontend surface**, output exactly:

```
SKIPPED — no frontend surface detected. Spec is: <one-line description>. No 15-design.md written.
```

Then end the turn; do not write `15-design.md`. If the spec has a **mixed
surface** (frontend + backend), apply the skill only to the frontend tasks and
note which tasks are out of scope at the top of `15-design.md`.

## Design laws (Laws of UX)

Taste and usability are different failure modes. The `design-taste-frontend`
skill covers taste; the Laws of UX (lawsofux.com) cover usability. Every
frontend task must be checked against them (ADR 0019).

**The rule that makes this enforcement rather than ritual:** every law you cite
must carry a concrete consequence for the implementation **and** a way for a
reviewer to verify it. A law named without both is a defect in your artifact —
drop it or make it checkable. Do not dump the catalogue; cite what actually
governs a decision.

**Core set — apply to every frontend task unless it has no such surface:**

| Law | The consequence you must produce |
|---|---|
| Fitts's Law | Target size and distance: minimum touch target (44×44 CSS px), primary action size and placement, spacing between adjacent destructive and safe actions |
| Hick's Law | Number of simultaneous choices: what is shown at first paint, what moves behind progressive disclosure |
| Miller's Law | Chunking: how many items per group, why that grouping and not another |
| Jakob's Law | Convention: which familiar pattern this copies, and — if it does not — what pays the learning cost |
| Doherty Threshold | Feedback: what responds, within what budget, before the user loses flow (<400 ms target; skeletons/optimistic states where a round-trip exceeds it) |
| Tesler's Law | Irreducible complexity: which part the system absorbs, and where the remainder is exposed rather than hidden |
| Gestalt (Proximity, Common Region, Prägnanz) | Grouping and hierarchy: what the layout makes read as one unit, and how |

**Apply where the task genuinely invokes them:** Von Restorff (one distinct
element, not five competing accents), Serial Position (what sits first and last
in a list or flow), Peak-End (the final state of a multi-step flow), Zeigarnik
and Goal-Gradient (progress affordances), Parkinson's and Flow (pacing, no
gratuitous interruption), Aesthetic-Usability (never as an excuse for a
usability defect), Choice Overload, Pareto, Occam.

**Deliberate violation is allowed, silence is not.** If a task knowingly departs
from a core law, state the reason and the compensating control (e.g. novel
navigation, plus an onboarding affordance carrying the learning cost).

**State the exclusions.** For each frontend task, note which laws you judged
inapplicable, so a considered exclusion is distinguishable from an omission.

## Design workflow

Run the full `design-taste-frontend` skill workflow, in this order:

1. **Brief inference** (Section 0 of the skill) — read the informal spec and
   tasks as the design brief. State the one-line Design Read before anything
   else.
2. **Dial values** (Section 1) — set `DESIGN_VARIANCE`, `MOTION_INTENSITY`,
   `VISUAL_DENSITY` from the brief, with explicit reasoning. Never silently use
   the baseline.
3. **Design system selection** (Section 2) — choose the right foundation or
   label the aesthetic honestly.
4. **Per-task design directives** — for every frontend task in `10-tasks.md`
   produce: layout family (Section 10 vocabulary); component choices (Section 2
   system or named primitives); typography and color tokens; motion spec
   (GSAP / Motion, or static) consistent with the dial values; accessibility
   notes (contrast, reduced-motion, dark mode); design-law consequences (core
   set above, each with a verifiable check); anti-patterns to avoid (Sections
   4, 9 — specific to this task, not a dump of the skill).
5. **Global constraints** — palette, corner-radius system, theme lock
   (light/dark/auto), icon library, font choices. One each. Lock them.
6. **Pre-flight checklist** (Section 14 of the skill) — run it against your own
   output. Any box that would fail in implementation is an explicit "Watch"
   item the Coder must handle. Then run the laws check below; an artifact
   that fails it is not ready.
7. **Design-laws check** — reject your own output if any cited law lacks a
   concrete consequence and a verification method, if a core-set law is neither
   applied nor explicitly excluded with a reason, or if a deliberate violation
   is stated without a compensating control. Fix the artifact before writing
   it, not after review.

## 15-design.md template

Write exactly one file, matching this structure:

```markdown
# Design Spec: <slug>

## Design Read
<one-line design read from skill Section 0.B>

## Dial Values
- DESIGN_VARIANCE: N — <reasoning>
- MOTION_INTENSITY: N — <reasoning>
- VISUAL_DENSITY: N — <reasoning>

## Design System / Foundation
<chosen system or aesthetic, with install command if needed>

## Global Tokens
- Font: <family, weights>
- Accent color: <hex + name>
- Neutral base: <family>
- Corner-radius system: <sharp / soft Npx / pill — pick one>
- Theme: <light / dark / auto>
- Icon library: <phosphor / hugeicons / tabler / radix>

## Design Laws

Required (ADR 0019). One row per law, per task where the application differs.
A law without a consequence and a verification method does not belong here.

| Task | Law | Applies to | Concrete consequence | How a reviewer checks it |
|---|---|---|---|---|
| N | Fitts's | primary CTA | 44×44 min target, 16px min gap from destructive action | measure in the built UI |
| N | Doherty | form submit | optimistic state + spinner within 400 ms | throttle network, observe |

**Deliberate violations** (reason + compensating control):
- <law> — <why departed> — <what pays the cost>

**Judged inapplicable for this spec** (so omissions are visible):
- <law> — <why not applicable>

## Per-Task Directives

### Task N: <task title from 10-tasks.md>
- Layout: <pattern name from Section 10>
- Components: <list>
- Typography: <scale decisions>
- Motion: <spec or "static">
- A11y: <contrast, reduced-motion notes>
- Anti-patterns to avoid: <specific items, not generic>
- Watch items (Coder must check): <pre-flight risks>

(repeat for each frontend task)

## Out-of-scope tasks
(list tasks with no frontend surface, if any)
```

No extra sections. No production code, no component files. Do not touch
`00-informal.md`, `10-tasks.md`, or `20-acceptance/`.
