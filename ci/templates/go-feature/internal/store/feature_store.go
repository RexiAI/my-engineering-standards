package store

import (
	"context"
	"example.com/feature/internal/models"
)

type FeatureStore interface {
	Get(ctx context.Context, id string) (*models.Feature, error)
	Save(ctx context.Context, f *models.Feature) error
}

type memoryStore struct {
	data map[string]*models.Feature
}

func NewMemoryStore() FeatureStore {
	return &memoryStore{data: make(map[string]*models.Feature)}
}

func (m *memoryStore) Get(_ context.Context, id string) (*models.Feature, error) {
	if f, ok := m.data[id]; ok {
		return f, nil
	}
	return nil, nil
}

func (m *memoryStore) Save(_ context.Context, f *models.Feature) error {
	m.data[f.ID] = f
	return nil
}
