# AC-042-02: CSRF guidance in `docs/SECURITY.md`

## AC-042-02-01 — Cookie-authenticated state changes require a CSRF token
Given `docs/SECURITY.md`
When the CSRF section is read
Then the file contains the heading `## CSRF (Cross-Site Request Forgery)`
And the section contains `state-changing`
And it contains `CSRF token`
And it states that a state-changing request authenticated by a cookie without a valid token is rejected
And it states that safe methods such as GET and HEAD never mutate state

## AC-042-02-02 — Session cookies carry a SameSite policy
Given the CSRF section of `docs/SECURITY.md`
When the cookie rule is read
Then the section contains `SameSite=Lax`
And it contains `SameSite=Strict`
And it contains `SameSite=None`
And it states that `SameSite=None` requires the `Secure` attribute

## AC-042-02-03 — Origin or Referer is checked against an allowlist
Given the CSRF section of `docs/SECURITY.md`
When the request-origin rule is read
Then the section contains `Origin` and `Referer`
And it states that a state-changing request whose origin does not match the allowlist is rejected
And it states that the Referer check is the fallback when no Origin header is present

## AC-042-02-04 — Bearer-token APIs are distinguished from cookie APIs
Given the CSRF section of `docs/SECURITY.md`
When the bearer-token note is read
Then the section contains `Authorization: Bearer`
And it states that a header-borne bearer token is not CSRF-susceptible
And it states that the bearer token must not be stored in a cookie
And it states that a pure bearer API does not need a CSRF token
