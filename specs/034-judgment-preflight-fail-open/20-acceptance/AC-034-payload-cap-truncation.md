# AC-034: Task 2 — payload cap and deterministic truncation

## AC-034-06 — Under-cap state is sent byte-identical
Given `JUDGMENT_MAX_STATE_BYTES` is unset (default 12288)
And the state payload is smaller than 12288 bytes
When `scripts/typed-judgment.sh` is invoked against a mock backend
Then the request body's state field equals the original state exactly
And stderr contains no `payload_overflow` reason line

## AC-034-07 — Over-cap state is truncated head + marker + tail, then sent
Given `JUDGMENT_MAX_STATE_BYTES=12288`
And the state payload is larger than 12288 bytes
When `scripts/typed-judgment.sh` is invoked against a mock backend
Then the request body's state field is at most 12288 bytes
And the truncated state begins with a prefix of the original state
And the truncated state ends with a suffix of the original state
And the truncated state contains a marker naming the omitted byte count
And stderr contains exactly one line matching `typed-judgment: reason=payload_overflow`
And the HTTP call is still made (the mock records one request)
And the script exits 0 when the mock returns a usable answer

## AC-034-08 — Truncation is deterministic
Given a fixed state payload larger than the cap
When `scripts/typed-judgment.sh` is invoked twice with the same inputs
Then both invocations produce byte-identical truncated state fields

## AC-034-09 — Cap is configurable by flag and env, defaulting to 12288
Given no flag and `JUDGMENT_MAX_STATE_BYTES` unset
When the wrapper resolves the cap
Then the cap is 12288
Given `JUDGMENT_MAX_STATE_BYTES=2048`
When the wrapper resolves the cap
Then the cap is 2048
Given `--max-state-bytes 4096` and `JUDGMENT_MAX_STATE_BYTES=2048`
When the wrapper resolves the cap
Then the cap is 4096 (the flag wins)

## AC-034-10 — `--dry-run` prints the truncated body, never the full state
Given `--dry-run` and a state payload larger than the cap
When `scripts/typed-judgment.sh` is invoked
Then stdout contains the marker and a state field at most the cap bytes
And stdout does not contain the untruncated state payload

## AC-034-11 — Non-JSON string state over the cap is truncated as a string
Given the state payload is not valid JSON and is larger than the cap
When `scripts/typed-judgment.sh` is invoked against a mock backend
Then the request body embeds the state as a JSON string
And the embedded string is at most the cap bytes and carries the head + marker + tail
And stderr contains a `payload_overflow` reason line
