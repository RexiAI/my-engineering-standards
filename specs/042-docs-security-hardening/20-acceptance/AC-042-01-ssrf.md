# AC-042-01: SSRF guidance in `docs/SECURITY.md`

## AC-042-01-01 — Section exists and requires a default-deny destination allowlist
Given `docs/SECURITY.md`
When the SSRF section is read
Then the file contains the heading `## SSRF (Server-Side Request Forgery)`
And the section contains the word `allowlist`
And it states that a destination supplied by a user or an upstream response must match the allowlist
And it states that an unmatched destination is refused

## AC-042-01-02 — Loopback, private, link-local, and metadata ranges are refused
Given the SSRF section of `docs/SECURITY.md`
When its list of refused destinations is read
Then it contains `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, and `fe80::/10`
And it contains the metadata endpoint `169.254.169.254`
And it states that the check is applied to the resolved IP, not to the hostname

## AC-042-01-03 — DNS rebinding cannot bypass the check
Given the SSRF section of `docs/SECURITY.md`
When the resolution rule is read
Then the section contains the literal phrase `DNS rebinding`
And it requires the address that was validated to be the address that is connected to
And it requires a re-resolved address to be re-checked before use

## AC-042-01-04 — Redirects are not followed blindly
Given the SSRF section of `docs/SECURITY.md`
When the redirect rule is read
Then the section contains the word `redirect`
And it states that redirects are not followed automatically, or that every hop is re-validated against the allowlist
