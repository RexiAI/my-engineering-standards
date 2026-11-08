# AC-044-16: Operator docs, ADR, weight guard

## AC-044-16-01 — Required sections exist
Given `docs/VOICE_CONSOLE.md`
When its headings are read
Then it contains `## Modes`, `## Install`, `## Headless file modes`, `## Configuration`, `## Exit codes`, `## Never-list`, `## Speech budget`, `## Speech recognition`, `## Licensing and weights`, `## API mapping`, and `## Troubleshooting`

## AC-044-16-02 — The document does not overclaim duplex
Given `docs/VOICE_CONSOLE.md`
When it is searched for `half-duplex` and `full-duplex`
Then `half-duplex` appears
And every occurrence of `full-duplex` is in a sentence stating it is not supported or out of scope

## AC-044-16-03 — Privacy and fallback are stated
Given `docs/VOICE_CONSOLE.md`
When the modes and recognition sections are read
Then they state that audio never leaves the machine
And they state that local recognition is the default
And they state the Bailian fallback is optional, restricted to URL or long audio, and requires a standard `sk-` key

## AC-044-16-04 — Licensing and weights are stated
Given the `## Licensing and weights` section
When it is read
Then it states that model weights are not redistributed with this repository
And it names the Hugging Face model-card terms
And it names the prohibited-use clause on voice cloning

## AC-044-16-05 — Never-list and exit codes match the code
Given the `## Never-list` and `## Exit codes` sections
When they are read
Then the never-list lists `merge`, `tag`, `push-main`, `force-push`, `delete-branch`, `gate-threshold`, `secret-rotate`, `write-outside-repo`, `git-init` in that order
And the exit-code table lists `0`, `2`, `3`, `4`, `5` with the meanings of the CLI contract

## AC-044-16-06 — Configuration matches print-config
Given the `## Configuration` section
When its env vars and defaults are compared with `--print-config`
Then `VOICE_MODE`, `VOICE_OPENCODE_URL`, `VOICE_SESSION`, `VOICE_ASR_ENGINE`, and `VOICE_ARTIFACTS_DIR` are named
And every default shown equals the value `--print-config` reports

## AC-044-16-07 — The ADR is recorded
Given `docs/adr/0026-voice-console.md`
When it is read
Then its status is `Accepted`
And it has `Context`, `Decision`, and `Consequences` sections
And it references `docs/adr/0007-media-agent-family.md` and `docs/adr/0011-agent-model-agnostic-gate.md`
And `docs/adr/README.md` lists 0026

## AC-044-16-08 — Repo gates stay green and no weights are tracked
Given the Makefile `DOCS` list includes `docs/VOICE_CONSOLE.md`
When `make validate` runs
Then exit code is 0
And `git ls-files` matches no `*.onnx`, `*.safetensors`, `*.pt`, `*.ckpt`, `*.npz`, or `*.bin` path
And the configured model cache is under the gitignored `.cache/`
And `scripts/check-orchestration.sh` exits 0
