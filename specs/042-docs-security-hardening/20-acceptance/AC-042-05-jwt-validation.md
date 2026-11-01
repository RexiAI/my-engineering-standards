# AC-042-05: JWT validation checklist in `docs/SECURITY.md`

## AC-042-05-01 — The section is a checklist with one line per check
Given `docs/SECURITY.md`
When the JWT section is read
Then the file contains the heading `## JWT Validation Checklist`
And the section contains at least five lines starting with `- [ ]`
And every checklist item states that a failing token is rejected

## AC-042-05-02 — Algorithm allowlist, and alg=none is rejected
Given the JWT checklist in `docs/SECURITY.md`
When the algorithm items are read
Then the section contains `Algorithm allowlist`
And it states that the accepted `alg` values are fixed in configuration
And it states that the token header's `alg` only selects from that set and is never itself trusted
And it contains `Reject alg=none`
And it states that an unlisted algorithm is rejected before signature verification

## AC-042-05-03 — Key selection is bound to a trusted JWKS
Given the JWT checklist in `docs/SECURITY.md`
When the key-selection item is read
Then the section contains `Key selection by kid`
And it states that the verification key comes from a configured, trusted JWKS
And it contains `jku` and `x5u` and states that neither URL is fetched
And it states that a key embedded in the token is never used

## AC-042-05-04 — Signature is verified first, then time claims
Given the JWT checklist in `docs/SECURITY.md`
When the verification-order item is read
Then the section contains `Signature before claims`
And it states that no claim is read before the signature verifies
And it contains `Time claims (exp, nbf, iat)`
And it states that `exp` is required and that `nbf` and `iat` are honoured with bounded clock skew

## AC-042-05-05 — Audience and issuer are validated; the section closes the block
Given the JWT checklist in `docs/SECURITY.md`
When the audience item is read
Then the section contains `Audience and issuer (aud, iss)`
And it states that both are validated against expected values and that a missing or mismatched value is rejected
And the `## JWT Validation Checklist` heading appears after the heading `## Input Validation`
And it appears after each of the headings `## SSRF (Server-Side Request Forgery)`, `## CSRF (Cross-Site Request Forgery)`, `## CORS (Cross-Origin Resource Sharing)`, and `## Password Hashing`
And it appears before the heading `## Upstream Error Responses Must Not Reach the Client`
