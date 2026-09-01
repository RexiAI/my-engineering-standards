# Coding Conventions

## Naming

| Element | Convention | Examples |
|---|---|---|
| Repository names | kebab-case | `authentication-service`, `nodepop-advanced` |
| Java packages | `com.<company>.<service>.<layer>` | `com.company.authservice.controller` |
| Go packages | `common_` prefix for shared code | `common_errors`, `common_services` |
| Classes / Types | PascalCase | `AuthenticationService`, `IdentityClaim` |
| Methods / Functions | camelCase | `getUserById()`, `hashPassword()` |
| Variables | camelCase | `userName`, `traceId` |
| Constants / Enums | UPPER_SNAKE_CASE | `CHANNEL_WEB`, `STATUS_SUCCESS` |
| Database columns | snake_case | `user_name`, `created_at` |
| JSON fields | camelCase | `"userName":`, `"createdAt":` |
| Environment variables | UPPER_SNAKE_CASE | `SERVICE_NAME`, `AWS_REGION` |

## File Organization

- **One class per file** (Java).
- **One React component per file** (TSX/JSX: ≤1 exported component; hooks/helpers co-located only if <20 lines and used by that single component) — barrel `index.ts` re-exports. **BookingWidget 14-in-1 (390 lines, 14 components in one file) is the anti-pattern.** `scripts/check-code-principles.sh` gate `component-per-file` enforces this (FAIL if >2 exported components, WARN if >1; FAIL if >4 exported functions in `.tsx`).
- **One component per directory** with barrel export `index.js` / `index.ts` (JS/TS) — the directory holds the single component file plus its co-located CSS module / test / stories.
- **Shared code** goes in `common_*` packages (Go) or `shared/` (JS).
- **Test files** mirror the source package structure.

## Design Principles

The principles below are the mechanical standards this repo enforces on code.
`scripts/check-code-principles.sh` audits them across Java, Go, and JS/TS; the
spec pipeline's Verifier stage runs it as an independent gate. A FAIL is a
defect; a WARN is a review hint to verify before merging.

### KISS — Keep It Simple, Stupid

- **Methods under 20 lines**, classes under 200 lines, files under 500 lines.
  Split by responsibility, not by arbitrary size limits.
- **≤6 parameters per method.** More means the method is doing too much — bundle
  the arguments into a request object or split the method.
- **Low nesting.** Deeply nested conditionals (>6 brace levels) are a smell;
  extract methods or return early.

### DRY — Don't Repeat Yourself

- Same shape repeated across files is structural duplication, not just literal
  copy-paste. Consolidate only when the duplication shares a **reason to
  change** — two pieces that merely look similar for unrelated reasons are not
  duplicates.
- `scripts/check-code-principles.sh` flags identical 4-line blocks appearing in
  2+ places. Verify the "same reason to change" rule before consolidating.

### YAGNI — You Aren't Gonna Need It

- **No interface for one implementation.** An abstraction with exactly one
  concrete implementation is premature; add the interface when a second
  implementation exists or is demonstrably imminent.
- No empty method bodies in production code, no config knobs for values that
  never change, no speculative generality.

### SOLID

- **S**ingle Responsibility — one reason to change per class; a god file (>400
  lines, >15 methods) is a sign to split.
- **O**pen/Closed — open for extension, closed for modification. Large
  `switch`/`if-else` chains that dispatch on a type discriminator (≥4 cases)
  should be polymorphic dispatch or a lookup instead.
- **L**iskov Substitution — subtypes must be substitutable for their base
  without breaking callers. Heavy `instanceof`/type-test dispatch (≥3 in one
  file) usually means substitutability is broken.
- **I**nterface Segregation — clients shouldn't depend on methods they don't
  use. Split fat interfaces (>5 methods) by role.
- **D**ependency Inversion — depend on abstractions, and point dependencies
  inward. Domain/engine code must never import infrastructure (store,
  repository, persistence, DB clients). See `docs/ARCHITECTURE.md`.

### Base rules

