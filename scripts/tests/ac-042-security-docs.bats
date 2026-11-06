#!/usr/bin/env bats
# Spec 042 — docs/SECURITY.md hardening sections.
# One test per acceptance scenario in
# specs/042-docs-security-hardening/20-acceptance/AC-042-01…05.
#
# Content assertions are grep-based against the real document: the contract is
# that the section exists and states the rule, so the test greps the section
# body (from its heading to the next '## ' heading), not the whole file.

load test_helper

SECURITY_MD="${REPO_ROOT}/docs/SECURITY.md"

# assert_section_has <file> <heading> <literal> — the section must state the
# rule literally; md_section (test_helper) bounds the search to that section.
assert_section_has() {
  local sec
  sec="$(md_section "$1" "$2")"
  if [ -z "$sec" ]; then
    echo "section not found in $1: $2" >&2
    return 1
  fi
  if [[ "$sec" != *"$3"* ]]; then
    echo "section '$2' in $1 does not contain: $3" >&2
    return 1
  fi
}

# heading_line <file> <heading> — 1-based line number of an exact '## ' heading.
heading_line() {
  grep -nxF -- "$2" "$1" | head -1 | cut -d: -f1
}

# ── AC-042-01 — SSRF ──────────────────────────────────────────────────────────

@test "AC-042-01-01: SSRF section requires a default-deny destination allowlist" {
  run grep -cxF -- '## SSRF (Server-Side Request Forgery)' "$SECURITY_MD"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  assert_section_has "$SECURITY_MD" '## SSRF (Server-Side Request Forgery)' 'allowlist'
  assert_section_has "$SECURITY_MD" '## SSRF (Server-Side Request Forgery)' \
    'destination supplied by a user or derived from an upstream response must match the allowlist'
  assert_section_has "$SECURITY_MD" '## SSRF (Server-Side Request Forgery)' \
    'an unmatched destination is refused'
}

@test "AC-042-01-02: loopback, private, link-local, and metadata ranges are refused" {
  local h='## SSRF (Server-Side Request Forgery)' range
  for range in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 'fe80::/10' 169.254.169.254; do
    assert_section_has "$SECURITY_MD" "$h" "$range"
  done
  assert_section_has "$SECURITY_MD" "$h" 'Check the resolved IP, not the hostname'
}

@test "AC-042-01-03: DNS rebinding cannot bypass the check" {
  local h='## SSRF (Server-Side Request Forgery)'
  assert_section_has "$SECURITY_MD" "$h" 'DNS rebinding'
  assert_section_has "$SECURITY_MD" "$h" 'Connect to the IP address that was validated'
  assert_section_has "$SECURITY_MD" "$h" 'Re-checking a re-resolved address is mandatory'
}

@test "AC-042-01-04: redirects are not followed blindly" {
  local h='## SSRF (Server-Side Request Forgery)'
  assert_section_has "$SECURITY_MD" "$h" 'redirect'
  assert_section_has "$SECURITY_MD" "$h" 'Do not follow redirects automatically'
  assert_section_has "$SECURITY_MD" "$h" 're-validate every'
}

# ── AC-042-02 — CSRF ──────────────────────────────────────────────────────────

@test "AC-042-02-01: cookie-authenticated state changes require a CSRF token" {
  local h='## CSRF (Cross-Site Request Forgery)'
  run grep -cxF -- "$h" "$SECURITY_MD"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  assert_section_has "$SECURITY_MD" "$h" 'state-changing'
  assert_section_has "$SECURITY_MD" "$h" 'CSRF token'
  assert_section_has "$SECURITY_MD" "$h" 'without a valid token is rejected'
  assert_section_has "$SECURITY_MD" "$h" 'GET` and `HEAD` never mutate state'
}

@test "AC-042-02-02: session cookies carry a SameSite policy" {
  local h='## CSRF (Cross-Site Request Forgery)'
  assert_section_has "$SECURITY_MD" "$h" 'SameSite=Lax'
  assert_section_has "$SECURITY_MD" "$h" 'SameSite=Strict'
  assert_section_has "$SECURITY_MD" "$h" 'SameSite=None'
  assert_section_has "$SECURITY_MD" "$h" 'always carries the `Secure` attribute'
}

