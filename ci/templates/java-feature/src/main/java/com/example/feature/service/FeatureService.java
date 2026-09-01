package com.example.feature.service;

import com.example.feature.model.Feature;
import com.example.feature.repository.FeatureRepository;
import java.util.Optional;

public class FeatureService {
  private final FeatureRepository repository;

  public FeatureService(FeatureRepository repository) {
    this.repository = repository;
  }

  public Feature getOrCreate(String id, String name) {
    Optional<Feature> existing = repository.findById(id);
    if (existing.isPresent()) {
      return existing.get();
    }
    return repository.save(new Feature(id, name));
  }
}
