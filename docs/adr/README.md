# Architecture Decision Records (ADR) Index

Architecture Decision Records are indexed here, one per file, named
`NNNN-slug.md` (zero-padded sequence + slug), per `templates/ADR.md` — the
mandated template. ADRs follow the lifecycle in
`docs/GIT_WORKFLOW.md §Architecture Decision Records (ADRs)`:
Proposed → Accepted → Deprecated → Superseded.

| ADR  | Title                                                                                                                                                                | Status   |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 0001 | [Pure direnv dotenv for spec-pipeline model configuration and credentials](0001-direnv-model-env.md)                                                                 | Accepted |
| 0002 | [Provider-agnostic general documentation](0002-provider-agnostic-docs.md)                                                                                            | Accepted |
| 0003 | [Provider-agnostic PR-review wiring](0003-provider-agnostic-pr-review.md)                                                                                            | Accepted |
| 0004 | [Typed-judgment layer: opt-in fast-path for probabilistic classification](0004-typed-judgment-layer.md)                                                              | Accepted |
| 0005 | [Local judgment backend: an optional self-hosted compute backend for the typed-judgment layer](0005-local-judgment-backend.md)                                       | Accepted |
| 0006 | [Extend the gate catalog to Python and Rust without adding gate names](0006-python-rust-gate-coverage.md)                                                            | Proposed |
| 0007 | [Media agent family: global opencode agents driving the Bailian `bl` CLI, with a URL-chained pipeline and a separate realtime voice app](0007-media-agent-family.md) | Accepted |
| 0008 | [Vercel deploy lane: a spec-deployer stage (5c), the 40-deploy.md gate artifact, and a split pipeline tail (5a/5b/5c/5d)](0008-vercel-deploy-lane.md) | Accepted |
| 0009 | [Judgment consumer contract and AC-024-01-12 base-ref semantics](0009-judgment-consumer-contract-and-gate-base-ref.md) | Accepted |
| 0010 | [Stage-split deploy-artifact gate: --require-deploy for the stage-5d final run](0010-audit-trail-require-deploy-flag.md) | Accepted |
| 0011 | [Mechanical gate for model-agnostic agent definitions](0011-agent-model-agnostic-gate.md) | Proposed |
| 0012 | [Structural cleanliness rules and opt-in god-file enforcement](0012-structural-cleanliness-gates.md) | Proposed |
| 0013 | [Clean Code comment hygiene and naming gates](0013-clean-code-comment-gates.md) | Proposed |
| 0014 | [Judgment consumer contract: exit-10 = stock procedure, fail-open preflight, payload cap, four-way fallback reasons](0014-judgment-consumer-contract-fail-open-preflight.md) | Accepted |