@test "AC-042-02-03: Origin or Referer is checked against an allowlist" {
  local h='## CSRF (Cross-Site Request Forgery)'
  assert_section_has "$SECURITY_MD" "$h" '`Origin`'
  assert_section_has "$SECURITY_MD" "$h" '`Referer`'
  assert_section_has "$SECURITY_MD" "$h" 'does not match an allowlist of your own origins is rejected'
  assert_section_has "$SECURITY_MD" "$h" 'When no `Origin` header is present, validate `Referer`'
}

@test "AC-042-02-04: bearer-token APIs are distinguished from cookie APIs" {
  local h='## CSRF (Cross-Site Request Forgery)'
  assert_section_has "$SECURITY_MD" "$h" 'Authorization: Bearer'
  assert_section_has "$SECURITY_MD" "$h" 'is not CSRF-susceptible'
  assert_section_has "$SECURITY_MD" "$h" 'never store the bearer token in a cookie'
  assert_section_has "$SECURITY_MD" "$h" 'does not need a CSRF token'
}

# ── AC-042-03 — CORS ──────────────────────────────────────────────────────────

@test "AC-042-03-01: wildcard origin is never combined with credentials" {
  local h='## CORS (Cross-Origin Resource Sharing)'
  run grep -cxF -- "$h" "$SECURITY_MD"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  assert_section_has "$SECURITY_MD" "$h" 'Access-Control-Allow-Origin'
  assert_section_has "$SECURITY_MD" "$h" 'Access-Control-Allow-Credentials'
  assert_section_has "$SECURITY_MD" "$h" 'is never used on an endpoint that returns credentialed or authenticated data'
  assert_section_has "$SECURITY_MD" "$h" 'combined with `Access-Control-Allow-Credentials: true` is invalid'
}

@test "AC-042-03-02: origins come from an exact allowlist, never reflection" {
  local h='## CORS (Cross-Origin Resource Sharing)'
  assert_section_has "$SECURITY_MD" "$h" 'allowlist'
  assert_section_has "$SECURITY_MD" "$h" 'An unmatched origin receives no CORS header at all'
  assert_section_has "$SECURITY_MD" "$h" 'never reflected unvalidated'
  assert_section_has "$SECURITY_MD" "$h" 'Vary: Origin'
}

@test "AC-042-03-03: preflight responses are minimal" {
  local h='## CORS (Cross-Origin Resource Sharing)'
  assert_section_has "$SECURITY_MD" "$h" 'only the methods the endpoint actually uses'
  assert_section_has "$SECURITY_MD" "$h" 'only the headers the endpoint actually reads'
  assert_section_has "$SECURITY_MD" "$h" 'wildcard `Access-Control-Allow-Headers` is not combined with credentials'
}

@test "AC-042-03-04: CORS is not treated as access control" {
  local h='## CORS (Cross-Origin Resource Sharing)'
  assert_section_has "$SECURITY_MD" "$h" 'not access control'
  assert_section_has "$SECURITY_MD" "$h" 'does not protect against non-browser clients'
  assert_section_has "$SECURITY_MD" "$h" 'Authorization is enforced server-side'
}

# ── AC-042-04 — password hashing ──────────────────────────────────────────────

@test "AC-042-04-01: only a password-hashing algorithm is used" {
  local h='## Password Hashing'
  run grep -cxF -- "$h" "$SECURITY_MD"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  assert_section_has "$SECURITY_MD" "$h" 'Argon2id'
  assert_section_has "$SECURITY_MD" "$h" 'bcrypt'
  assert_section_has "$SECURITY_MD" "$h" '`Argon2id` is preferred'
  assert_section_has "$SECURITY_MD" "$h" '`bcrypt` is the accepted alternative'
  assert_section_has "$SECURITY_MD" "$h" 'never stored in plaintext and never encrypted reversibly'
}

@test "AC-042-04-02: fast general-purpose hashes are forbidden" {
  local h='## Password Hashing'
  assert_section_has "$SECURITY_MD" "$h" 'MD5'
  assert_section_has "$SECURITY_MD" "$h" 'SHA-1'
  assert_section_has "$SECURITY_MD" "$h" 'SHA-256'
  assert_section_has "$SECURITY_MD" "$h" 'are all rejected for this use'
}

@test "AC-042-04-03: work factors are recorded as minimums" {
  local h='## Password Hashing'
  assert_section_has "$SECURITY_MD" "$h" '`cost` (work factor) of at least `12`'
  assert_section_has "$SECURITY_MD" "$h" '`19 MiB` of memory'
  assert_section_has "$SECURITY_MD" "$h" 'at least 2 `iterations`'
  assert_section_has "$SECURITY_MD" "$h" '`parallelism` of at least 1'
}

