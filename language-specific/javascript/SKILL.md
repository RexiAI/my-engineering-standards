---
name: javascript
description: JavaScript / TypeScript standards: project shape (Node 22+, npm, React/Vite or Next.js, NestJS backend), lint/format/test commands, and pointers to PATTERNS.md / TESTING.md. Use whenever a child repo uses JavaScript or TypeScript.
license: See repo root
applyTo: "**/package.json, **/*.{ts,tsx,js,jsx}"
---

# JavaScript / TypeScript Standards

Entry point for the JavaScript / TypeScript stack. Repo-wide rules
(conventional commits, layered testing, secrets handling) are
inherited from the root `AGENTS.md` and are not restated here.

## Build System

- **Runtime**: Node.js 22+.
- **Package manager**: npm.
- **Frontend**: React 17+ (Vite) or Next.js 15+ (App Router, public web).
- **Backend**: NestJS with TypeORM or Prisma (SQL).

## Commands

| Command | What it does |
|---|---|
| `npm run dev` | Start dev server (Next.js: next dev, React: vite, NestJS: nest start) |
| `npm run build` | Production build |
| `npm start` | Start production server (Next.js: next start) |
| `npm test` | Run test suite |
| `npm run lint` | Run ESLint |
| `npm run format` | Run Prettier |

## Project Structure

### NestJS Backend

```
src/
├── main.ts                  # Entry point (NestFactory.create)
├── app.module.ts            # Root module imports
├── common/                  # Shared guards, filters, pipes, interceptors
│   ├── guards/
│   ├── filters/
│   ├── pipes/
│   └── interceptors/
├── modules/                 # Feature modules
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── dto/             # class-validator DTOs
│   │   └── strategies/      # Passport strategies
│   ├── users/
│   │   ├── users.module.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── entities/        # TypeORM entities / Prisma schema
│   │   └── dto/
│   └── ...
├── database/                # Migrations, seeds, data sources
├── config/                  # Configuration modules (env, validation)
└── test/                    # E2E test files
```

### React Frontend

```
src/
├── api/
│   ├── client.js            # Axios instance + interceptors
│   ├── auth.js              # Auth API functions
│   ├── adverts.js           # Domain API functions
│   └── index.js             # Barrel export
├── components/
│   ├── auth/
│   │   ├── LoginPage/
│   │   │   ├── LoginPage.js
│   │   │   └── index.js     # export { default } from './LoginPage'
│   │   └── index.js         # Barrel export
│   ├── adverts/
│   │   ├── AdvertsPage/
│   │   │   ├── Advert.js
│   │   │   ├── AdvertsPage.js
│   │   │   └── index.js
│   │   └── index.js
│   └── shared/              # Reusable UI components
├── hooks/
│   └── useForm.js           # Form state + validation hook
├── store/                   # Redux store (if using Redux)
│   ├── index.js             # configureStore
│   ├── actions.js           # Action creators + thunks
│   ├── reducers.js          # Reducers
│   ├── selectors.js         # Selectors
│   └── types.js             # Action type constants
├── utils/
│   ├── storage.js           # localStorage helpers
│   └── utils.js             # General utilities
├── styles/                  # Global CSS
├── translations/            # i18n config and locale files
├── App.js                   # Root component
└── index.js                 # Entry point
```

## Linting & Formatting

- **ESLint**: Extends from shared config (see `eslint.config.js` in this standards repo).
- **Prettier**: Enforced formatting with pre-configured shared config (see `prettier.config.js`).

Run linting: `npm run lint`
Run formatter: `npm run format`

## Frontend Clean Code — TypeScript, HTML/TSX, CSS

Authoritative rules live in `docs/CODING_CONVENTIONS.md §Formatting / TypeScript / HTML-TSX / CSS`. This section summarizes them for the JS/TS stack.

**TypeScript**
- No `any` — use `unknown` + narrowing. ESLint `@typescript-eslint/no-explicit-any: error` (was `warn` pre-spec/001; tighten to `error` when 136 legacy warnings are cleared).
- `prefer-const: error`, `complexity: [error, 6]`, `import/order: warn` (builtin → external → internal → parent → sibling → index), `use-unknown-in-catch-callback-variable: error` (preserve error cause via `{ cause }`).

**HTML / TSX**
- No inline `style={{...}}` — use CSS classes / CSS Modules / tokens. Spec/001 had 68 inline objects extracted to classes — do not reintroduce.
- Semantic markup (`header`, `nav`, `main`, `section`, `button`) — no div soup. Headings form one ordered hierarchy. A11y lint via `eslint-plugin-jsx-a11y`.

**CSS**
- Property order: Layout → Box model → Typography → Visual → Animation (enforce via `stylelint-order`).
- Tokens via CSS variables (`:root { --color-*, --space-* }`, `var(--token)`). No duplicated hex/px literals across files.
- BEM or CSS Modules, one convention per repo. No duplicated 4-line blocks (DRY gate).

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — React patterns, Redux, API client, Next.js (App Router), NestJS backend patterns.
2. [`TESTING.md`](./TESTING.md) — framework table and per-stack examples (inherits the layered strategy from `docs/TESTING.md`).
3. [`docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md) — TypeScript / HTML-TSX / CSS clean-code gates and CI job-orchestration rule (parallel jobs, no `needs: [lint]` gating `build`).

## Saga & Outbox CI Gates

Shell and ESLint gates run in CI when `SAGA_DETECTED=true` or `OUTBOX_DETECTED=true`. Merge blocked on violation.

**ESLint plugin:** `ci/templates/eslint-saga-rules/saga-compensation.js`
- Rule `saga/step-timeout-required`: every `sagaStep()` call must include both `compensate` and `timeout` properties.
- CJS format. ESLint v8: add to `.eslintrc` plugins array. ESLint v9 flat config: `require()` the file or rename to `.cjs`.

**Shell gates run when `SAGA_DETECTED=true`:**
- `check-saga-timeouts.sh` — every `sagaStep()` file must include `timeout:` property (not just the word in a comment).
- `check-saga-tests.sh` — integration test files with compensation scenarios required.

**Shell gates run when `OUTBOX_DETECTED=true`:**
- `lint-outbox-schema.sh` — outbox migration (in `migrations/`, `database/migrations/`, or `prisma/migrations/`) must have required columns (`aggregate_type`, `aggregate_id`, `published_at`, etc.), a partial index on `published_at IS NULL`, and a cleanup mechanism.
- `check-outbox-relay.sh` — relay component and consumer dedup logic must exist.

**Test templates:** `ci/templates/tests/saga.integration.test.ts`, `ci/templates/tests/outbox.integration.test.ts`.

Read `docs/SAGA_PATTERN.md §CI Quality Gates` and `docs/OUTBOX_PATTERN.md §CI Quality Gates` before writing saga or outbox code.
