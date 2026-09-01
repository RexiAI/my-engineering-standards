package services

import (
	"context"
	"testing"
	"example.com/feature/internal/models"
	"example.com/feature/internal/store"
)

// AC-005-01: acceptance test traceable via TestAC_005_01 naming (stdlib testing only, no testify)
func TestAC_005_01_GetOrCreateCreatesFeature(t *testing.T) {
	s := store.NewMemoryStore()
	svc := NewFeatureService(s)
	ctx := context.Background()

	f, err := svc.GetOrCreate(ctx, "123", "demo")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.ID != "123" || f.Name != "demo" {
		t.Fatalf("unexpected feature: %+v", f)
	}
}

func TestAC_005_02_GetOrCreateReturnsExisting(t *testing.T) {
	s := store.NewMemoryStore()
	_ = s.Save(context.Background(), &models.Feature{ID: "123", Name: "existing"})
	svc := NewFeatureService(s)

	f, err := svc.GetOrCreate(context.Background(), "123", "new")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.Name != "existing" {
		t.Fatalf("expected existing, got %v", f.Name)
	}
}
