# AC-020-01: opencode.json resolves every spec-* agent model from an env var

## AC-020-01-01 — Every agent model value is a `{env:SPEC_*_MODEL}` reference, no literals
Given the repo's `opencode.json`
When its `agent` block is inspected
Then it contains exactly the 8 spec agents: spec-specifier, spec-ux, spec-verifier, spec-mutation-runner, spec-pr-opener, spec-coder, spec-refactorer, spec-pipeline
And each `model` value is exactly a `{env:SPEC_<AGENT>_MODEL}` reference with the mapped var name (spec-specifier→`SPEC_SPECIFIER_MODEL`, spec-ux→`SPEC_UX_MODEL`, spec-verifier→`SPEC_VERIFIER_MODEL`, spec-mutation-runner→`SPEC_MUTATION_RUNNER_MODEL`, spec-pr-opener→`SPEC_PR_OPENER_MODEL`, spec-coder→`SPEC_CODER_MODEL`, spec-refactorer→`SPEC_REFACTORER_MODEL`, spec-pipeline→`SPEC_PIPELINE_MODEL`)
And no literal provider/model id (e.g. `opencode-go/deepseek-v4-flash`) appears anywhere in `opencode.json`
And `opencode.json` parses as valid JSON against its `$schema`

## AC-020-01-02 — Local env value overrides the committed default, no commit
Given the loader has run in the current shell environment
And `config/model.local.env` sets `SPEC_SPECIFIER_MODEL=opencode-go/some-other-model`
When `opencode debug config` is run
Then the resolved config for agent `spec-specifier` has model `opencode-go/some-other-model`
And this was achieved without editing or committing `opencode.json`

## AC-020-01-03 — No env file present still resolves to the committed defaults, never empty
Given no `config/model.local.env` exists on disk
And the loader has run in the current shell environment (so the vars are exported)
When `opencode debug config` is run
Then the resolved config for agent `spec-specifier` has model `opencode-go/deepseek-v4-flash`
And the resolved config for agent `spec-verifier` has model `opencode-go/qwen3.7-plus`
And no spec-* agent model resolves to an empty string
