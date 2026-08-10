# JavaScript / TypeScript — Testing

The layered test strategy (unit / integration / component / E2E) and
what each layer proves is defined in the root
[`docs/TESTING.md`](../../../docs/TESTING.md) and inherited here —
this file covers the *tools* and the *examples* for each layer.

## Layer / Framework Table

| Layer | Framework | Tools |
|---|---|---|
| Unit | Vitest (preferred) or Jest | React Testing Library |
| Integration | Vitest / Jest | Supertest (NestJS), redux-mock-store, msw |
| Component | Vitest / Jest | React Testing Library |
| E2E | Playwright | Playwright (recommended for Next.js) |

Vitest is the default for new projects. Jest remains supported for
projects that have already standardized on it; the configuration
shapes in this document are Jest-flavored (Vitest equivalents are
documented in the Vitest docs).

## Next.js Testing

```tsx
// __tests__/dashboard.test.tsx
import { render, screen } from '@testing-library/react'
import DashboardPage from '@/app/dashboard/page'

// Mock server component data fetching
jest.mock('@/lib/db', () => ({
  user: { findMany: () => [{ id: '1', name: 'Test' }] },
}))

it('renders user list', async () => {
  const page = await DashboardPage()
  render(page)
  expect(screen.getByText('Test')).toBeInTheDocument()
})
```

```tsx
// E2E — Playwright
// e2e/dashboard.spec.ts
import { test, expect } from '@playwright/test'

test('displays dashboard after login', async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name="email"]', 'user@example.com')
  await page.fill('[name="password"]', 'password')
  await page.click('button[type="submit"]')
  await expect(page.locator('h1')).toContainText('Dashboard')
})
```

## NestJS Testing

```tsx
// Integration test with supertest
import * as request from 'supertest'
const app = await new TestingModule(/* ... */).compile().createNestApplication()
await request(app.getHttpServer()).get('/v1/users/123').expect(200)
```

## Running Tests

Run all tests: `npm test` (or `npm run test -- --coverage` for coverage).

## Layer Boundaries

- Unit tests do not touch the network, the file system, or external services.
- Integration tests cross one architectural boundary (HTTP request to a controller,
  database round-trip, queue publish) with the rest mocked.
- Component tests render a real React tree against `@testing-library/react` and
  mock the network boundary with `msw`.
- E2E tests run the real binary and exercise the full stack.

See [`docs/TESTING.md`](../../../docs/TESTING.md) for the full layer
definitions and the rationale.
