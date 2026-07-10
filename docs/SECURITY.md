# Security Standards

## Authentication

### User Authentication

- JWT-based authentication with RSA-256 signed tokens.
- Token payload includes identity claims, roles, session ID, and channel.
- Access tokens have short expiry (configurable, default 15 min).
- Refresh tokens have long expiry (configurable, default 30 days), stored in Redis.
- Support multiple identity providers: custom JWT, Azure AD (JWKS validation), Keycloak.

### Inter-service Authentication

- Services communicate using service-user JWT tokens.
- `ServiceUserAuthenticator` (Java) or `common_token_providers` (Go) handles automatic token management.
- Service tokens are obtained from the authentication service on startup and cached.
- Token is injected into outgoing HTTP requests via Feign interceptor or OkHttp interceptor.

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

- **At rest**: AWS KMS for key management. Service-specific data encryption keys wrapped by KMS.
- **In transit**: TLS 1.2+ for all HTTP traffic. Redis over TLS (stunnel).
- **Field-level encryption**: Sensitive fields encrypted with AES-256/GCM using KMS-derived keys before storage.
- **Hashing**: User identifiers hashed with document-type-specific pepper (via KMS).

## Secrets Management

- **Never** commit secrets, credentials, API keys, or tokens to Git.
- `PRIVATE-TOKEN` headers, database passwords, and JWT signing keys must come from AWS SSM Parameter Store.
- Environment variables should only reference parameter store paths, not contain raw values.
- `.env` files are for local development only and must be in `.gitignore`.
- Talisman pre-commit hook scans for accidental secret commits.

## Input Validation

- Validate all input at the controller boundary.
- Use argument resolvers (Java) or middleware (Go) for automatic validation and failure logging.
- Bean Validation (JSR-380) annotations on DTOs.
- String length, format, and range checks on all request parameters.
- Never trust or propagate user-supplied data without validation.

## Vulnerability Scanning

| Tool | What it scans | When |
|---|---|---|
| OWASP Dependency Check | Maven/Gradle dependency CVEs | CI (profile-activated) |
| SpotBugs + FindSecBugs | Java bytecode for security bugs | Every build |
| Nancy | Go dependency CVEs | CI |
| Talisman | Git history for secrets | Pre-commit |
| Checkmarx | Source code SAST | CI (Bamboo plan) |
| ZAP | Running service DAST | CI (scheduled) |

## Dependency Management

- Pin all dependency versions in parent POM or `go.mod`. Never use version ranges.
- Review OWASP Dependency Check reports before upgrading.
- Use Dependabot or Renovate for automated dependency update PRs where available.
- Exclude unnecessary transitive dependencies to minimize attack surface.