- **Prefer composition over inheritance.** Use interfaces and delegation instead of abstract base classes. For tests, use plain `@BeforeEach` + helper methods instead of `AbstractBaseTestSuite` base classes.
- **Keep things small.** Classes under 200 lines, methods under 20 lines, files under 500 lines. Split by responsibility, not by arbitrary size limits. For TSX/JSX, `scripts/check-code-principles.sh` `component-per-file` gate enforces tighter bounds: **FAIL if >2 exported components per file (WARN if >1), FAIL if >4 total exported functions in `.tsx`, and FAIL if >300 lines or >8 components (god-file)** — BookingWidget 14-in-1 is the canonical violation.
- **Cyclomatic complexity ≤6 per method/function.** Enforced via PMD `CyclomaticComplexity`/`CognitiveComplexity` (Java), golangci `cyclop`/`gocognit` (Go), ESLint `complexity` (JS/TS) — see `language-specific/<lang>/`. Extract methods, invert conditionals, or replace nested branching with early returns rather than raise the threshold. `scripts/check-code-principles.sh` applies the same threshold as a language-agnostic heuristic.
- **Dependency rule.** Source code dependencies must point inward. Domain code never depends on infrastructure code. Controllers depend on services, services on repositories, never the reverse.
- **Generalize, don't special-case.** One mechanism should handle all similar cases. Avoid if/else chains that check exception types — use polymorphic dispatch or Result pattern matching.
- **Design interfaces to be deep.** A module's interface should be much simpler than its implementation. If a method just delegates with the same signature, it's a pass-through — remove it.
- **First do no harm with dependencies.** Each external dependency adds cognitive load and attack surface. Prefer stdlib, justify each dependency. Audit quarterly (see SECURITY.md).
- **Comment the why, not the what.** Code shows what a line does; a comment earns its place by explaining why it's not the obvious version — the incident it fixes, the second-order effect it avoids, the constraint that isn't visible in the diff. A one-line workaround with a multi-line comment explaining the trap it dodges is normal and correct; a comment restating the code below it is noise. If a line looks wrong at a glance but is intentional, that's exactly the line that needs the comment.

## Error Handling Philosophy

Prefer domain Result types for expected failure modes. Reserve exceptions for truly exceptional conditions (infrastructure failure, programming errors).

### Result Type Pattern

```java
// Expected failures are return values, not control flow
public sealed interface Result<T, E> {
    record Ok<T, E>(T value) implements Result<T, E> {}
    record Error<T, E>(E error) implements Result<T, E> {}
}

public enum CreateUserError {
    EMAIL_TAKEN,
    INVALID_EMAIL,
}
```

```go
// Go: Use Result[T, E] or (T, error) where error is a domain type
type CreateUserResult struct {
    User *User
    Err  *CreateUserError
}

type CreateUserError string
const (
    ErrEmailTaken    CreateUserError = "EMAIL_TAKEN"
    ErrInvalidEmail  CreateUserError = "INVALID_EMAIL"
)
```

```ts
// TypeScript: discriminated union
type CreateUserResult =
    | { ok: true; user: User }
    | { ok: false; error: CreateUserError }
```

### When to Use Which

| Scenario | Use |
|----------|-----|
| Caller expects this failure (validation, not found, conflict) | Result type |
| Infrastructure failure (DB down, network timeout) | Exception → circuit breaker |
| Programming error (null pointer, illegal argument) | Exception → fix the code |
| Expected retry scenario (rate limit, conflict) | Result type + retry |

## Formatting

### Java
- Google Java Format via Spotless Maven Plugin.
- 4-space indentation.
- 100-character line width.
- No trailing whitespace.
- One blank line between import groups (static, java, javax, org, com).

### Go
- `gofmt` standard formatting enforced by `golangci-lint`.
- Tab indentation.
- No unused imports or variables.

### JavaScript / TypeScript
- Prettier formatting with:
  - Single quotes.
  - Trailing commas (es5).
  - 100-character line width.
  - 2-space indentation.
- ESLint enforces: `prefer-const` (error), `complexity ≤6` (error), `import/order` (warn, groups: builtin → external → internal → parent → sibling → index, alphabetized), `no-explicit-any` (error — use `unknown` + narrowing), `use-unknown-in-catch-callback-variable` (error, preserve caught error cause).

### TypeScript — Clean Code

