# 044 — Voice console: tasks

Context (facts from the repo, not requirements): `agents/*.md` is symlinked into
every child repo's `.opencode/agents`, so anything placed there loads by default;
spec 040 (accepted at its human gate) establishes `agents-optional/` as the
opt-in location and `scripts/media/install.mjs` as the installer shape.
`scripts/check-orchestration.sh` scans only `agents/` and `commands/` at
`maxdepth 1`; `scripts/check-agent-models.sh` scans only `agents/` and
`.opencode/agents`. Shell tests live in `scripts/tests/*.bats` and run under
`make test-scripts`; `scripts/check-bats-assertions.sh` rejects vacuous
assertions. `docs/GOVERNANCE.md` §Agent-to-tier mapping is validated by
`scripts/check-governance.sh`, which requires rows shaped
`| \`agent-name\` |` and refuses any `**T3**` assignment. The dev shell has no
capture device, and `make test` must stay green with no Python, PyTorch, or
Pocket TTS installed.

Three deliverables are the point: the TTS worker, the bridge, and the read-only
concierge agent — plus the opt-in installer, operator docs, and a structural
smoke that downloads no model weights.

## Interface decisions taken by the Specifier (veto at review)

The informal spec fixes intent but not wire-level detail. Every value below is
needed to make an acceptance criterion checkable; each is recorded here so the
human gate can veto one line instead of re-reading a scenario set.

| # | Decision | Value | Basis |
|---|---|---|---|
| D1 | Concierge agent location | `agents-optional/voice-concierge.md` | "not loaded by default in every child repo" + spec 040's accepted `agents-optional/` folder |
| D2 | Concierge is its own agent (00-informal OQ2) | separate agent, read-only, `mode: primary` | Scope boundary names "the read-only concierge agent" as a deliverable; a separate agent is the only way the read-only guarantee is structural |
| D3 | Gated-control ordering (00-informal OQ3) | terminal confirmation **before** the bridge replies; timeout or EOF ⇒ no reply sent | "not voice alone" + "the first is safer"; fail-closed is the only reading that makes the never-list enforceable in code |
| D4 | Modes | `--mode narrate\|converse\|control`, default `narrate` | The three capabilities named in "What we want"; control is the opt-in flag |
| D5 | Exit codes | `0` ok, `2` usage, `3` missing runtime/dependency, `4` policy refusal, `5` upstream/transport | Needed so "refused in code" is observable, not prose |
| D6 | Speech budget | 3 sentences **and** 45 s, seconds estimated at 2.5 words/s | "at most 3 sentences or ~45 seconds per turn"; whole sentences only, never split mid-sentence |
| D7 | Voice-activity endpointing | 16 kHz mono s16le; RMS threshold 500; ≥300 ms speech starts an utterance; 800 ms silence ends it; 30 s force-split | Half-duplex with endpointing is required; these constants make it testable on synthetic WAVs |
| D8 | CI audio test double | `--tts-engine silent` (no third-party imports) plus `tts-worker.py --self-check` | "Every audio path must have a file-based mode"; "smoke tests are structural and download no model weights" |
| D9 | Run artifacts | `--artifacts DIR` (default `.cache/voice/runs/<runId>`) holding `ledger.jsonl` and `audio/NNNN.wav` | The only way a spoken turn can be asserted in CI without a sound card |
| D10 | Local command words | `more`, `stop`, `repeat` — consumed by the bridge, never sent to the session | "the operator can ask for the rest" needs a concrete trigger |
| D11 | Never-list rule ids | `merge`, `tag`, `push-main`, `force-push`, `delete-branch`, `gate-threshold`, `secret-rotate`, `write-outside-repo`, `git-init` | Nine items in the informal never-list sentence; ids let each be asserted separately |
| D12 | Session binding | `--session <id>` required for `narrate` and `control`; optional for `converse`, where it creates a session with `--agent` (default `voice-concierge`) | "Speak the orchestrator, not the swarm" requires naming the parent session |
| D13 | HTTP surface | One mapping table in `docs/VOICE_CONSOLE.md §API mapping`; `scripts/voice/opencode-client.mjs` is its only implementation and `scripts/tests/voice-fake-server.mjs` its executable contract | The repo carries no v2 API doc; a single table keeps a shape correction to one place (see Q2) |
| D14 | Artifact retention | never pruned by the bridge; the operator deletes `.cache/voice/` | Retention policy is not in the informal spec; doing nothing is the reversible choice |

