# AC-004: Java TDD scaffold

## AC-004-01 — Scaffold directory and fragments exist
Given the repo after this task
When listing `ci/templates/java-feature/` (or `templates/java-tdd/`)
Then `pom-fragment.xml` exists and contains `junit-jupiter`, `mockito`, `assertj`, and `jqwik`
And a `pitest-profile.xml` reference or copy exists with `mutationThreshold` 80

## AC-004-02 — Layered skeleton mirrors ARCHITECTURE.md
Given the scaffold
When inspecting its `src/main/java/` layout
Then it contains `controller/`, `service/`, `repository/`, and `model/` packages
And `service/` does not import `repository` persistence types directly in the interface (domain inward rule referenced)

## AC-004-03 — Sample acceptance test is traceable and red-then-green
Given the scaffold's sample test containing `AC_004_01` in its method name
When `mvn test -Pservice` is run before implementing the service
Then the test fails (red)
And after stubbing the service to return the expected value, the same test passes (green)

## AC-004-04 — mvn wiring documented and CI template references it
Given the scaffold README fragment (≤20 lines)
When reading it
Then it states `mvn test -Pservice` for unit/acceptance and `mvn verify -Pmutation` for mutation
And `ci/templates/child-ci-java.yml` (or equivalent) already invokes `mvn test` (no new CI file needed if existing covers it)

## AC-004-05 — No speculative generality in scaffold
Given the scaffold
When counting top-level interfaces
Then no interface has exactly one implementation without a second imminent consumer
And no `AbstractBaseTestSuite` exists (per `check-code-principles.sh` YAGNI and `docs/CODING_CONVENTIONS.md`)

## AC-004-06 — Complexity threshold stays at ≤6
Given the scaffold's `pom-fragment.xml` (or PMD config reference)
When inspecting complexity settings
Then no custom threshold above 6 is introduced
And the default `CyclomaticComplexity`/`CognitiveComplexity` check remains ≤6
