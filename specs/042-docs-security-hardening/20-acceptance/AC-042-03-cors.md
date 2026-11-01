# AC-042-03: CORS guidance in `docs/SECURITY.md`

## AC-042-03-01 — Wildcard origin is never combined with credentials
Given `docs/SECURITY.md`
When the CORS section is read
Then the file contains the heading `## CORS (Cross-Origin Resource Sharing)`
And the section contains `Access-Control-Allow-Origin`
And it contains `Access-Control-Allow-Credentials`
And it states that `*` is never used on an endpoint returning credentialed or authenticated data
And it states that `*` combined with `Access-Control-Allow-Credentials: true` is invalid

## AC-042-03-02 — Origins come from an exact allowlist, never reflection
Given the CORS section of `docs/SECURITY.md`
When the origin rule is read
Then the section contains `allowlist`
And it states that the matched origin is echoed back and an unmatched origin receives no CORS header
And it states that the request's `Origin` is never reflected without an allowlist match
And it contains `Vary: Origin`

## AC-042-03-03 — Preflight responses are minimal
Given the CORS section of `docs/SECURITY.md`
When the preflight rule is read
Then it states that only the methods the endpoint actually uses are allowed
And it states that only the headers the endpoint actually reads are allowed
And it states that a wildcard `Access-Control-Allow-Headers` is not combined with credentials

## AC-042-03-04 — CORS is not treated as access control
Given the CORS section of `docs/SECURITY.md`
When the threat-model note is read
Then the section contains `not access control`
And it states that CORS does not protect against non-browser clients
And it states that authorization is enforced server-side
