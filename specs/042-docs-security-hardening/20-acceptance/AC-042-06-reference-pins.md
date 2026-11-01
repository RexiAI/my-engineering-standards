# AC-042-06: Java, Go, and React Native version pins

## AC-042-06-01 — Java is pinned at 21 with an Oracle authority link
Given `docs/OFFICIAL_REFERENCES.md`
When the `## Version pins` table is read
Then a row starts with `| Java |`
And that row's pinned-version cell contains `21`
And that row links an upstream authority at `docs.oracle.com`

## AC-042-06-02 — Go's pin is the module manifest, not a hardcoded version
Given the `## Version pins` table
When the Go row is read
Then a row starts with `| Go |`
And the pinned-version cell contains `go.mod`
And the row states that the version is resolved from the module's `go` and `toolchain` lines
And the row links an upstream authority at `go.dev`

## AC-042-06-03 — React Native is pinned at 0.88.1 with its runtime floors
Given the `## Version pins` table
When the React Native row is read
Then a row starts with `| React Native |`
And the pinned-version cell contains `0.88.1`
And the floor cell contains `^22.13.0`, `^24.3.0`, and `>= 26.0.0`
And the floor cell contains `^19.3.0`
And the row links `registry.npmjs.org/react-native/0.88.1`

## AC-042-06-04 — Existing rows are preserved and the new rows are dated
Given the `## Version pins` table and the `## Licences` table
When both tables are read after the change
Then the rows for Angular, Ionic, Capacitor, NestJS, FastAPI, Rust, and Vercel CLI are still present
And a sentence below the version table records `2026-11-01` for the three added rows and `2026-10-15` for the existing rows
And the licences table has rows for Java, Go, and React Native carrying `Not reproduced — links only`
