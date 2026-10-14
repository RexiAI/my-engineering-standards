# Writing agentic E2E tests

Journeys are TypeScript files matching `tests/**/*.e2e.ts`. Each test drives
the real app through the framework's verbs — `agent.act(...)`,
`agent.assert(...)`, `agent.waitFor(...)`, `agent.extract(...)` — and is
judged by a separate model.

## The act+expect golden rule

**Every `act` must be followed by an `expect` / `agent.assert`** before the
next `act`. One act, one verification, in order:

```ts
await agent.act("submit valid credentials into the login form");
await agent.assert("the dashboard header shows the signed-in user's name");
```

An unverified act proves nothing: the run cannot distinguish "the app
accepted my action" from "the app ignored it". A journey that acts several
times before asserting anything is a defect, not a shortcut.

## Judge isolation

The judge that evaluates `agent.assert` **does not see the actor's step-by-step
trace** — it evaluates the stated expectation against the outcome. This is
deliberate: an actor that "persuaded" its way through a broken flow cannot
persuade the judge. Write expectations as observable statements about the app's
state (what a user would see), never as restatements of the steps you just
performed.

## Params and unique

Parameterize journeys with `params` when the same intent must run over several
inputs. Give each run a **unique** identifier (e.g. a generated email or order
ref) so parallel and replayed runs never collide on shared app state. Shared
fixtures mutated by more than one journey are the top cause of false failures.

## Sessions and opaque secrets

Authentication state rides in framework **sessions** so journeys start signed
in. Credentials themselves go through the opaque `Secret` path:

```ts
const acct = credentials.user("qa-login-01"); // a handle, not a value
await agent.act(`sign in as ${acct}`);        // the plaintext never appears
```

The test body — and the models — only ever see the handle. Never inline or
hardcode a credential value in a test file, in `e2e.config.ts`, or in any
tracked file. Rotate anything that lands in a diff.

## waitFor and extract

Never sleep to let the app catch up — wait for the condition:

```ts
await agent.waitFor("the order confirmation banner is visible");
```

And when a later step needs data the app produced, take it explicitly with
`agent.extract(...)` instead of re-deriving it from a screenshot description:

```ts
const orderId = await agent.extract("the order id shown on the receipt");
```

`waitFor` keeps runs fast and deterministic under the replay cache;
`extract` gives downstream steps and assertions a typed value rather than a
re-narrated one.