## Task 1 — CLI surface, configuration resolution, run artifacts

`scripts/voice/voice-console.mjs` (entry point) and `scripts/voice/config.mjs`.

- Both files exist and pass `node --check`.
- `--help` exits 0 and lists the three modes and the five exit codes.
- `--print-config` prints exactly one JSON object to stdout, exits 0, opens no
  socket, loads no model, and writes no file.
- The printed object carries the keys `mode`, `control`, `session`, `agent`,
  `opencodeUrl`, `audioIn`, `audioOut`, `asr`, `tts`, `budget`, `artifacts`,
  `modelCache`. `budget` is `{"maxSentences":3,"maxSeconds":45,"wordsPerSecond":2.5}`;
  `modelCache` is `.cache/voice/models`.
- Precedence per option is flag > `VOICE_*` environment variable > default. The
  env names are `VOICE_MODE`, `VOICE_OPENCODE_URL`, `VOICE_SESSION`,
  `VOICE_ASR_ENGINE`, `VOICE_ARTIFACTS_DIR`.
- `--mode` accepts only `narrate`, `converse`, `control`; anything else exits 2
  with the accepted values named on stderr and nothing on stdout.
- `--max-sentences` accepts integers ≥ 1 only; `0`, `-1`, `abc`, and a missing
  value each exit 2.
- `narrate` with any audio-input flag, and `narrate` or `control` without
  `--session`, exit 2 before any socket or child process is created.
- An unknown flag exits 2, names the flag on stderr, and prints nothing on
  stdout.
- `--artifacts DIR` creates `DIR/ledger.jsonl` and `DIR/audio/` on first write
  only, and never writes outside `DIR`.
- `ledger.jsonl` records are one JSON object per line with keys `seq` (1-based,
  contiguous, no gaps), `kind`, `turn`, `text`, `rule`, `detail`. `kind` is one
  of `spoken`, `deferred`, `resumed`, `prompt-sent`, `reply-sent`, `refused`,
  `pending`, `ignored`, `skipped-utterance`, `cancelled`, `nothing-more`.
- No ledger record contains a wall-clock timestamp or a process id.
- Scenarios: AC-044-01.

## Task 2 — Never-list policy module

`scripts/voice/policy.mjs`: a pure classifier, no I/O.

- Exports `RULES` (array of the nine ids from D11, in that order),
  `classify(intent)`, and a CLI: `node policy.mjs --intent '<json>'` prints one
  JSON object `{"blocked":bool,"rule":string|null,"requiresConfirmation":bool}`
  and exits 0 whether or not the intent is blocked.
- The module imports nothing from `node:fs`, `node:net`, `node:http`, or
  `node:https`, and contains no `fetch(` call.
- `intent` shape: `{"tool":"bash"|"edit"|"write"|"read"|"grep"|"glob"|string,
  "command":string|null,"paths":string[],"repoRoot":string}`.
- `merge` blocks any bash command matching `gh pr merge`, `glab mr merge`, or
  `git merge`.
- `tag` blocks `git tag` (any subcommand) and `gh release create`.
- `push-main` blocks `git push` whose arguments contain a whole token equal to
  `main`, `master`, `refs/heads/main`, `refs/heads/master`, a refspec ending in
  `:main`/`:master`, or one of `--all`, `--mirror`.
- `force-push` blocks `git push` with `-f`, `--force`, `--force-with-lease`, or a
  refspec beginning with `+`.
- `delete-branch` blocks `git branch -d`/`-D`, `git push --delete`, and a
  `git push` refspec of the form `:branch`.
- `gate-threshold` blocks any edit/write whose path matches
  `**/check-code-principles.sh`, `**/pmd*.xml`, `**/*golangci*.yml`,
  `**/.eslintrc*`, `**/stryker.conf.json`, `**/mutation.mk`,
  `**/pitest-profile.xml`, or `**/mutmut-pyproject.toml`.
- `secret-rotate` blocks `gh secret`, `glab variable`, `security add-generic-password`,
  and any edit/write to `config/agent.local.env`, `config/model.local.env`, or
  `.envrc`.
- `write-outside-repo` blocks any edit/write path whose realpath-joined form is
  not under `repoRoot`; a `..` segment or a symlink escaping the root is blocked.
