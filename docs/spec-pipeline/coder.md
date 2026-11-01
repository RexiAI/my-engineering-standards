# Coder stage file (stage 2)

Index: `docs/SPEC_PIPELINE.md` — read §Stages, §Artifact layout,
§Stop-and-Ask decision matrix, and §Remediation budget.

## Conformance tiers

Per `docs/CONFORMANCE_TIERS.md`, the pipeline runs fewer stages at lower tiers
instead of being all-or-nothing:

| Stage | `mvp` | `production` | `multi-service` |
|---|---|---|---|
| Specifier | yes | yes | yes |
| UX Designer (frontend specs only) | yes | yes | yes |
| Coder | yes | yes | yes |
| Refactorer — complexity + duplication | yes | yes | yes |
| Refactorer — property tests | skip | yes | yes |
| Verifier — traceability, tests, complexity re-check, design-principles gate | yes | yes | yes |
| Architect — mutation testing | skip | yes | yes |

An `mvp` project runs a 4-stage pipeline (Specifier, Coder, Refactorer, Verifier)
and conforms fully to it — see `docs/CONFORMANCE_TIERS.md` for what "conforms fully
to a subset" means. Architect still runs at `mvp` to commit/push/open the PR; it
simply skips the mutation-testing gate.

## Tooling by language

| Concern | Java | Go | JS/TS |
|---|---|---|---|
| Unit / acceptance tests | JUnit 5 | stdlib `testing` | Vitest/Jest |
| Property testing (`production`+) | jqwik | stdlib `testing/quick` | fast-check |
| Complexity gate | PMD `CyclomaticComplexity`/`CognitiveComplexity` (≤6) | golangci `cyclop`/`gocognit` (≤6) | ESLint `complexity` (≤6) |
| Design-principles gate (KISS/DRY/YAGNI/SOLID) | `scripts/check-code-principles.sh` — language-agnostic heuristic | same | same |
| Mutation testing (`production`+) | PiTest, `mvn verify -Pmutation`, ≥80% | `go-mutesting` or `gremlins` (verify current maintenance status before adopting) | Stryker, `npx stryker run`, ≥80% |

`testing/quick` is stdlib — no new Go dependency, consistent with this repo's
"prefer stdlib, justify each dependency" rule (`docs/CODING_CONVENTIONS.md`) and the
existing demotion of `testify`/`gomock` to optional. It generates simple types well
(ints, strings, slices); reach for a real library only if a project's domain types
need custom generators it can't express.
