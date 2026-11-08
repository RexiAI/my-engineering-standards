# AC-044-06: opencode client and parent-only filter

## AC-044-06-01 — Parent assistant text is spoken
Given a parent session `ses_parent`
And an event carrying an assistant `text` part for `ses_parent`
When the client dispatches it
Then the text reaches the chunker

## AC-044-06-02 — Subtask chatter is suppressed
Given the same parent session
And an event whose part has `type: "subtask"`, or `synthetic: true`, or a non-empty `parentID`
When the client dispatches it
Then the part is dropped before the chunker
And no ledger record is written for it

## AC-044-06-03 — Foreign sessions and user parts are suppressed
Given a parent session `ses_parent`
When events for session `ses_other`, a `user`-role message part, and a non-`text` part arrive
Then each is dropped before the chunker
And the ledger records nothing for them

## AC-044-06-04 — Growing parts yield only the delta
Given a text part `p1` first carrying `Hello`
And then the same part id carrying `Hello world`
When both events are dispatched
Then the chunker receives `Hello` exactly once
And ` world` is not duplicated

## AC-044-06-05 — One request per prompt
Given a fake server recorder
When `sendPrompt("ses_parent", "what stage is 044 at?")` runs
Then the recorder contains exactly one request
And its body carries `what stage is 044 at?` as a single text part

## AC-044-06-06 — One request per reply
Given a fake server recorder
When `sendReply("question", "q1", {label: "Approve"})` and `sendReply("permission", "p1", {reply: "once"})` run
Then the recorder contains exactly two requests
And each targets the documented reply path for its kind

## AC-044-06-07 — Upstream failure is bounded and loud
Given a fake server returning status 500 for the prompt path
When `sendPrompt` runs
Then exactly two requests are recorded, 250 ms apart
And the process exits 5
And stderr contains the status and path
And no ledger record claims the prompt was sent

## AC-044-06-08 — Stream reconnect is bounded
Given a fake server that closes the event stream immediately, three times
When the client connects
Then it retries three times with 500 ms base backoff
And then exits 5

## AC-044-06-09 — Dry run sends nothing
Given `--dry-run` and a fake server recorder
When a prompt and a reply are requested
Then stdout contains two JSONL lines describing the requests
And the recorder contains zero requests

## AC-044-06-10 — Fake server contract
Given `node scripts/tests/voice-fake-server.mjs --events <fixture> --record <file> --port 0`
When it starts
Then it prints exactly `LISTENING <port>` on stdout
And after two requests the record file has two JSON objects
And on `SIGTERM` it exits 0