- `git-init` blocks `git init`, `git submodule add`, and `git submodule update
  --init`.
- Matching is case-insensitive and collapses runs of whitespace in `command`;
  `command` is split on whitespace before token comparison, so `git  push` and
  `GIT PUSH` behave identically to the single-space lower-case form.
- A `read`/`grep`/`glob` intent is never blocked and never requires
  confirmation.
- An unknown tool with no command and no paths returns `blocked:false`,
  `rule:null`, `requiresConfirmation:true`.
- Classification has no filesystem side effect: after any call the working tree
  is byte-identical.
- Scenarios: AC-044-02.

## Task 3 — Enforcement at the outbound boundary

`scripts/voice/guard.mjs`, used by every mode that can reply.

- `guard.authorize(intent)` calls `policy.classify`; a blocked result throws a
  `PolicyRefusal` carrying `rule`, which the caller prints as
  `refused: <rule>` and turns into exit 4 when nothing else remains to do.
- A blocked action is never sent: with the fake server recording requests, a
  blocked permission reply produces zero recorded requests.
- A never-list refusal is not overridable: no flag (`--yes`, `--force`,
  `--confirm all`) changes the outcome. `--yes` is not a recognised flag and
  exits 2 as an unknown flag.
- `opencode-client.mjs` exports the only reply-sending function in the
  codebase; `control.mjs` is its only caller, and it calls `guard.authorize`
  immediately before each send (grep-checkable: no other module imports the
  reply function).
- The installer (`scripts/voice/install.mjs`) does not route through the guard —
  it writes only to `$OPENCODE_CONFIG_DIR`, and Task 14 asserts that scope
  directly.
- For a non-blocked mutating tool (`bash`, `edit`, `write`), the guard returns
  `requiresConfirmation:true`; the caller sends only after a terminal `y`.
- For a non-blocked read-only tool (`read`, `grep`, `glob`), the guard returns
  `requiresConfirmation:false`; the caller may send on a spoken yes.
- Scenarios: AC-044-03.

## Task 4 — Pocket TTS worker

`scripts/voice/tts-worker.py` — a streaming, cancellable speech worker driven
over JSONL on stdin/stdout.

- `--self-check` prints one JSON object with keys `python`, `pocket_tts`,
  `torch`, `sample_rate`; exits 0 whether or not the optional packages are
  importable; performs no network access and downloads nothing.
- `--engine silent` imports no third-party module (no top-level `import torch`,
  no `import pocket_tts`) and synthesises a WAV from text alone.
- Output is 24 kHz mono 16-bit PCM WAV unless `--sample-rate` overrides it.
- Request protocol: one JSON object per stdin line, `{"id","text","out"}`.
  Response events on stdout, one JSON object per line: `{"id","event":"start"}`,
  then one or more `{"id","event":"chunk","bytes":N}`, then
  `{"id","event":"done","path","durationMs","sampleRate","cancelled":false}`.
- Empty `text` or a missing `id` yields
  `{"id":...,"event":"error","code":"bad-request","message":...}` and the worker
  stays alive for the next request.
- `{"event":"cancel","id":"<id>"}` cancels that request: the worker emits `done`
  with `cancelled:true` and stops writing within 500 ms.
- `SIGINT` cancels the in-flight request the same way and exits 0 within 2 s.
  The cancellation mechanism is a `threading.Event`, per the Pocket TTS API.
- `--engine pocket-tts` when the package is absent emits
  `{"event":"error","code":"missing-runtime"}` and exits 3.
- `durationMs` equals `frames * 1000 / sampleRate` within 1 ms.
- The worker never opens an audio device: no `sounddevice`, `pyaudio`, or
  playback `subprocess` in the file; it writes only to the `out` path it is
  given.
- Scenarios: AC-044-04.

## Task 5 — Sentence chunking and the speech budget

`scripts/voice/chunk.mjs`.

- `splitSentences(text)` returns whole sentences with their terminator retained.
- A boundary exists at `!` or `?` followed by whitespace or end of text.
- A boundary exists at `.` followed by whitespace or end of text, except when
  the preceding token is one of `e.g`, `i.e`, `etc`, `vs`, `Dr`, `Mr`, `Mrs`,
  `Ms`, `No`, `Fig`, `cf`, or when the period sits between two digits.
