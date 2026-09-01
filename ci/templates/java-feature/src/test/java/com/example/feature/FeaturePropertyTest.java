package com.example.feature;

import net.jqwik.api.*;
import static org.assertj.core.api.Assertions.assertThat;

class FeaturePropertyTest {

  // Property test AC_004_03 (production tier — optional at mvp per docs/CONFORMANCE_TIERS.md)
  @Property
  void idNeverNull_AC_004_03(@ForAll String id) {
    com.example.feature.model.Feature f = new com.example.feature.model.Feature(id, "name");
    assertThat(f.getId()).isEqualTo(id);
  }
}
