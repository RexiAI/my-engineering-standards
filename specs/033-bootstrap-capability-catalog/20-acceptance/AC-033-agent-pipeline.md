# AC-033: Agent pipeline — spec pipeline, PR review, deploy verifier

## AC-033-38 — `--with-pr-review` forwards to init-ci
Given `bootstrap.sh --with-pr-review`
When the script runs
Then `init-ci.sh` is invoked with `--with-pr-review`

## AC-033-39 — `--copy-agents` copies as real directories
Given a child repo whose `.opencode/agents`, `.opencode/commands`, and `.opencode/skills` do not exist
When `bootstrap.sh --copy-agents` runs
Then those three paths are created as real directories (not symlinks)

## AC-033-40 — `--with-spec-pipeline` wires the spec pipeline agents
Given `bootstrap.sh --with-spec-pipeline`
When the script runs
Then the spec pipeline agents and commands are wired per OQ-7
