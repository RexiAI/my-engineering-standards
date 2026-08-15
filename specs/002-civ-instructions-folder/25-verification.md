# 002 — Verification

This file is populated by `spec-verifier` after Coder + Refactorer
finish. The Verifier transcribes its independent re-check here. The
human does not write this file.

## Re-execution checklist (run before writing the verdict)

- [ ] `bash scripts/check-scenario-traceability.sh` — exit code
- [ ] `grep -F "## " docs/SPEC_PIPELINE.md` — list of section headings
  to confirm slimness
- [ ] For each of the nine new `.standards/instructions/NN-*.md`
  files: existence check + YAML frontmatter sanity check
- [ ] For each of seven `agents/spec-*.md` files: pointer-line count
  = 1, no restated rules
- [ ] For root `AGENTS.md` and `README.md`: every behavioral pointer
  resolves

## Verdict

(Verdict block written by the Verifier agent.)

- [ ] PASS — every box above is green and every AC scenario file
  under `20-acceptance/` is satisfied by the implementation.
- [ ] FAIL — describe what failed and which AC scenarios are
  unsatisfied. Do not fix; the Coder will re-run.
