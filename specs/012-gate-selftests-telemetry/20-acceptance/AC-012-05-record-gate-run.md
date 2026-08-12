# AC-012-05: record-gate-run.sh appends a validated record to runs.jsonl

## AC-012-05-01 — A valid record is appended as one JSONL line (AC-003)
Given a scratch `GATE_RUNS_FILE=/tmp/runs.jsonl`
When `record-gate-run.sh -record '{"runId":"r1","specSlug":"012-slug","gatesFailed":["complexity"],"loopCount":1,"phase1Retries":0,"phase2Retries":0,"warnings":[],"durationSec":12.5,"outcome":"fail"}'` runs
Then `/tmp/runs.jsonl` contains exactly one line
And that line is the record verbatim
And the script exits 0

## AC-012-05-02 — Appends, never rewrites (append-only)
Given `/tmp/runs.jsonl` already contains one valid record
When a second valid record is appended
Then the file contains two lines in insertion order
And the first line is byte-identical to the original

## AC-012-05-03 — runId is generated when omitted
Given a valid record with no `runId` field
When `record-gate-run.sh` appends it
Then the appended line has a non-empty `runId` (from `uuidgen`, or an `<epoch>-<pid>` fallback)
And the record is otherwise unchanged

## AC-012-05-04 — loop/retry fields default from SPEC_* env vars, then to 0
Given `SPEC_LOOP_COUNT=3 SPEC_PHASE1_RETRIES=2` and a record with no loop fields
When `record-gate-run.sh` appends it
Then the appended line has `"loopCount":3` and `"phase1Retries":2` and `"phase2Retries":0`
And with no env vars set, the appended line has `"loopCount":0,"phase1Retries":0,"phase2Retries":0`

## AC-012-05-05 — Validation rejects a malformed record without appending
Given each of: (a) a non-JSON string, (b) an object missing `outcome`, (c) `outcome` set to `"unknown"`, (d) both `specSlug` and `jiraKey` present, (e) neither present
When `record-gate-run.sh` runs with that record
Then it prints an error to stderr naming the problem field
And it exits 1
And the target runs.jsonl is not modified

## AC-012-05-06 — Exactly one of specSlug/jiraKey is accepted
Given a record with `"jiraKey":"PROJ-123"` and no `specSlug`
When `record-gate-run.sh` appends it
Then it exits 0 and the line is appended unchanged

## AC-012-05-07 — -f and GATE_RUNS_FILE override the default path
Given no `GATE_RUNS_FILE` and no `-f`
When a valid record is appended
Then it lands in `<repo-root>/runs.jsonl`
And with `-f /tmp/other.jsonl` it lands there instead, leaving `<repo-root>/runs.jsonl` untouched
