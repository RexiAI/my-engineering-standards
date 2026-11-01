# AC-042-07: The `docs/CI_CD.md.md` reference is repaired

## AC-042-07-01 — The tag bullet cites the real document
Given `AGENTS.md`
When the `Never create git version tags` bullet is read
Then it cites `docs/CI_CD.md §Release Process`
And it does not contain `docs/CI_CD.md.md`

## AC-042-07-02 — No doubled-extension reference remains
Given the tracked Markdown under `AGENTS.md`, `README.md`, `docs/`, `language-specific/`, `templates/`, `skills/`, and `commands/`
When every file is searched for the literal `docs/CI_CD.md.md`
Then no match is returned
