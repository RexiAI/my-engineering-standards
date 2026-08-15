# 004 — Verification

Populated by `spec-verifier` after Coder + Refactorer finish.

## Re-execution checklist

- [ ] `agents/hooks/hooks.json` validates against the expected
  schema (preToolUse bash, postToolUse edit|create)
- [ ] `agents/hooks/find-harness.sh` exists and exits `0`
- [ ] `agents/hooks/format-guard.sh` exists
- [ ] `agents/hooks/pre-push` runs `gate-runner.sh -Phase local
  -Gates G0,G1,G6,S1` on a `spec/*` branch
- [ ] `agents/hooks/commit-msg` enforces the Conventional Commits
  regex `^(feat|fix|chore|docs|test|refactor|perf|build|ci|style|version)\([^)]+\): .+`
- [ ] Soft-fail pattern works when `scripts/gates/gate-runner.sh`
  is removed
- [ ] `scripts/init-ci.sh --help` mentions `--with-hooks`
- [ ] `.gitignore` contains `.civ/` and `.civ-dryrun/`
- [ ] `git status --porcelain` stays clean after a runner run

## Manual end-to-end

- [ ] Bad commit message rejected (`commit-msg`)
- [ ] Push aborts on a flipped gate
- [ ] Push succeeds on a clean branch (hooks run, never BLOCK)
- [ ] Missing harness is silent

## Verdict

- [ ] PASS
- [ ] FAIL
