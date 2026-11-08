# AC-044-13: Read-only concierge agent

## AC-044-13-01 — The agent lives outside the default agent set
Given the file `agents-optional/voice-concierge.md`
When the repository tree is read
Then the file exists at exactly that path
And no `agents/voice-concierge.md` exists

## AC-044-13-02 — Frontmatter shape
Given `agents-optional/voice-concierge.md`
When its frontmatter is parsed
Then it has exactly one `description:` line
And exactly one `mode: primary` line

## AC-044-13-03 — No pinned model
Given `agents-optional/voice-concierge.md`
When the frontmatter is searched for `model:`
Then zero matches are found

## AC-044-13-04 — Read-only permissions are structural
Given the agent's `permission` block
When it is read
Then `read` allows `*`
And `edit` denies `*`
And `bash` denies `*`
And `task` denies `*`

## AC-044-13-05 — The prompt states its limits
Given the agent prompt body
When it is read
Then it states answers are at most three sentences
And it states the agent never performs or claims to perform a mutation
And it states the agent says it is read-only when asked to change something

## AC-044-13-06 — Governance row is present and T0
Given `docs/GOVERNANCE.md`
When the agent-to-tier mapping table is read
Then a row beginning `` | `voice-concierge` | `` exists
And that row carries **T0**
And it names the deny-all edit, bash, and task grants as its basis
And no row in the table carries **T3**
And `scripts/check-governance.sh` exits 0

## AC-044-13-07 — The model-pin gate is not weakened
Given `scripts/check-agent-models.sh`
When its scanned directories are read
Then they are still `agents` and `.opencode/agents`
And `scripts/voice/smoke.mjs` reports `[OK] agent voice-concierge.md` after asserting no `model:` key
