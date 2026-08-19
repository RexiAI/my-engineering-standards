# Architecture Decision Records (ADR) Index

Architecture Decision Records are indexed here, one per file, named
`NNNN-slug.md` (zero-padded sequence + slug), per `templates/ADR.md` — the
mandated template. ADRs follow the lifecycle in
`docs/GIT_WORKFLOW.md §Architecture Decision Records (ADRs)`:
Proposed → Accepted → Deprecated → Superseded.

| ADR | Status |
|-----|--------|
| [0001-direnv-model-env](0001-direnv-model-env.md) | Proposed |

The index previously started empty. Per the ADR requirement in
`docs/GOVERNANCE.md`, the first ADR was expected to document the governance
split (trust tiers + model-discipline rule). It instead records the direnv
adoption for per-machine model config; the governance-split ADR remains a
follow-up recommendation.
