# Java TDD Feature Scaffold

Copy `ci/templates/java-feature/` into your project as a starting slice.

```bash
cp -r .standards/ci/templates/java-feature/* .
# edit groupId/artifactId in pom.xml, then:
mvn test -Pservice      # unit + acceptance (red → implement → green)
mvn verify -Pmutation   # mutation coverage ≥80 (production tier)
```

- Tests: JUnit 5 + Mockito + AssertJ, property tests via jqwik (production tier, optional at mvp).
- Complexity: PMD CyclomaticComplexity ≤6, CognitiveComplexity ≤6 (see pmd-rules.xml).
- Pitest profile: `ci/templates/pitest-profile.xml` mutationThreshold 80.
- Sample test `shouldGetOrCreateFeature_AC_004_01` fails before `FeatureService` is implemented, passes after.

Tier: mutation and property tests are `production`-tier per docs/CONFORMANCE_TIERS.md; `mvp` may skip them.
