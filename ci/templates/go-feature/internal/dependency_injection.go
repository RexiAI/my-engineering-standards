package internal

import (
	"example.com/feature/internal/services"
	"example.com/feature/internal/store"
)

// BuildDependencies wires the feature manually (no DI framework per standards).
func BuildDependencies() (*Dependencies, error) {
	s := store.NewMemoryStore()
	svc := services.NewFeatureService(s)
	return &Dependencies{FeatureService: svc, Store: s}, nil
}

type Dependencies struct {
	FeatureService *services.FeatureService
	Store          store.FeatureStore
}
