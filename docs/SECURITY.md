# Security Standards

## Authentication

### User Authentication

- JWT-based authentication with RSA-256 signed tokens.
- Token payload includes identity claims, roles, session ID, and channel.
- Access tokens have short expiry (configurable, default 15 min).
- Refresh tokens have long expiry (configurable, default 30 days), stored in Redis.
- Support multiple identity providers: custom JWT, Azure AD (JWKS validation), Keycloak.

### Inter-service Authentication

- Services communicate using service-to-service JWT tokens.
- Inter-service token management handles automatic token retrieval, caching, and refresh. Tokens are obtained from the auth service on startup and injected into outgoing requests via an HTTP interceptor.

### OAuth2

Support standard OAuth2 grant types:
- JWT Bearer grant.
- Client credentials grant.
- Refresh token grant.

## Authorization

- Role-Based Access Control (RBAC) using the `@RoleBasedAccessControl` annotation (Java) or middleware (Go).
- Roles and permissions are embedded in the JWT identity claim.
- Role checks happen at the service boundary, not in controllers.
- Admin endpoints require explicit admin role verification.

## Data Encryption

- **At rest**: Key management service (AWS KMS, HashiCorp Vault, Azure Key Vault) for key management. Service-specific data encryption keys wrapped by the master key.
- **In transit**: TLS 1.2+ for all HTTP traffic.
- **Field-level encryption**: Sensitive fields encrypted with AES-256/GCM using derived keys before storage.
- **Hashing**: User identifiers hashed with a domain-specific salt.

## Secrets Management

- **Never** commit secrets, credentials, API keys, or tokens to Git.
- **Small projects**: `.env` files are acceptable. Always add `.env` to `.gitignore`. No secrets manager required.
- **Larger projects / production**: Use a secrets manager (HashiCorp Vault, AWS SSM Parameter Store, Kubernetes Secrets). Environment variables reference secret store paths rather than containing raw values.
- Talisman pre-commit hook scans for accidental secret commits.

## Input Validation

- Validate all input at the controller boundary.
- Use argument resolvers (Java) or middleware (Go) for automatic validation and failure logging.
- Bean Validation (JSR-380) annotations on DTOs.
- String length, format, and range checks on all request parameters.
- Never trust or propagate user-supplied data without validation.

## Upstream Error Responses Must Not Reach the Client

A third-party API's raw error response is not automatically safe to forward. Provider APIs (payment processors, LLM providers, any upstream service authenticated with a credential of yours) can include partial key material, account identifiers, or internal details in their error bodies — a 401 from an upstream provider might echo back a masked or partial version of the credential you sent it. This is a distinct leak path from log redaction (docs/OBSERVABILITY.md's "mask secrets in logs" rule): the risk here is forwarding the error body itself to *your own client's browser/app*, not writing it to your own logs.

- Always log the full upstream error server-side (with normal secret-masking rules applied to your own logs).
- Return a generic, static error message to the caller — never `return c.JSON(502, gin.H{"error": upstreamErr.Error()})` or equivalent passthrough.
- This applies to any upstream call made with a credential the client doesn't already have: payment gateways, LLM providers, third-party auth, internal services called with a shared secret.

## Escape User Data in Outbound HTML

Any user-controlled value rendered into an outbound HTML surface — transactional email bodies,
PDF/report generation, admin notification panels, chat or webhook cards — must be HTML-escaped
at render time. These surfaces are usually read by operators, so injection here targets your
own inbox rather than a customer browser, and is easy to miss because it never touches the
public web app.

- Building a plaintext string and then converting it to HTML by replacing newlines with `<br>`
  is **not** escaping. The value is interpolated raw; only the line breaks changed.
- Build the text and HTML representations separately from the same per-field values, escaping
  each value for the HTML variant: replace `&` first, then `<`, `>`, `"`, `'`.
- Escape at every sink, not once at the boundary. A value stored safely can still be injected
  into a different sink later.

Permissive validators are the enabling condition. A common address pattern such as
`/^[^\s@]+@[^\s@]+\.[^\s@]+$/` accepts `<`, `>`, `"`, and `'`, so an address field can carry
markup and still pass validation. Use a conservative address pattern plus an explicit length
cap.

**Validation is not sanitisation.** A value that passed validation still needs escaping at
every sink it reaches.

## Internal and Machine-Facing Endpoints Fail Closed

An endpoint invoked only by an operator, a scheduled job, or another service is not protected
by obscurity. It requires an explicit credential check.

- When the credential is unconfigured, the endpoint **refuses** (503 or 500). It never falls
  through to open access — the misconfiguration must break the feature, not silently disable
  the guard.
- Compare shared secrets in constant time (`crypto.timingSafeEqual`, `hmac.Equal`,
  `MessageDigest.isEqual`), never with `==`.
- The auth check runs **before** body parsing and before any side-effecting or billable
  downstream call, so an unauthenticated caller cannot make you spend money or allocate memory.

| Condition | Behaviour |
|---|---|
| Credential configured and matches | Proceed |
| Credential configured and mismatches | 401/403 |
| Credential unconfigured | 503/500 — never proceed |

A machine-facing endpoint that accepts a quantity affecting money (minutes, units, amount)
must bound that quantity against an **independently recorded source of truth** — the recorded
duration, the stored order total — not merely a plausible range check. Trusting the caller
anywhere within an unbounded range is an authorization control, not a correctness control.

## Vulnerability Scanning

*ZAP is `production`-tier — see docs/CONFORMANCE_TIERS.md. The rest of this table applies at `mvp`.*

| Tool | What it scans | When |
|---|---|---|
| OWASP Dependency Check | Maven/Gradle dependency CVEs | CI (profile-activated) |
| SpotBugs + FindSecBugs | Java bytecode for security bugs | Every build |
| Talisman | Git history for secrets | Pre-commit |
| CodeQL | Source code SAST | CI (`.github/workflows/ci-security.yml`, every push) |
| Trivy | Filesystem dependency/CVE scan | CI (`.github/workflows/ci-security.yml`, every push) |
| ZAP | Running service DAST | Go services only, via `make docker-run-scan` (see `language-specific/go/SKILL.md`) |

Checkmarx, Bamboo, and Nancy are not used anywhere in this repo's CI — removed from this table (previously stale references).

## Dependency Management

- Pin all dependency versions in parent POM or `go.mod`. Never use version ranges.
- Review OWASP Dependency Check reports before upgrading.
- Use Dependabot or Renovate for automated dependency update PRs where available.
- Exclude unnecessary transitive dependencies to minimize attack surface.
