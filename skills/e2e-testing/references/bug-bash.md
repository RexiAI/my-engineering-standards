# Bug bash mode

Bug bash is bounded exploratory testing: the framework runs a small set of
attacker-style personas through a flow looking for broken behavior, then turns
confirmed findings into regression tests. It hunts; it does not prove green.

## Bounds before you start

- **Persona count cap.** Bug bash runs bounded parallelism — cap the number of
  personas per session. Start small; more personas multiply model-call cost
  and CI time, and the cap keeps a session finishable and reviewable.
- **Per-persona bounds.** Every persona is individually bounded:
  `--max-steps` caps how far one persona may wander, and `--timeout` caps how
  long it may take. A persona that hits either bound stops and reports — the
  bounds are the run's outer wall, mirroring the framework budgets inside it.

## The ASSERTION_FAILED confirmation gate

A bug bash finding is a **candidate**, not a bug. The gate:

> Only a generated repro test that fails with `ASSERTION_FAILED` counts as a
> confirmed bug.

For each finding, the flow is: reproduce as a standalone journey → run it →
if it fails with `ASSERTION_FAILED`, the behavior is broken; keep the repro
test as the regression. Everything else — a persona got lost, a step timed
out, a budget tripped, an environment flake — is not a bug and gets no test.

This gate exists because exploratory agents produce noise: confidence without
a confirmed `ASSERTION_FAILED` repro is exactly how "flaky bug reports" are
born.

## Explore findings are not regressions

Findings from explore mode (and unreprobed bug-bash observations) are leads,
not regressions — only confirmed `ASSERTION_FAILED` repro tests are promoted
into the suite as regressions. Do not file, gate, or alarm on the narration of
a persona.

## After the session

Confirm the session's own integrity from ground truth: read `.e2e/report.json`
and `.e2e/failures/` for each persona run. Persona counts, bounds hit, and
confirmed findings belong in the output summary — see the `e2e-runner` agent
for the operational contract of running a session.
