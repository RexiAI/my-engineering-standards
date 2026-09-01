export interface Feature {
  id: string;
  name: string;
}

const store = new Map<string, Feature>();

export function getOrCreate(id: string, name: string): Feature {
  const existing = store.get(id);
  if (existing) return existing;
  const f: Feature = { id, name };
  store.set(id, f);
  return f;
}

export function clearStore() {
  store.clear();
}