- `Pi is 3.14 exactly.` is one sentence; `Hello there. Next one!` is two.
- `takeWindow(sentences, budget)` returns `{spoken, deferred, estimatedSeconds}`;
  `spoken.length <= maxSentences`; whole sentences only — no sentence is ever
  truncated.
- `estimatedSeconds` is the spoken word count divided by `wordsPerSecond`;
  words are whitespace-separated non-empty tokens.
- Sentences are added while the running estimate stays at or below
  `maxSeconds`; the first sentence is always included even when it alone
  exceeds the estimate.
- Feeding the deferred remainder to a second `takeWindow` with the same budget
  yields the next window; repeated calls eventually return an empty `spoken`
  with a non-empty `deferred` of length 0.
- The chunker is a deterministic pure module: same input, identical output,
  no I/O imports.
- Streaming: `feed(delta)` returns only sentences completed by that delta;
  `finish()` flushes the remainder as one sentence; text already returned is
  never returned twice when the same source part grows.
- Scenarios: AC-044-05.

## Task 6 — opencode client and the parent-only event filter

`scripts/voice/opencode-client.mjs` and the test double
`scripts/tests/voice-fake-server.mjs`.

- The client's HTTP surface is the table in
  `docs/VOICE_CONSOLE.md §API mapping`; the fake server implements exactly that
  table and nothing else.
- `connect()` subscribes to the event stream and dispatches newline-delimited
  JSON events.
- A text part is spoken only when all four hold: its `sessionID` equals the
  configured parent session, the cached role for its `messageID` is
  `assistant`, its `type` is `text`, and it carries no subtask marker
  (`type: "subtask"`, `synthetic: true`, or a non-empty `parentID`).
- Parts from another session, user-role parts, subtask parts, and non-text
  parts are dropped before the chunker and leave no ledger record.
- A part that is re-sent with a longer `text` yields only the delta; the already
  spoken prefix is not spoken again.
- `sendPrompt(sessionID, text)` issues exactly one request carrying the text as
  a single text part; the fake server's recording shows the verbatim text and no
  second request.
- `sendReply(kind, id, body)` issues exactly one request per call to the
  documented reply path for that kind (`question`, `permission`).
- A non-2xx response is retried once after 250 ms, then the process exits 5 with
  the status and path on stderr; no ledger record claims success.
- Stream reconnect: three attempts with 500 ms base backoff, then exit 5.
- `--dry-run` prints the requests it would send as JSONL on stdout and opens no
  socket.
- The fake server takes `--events FILE`, `--record FILE`, `--port 0`; prints
  exactly `LISTENING <port>` on stdout; appends one JSON object per received
  request to the record file; exits 0 on `SIGTERM`.
- Scenarios: AC-044-06.

## Task 7 — Audio capture and voice-activity endpointing

`scripts/voice/audio-in.mjs`, with the deterministic fixture writer
`scripts/tests/voice-fixtures.mjs`.

- `voice-fixtures.mjs` exports `toneMs(ms, {freq, amplitude})`,
  `silenceMs(ms)`, and `wav({sampleRate, channels, samples})`; identical
  arguments produce byte-identical output.
- `--audio-in file:PATH` reads a 16 kHz mono s16le WAV and emits utterances
  through one callback.
- Endpointing per D7: RMS threshold 500; speech is ≥ `--min-utterance-ms`
  (default 300) of supra-threshold samples; an utterance ends after
  `--silence-ms` (default 800) of sub-threshold samples; a run longer than
  `--max-utterance-ms` (default 30000) is force-split into equal parts.
- A fixture of `tone(500) + silence(900) + tone(500) + silence(900)` yields
  exactly two utterances, each within one frame of the 500 ms tone length.
- Leading and trailing silence produce no utterance.
- A 100 ms blip is dropped, not emitted.
- Continuous speech longer than `--max-utterance-ms` yields
  `ceil(total/max)` utterances, none shorter than `--min-utterance-ms`.
- `--audio-in device` spawns `arecord -f S16_LE -r 16000 -c 1 -t raw` and
  funnels its stdout through the same endpointing path as file mode.
- When `arecord` is absent, `--audio-in device` exits 3, names `arecord` on
  stderr, and writes no ledger record.
- File mode spawns no child process.
- Scenarios: AC-044-07.

## Task 8 — Local speech-recognition adapter

`scripts/voice/asr.mjs`.

- Engine resolution: `--asr-engine` > `VOICE_ASR_ENGINE` > `ASR_DEFAULT_ENGINE`
  exported from `scripts/voice/config.mjs`.
