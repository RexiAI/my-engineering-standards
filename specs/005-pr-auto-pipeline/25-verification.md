# 005 — Verification

Populated by `spec-verifier` after Coder + Refactorer finish.

## Re-execution checklist

- [ ] `.opencode/skills/openspec-ship/SKILL.md` states the BLOCK-halt
  contract
- [ ] `.opencode/skills/openspec-ship/README.md` exists
- [ ] `agents/spec-ship.md` is `mode: primary`, thin pointer, no
  procedural rules
- [ ] `.opencode/commands/ship.md` maps `/ship <slug>` to the skill
- [ ] `agents/spec-pipeline.md` lists three modes (`/spec`,
  `/build`, `/ship`)
- [ ] `agents/spec-architect.md` requires `.civ/gate-report.json`
  with `status: PASS`, matching branch + SHA
- [ ] `agents/spec-verifier.md` verdict contract is transcription +
  warnings
- [ ] Stale report is rejected

## End-to-end manual

- [ ] PASS path: `/spec` → `/build` → `/ship` on a trivial feature
- [ ] BLOCK path: introduce a failing scenario; `/ship` halts with
  gate IDs
- [ ] Re-run after fix: PASS resumes

## Verdict

- [ ] PASS
- [ ] FAIL