- **No `any`.** Use `unknown` and narrow with type guards / `zod` / `instanceof`. `any` disables the type checker — it is not a shortcut. If an external API is untyped, wrap it in a typed adapter that returns `unknown` at the boundary.
- **`prefer-const` (error).** Never use `let` when the binding is not reassigned. ESLint `prefer-const` is enforced.
- **Complexity ≤6 per function.** Same gate as `Base rules` — ESLint `complexity: [error, 6]`. Extract helpers, early-return, replace nested branching with lookup/polymorphism. Verifier (`spec-verifier`) re-checks this; `scripts/check-code-principles.sh` applies the same heuristic language-agnostically.
- **Preserve caught error cause.** When re-throwing, use `throw new AppError(msg, { cause })` (ES2022 cause) or include the original error in the Result. ESLint `@typescript-eslint/use-unknown-in-catch-callback-variable` enforces `unknown` in `catch (e)` — narrow before use. Never `catch (e) { throw new Error('failed') }` that discards the stack/cause.
- **Explicit boundaries over implicit.** Public/exported function return types should be explicit when the inferred type is non-trivial (generic, union, Promise). Internal helpers may rely on inference.
- **Import order.** Enforced by `eslint-plugin-import` (`import/order`). Keep imports sorted and grouped; no duplicate imports (`import/no-duplicates: error`).
- **No magic numbers / duplicated literals.** Extract shared numeric/string literals to named constants or design tokens. Duplicated 4-line blocks trigger `check-code-principles.sh` DRY gate.

### HTML / TSX — Clean Code

- **No inline `style` prop (`style={{...}}`).** All visual styling lives in CSS classes / CSS Modules / design-token variables. Inline objects are unordered, un-lintable, duplicated, and bypass the token system. The spec/001 fix (68 inline objects → CSS classes) is the canonical example. ESLint `react/no-inline-style` or equivalent custom rule should warn/error on `style=` in TSX.
- **Semantic markup.** Use `<header>`, `<nav>`, `<main>`, `<section>`, `<article>`, `<aside>`, `<footer>`, `<button>`, `<a>` for their meaning — not `<div>` soup. Headings form a single ordered hierarchy (`h1` → `h2` → `h3`).
- **Accessibility (a11y).** Every interactive element is keyboard-reachable, has an accessible name (`aria-label` or visible text), images have `alt`, forms have associated `<label>`. Lint with `eslint-plugin-jsx-a11y` (`jsx-a11y/*`) at warn minimum.
- **Tokens, not literals.** Colors, spacing, radii, shadows, font sizes/weights come from CSS variables / design tokens (`--color-*`, `--space-*`, `--radius-*`), never hard-coded hex/px scattered through TSX or CSS.
- **Class naming.** BEM (`block__element--modifier`) or CSS Modules (`Component.module.css`) — one convention per repo, enforced at review. No global single-word classes that collide.

### CSS — Clean Code

- **Property order.** Within each rule, order groups as: **Layout** (display, position, top/right/bottom/left, z-index, flex/grid) → **Box model** (width/height, margin, padding, border, box-sizing) → **Typography** (font-*, line-height, text-*, color) → **Visual** (background, opacity, box-shadow, filter) → **Animation** (transform, transition, animation). Enforce with `stylelint-order` (`order/properties-order`) or Prettier + review. Ordered properties reduce merge conflicts and make diffs scannable.
- **Design tokens via CSS variables.** Define tokens once in `styles/tokens.css` or `globals.css` (`:root { --color-primary: ...; --space-md: ... }`) and reference with `var(--token)`. No duplicated hex/rgba/px values across files — duplication is a DRY violation flagged by `check-code-principles.sh`.
- **No magic numbers.** Bare `16px`, `#2563eb`, `0.5rem` outside a token definition is a review finding. Promote repeated values to a token; one-off values get a comment explaining why they are not tokenized.
- **BEM or CSS Modules, not ad-hoc globals.** Choose one: BEM for plain CSS, CSS Modules / Tailwind utility composition for component-scoped styles. Mixing conventions in one repo requires an ADR.
- **No dead / duplicated rules.** Identical 4-line CSS blocks across files trigger the DRY gate. Extract to a shared class or token. Remove unused selectors before merge (stylelint `no-duplicate-selectors`, `block-no-empty`).

### Currency and Quantity Formatting

- **Store and compute money in the smallest currency unit** (integer minor units — cents, pence, sen). Never a float, never a decimal string parsed back into a float.
- **Render the full precision of the currency when formatting for display or notification.** The number of decimals is a property of the currency, not a formatting preference: 2 for EUR/USD/GBP, 0 for JPY/KRW, 3 for BHD/KWD. `toFixed(0)` on a euro amount silently misreports a real charge.
- **Never round a monetary value for display.** A rounded figure in an email, invoice, or dashboard contradicts the amount actually captured, and the discrepancy surfaces as a support ticket rather than a test failure.
- **Derive unit labels from the same configuration source as the value.** Where a label accompanies a configurable value — timezone, currency code, locale — the label must come from that same config. A hardcoded label beside a config-driven value produces output that contradicts itself the moment the knob changes.

