package com.example.feature.repository;

import com.example.feature.model.Feature;
import java.util.Optional;

public interface FeatureRepository {
  Optional<Feature> findById(String id);
  Feature save(Feature feature);
}
