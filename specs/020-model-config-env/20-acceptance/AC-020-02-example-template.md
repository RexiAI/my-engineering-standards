# AC-020-02: committed `config/model.local.env.example` template, one var per agent

## AC-020-02-01 — The example template exists and is tracked
Given the repo root
When `config/model.local.env.example` is checked
Then the file exists
And `git ls-files --error-unmatch config/model.local.env.example` exits 0 (it is tracked)

## AC-020-02-02 — Exactly one var per modelable agent, committed defaults as values
Given `config/model.local.env.example` exists
When its `SPEC_*_MODEL` assignments are enumerated
Then there are exactly 8, one per agent, with no duplicates
And each value is the current committed default: `opencode-go/deepseek-v4-flash` for spec-specifier, spec-ux, spec-coder, spec-refactorer, spec-pipeline
And `opencode-go/qwen3.7-plus` for spec-verifier, spec-mutation-runner, spec-pr-opener

## AC-020-02-03 — A comment above every var names the agent it drives
Given `config/model.local.env.example` exists
When each `SPEC_*_MODEL` line is inspected
Then a comment line directly above it states which agent the var drives and that the value is the committed default until overridden locally
And no var line has a comment missing

## AC-020-02-04 — Header documents the one-time setup: profile wiring, optional copy, restart, never commit
Given `config/model.local.env.example` exists
When its header comment block is read
Then it instructs wiring `source <repo>/scripts/load-model-env.sh` into the shell profile once so every shell exports these vars automatically
And it instructs copying the file to `config/model.local.env` only when overriding, filling in real model ids, restarting opencode (config is read once at startup), and never committing the real file
