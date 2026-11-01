# Deploy Verifier stage file (stage 5c)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Stop-and-Ask decision matrix,
and §Remediation budget (phase 3).

## Deploy verification loop (phase 3)

After stage 5b opens the draft PR (spec 031), stage 5c (`spec-deployer`)
verifies the live system: it waits for the Vercel preview deployment the Git
integration built for the PR head commit, runs a health check, then delegates
E2E against the live preview URL, and records every round in
`specs/NNN-slug/40-deploy.md`. Phase 3 is bounded: its budget is **max 3**
fix-and-redeploy rounds and its counter is independent of **Phase 1** (pre-PR)
and **Phase 2** (post-PR CI) — exhaustion of one does not consume another's
budget.

Ordering is explicit: Phase 3 runs only after the phase-2 CI loop is green; on a
phase-2 FAIL verdict phase 3 does not start and the pipeline stops with the
phase-2 failure evidence. The two loops never race.

On the 3rd failed round `40-deploy.md` carries the marker line
`Phase-3 budget exhausted` and `Verdict: ESCALATED`, the pipeline STOPs before
stage 5d (the Archiver never runs for an exhausted spec —
`check-specs-archived.sh` accepts that non-archival), relays the failing check
IDs and the last log evidence from `40-deploy.md` verbatim, and escalates to the
human.

### Fix-routing (deterministic)

- E2E test runner exits non-zero against the live preview URL → route to spec-coder (behavior). Deterministic: the test runner's exit code is unambiguous.
- Vercel API returns a configuration-classified error (invalid vercel.json, wrong framework preset, env var missing from the Vercel project) → spec-deployer retries itself after the config repair. Deterministic: the Vercel error code classifies it.
- Structural or complexity gate failure → route to spec-refactorer. Deterministic: the gate script's exit code is unambiguous.

### Ambiguous cases — flagged open, escalated, never guessed

- A Vercel build failure (`BUILD_FAILED`) where the build log does not contain a
  clearly code-diagnostic or config-diagnostic pattern: STOP and escalate to the
  human.
- A health-check failure whose cause could be code or a missing runtime
  environment variable: STOP and escalate to the human.

Both cases stay open questions (spec 031 `10-tasks.md` §Open questions): the
routing rule above is the deliberate Option B — immediate escalation, no log
grepping heuristic invented. Upgrade path if a later spec adopts pattern-based
routing: extend this section and its contract test together, never the routing
silently.