@test "AC-042-04-04: verification is constant-time and hashes are upgraded" {
  local h='## Password Hashing'
  assert_section_has "$SECURITY_MD" "$h" '`constant-time`'
  assert_section_has "$SECURITY_MD" "$h" 'never with `==`'
  assert_section_has "$SECURITY_MD" "$h" '`rehash` it during the next successful login'
  assert_section_has "$SECURITY_MD" "$h" 'the session stays valid'
}

# ── AC-042-05 — JWT checklist ────────────────────────────────────────────────

@test "AC-042-05-01: the section is a checklist with one line per check" {
  local h='## JWT Validation Checklist' sec count
  sec="$(md_section "$SECURITY_MD" "$h")"
  [ -n "$sec" ]
  count="$(printf '%s\n' "$sec" | grep -c '^- \[ \] ')"
  [ "$count" -ge 5 ]
  # Every checklist item ends in the same disposition: reject the token.
  local items item
  items="$(printf '%s\n' "$sec" | grep '^- \[ \] ')"
  while IFS= read -r item; do
    [[ "$item" == *"reject"* || "$item" == *"rejected"* || "$item" == *"rejection"* ]]
  done <<< "$items"
}

@test "AC-042-05-02: algorithm allowlist, and alg=none is rejected" {
  local h='## JWT Validation Checklist'
  assert_section_has "$SECURITY_MD" "$h" 'Algorithm allowlist'
  assert_section_has "$SECURITY_MD" "$h" 'accepted `alg` values are fixed in configuration'
  assert_section_has "$SECURITY_MD" "$h" 'never itself the source of trust'
  assert_section_has "$SECURITY_MD" "$h" 'Reject alg=none'
  assert_section_has "$SECURITY_MD" "$h" 'rejected before signature verification'
}

@test "AC-042-05-03: key selection is bound to a trusted JWKS" {
  local h='## JWT Validation Checklist'
  assert_section_has "$SECURITY_MD" "$h" 'Key selection by kid'
  assert_section_has "$SECURITY_MD" "$h" 'configured, trusted JWKS'
  assert_section_has "$SECURITY_MD" "$h" '`jku` and `x5u` are never fetched'
  assert_section_has "$SECURITY_MD" "$h" 'never supplies its own key'
}

@test "AC-042-05-04: signature is verified first, then time claims" {
  local h='## JWT Validation Checklist'
  assert_section_has "$SECURITY_MD" "$h" 'Signature before claims'
  assert_section_has "$SECURITY_MD" "$h" 'no claim'
  assert_section_has "$SECURITY_MD" "$h" 'is read before the signature verifies'
  assert_section_has "$SECURITY_MD" "$h" 'Time claims (exp, nbf, iat)'
  assert_section_has "$SECURITY_MD" "$h" '`exp` is required'
  assert_section_has "$SECURITY_MD" "$h" 'bounded clock skew'
}

@test "AC-042-05-05: audience and issuer are validated; the section closes the block" {
  local h='## JWT Validation Checklist'
  assert_section_has "$SECURITY_MD" "$h" 'Audience and issuer (aud, iss)'
  assert_section_has "$SECURITY_MD" "$h" 'validated against expected values'
  assert_section_has "$SECURITY_MD" "$h" 'mismatched `aud` or `iss` is a rejection'

  local jwt_line input_line own_line
  jwt_line="$(heading_line "$SECURITY_MD" "$h")"
  input_line="$(heading_line "$SECURITY_MD" '## Input Validation')"
  own_line="$(heading_line "$SECURITY_MD" '## Upstream Error Responses Must Not Reach the Client')"
  [ -n "$jwt_line" ]
  [ "$jwt_line" -gt "$input_line" ]
  [ "$jwt_line" -lt "$own_line" ]

  local other other_line
  for other in '## SSRF (Server-Side Request Forgery)' '## CSRF (Cross-Site Request Forgery)' \
               '## CORS (Cross-Origin Resource Sharing)' '## Password Hashing'; do
    other_line="$(heading_line "$SECURITY_MD" "$other")"
    [ -n "$other_line" ]
    [ "$jwt_line" -gt "$other_line" ]
  done
}

# ── Gate coverage (each AC-042-01…05 criterion requires it still exits 0) ────

@test "security docs: the security-hardening gate still passes" {
  run bash "$REPO_ROOT/scripts/check-security-hardening.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Security hardening check: every check passed"* ]]
}
