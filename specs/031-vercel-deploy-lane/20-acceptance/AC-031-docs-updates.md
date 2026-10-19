# AC-031: Documentation updates (OFFICIAL_REFERENCES.md, DEPLOYMENT.md)

## AC-031-53 — OFFICIAL_REFERENCES.md pins Vercel CLI 64.5.0
Given `docs/OFFICIAL_REFERENCES.md` has been updated
When the version-pins table is read
Then it contains a row for Vercel CLI **64.5.0** with a source URL (npm registry or Vercel changelog) and the licence (Apache-2.0)

## AC-031-54 — OFFICIAL_REFERENCES.md records pages consulted
Given `docs/OFFICIAL_REFERENCES.md` has been updated
When the pages-consulted section is read
Then it contains a Vercel CLI subsection listing the documentation pages that were actually read

## AC-031-55 — DEPLOYMENT.md gains frontend/Vercel lane section
Given `docs/DEPLOYMENT.md` has been updated
When the file is read
Then it contains a "Frontend: Vercel" section alongside the existing backend sections (Kamal, Dokku, Raw SSH) describing: Vercel Git integration as source of truth, CLI limited to observation/sync, credential pattern (`VERCEL_TOKEN`/`VERCEL_ORG_ID`/`VERCEL_PROJECT_ID`), coexistence with GHCR container path, and the prohibition against `vercel deploy`
