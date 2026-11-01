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

## SSRF (Server-Side Request Forgery)

Any outbound request whose destination comes from a user or from an upstream response is an SSRF vector: the caller can point your server at itself, at another internal service, or at a cloud metadata endpoint that hands out credentials. Destination selection is therefore default-deny, not "block the hosts we thought of".

- **Default-deny destination allowlist.** Keep an allowlist of scheme + host + port that this service may call. A destination supplied by a user or derived from an upstream response must match the allowlist; an unmatched destination is refused before any connection is made. A denylist of known-bad hosts is not a substitute — it is bypassable by every address it forgot.
- **Check the resolved IP, not the hostname.** An allowlist match on a hostname proves nothing: the name can resolve to a private address. Resolve first, then validate the resolved IP against the allowlist and against the refused ranges below.
- **Refused ranges.** `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `fe80::/10`, the cloud metadata endpoint `169.254.169.254`, and the IPv6 equivalents `::1/128` and `fc00::/7`. Refuse these even when the allowlist would otherwise match — unless reaching one specific internal host is the service's whole purpose, in which case allowlist that single address explicitly.
- **Pin the validated address.** Connect to the IP address that was validated, not to the hostname again. Re-checking a re-resolved address is mandatory: a second resolution between the check and the connection is the **DNS rebinding** window. If the address changes, re-check the new one before use; a request that would need a new address is refused rather than retried against the name.
- **Do not follow redirects automatically.** An allowlisted URL can redirect to a refused one. Either disable automatic redirect following, or re-validate every redirect hop against the allowlist and the refused ranges before following it, and cap the hop count.
- Apply the same rule to webhook delivery, image/PDF fetchers, link previews, and any "fetch this URL for me" endpoint. The rule belongs in one shared outbound-request helper, not copy-pasted per caller.

## CSRF (Cross-Site Request Forgery)

CSRF is the browser being tricked into attaching your user's session cookie to a request the user never made. It exists only where the credential is ambient — attached by the browser automatically.

- **Cookie-authenticated state-changing requests need a CSRF token.** Any POST/PUT/PATCH/DELETE that mutates state and is authenticated by a cookie must carry a CSRF token the attacker's page cannot read (synchronizer token or double-submit, bound to the session). A state-changing request authenticated by a cookie without a valid token is rejected with `403`, before the handler runs. Safe methods such as `GET` and `HEAD` never mutate state — an endpoint that changes data on `GET` cannot be CSRF-protected and must be redesigned.
- **Session cookies carry a SameSite policy.** Set session cookies `SameSite=Lax` or `SameSite=Strict`. `SameSite=None` turns that protection off, so it is allowed only for a cookie that genuinely must cross-site, is not the session cookie, and always carries the `Secure` attribute. Session cookies also carry `Secure` and `HttpOnly`.
- **Validate `Origin`, fall back to `Referer`.** A state-changing request whose `Origin` header does not match an allowlist of your own origins is rejected. When no `Origin` header is present, validate `Referer` against the same allowlist; if neither header is present, reject. Compare as an exact origin, never a substring or suffix match.
- **Bearer-token APIs need no CSRF token.** A header-borne bearer token, sent in `Authorization: Bearer <token>`, is not CSRF-susceptible: it is attached by the caller's code rather than by the browser, so a cross-site form post cannot carry it: a pure bearer API does not need a CSRF token. Keep it that way — never store the bearer token in a cookie (that makes it ambient and re-introduces CSRF), and never accept the same token from either a cookie or a header on the same endpoint.
- Framework CSRF middleware counts only if it is enabled for the endpoint. A globally disabled filter is not protection.

## CORS (Cross-Origin Resource Sharing)

CORS is a browser relaxation mechanism, not a security boundary (see the last bullet). Misconfigured, it hands any website the ability to read your authenticated responses.

- **Never combine a wildcard with credentials.** `Access-Control-Allow-Origin: *` is never used on an endpoint that returns credentialed or authenticated data. `*` combined with `Access-Control-Allow-Credentials: true` is invalid per the Fetch standard — browsers reject such a response outright, so emitting both is both broken and an admission that the endpoint trusts everyone.
- **Echo an exact allowlist match, nothing else.** Configure allowed origins explicitly. When the request's `Origin` matches an allowlist entry exactly, echo that origin back in `Access-Control-Allow-Origin` and add `Vary: Origin` so a cache never serves one origin's response to another. An unmatched origin receives no CORS header at all. The request's `Origin` is never reflected unvalidated — reflection is equivalent to `*` with credentials, and a substring or suffix match is bypassable with `evil-example.com`.
- **Keep preflight responses minimal.** A preflight response allows only the methods the endpoint actually uses (no blanket `GET, POST, PUT, PATCH, DELETE, OPTIONS`) and only the headers the endpoint actually reads. A wildcard `Access-Control-Allow-Headers` is not combined with credentials; when credentials are allowed, list the headers explicitly. Keep `Access-Control-Expose-Headers` just as narrow, and `Access-Control-Max-Age` short enough that a policy change takes effect the same day.
- **CORS is not access control.** CORS does not protect against non-browser clients: curl, a server-side script, or a native app ignores it completely. Authorization is enforced server-side on every request, independently of any CORS decision. A request CORS "blocked" still reached your server, and its side effects already happened.

## Password Hashing

Passwords are verified with a deliberately slow, memory-hard password-hashing function. Nothing else.

- **Algorithm.** `Argon2id` is preferred; `bcrypt` is the accepted alternative where Argon2id is unavailable. A password is never stored in plaintext and never encrypted reversibly — "we can decrypt it for support" is not an exception.
- **Forbidden.** Fast general-purpose hashes are unacceptable for password storage: `MD5`, `SHA-1`, and `SHA-256` — plain, salted, iterated, or "with a pepper" — are all rejected for this use. They are designed to be fast, which is exactly the property an offline attacker wants, and a home-grown construction built from them inherits the same problem.
- **Minimum parameters.** bcrypt: a `cost` (work factor) of at least `12`, raised as hardware improves. Argon2id: at least `19 MiB` of memory, at least 2 `iterations`, and `parallelism` of at least 1 — the OWASP baseline; tune upward, never down. Store the algorithm and its parameters alongside the hash so verification knows what produced it.
- **Verification is constant-time.** Compare through the library's `constant-time` verify function (`argon2_verify`, `bcrypt.compare`, or the platform equivalent), never with `==` / `===`, and never with an early-return byte loop. Never re-hash the candidate with application code and compare digests yourself.
- **Rehash on login.** When a stored hash's algorithm or parameters are below the current baseline, `rehash` it during the next successful login — after the candidate is verified, never before — and do it transparently: the session stays valid and the user is not asked to log in again. A failed upgrade must not fail the login.

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

## CI/CD Supply Chain (spec 026)

A security review of this repo's own `.github/workflows/` and headless agent
invocations found and fixed several classes of issue. This section is the
standing rule set that keeps them fixed — every point below has a concrete
enforced example in this repo; treat a new workflow or agent invocation that
violates one of these as a regression, not a style preference.

### Pwn requests

A `workflow_run`-, `pull_request_target`-, or `issue_comment`-triggered
workflow always runs with the **base repository's** privileges (secrets, a
writable `GITHUB_TOKEN`) — including when the event it reacts to originated
from a fork. Checking out that event's head commit and then executing
anything from the checked-out tree (a script, a symlinked skill, a sourced
env file, `npm install`, a build step) hands an attacker-controlled commit
those privileges. This is the "pwn request" pattern GitHub's own security
docs and the tj-actions/changed-files and eigent-ai incidents are examples
of.

Rules:

- A `workflow_run`-triggered job must gate on the triggering run's origin
  (`github.event.workflow_run.head_repository.full_name == github.repository`)
  before doing anything privileged. A fork-originated run gets no automated
  reaction — a human triages it via the PR's own (unprivileged) checks.
  See `.github/workflows/ci-sweeper.yml`.
- Never pass `ref: <event-supplied SHA>` to `actions/checkout` in a
  privileged trigger context. Check out the workflow's own trusted ref (no
  `ref:` override, or an explicit `github.sha`/default-branch ref) and read
  anything about the untrusted commit through a read-only API (`gh run view
  --log-failed`, `gh pr diff`) instead of executing its tree.
- If a privileged workflow genuinely needs the untrusted tree (rare — e.g.
  building a preview), check it out in an unprivileged job with no secrets,
  never in the same job that holds them.

### Pin third-party Actions and reusable workflows to a commit SHA

`uses: owner/action@v4` and `uses: owner/action@master` both resolve a
mutable ref at the moment the job runs — the exact mechanism behind the
tj-actions/changed-files supply-chain compromise (a maintainer's compromised
account moved a tag to a malicious commit; every workflow pinned to that tag
picked it up immediately). Pin every third-party action to its full-length
commit SHA, with the version as a trailing comment for humans:

```yaml
uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.3.0
```

Cross-repository reusable workflows follow the same rule — pin
`RexiAI/my-engineering-standards/.github/workflows/<name>.yml` to a commit
SHA, bump deliberately, never track `@main`. This repo's own
consumer-facing workflows do this (`.github/workflows/pr-review.yml`,
`scripts/init-ci.sh`'s `STANDARDS_PIN`).

### Caller workflows must grant what a reusable workflow declares

A `workflow_call` workflow's `permissions:` block is a request, capped by its
caller: the callee's token is the callee's declaration intersected with the
calling workflow's `permissions:` block — and when the caller declares
nothing, the org/repo default `GITHUB_TOKEN` permissions apply. A callee that
requests more than the caller allows fails the **entire run at startup**
(`startup_failure`, no jobs, no logs) with an annotation like `The workflow
is requesting 'packages: write', but is only allowed 'packages: read'`. Since
the org default is commonly read-only, an explicit caller-side `permissions:`
block is mandatory, not hygiene. `scripts/init-ci.sh` emits one in every
generated child `ci.yml` (union of the wired callees); see
`docs/CI_CD.md §Reusable-workflow permissions` for the sizing table. When
hand-writing a caller, grant exactly the union of the callees' declared
permissions — least privilege, but never less than the callees need.

### Binaries fetched by a script must be checksum-verified

A workflow that `curl`s a release tarball and executes it (this repo's
pinned `opencode` binary, installed by `scripts/install-opencode.sh`) is
downloading and running a binary based on a version string alone. Pin a
SHA-256 alongside the version and verify with `sha256sum -c` before
extracting — a compromised release, a stale CDN cache, or a MITM window all
fail closed instead of silently executing.

### An agent's `permission` block must actually load at invocation time

An agent config's frontmatter (`agents/*.md`) — `mode`, `permission.edit`,
`permission.bash` — is only an enforced boundary if the invocation actually
passes through it. Concatenating an agent file's prose into a plain prompt
string (because its declared `mode` rejected `--agent <name>` from a
headless `opencode run`) strips the frontmatter before opencode ever parses
it: the `permission` block was true of the committed file and false of every
CI run. If an agent needs direct headless invocation, its `mode` must allow
that (`primary`, not `subagent`) so `--agent` — and the real permission
enforcement — is available. See `agents/pr-review.md` and
`.github/workflows/ci-pr-review.yml`.

### Treat model input as untrusted data (prompt injection)

Anything an agent reads that a third party wrote — a PR diff, a commit
message, a CI log line, an issue comment — is data, not an instruction from
the operator, however it is phrased. An agent's system prompt must say this
explicitly, but the prompt is a courtesy, not the boundary: the `permission`
block (previous section) is what actually stops an injected instruction from
having effect. Never let an agent's own prompt text be the only thing
standing between untrusted input and a write/push/merge/secret-disclosure
action. See `agents/pr-review.md §Untrusted content warning`.

### Bound automated-loop cost

An automation that reacts to an external trigger (a failing CI run, a
schedule) without an invocation ceiling can be driven into unbounded model
spend by anyone who can cause that trigger to fire — see
`.github/workflows/ci-sweeper.yml`'s budget-guard step and
`loop-budget.md`. Every `on: workflow_run` or `on: schedule` loop that
invokes a model gets an explicit per-window cap, checked before the model
is invoked, that skips cleanly (not a failure) when exceeded.

### Reusable-workflow inputs are not repo-owner-controlled

A `workflow_call` `inputs:` value comes from whoever calls the workflow — a
child repo's own workflow file, potentially years out of sync with this
one's expectations — and must be validated the same way any external input
would be before it is interpolated into a remote shell command (see
`.github/workflows/ci-deploy-ssh.yml`'s input-validation step). Prefer
mapping `${{ secrets.* }}` and `${{ inputs.* }}` into a step's `env:` block
and referencing them as shell variables over interpolating them directly
into a `run:` script body — this avoids both accidental shell injection via
special characters and secret values landing in a process's argv (visible
via `/proc` to co-resident processes on the runner).