- The accepted set is exactly `["faster-whisper","sherpa-onnx"]`; any other
  value exits 2 and lists both on stderr.
- `--asr file:PATH` bypasses every engine: line N of the file is the transcript
  of utterance N. Blank lines are ignored; an utterance with no available line
  is skipped with ledger `kind: "skipped-utterance"`.
- A transcript line that is empty after trimming produces no prompt and no
  ledger `prompt-sent` record.
- No cloud path: the module contains no `http://` or `https://` literal and
  spawns no `bl` process.
- With a real engine selected and its package absent, the adapter exits 3 with
  `missing-runtime` and the engine name before reading any audio.
- `--print-config` reports `asr.engine` and `asr.kind` (`file` or `local`), and
  `modelCache` as `.cache/voice/models`.
- `docs/VOICE_CONSOLE.md` names the same engine as `ASR_DEFAULT_ENGINE`
  (single-source consistency; the value itself is open question Q1).
- Scenarios: AC-044-08.

## Task 9 — Playback and cancellation

`scripts/voice/audio-out.mjs`.

- `--audio-out file:DIR` writes `NNNN.wav` (four digits, starting at `0001`)
  one file per utterance, in order, and creates `DIR` if absent.
- Numbering continues across turns and never overwrites an existing file — a
  pre-existing `0001.wav` makes the next write `0002.wav`.
- File mode spawns no child process; a `ffplay` shim that exits 99 on `PATH`
  does not affect it.
- `--audio-out device` plays each file with
  `ffplay -nodisp -autoexit -loglevel quiet <path>`; when `ffplay` is absent
  the mode exits 3 naming `ffplay`.
- `cancel()` stops the current playback within 500 ms (`SIGTERM`, then
  `SIGKILL` after 1 s) and returns `{cancelled:true}`.
- A new utterance while one is playing cancels the previous one — playback
  depth is one — and the cancelled utterance is reported with reason
  `superseded`.
- Scenarios: AC-044-09.

## Task 10 — Narrate mode

`scripts/voice/narrate.mjs`, wired from `voice-console.mjs`.

- Narrate constructs no capture adapter and no ASR adapter: an `arecord` shim
  that exits 99 on `PATH` is never invoked, and the ledger contains no
  `prompt-sent` or transcript record.
- End-to-end, file-based: a fixture event stream with five parent sentences and
  one subtask paragraph plus `--tts-engine silent --audio-out file:OUT`
  produces exactly three `spoken` ledger records, one `deferred` record for the
  remaining two sentences, three WAV files `0001`–`0003`, and no ledger text
  from the subtask paragraph.
- Ledger `seq` is contiguous from 1 and `turn` is 1 for every record of the
  first turn.
- `more` on `--input-script` speaks the deferred sentences as a second window
  (`resumed` then `spoken` records); a second `more` after exhaustion records
  `nothing-more` and writes no WAV.
- `stop` cancels the in-flight utterance and writes a `cancelled` record; the
  process keeps running and accepts a later turn.
- `SIGINT` cancels the in-flight utterance, writes one `cancelled` record, and
  exits 0 within 2 s; a second `SIGINT` exits 130.
- When stdin is not a TTY and `--input-script` is absent, narrate ignores stdin,
  never blocks on it, and exits 0 when the event stream ends.
- Scenarios: AC-044-10.

## Task 11 — Converse mode

`scripts/voice/converse.mjs`.

- End-to-end, file-based: a two-utterance WAV plus a two-line transcript file
  produces two `prompt-sent` records in utterance order with the verbatim
  transcript text, and two assistant replies spoken and recorded.
- `turn` increments per utterance; records for one turn are contiguous in `seq`.
- An utterance with an empty transcript writes `skipped-utterance` and sends no
  prompt.
- A four-sentence reply is spoken as three sentences with one deferred; `more`
  speaks the fourth.
- `--mode converse` without `--session` creates a session with `--agent`
  (default `voice-concierge`) and records the returned session id in the ledger
  `detail` of the first `prompt-sent` record.
- Device capture with no capture device exits 3 naming `arecord`
  (operator-verified; CI uses file mode).
- Scenarios: AC-044-11.

## Task 12 — Gated control (opt-in)

`scripts/voice/control.mjs`.

