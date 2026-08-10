# React Native — Testing

Testing guide for the React Native stack. The layered test strategy
(unit / integration / component / E2E) and what each layer proves is
defined in the root [`docs/TESTING.md`](../../../docs/TESTING.md) and
inherited here — this file covers the *tools* and *what's mockable*.

## Frameworks

- **Unit and component tests**: [React Native Testing Library
  (RNTL)](https://callstack.github.io/react-native-testing-library/).
  Pairs with `jest` (the test runner that ships with RNTL) and
  `@testing-library/jest-native` for matchers.
- **End-to-end tests**: [Maestro](https://maestro.mobile.dev/). YAML
  flows that drive the actual binary on a simulator or device.
- **Detox** is the upgrade path for projects that outgrow Maestro —
  pixel-perfect synchronous control, in-test device manipulation,
  CI-friendly retries. Maestro is the default; reach for Detox when
  you need what Maestro can't give you.

## E2E Scope

| Belongs in RNTL | Belongs in Maestro / Detox |
|---|---|
| Component rendering, props, state transitions | Full user flows across screens |
| Hook logic in isolation | Permissions, OS dialogs (camera, notifications) |
| Form validation and submission | Push notification delivery |
| Navigation between two screens | Cold start, deep links, backgrounding |
| Redux / Zustand / Query state transitions | Real network, real persistence |

Rule of thumb: if the test can run on a single screen with mocked
external services, it's an RNTL test. If it needs the real binary
running on a real device, it's an E2E test.

## What to Mock

Two layers need explicit mocking. The default for everything else is
"don't mock it; use the real one."

### Native modules

Native modules are absent in the Jest environment — calling them
throws. Mock at the module boundary with `jest.mock`.

```ts
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(() => Promise.resolve('mock-token')),
  setItemAsync: jest.fn(() => Promise.resolve()),
}))
```

For Expo modules, `jest-expo` ships a preset that mocks the common
ones out of the box; only add explicit mocks for modules your test
actually exercises.

### Network layer

Mock at the HTTP client, not at the function that calls it. If your
code uses `fetch`, mock `fetch`. If it uses an `axios` instance, mock
the instance. This keeps the assertion on the right layer (network
contract, not internal helper).

```ts
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/native'

const server = setupServer(
  http.get('https://api.example.com/v1/users/:id', () =>
    HttpResponse.json({ id: '1', name: 'Test' }),
  ),
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

`msw` is the standard — it intercepts at the network layer, so your
code calls `fetch` for real and the test verifies the actual request
shape, headers, and body.

### What not to mock

- **React Navigation**: use the testing utilities that ship with
  Expo Router. A `Stack` wrapper is one import.
- **TanStack Query**: wrap the component in a `QueryClientProvider`
  with a `QueryClient` configured for tests. Do not mock `useQuery`.
- **Zustand stores**: import the real store. Reset state between
  tests with the store's own `setState` reset action.
- **Your own hooks and services**: if you find yourself mocking
  them, the test is probably pointing at the wrong layer. Reach for
  the actual unit test on that hook or service instead.

## Component Test Skeleton

```tsx
import { render, screen, fireEvent } from '@testing-library/react-native'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { LoginPage } from './LoginPage'

const renderWithProviders = (ui: React.ReactNode) => {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
  return render(
    <QueryClientProvider client={client}>{ui}</QueryClientProvider>,
  )
}

it('submits the form', async () => {
  renderWithProviders(<LoginPage />)
  fireEvent.changeText(screen.getByPlaceholderText('email'), 'a@b.c')
  fireEvent.changeText(screen.getByPlaceholderText('password'), 'pw')
  fireEvent.press(screen.getByRole('button', { name: /sign in/i }))
  expect(await screen.findByText(/welcome/i)).toBeOnTheScreen()
})
```

## Maestro Flow Skeleton

```yaml
# e2e/login.yaml
appId: com.example.app
---
- launchApp
- tap: "email"
- inputText: "user@example.com"
- tap: "password"
- inputText: "password"
- tap: "Sign in"
- assertVisible: "Welcome"
```

Run with: `maestro test e2e/login.yaml`. Run the full suite in CI
with `maestro test .maestro/`.

## Further Reading

- Layer definitions: [`docs/TESTING.md`](../../../docs/TESTING.md)
- React Native Testing Library docs: https://callstack.github.io/react-native-testing-library/
- Maestro docs: https://maestro.mobile.dev/
