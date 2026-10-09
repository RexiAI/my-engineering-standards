# AC-029: Backend switch in typed-judgment.sh

## AC-029-10 — Backend unset preserves hosted behavior
Given `JUDGMENT_BACKEND` is unset
And `JUDGMENT_API_URL` and `JUDGMENT_API_KEY` and `JUDGMENT_MODEL` are set
And the mock server returns a valid response
When `scripts/typed-judgment.sh` is invoked
Then the request includes `Authorization: Bearer <key>`
And the exit code is 0
And all 66 existing spec-028 bats tests pass without modification

## AC-029-11 — Backend hosted is identical to unset
Given `JUDGMENT_BACKEND=hosted`
And `JUDGMENT_API_URL` and `JUDGMENT_API_KEY` and `JUDGMENT_MODEL` are set
And the mock server returns a valid response
When `scripts/typed-judgment.sh` is invoked
Then the request includes `Authorization: Bearer <key>`
And the exit code is 0
And the request body and headers are byte-identical to the unset-backend case

## AC-029-12 — Local backend without API key sends no auth header
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_API_URL` is set
And `JUDGMENT_API_KEY` is unset
And `JUDGMENT_MODEL` is set (or unset per spike-determined behavior)
And the mock server returns a valid response
When `scripts/typed-judgment.sh` is invoked
Then the request does not include an `Authorization` header (or includes a dummy header if the spike report documents the server requires one)
And the exit code is 0

## AC-029-13 — Local backend with API key sends auth header
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_API_URL` is set
And `JUDGMENT_API_KEY` is set
And `JUDGMENT_MODEL` is set
And the mock server returns a valid response
When `scripts/typed-judgment.sh` is invoked
Then the request includes `Authorization: Bearer <key>`
And the exit code is 0

## AC-029-14 — Local backend without URL falls back
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_API_URL` is unset
When `scripts/typed-judgment.sh` is invoked
Then the exit code is 10
And no HTTP request is made

## AC-029-15 — Invalid backend value is a usage error
Given `JUDGMENT_BACKEND=invalid`
When `scripts/typed-judgment.sh` is invoked
Then the exit code is 2
And stderr contains a diagnostic mentioning the invalid value

## AC-029-16 — Local backend parses Kev response shape
Given `JUDGMENT_BACKEND=local`
And the mock server returns a response with `latency_ms` per answer (Kev shape)
When `scripts/typed-judgment.sh` is invoked
Then the normalized output includes `latency_ms` from the response body
And `answer`, `confidence`, `probabilities`, `usage` are correctly extracted
And the exit code is 0

## AC-029-17 — Local backend parses CLM response shape
Given `JUDGMENT_BACKEND=local`
And the mock server returns a response with `billing_units` per answer (CLM shape, no `latency_ms` in body)
When `scripts/typed-judgment.sh` is invoked
Then `billing_units` is ignored in the normalized output
And `answer`, `confidence`, `probabilities`, `usage` are correctly extracted
And `latency_ms` falls back to client-measured elapsed time
And the exit code is 0

## AC-029-18 — Local backend server down falls back after retries
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_API_URL` points to a non-responsive endpoint
And `JUDGMENT_BACKOFF_SECONDS=0` (offline test)
When `scripts/typed-judgment.sh` is invoked
Then the script attempts at most 3 requests
And the exit code is 10

## AC-029-19 — Local backend daily cap enforced
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_DAILY_CAP=1`
And the counter file already contains `1`
When `scripts/typed-judgment.sh` is invoked
Then the exit code is 10
And no HTTP request is made
And the counter is not incremented

## AC-029-20 — Local backend low confidence exits 10 with answer printed
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_MIN_CONFIDENCE=0.8`
And the mock server returns a valid response with confidence 0.5
When `scripts/typed-judgment.sh` is invoked
Then the normalized answer is printed on stdout
And the exit code is 10

## AC-029-21 — Existing 66 tests pass without modification
Given the spec 029 changes are applied
When `scripts/tests/typed-judgment.bats` is run
Then all 27 existing tests pass
When `scripts/tests/typed-judgment-integration.bats` is run
Then all 39 existing tests pass
And no existing test file has been modified (diff is empty for these files' original lines)