- `control` is reachable only via `--mode control`; in `narrate` and `converse`
  a `question.asked` or `permission.asked` event writes `ignored` and sends
  nothing.
- `question.asked` with options: the bridge speaks the header followed by the
  numbered option labels, and records one `spoken` ledger entry containing each
  label.
- A spoken answer matching `1`–`9` or a label (case-insensitive, punctuation
  stripped) sends that option's label as the reply; an unmatched phrase
  re-prompts once, then leaves the question `pending` with no reply.
- A question with no options sends the trimmed transcript verbatim.
- `permission.asked` whose intent classifies as read-only: a spoken `yes` sends
  the reply without any terminal confirmation.
- `permission.asked` whose intent classifies as mutating: the bridge speaks a
  summary (tool plus command or paths) and sends nothing until a terminal `y`;
  `n` sends nothing and records `refused` with rule `not-confirmed`; EOF or
  `--confirm-timeout` (default 60 s) expiry records `pending` and sends nothing.
- `permission.asked` whose intent is blocked is refused with its rule id, sends
  no request, and is not overridable by a terminal `y`.
- A spoken prompt whose trimmed text starts with `/` requires terminal
  confirmation: `y` sends it, `n`/EOF sends nothing and records `refused` with
  rule `not-confirmed`.
- Terminal input comes from stdin, or from `--input-script FILE` which supplies
  the same lines; `--input-script` never opens the microphone and never blocks.
- Scenarios: AC-044-12.

## Task 13 — Read-only concierge agent and governance row

- `agents-optional/voice-concierge.md` exists at exactly that path.
- Frontmatter has `description`, `mode: primary`, and no `model:` key.
- Frontmatter permission block: `read: "*": allow`; `edit: "*": deny`;
  `bash: "*": deny`; `task: "*": deny`.
- The prompt states, in its own words, that the agent answers in at most three
  sentences, that it never performs or claims to perform a mutation, and that it
  says it is read-only when asked to change anything.
- The prompt references `docs/VOICE_CONSOLE.md`, which exists (Task 16).
- `docs/GOVERNANCE.md` gains one mapping-table row beginning
  `` | `voice-concierge` | `` with trust tier **T0**, a frontmatter basis
  naming the deny-all edit/bash/task grants, and no **T3** anywhere in the
  table.
- `scripts/check-governance.sh` exits 0 after the row is added.
- `scripts/check-agent-models.sh` is not modified, and its scan set remains
  `agents` and `.opencode/agents`; the no-pin guarantee for this file is
  asserted by `scripts/voice/smoke.mjs` and by AC-044-13.
- Scenarios: AC-044-13.

## Task 14 — Opt-in installer, make targets, structural smoke

`scripts/voice/install.mjs` and `scripts/voice/smoke.mjs`, mirroring
`scripts/media/install.mjs`.

- `install.mjs` copies `agents-optional/voice-concierge.md` to
  `$OPENCODE_CONFIG_DIR/agents/voice-concierge.md` and every
  `scripts/voice/*.mjs` plus `scripts/voice/tts-worker.py` to
  `$OPENCODE_CONFIG_DIR/voice/`.
- `OPENCODE_CONFIG_DIR` defaults to `~/.config/opencode`.
- A second run is idempotent: exit 0 and an unchanged file set.
- `--uninstall` removes exactly the installed paths and nothing else; a sentinel
  file in the config dir survives.
- `--dry-run` prints each destination path, one per line, and writes nothing.
- A missing source file exits 3, names the missing path, and copies nothing.
- With a temporary `HOME` and `OPENCODE_CONFIG_DIR`, no file is created outside
  the config dir and no file is created under the temporary `HOME` except
  through the config dir.
- `make install-voice`, `make uninstall-voice`, and `make smoke-voice` invoke
  the two scripts; all three appear in `.PHONY` and in `make help` output.
- `scripts/voice/smoke.mjs` exits 0 and prints at least these lines:
  `[OK] agent voice-concierge.md`, `[OK] policy refuses`, `[OK] install dry-run`,
  one `[OK] <file> parses` per `.mjs`, and `[OK] print-config`.
- Smoke performs no network access: the file imports no `node:http`/`node:https`
  and contains no `fetch(` call; it downloads no model weights.
- When `python3` is absent the smoke prints `[SKIP] tts-worker.py` and still
  exits 0.
- Scenarios: AC-044-14.

## Task 15 — Bats acceptance suite

