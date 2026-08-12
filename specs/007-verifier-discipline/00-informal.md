# Verifier mechanical-transcription discipline

The Verifier is this pipeline's independent QA. Its credibility rests on it
never "interpreting" a failure as a pass. acdc-civ hardens this with three rules
this repo lacks:

1. **The script is the authority.** The Verifier's verdict is a transcription of
   the gate script's exit code and JSON, never a judgment that overrides it. If
   its own reading of a diff disagrees with a deterministic gate, the gate wins.
2. **A missing/errored script is a BLOCK, not a pass.** If `check-code-principles.sh`
   or `check-scenario-traceability.sh` fails to run (missing file, jq absent,
   non-zero for a reason other than a finding), the Verifier reports a tooling
   failure — it must not mark the gate green by reasoning about what the script
   "would have" checked.
3. **Scoped re-verification.** When a BLOCK is fixed, re-run only the failing
   gates (`-Gates G2` analog), not the whole suite; combine with the prior full
   report. A one-line fix must not reboot the app or re-run every scan.

## Acceptance criteria

- AC-001: spec-verifier.md states the script-is-authority rule and the
  missing-script = BLOCK rule verbatim.
- AC-002: spec-verifier.md documents scoped re-verification for BLOCK fixes.
- AC-003: the check-code-principles.sh / check-scenario-traceability.sh scripts
  support a `-Gates`-style scoped flag (or the verifier spec names the exact
  subset to re-run).