| Currency | Minor units | Displayed as |
|---|---|---|
| EUR / USD / GBP | 100 | `12.34` |
| JPY / KRW | 1 | `1234` |
| BHD / KWD | 1000 | `12.345` |

## Logging

### Java
- Use SLF4J with `@Slf4j` Lombok annotation.
- Log at method boundaries: input parameters and results. Use a `HandlerInterceptor` or filter for cross-cutting request logging instead of an AOP-based event framework.
- Trace ID in MDC. Propagate via `traceparent` header (W3C Trace Context).
- Log messages are capped at 1024 characters.
- Never log PII, secrets, or tokens.

### Go
- Use the stdlib `log/slog` package for structured logging: `slog.Info("message", "key", "value")`. This supersedes any previous zerolog guidance — `slog` has been in the stdlib since Go 1.21, so it's the "prefer stdlib" default from §Design Principles rather than an added dependency. `zerolog` remains an acceptable choice for a project that already standardized on it; don't migrate a working project just to match this doc.
- Trace ID propagated via `context.Context`.
- Log at service method boundaries. Log input parameters and results.

### JavaScript
- Use structured logging library (pino, winston).
- Include trace ID in every log entry.
- Avoid `console.log` in production code.

## Exception Handling

### Philosophy

Exceptions are for exceptional conditions only. Expected failures — validation errors, resource not found, duplicate key — are return values via Result types, not exceptions.

Exceptions map to Result.Error values at the service boundary. The controller translates the error value into the appropriate HTTP response.

### Java

Reserve exceptions for truly exceptional conditions. Expected failures use a closed Result type:

```java
// Service returns result, not exception
public Result<User, CreateUserError> createUser(CreateUserRequest request) {
    if (emailExists(request.email())) return Result.error(CreateUserError.EMAIL_TAKEN);
    return Result.ok(repository.save(request.toUser()));
}

// Controller maps result to HTTP response
@PostMapping("/v1/users")
public ResponseEntity<?> createUser(@Valid @RequestBody CreateUserRequest request) {
    return switch (userService.createUser(request)) {
        case Result.Ok(var user) -> ResponseEntity.status(201).body(user);
        case Result.Error(var err) -> switch (err) {
            case EMAIL_TAKEN -> ResponseEntity.status(409).body(Map.of("error", "email taken"));
            case INVALID_EMAIL -> ResponseEntity.status(422).body(Map.of("error", "invalid email"));
        };
    };
}
```

The `@ControllerAdvice` catches only truly exceptional conditions (infrastructure failures, programming errors) and returns uniform JSON. Not used for expected business logic failures.

### Go

Define `ApplicationError` interface with `StatusCode()` and `Error() string`. Use a custom HTTP error handler middleware that converts errors to JSON responses. Prefer sentinel errors for expected failures:

```go
var (
    ErrEmailTaken   = errors.New("email taken")
    ErrInvalidEmail = errors.New("invalid email")
)
```

### JavaScript

Use NestJS global exception filter with custom exception classes extending `HttpException`. For expected failures, use Result types rather than throwing. Single `@Catch()` filter catches only truly exceptional conditions.

## Imports Ordering

### Java
```
// static imports
// java.*
// javax.*
// org.*
// com.*
// Blank line between groups
```

### Go
Standard Go imports: stdlib first, third-party, local, blank line between groups.

### JavaScript
Organized imports: `react`/framework → libraries → local modules → styles.

## CI Job Orchestration — Clean Feedback

CI jobs must run in parallel and report independently. A lint failure must never hide build or test results.

- **No `needs: [lint]` gating `build` or `test`.** `lint`, `unit-test`, and `build` run with no inter-dependencies (or only `needs` that are truly required, e.g. `docker` needs `build`). Each job validates independently.
- **If gating is unavoidable, use an aggregator.** Add a final `ci-success` job with `needs: [lint, unit-test, build]` and `if: always()` that checks all results — this is the branch-protection required check, not the individual jobs.
- **Anti-pattern (from spec/001):** `build: needs: [lint, unit-test]` causes Build to show SKIPPED on lint failure — reviewer sees no build signal. Fixed by removing the `needs` line so all three jobs post their own pass/fail.
- **Canonical example:** `.standards/.github/workflows/ci-react.yml` — `unit-test`, `lint`, `build` have no `needs` between them; `docker` alone has `needs: [build]`.
