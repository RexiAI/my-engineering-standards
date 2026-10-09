# AC-029: Documentation updates

## AC-029-60 — SPEC_PIPELINE.md mentions local backend
Given the spec 029 changes are applied
When `docs/SPEC_PIPELINE.md` §Typed-judgment layer is read
Then it mentions the local backend option
And uses provider-agnostic wording (no product names)
And references `JUDGMENT_BACKEND=local`

## AC-029-61 — LOOP_ENGINEERING.md mentions local backend
Given the spec 029 changes are applied
When `docs/LOOP_ENGINEERING.md` is read
Then it mentions the local backend as an option for judgment calls
And uses provider-agnostic wording

## AC-029-62 — OKF operator content has Local backends section
Given the spec 029 changes are applied
When `okf/when-to-use-typesafe.md` (or equivalent OKF file) is read
Then it contains a "Local backends" section
And may name Kev and CLM (scoped operator content)

## AC-029-63 — OKF log entry exists
Given the spec 029 changes are applied
When `okf/log.md` is read
Then it contains an entry for the local-judgment-backend addition

## AC-029-64 — No provider names in general docs
Given the spec 029 changes are applied
When `agents/` and `skills/` and general `docs/` files are grepped
Then no file contains provider names (Kev, CLM, jaredpalmer, Contrastive-LM) except:
  - `config/model.local.env.example`
  - `config/agent.local.env.example`
  - `docs/adr/0005-local-judgment-backend.md`
  - `okf/when-to-use-typesafe.md` (operator content)
  - `okf/log.md`

## AC-029-65 — Orchestration check passes
Given the spec 029 changes are applied
When `scripts/check-orchestration.sh` is run
Then the exit code is 0

## AC-029-66 — Content-contract tests verify docs
Given the spec 029 changes are applied
When `scripts/tests/typed-judgment-integration.bats` is run
Then content-contract tests verify:
  - `docs/SPEC_PIPELINE.md` contains "local" in the typed-judgment section
  - `docs/LOOP_ENGINEERING.md` contains "local"
  - OKF file has "Local backends" heading