`scripts/tests/voice-console.bats`.

- The file exists and every scenario id `AC-044-*` in
  `specs/044-voice-console/20-acceptance/` appears in exactly one
  `@test "AC-044-NN-MM: ..."` name.
- `scripts/check-scenario-traceability.sh` exits 0.
- `scripts/check-bats-assertions.sh` exits 0.
- `make test-scripts` passes on a machine with Node and no Python, PyTorch,
  Pocket TTS, `arecord`, or `ffplay` installed: absent-runtime paths assert
  exit 3, and only the operator-only device scenarios use `skip`.
- No test opens a socket other than to `127.0.0.1`, and no test downloads a
  model or writes outside `$TMPDIR_HELPER` or a temp `OPENCODE_CONFIG_DIR`.
- Every test runs with `setup_tmpdir`/`teardown_tmpdir` from
  `scripts/tests/test_helper.bash`.
- Scenarios: AC-044-15.

## Task 16 — Operator documentation, ADR, weight guard

- `docs/VOICE_CONSOLE.md` exists and contains the headings `## Modes`,
  `## Install`, `## Headless file modes`, `## Configuration`, `## Exit codes`,
  `## Never-list`, `## Speech budget`, `## Speech recognition`,
  `## Licensing and weights`, `## API mapping`, `## Troubleshooting`.
- The document contains the word `half-duplex` and mentions full duplex only in
  a sentence stating it is not supported or out of scope.
- It states that audio never leaves the machine, that local ASR is the default,
  and that the Bailian path is an optional fallback restricted to URL or long
  audio and requiring a standard `sk-` key.
- `## Licensing and weights` states that model weights are not redistributed
  with this repository and names the Hugging Face model-card terms and the
  prohibited-use clause on voice cloning.
- `## Never-list` lists exactly the nine rule ids from `RULES`, in the same
  order.
- `## Exit codes` lists `0`, `2`, `3`, `4`, `5` with the meanings from D5.
- `## Configuration` names the same env vars and defaults as `--print-config`.
- `docs/adr/0026-voice-console.md` exists with status `Accepted` and sections
  `Context`, `Decision`, `Consequences`; it references
  `docs/adr/0007-media-agent-family.md` and
  `docs/adr/0011-agent-model-agnostic-gate.md`.
- `docs/adr/README.md` index lists 0026.
- The Makefile `DOCS` list includes `docs/VOICE_CONSOLE.md`; `make validate`
  passes.
- Weight guard: `git ls-files` matches no `*.onnx`, `*.safetensors`, `*.pt`,
  `*.ckpt`, `*.npz`, or `*.bin` path, and the configured model cache
  (`.cache/voice/models`) sits under the already-gitignored `.cache/`.
- `scripts/check-orchestration.sh` exits 0.
- Scenarios: AC-044-16.

## Open questions

- **Q1 — default local ASR engine (from `00-informal.md`).** The informal spec
  says "Pick one as the shipped default" without picking. Question for the
  reviewer: `faster-whisper` or `sherpa-onnx`? Non-blocking: AC-044-08 asserts
  single-source consistency (one constant, documented value equal to it) and a
  one-line change pins the choice. Answering it adds one scenario asserting
  `ASR_DEFAULT_ENGINE` equals the chosen engine.
- **Q2 — live API fixture.** The repo carries no opencode v2 API reference.
  Question: is a live `opencode serve` available on the operator's machine to
  capture one real event stream into `scripts/tests/voice-fixture-events.jsonl`?
  If yes, Task 6's mapping table must be pinned to that capture; if no, the
  hand-written fixture in `scripts/tests/voice-fake-server.mjs` is the contract
  of record. Non-blocking either way — the mapping lives in one table.
- **Q3 — cross-spec ordering.** Task 13 places the agent in `agents-optional/`,
  the folder spec 040 (accepted, not yet merged) creates; `agents/` still holds
  `media-*.md` today. Question: if 040 is dropped or renames that folder before
  either PR merges, should 044 create the directory itself (recorded default) or
  wait and depend on 040? Non-blocking: creating it is additive and reversible.
- **Q4 — spoken command vocabulary (D10).** `more` / `stop` / `repeat` are the
  Specifier's choice for "the operator can ask for the rest". Question: does the
  reviewer want different words, or keystroke-only control? Affects Task 10 and
  Task 11 scenarios, which name the three words.
