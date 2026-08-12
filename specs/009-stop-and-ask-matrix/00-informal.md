# Stop-and-Ask decision matrix

Resolve these the same way every run — never improvise. A table in
docs/SPEC_PIPELINE.md, referenced by every pipeline agent:

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery | Ask for the absolute path once; never scaffold unprompted |
| Project type ambiguous | Defer to harness default; ask only if interactive and unconfirmed |
| Confluence space/parent unknown | Ask once per run; if still unknown, WARN and continue |
| Version bump not requested | Off by default; never infer from SemVer or diff |
| A design gate blocks | Fix the code, never the threshold — gate config is off-limits to agents |
| Out-of-scope finding | Record in outOfScopeFindings[], do not fix; propose follow-up |
| Acceptance criteria ambiguous | Resolve before delegating implementation |

## Acceptance criteria

- AC-001: docs/SPEC_PIPELINE.md contains the matrix; every pipeline agent
  frontmatter or body links to it.
- AC-002: the "fix the code, never the threshold" rule is enforced in
  check-code-principles.sh / design-gate defaults (agent cannot edit the config).
- AC-003: each pipeline agent's prompt references the matrix as authoritative.
