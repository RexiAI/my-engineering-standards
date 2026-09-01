# JS/TS TDD Feature Scaffold

Copy `ci/templates/js-feature/` into your project as a starting slice.

```bash
cp -r .standards/ci/templates/js-feature/* .
npm install
npm test              # vitest run (red → implement → green)
npx stryker run       # mutation 80 (production tier)
npm run lint          # eslint complexity ["error", 6]
```

- Runner: vitest (jest alternative works), fast-check for property tests.
- Stryker config `stryker.conf.json` thresholds.break 80, testRunner vitest (copied from ci/templates/stryker.conf.json).
- ESLint `complexity: ["error", 6]` ≤6.
- Sample test `it("AC-006-01: ...")` plus fast-check `fc.assert` property test.

Tier: mutation and property tests are `production`-tier per docs/CONFORMANCE_TIERS.md (may be skipped at mvp).
See docs/TESTING.md §Property Testing and §Mutation Testing.
