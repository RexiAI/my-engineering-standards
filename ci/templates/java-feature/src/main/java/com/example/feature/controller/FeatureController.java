package com.example.feature.controller;

import com.example.feature.model.Feature;
import com.example.feature.service.FeatureService;

public class FeatureController {
  private final FeatureService service;

  public FeatureController(FeatureService service) {
    this.service = service;
  }

  public Feature handle(String id, String name) {
    return service.getOrCreate(id, name);
  }
}
