package services

import (
	"context"
	"example.com/feature/internal/models"
	"example.com/feature/internal/store"
)

type FeatureService struct {
	store store.FeatureStore
}

func NewFeatureService(s store.FeatureStore) *FeatureService {
	return &FeatureService{store: s}
}

func (s *FeatureService) GetOrCreate(ctx context.Context, id, name string) (*models.Feature, error) {
	existing, err := s.store.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return existing, nil
	}
	f := &models.Feature{ID: id, Name: name}
	if err := s.store.Save(ctx, f); err != nil {
		return nil, err
	}
	return f, nil
}
