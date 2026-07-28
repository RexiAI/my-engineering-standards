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

## Vulnerability Scanning

*ZAP is `production`-tier — see docs/CONFORMANCE_TIERS.md. The rest of this table applies at `mvp`.*

| Tool | What it scans | When |
|---|---|---|
| OWASP Dependency Check | Maven/Gradle dependency CVEs | CI (profile-activated) |
| SpotBugs + FindSecBugs | Java bytecode for security bugs | Every build |
| Talisman | Git history for secrets | Pre-commit |
| CodeQL | Source code SAST | CI (`.github/workflows/shared/ci-security.yml`, every push) |
| Trivy | Filesystem dependency/CVE scan | CI (`.github/workflows/shared/ci-security.yml`, every push) |
| ZAP | Running service DAST | Go services only, via `make docker-run-scan` (see `language-specific/go/AGENTS.md`) |

Checkmarx, Bamboo, and Nancy are not used anywhere in this repo's CI — removed from this table (previously stale references).

## Dependency Management

- Pin all dependency versions in parent POM or `go.mod`. Never use version ranges.
- Review OWASP Dependency Check reports before upgrading.
- Use Dependabot or Renovate for automated dependency update PRs where available.
- Exclude unnecessary transitive dependencies to minimize attack surface.
