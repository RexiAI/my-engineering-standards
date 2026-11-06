# Verifier stage file (stage 4)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Artifact layout, §Stop-and-Ask
decision matrix, and §Remediation budget.
Must read: `docs/spec-pipeline/audit-contract.md` (§Audit contract,
§Definition of done) before writing `25-verification.md`.

Deliverable: `specs/NNN-slug/25-verification.md`; the evidence rules are in the
audit contract named above.

## Lite mode

When the run resolved to `lite` (`docs/SPEC_PIPELINE.md §Lite mode`), nothing
about this stage's checks changes: the full test suite, the secrets scan
(`scripts/check-no-hardcoded-secrets.sh`), `scripts/check-code-principles.sh`
(a FAIL blocks), and scenario traceability all still run and are all recorded in
`25-verification.md`.

Lite also makes this stage the author of `specs/NNN-slug/30-report.md`, because
the Mutation Runner that normally writes it is not invoked. Record
`Pipeline mode: lite`, one `## <stage>` section per skipped stage (`spec-refactorer`,
`spec-mutation-runner`, `spec-ux`, `spec-deployer`) reading `skipped (lite)`, and
the mutation score line reading `skipped (lite)` — see
`docs/spec-pipeline/lite-mode.md §30-report.md in lite`.
