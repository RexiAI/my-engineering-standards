# Contract Testing Standards

## Philosophy

From Ousterhout: "Module interfaces should be deep — simple on the outside, complex inside. Contract tests validate that interface."

From Kleppmann: "Protocols evolve independently. Contract testing ensures consumer and provider stay in sync without heavyweight integration tests."

Contract tests replace most E2E tests. They verify that service providers still match consumer expectations without deploying the full stack.

## Pact

Use Pact as the contract testing framework for all languages.

### Workflow

```
Consumer Service                     Provider Service
┌──────────────────┐                 ┌──────────────────┐
│ 1. Write test    │                 │                   │
│    that defines  │                 │                   │
│    expectations  │                 │                   │
│ 2. Pact generates│                 │                   │
│    contract file │ ──── Pact ────→ │ 3. Verify         │
│    (JSON)        │     Broker      │    provider       │
│ 3. Publish to    │                 │    against         │
│    Pact Broker   │                 │    contract        │
│ 4. CI validates  │                 │ 4. CI fails if    │
│    can deploy    │                 │    contract broken │
└──────────────────┘                 └──────────────────┘
```

### CI Integration

```yaml
# Consumer: generates and publishes contract
consumer-test:
  script:
    - make test-contract   # Runs Pact consumer tests
    - pact-broker publish-consumer-contracts

# Provider: verifies against published contracts
provider-verify:
  script:
    - pact-broker can-i-deploy --pacticipant my-service
    - make start-service-for-testing
    - make test-contract-verify  # Runs Pact provider verification
```

## Consumer Tests

### Java (Spring Boot)

```java
@ExtendWith(PactConsumerTestExt.class)
@PactTestFor(providerName = "user-service", port = "8081")
class OrderServiceConsumerPactTest {

    @Pact(consumer = "order-service")
    public V4Pact createUserPact(PactDslWithProvider builder) {
        return builder
            .given("user exists with id user_123")
            .uponReceiving("a request for user user_123")
                .path("/v1/users/user_123")
                .method("GET")
            .willRespondWith()
                .status(200)
                .headers(Map.of("Content-Type", "application/json"))
                .body(new PactDslJsonBody()
                    .stringType("id", "user_123")
                    .stringType("email", "user@example.com"))
            .toPact(V4Pact.class);
    }

    @Test
    @PactTestFor(pactMethod = "createUserPact")
    void shouldGetUserById(MockServer mockServer) {
        UserClient client = new UserClient(mockServer.getUrl());
        User user = client.getUser("user_123");
        assertThat(user.getId()).isEqualTo("user_123");
    }
}
```

### Go

```go
func TestUserConsumer(t *testing.T) {
    pact := &dsl.Pact{
        Consumer: "order-service",
        Provider: "user-service",
    }

    pact.AddInteraction().
        Given("user exists with id user_123").
        UponReceiving("a request for user user_123").
        WithRequest(dsl.Request{
            Method: "GET",
            Path:   dsl.String("/v1/users/user_123"),
        }).
        WillRespondWith(dsl.Response{
            Status:  200,
            Headers: dsl.MapMatcher{"Content-Type": dsl.String("application/json")},
            Body:    dsl.Match(dsl.StructMatcher{
                "id":    dsl.String("user_123"),
                "email": dsl.String("user@example.com"),
            }),
        })

    test := func() error { return consumer.GetUser("user_123") }
    pact.Verify(t, test)
}
```

### TypeScript (NestJS)

```ts
describe('User Service Contract', () => {
    const provider = new PactV3({
        consumer: 'order-service',
        provider: 'user-service',
    })

    describe('get user by id', () => {
        it('returns a user', () => {
            provider
                .given('user exists with id user_123')
                .uponReceiving('a request for user user_123')
                .withRequest({ method: 'GET', path: '/v1/users/user_123' })
                .willRespondWith({
                    status: 200,
                    headers: { 'Content-Type': 'application/json' },
                    body: { id: like('user_123'), email: like('user@example.com') },
                })

            return provider.executeTest((mockServer) => {
                const client = new UserClient(mockServer.url)
                return client.getUser('user_123').then((user) => {
                    expect(user.id).toBe('user_123')
                })
            })
        })
    })
})
```

## Provider Verification

### Java (Spring Boot)

```java
@SpringBootTest(webEnvironment = WebEnvironment.DEFINED_PORT)
@Provider("user-service")
@PactBroker(url = "${pact.broker.url}")
class UserServiceProviderPactTest {

    @TestTemplate
    @ExtendWith(PactVerificationInvocationContextProvider.class)
    void pactVerificationTestTemplate(PactVerificationContext context) {
        context.verifyInteraction();
    }

    @BeforeEach
    void setUp(PactVerificationContext context) {
        context.setTarget(new HttpTestTarget("localhost", 8081));
    }

    @State("user exists with id user_123")
    void userExists() {
        userRepository.save(new User("user_123", "user@example.com"));
    }
}
```

### Go

```go
func TestUserServiceProvider(t *testing.T) {
    pact.VerifyProvider(t, types.VerifyRequest{
        Provider: "user-service",
        ProviderBaseURL: "http://localhost:8081",
        BrokerURL: os.Getenv("PACT_BROKER_URL"),
        PactURLs: []string{"file:///pacts/order-service-user-service.json"},
        StateHandlers: types.StateHandlers{
            "user exists with id user_123": func(settupData []byte) error {
                return setupUser("user_123", "user@example.com")
            },
        },
    })
}
```

### TypeScript

```ts
@PactVerificationService()
class UserServicePactVerification {
    @State('user exists with id user_123')
    async setupUser() {
        await userRepository.save({ id: 'user_123', email: 'user@example.com' })
    }
}

describe('Pact Verification', () => {
    it('validates against all published contracts', async () => {
        const opts: VerifierOptions = {
            provider: 'user-service',
            pactBrokerUrl: process.env.PACT_BROKER_URL,
            providerBaseUrl: 'http://localhost:3000',
        }
        await new Verifier(opts).verifyProvider()
    })
})
```

## Contract Testing Strategy

| Test Type | Scope | When | Speed |
|-----------|-------|------|-------|
| Consumer test | Single interaction | Every PR | Fast (< 1s) |
| Provider verification | All consumer contracts | Every PR | Medium (per service) |
| Pact Broker can-i-deploy | Deployment check | Before deploy | Instant |
| Full E2E | Cross-service workflow | Weekly (Scheduled) | Slow |

## Pact Broker

Host a Pact Broker (OSS or PactFlow) as shared infrastructure:

### Required CI Steps

```yaml
# Before deploy: verify no broken contracts
before_deploy:
  - pact-broker can-i-deploy \
      --pacticipant user-service \
      --version $GIT_SHA \
      --to-environment production

# After deploy: record deployment
after_deploy:
  - pact-broker record-deployment \
      --pacticipant user-service \
      --version $GIT_SHA \
      --environment production
```

## See Also

- `docs/TESTING.md` — overall testing strategy
- `docs/SCHEMA_EVOLUTION.md` — API versioning and compatibility
- `docs/CI_CD.md` — pipeline integration for contract tests
