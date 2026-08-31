package com.example.feature.model;

/** Domain model for the feature slice (AC-004). No infra imports. */
public class Feature {
  private final String id;
  private final String name;

  public Feature(String id, String name) {
    this.id = id;
    this.name = name;
  }

  public String getId() { return id; }
  public String getName() { return name; }
}
