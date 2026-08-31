package com.example.feature;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.example.feature.model.Feature;
import com.example.feature.repository.FeatureRepository;
import com.example.feature.service.FeatureService;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

// Sample acceptance test AC_004_01 — Given/When/Then naming, AC-004-NN traceability
// Demonstrates red-then-green: before implementing FeatureService#getOrCreate this test fails;
// after stubbing the service to return the expected value it passes (see README snippet).
@ExtendWith(MockitoExtension.class)
class FeatureServiceTest {

  @Mock FeatureRepository repository;

  @Test
  void shouldGetOrCreateFeature_AC_004_01() {
    // Given a feature id and name
    when(repository.findById("123")).thenReturn(Optional.empty());
    when(repository.save(org.mockito.ArgumentMatchers.any())).thenAnswer(i -> i.getArgument(0));
    FeatureService service = new FeatureService(repository);

    // When getOrCreate is called
    Feature result = service.getOrCreate("123", "demo");

    // Then the feature is returned with expected values
    assertThat(result.getId()).isEqualTo("123");
    assertThat(result.getName()).isEqualTo("demo");
  }

  @Test
  void shouldReturnExistingFeature_AC_004_02() {
    Feature existing = new Feature("123", "existing");
    when(repository.findById("123")).thenReturn(Optional.of(existing));
    FeatureService service = new FeatureService(repository);

    Feature result = service.getOrCreate("123", "new-name");

    assertThat(result.getName()).isEqualTo("existing");
  }
}
