# AC-021-06: docs/TESTING.md references the RNTL / jest-expo and Maestro split

## AC-021-06-01 — Unit-tests guidance names RNTL + jest-expo for React Native, not plain Jest
Given the file `docs/TESTING.md`
When its Unit-tests section is read
Then it references React Native Testing Library for RN unit/component tests
And it references the jest-expo preset as the RN test preset (distinct from plain Jest)
And it links `language-specific/react-native/TESTING.md`

## AC-021-06-02 — E2E guidance names Maestro for React Native with Detox as the upgrade path
Given the file `docs/TESTING.md`
When its E2E section is read
Then it references Maestro as the RN E2E tool (YAML flows on a simulator/device)
And it references Detox as the RN upgrade path
And it links `language-specific/react-native/TESTING.md`

## AC-021-06-03 — The relative RN testing link resolves
Given the file `docs/TESTING.md`
When the relative link target for the RN testing guide is resolved from `docs/`
Then it exists at `language-specific/react-native/TESTING.md`
