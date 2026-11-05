# 042-docs-security-hardening

> Spec pipeline archive. Original source: `specs/042-docs-security-hardening/` (deleted by this script).
> Archived: 2026-11-01

## Original ask

# Harden standards docs and repo config

Findings (read-only audit, 2026-10-30):
1. docs/SECURITY.md lacks SSRF, CSRF, CORS, password hashing (argon2/bcrypt) and a JWT validation checklist (algorithm allowlist, reject alg=none, aud/iss/exp).
2. docs/OFFICIAL_REFERENCES.md has no pins for Java, Go, React Native.
3. AGENTS.md:23 cites docs/CI_CD.md.md (broken; should be docs/CI_CD.md).
4. docs/CI_CD.md:283-285 bootstrap example ends with a bare git push, contradicting the PR-only rule.
5. Unenforced AGENTS.md rules: /health checking all dependencies, structured logging with trace IDs, controller->service->repository layering. Either add a script check or mark advisory explicitly.
6. scripts/check-skills.sh:74 only warns above 500 lines; language-specific/*/SKILL.md has no real cap (java 282, python 271).
7. Repo config: add a permission block to opencode.json (deny force-push, push to main/master, git tag, branch -D, remote branch delete; ask for commit/push), .gitignore .env.* + rb_*, and remove the tracked rb_* capture files.

Want: items 1-4 and 7 applied; 5 and 6 decided (script or advisory) and recorded. All existing gate scripts stay green; changes to agents/ require an ADR.

## Tasks

# 042 — Harden standards docs and repo config: tasks

Source: `00-informal.md` (read-only audit, 2026-10-30). Twelve tasks: nine doc
edits, two repo-config edits, one gate tightening. Acceptance scenarios:
`20-acceptance/AC-042-01-*.md` … `AC-042-12-*.md`.

Outcome shape: every finding in the informal spec is either fixed, explicitly
recorded as advisory, or explicitly deferred with a named follow-up. No task
edits `agents/**`, so this spec requires no new ADR (the informal spec's "changes
to `agents/` require an ADR" rule is not triggered).

## Decisions recorded (informal items 5 and 6)

These two items asked for a decision rather than a fix. Both are resolved here;
the resolution is binding on `/build`.

### D1 — Unenforced AGENTS.md rules (informal item 5)

- **Condition:** three AGENTS.md rules are stated as mandatory but no script
  checks them: layered architecture / business logic in services (stated across
  two adjacent bullets), `/health` checking every external dependency, and
  structured logging with trace IDs.
- **Options:** (a) add a script check now; (b) mark the rules advisory in
  AGENTS.md and leave enforcement to review; (c) leave the contradiction.
- **Chosen:** (b) — advisory, recorded explicitly. Task 9.
- **Why:** each check would need runtime or cross-language structural analysis
  that a static repo gate cannot do honestly (a `/health` body is not provably
  dependency-complete from source text; "structured logging with trace IDs" is
  not statically checkable across Java/Go/Node). A fake gate is worse than an
  honest label, and this spec is explicitly hardening docs, not adding heavy
  gates. (c) is the defect being fixed.
- **Reversibility:** trivial — delete the markers and the `### Enforcement
  status` table. A future spec can promote any of the three to a script check
  without reworking this one.

### D2 — Line cap for `language-specific/*/SKILL.md` (informal item 6)

- **Condition:** `scripts/check-skills.sh` only warns above 500 lines; the
  `language-specific/` entry-point guides have no real cap (java 282, python
  271, rust 241, go 223).
- **Options:** (a) advisory guidance only; (b) hard cap at 200 lines with the
  four oversized guides grandfathered at their current counts; (c) hard cap at
  300 for everything.
- **Chosen:** (b) — hard cap **200 lines** for every
  `language-specific/**/SKILL.md`, with an explicit grandfather map for the four
  existing oversized guides (java 282, python 271, rust 241, go 223) that caps
  each at its current count and forbids growth. `skills/*/SKILL.md` keeps the
  existing 500-line **warning**. Task 10.
- **Why:** (a) leaves the finding open. (c) does not force a split and would let
  a new guide reach 300 lines. (b) makes the cap real for new work, freezes the
  debt instead of adding to it, and keeps this spec's diff small. java/python
  must be split into an entry point plus siblings in a **follow-up spec** (and
  rust/go at the same time if the follow-up chooses to) — not here; splitting
  them now would mix a content rewrite into a security-hardening spec.
- **Reversibility:** trivial — the four map entries are the only exception
  mechanism; removing an entry after a split is a one-line change. The cap
  constant is one line.

### D3 — Authorization for the gate tightening

Task 10 changes a gate's threshold, which the pipeline otherwise forbids. This
is authorized by the informal spec ("item 6: script or advisory — decide and
record") and by the human gate approving this task list. It is a **tightening**,
not a relaxation: all four grandfathered files pass unchanged under the map, so
no existing gate is being weakened to make a red build green. `/build` may not
change any other gate configuration.

### D4 — Pin values (informal item 2)

- **Chosen:** Java **21** (matches `language-specific/java/SKILL.md`); Go
  **resolved from `go.mod`'s `go`/`toolchain` line** (matches
  `docs/CI_CD.md §Toolchain Versions`); React Native **0.88.1** (latest on the
  npm registry on 2026-11-01, verified against
  `https://registry.npmjs.org/react-native/0.88.1` — engines
  `^22.13.0 || ^24.3.0 || >= 26.0.0`, peer `react ^19.3.0`).
- **Why:** each value comes from the source the pin describes, not from a fresh
  guess: Java 21 is the version `language-specific/java/SKILL.md` already states;
  Go deliberately has no fixed version (`docs/CI_CD.md §Toolchain Versions`);
  React Native 0.88.1 is the registry's current release, which also matches the
  guide's Hermes / new-architecture baseline.
- **Reversibility:** trivial — a pin is one table row.

## Testing approach

Every scenario becomes one bats test in `scripts/tests/`, with the AC ID in the
test name (e.g. `@test "AC-042-01-01: ..." { ... }`). `Makefile`'s
`make test-scripts` already globs `scripts/tests/*.bats`, so no Makefile change
is needed. Content assertions are `grep -qF` on the edited file; config
assertions parse `opencode.json` with `python3`; the line-cap assertions run
`scripts/check-skills.sh` against temporary fixture roots.

Test file mapping:

| AC file | bats file |
|---|---|
| AC-042-01 … AC-042-05 | `scripts/tests/ac-042-security-docs.bats` |
| AC-042-06 | `scripts/tests/ac-042-reference-pins.bats` |
| AC-042-07, AC-042-09 | `scripts/tests/ac-042-agents-doc-integrity.bats` |
| AC-042-08 | `scripts/tests/ac-042-cicd-bootstrap.bats` |
| AC-042-10 | `scripts/tests/ac-042-skill-cap.bats` |
| AC-042-11, AC-042-12 | `scripts/tests/ac-042-repo-config.bats` |

Tests must assert an exit code and a contract string (or a JSON/section
structure). No bare `true`, no `run ... || true` without a `$status` assertion —
`scripts/check-bats-assertions.sh` is a live gate.

## Global constraints

- No file under `agents/` is edited. If a task seems to need one, STOP and
  report: that requires an ADR and human approval.
- Every existing gate stays green, at minimum: `make validate-all`,
  `make test-scripts`, `make lint`, `scripts/check-bats-assertions.sh`,
  `scripts/check-orchestration.sh`, `scripts/check-model-env.sh`,
  `scripts/check-no-hardcoded-secrets.sh`, `scripts/check-gate-consistency.sh`,
  `scripts/check-security-hardening.sh`, `scripts/check-skills.sh`.
  `scripts/check-security-hardening.sh` greps fixed strings in
  `docs/SECURITY.md`; the new sections must be additions that do not reword or
  move the strings it asserts (spec 026's AC-026 headings).
- No gate threshold changes except the one authorized in D2/D3.
- No secret, credential, or token is introduced anywhere.

---

## Task 1 — `docs/SECURITY.md`: SSRF section

Adds the missing server-side request forgery guidance.

Acceptance criteria:

- A new `## SSRF (Server-Side Request Forgery)` section exists in
  `docs/SECURITY.md`, placed before `## Upstream Error Responses Must Not Reach
  the Client`.
- The section requires a **default-deny destination allowlist** for any outbound
  request whose destination came from a user or from an upstream response, and
  states that an unmatched destination is refused. It contains the literal word
  `allowlist`.
- The section names the ranges that must be refused, literally:
  `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
  `169.254.0.0/16`, `fe80::/10`, and the cloud metadata endpoint
  `169.254.169.254`.
- The section states that the check is applied to the **resolved IP**, not the
  hostname, and that a re-resolved address must be re-checked — contains the
  literal phrase `DNS rebinding`.
- The section states that redirects are not followed automatically, or that every
  redirect hop is re-validated against the allowlist. Contains the literal word
  `redirect`.
- `scripts/check-security-hardening.sh` still exits 0.

## Task 2 — `docs/SECURITY.md`: CSRF section

Acceptance criteria:

- A new `## CSRF (Cross-Site Request Forgery)` section exists, in the same
  insertion block as Task 1 (after `## Input Validation`, before `## Upstream
  Error Responses Must Not Reach the Client`).
- The section states that any **`state-changing`** request authenticated by a
  cookie requires a `CSRF token`, and that safe methods (GET/HEAD) never mutate
  state.
- The section states that session cookies are set `SameSite=Lax` or
  `SameSite=Strict`, and that `SameSite=None` requires the `Secure` attribute.
- The section states that a state-changing request whose `Origin` (or, absent
  an Origin header, `Referer`) does not match an allowlist is rejected — both
  literal header names appear.
- The section distinguishes bearer-token APIs: it contains the literal
  `Authorization: Bearer` and states that a header-borne token is not
  CSRF-susceptible, must not be moved into a cookie, and does not need a CSRF
  token.
- `scripts/check-security-hardening.sh` still exits 0.

## Task 3 — `docs/SECURITY.md`: CORS section

Acceptance criteria:

- A new `## CORS (Cross-Origin Resource Sharing)` section exists in the same
  insertion block.
- The section states that `Access-Control-Allow-Origin: *` is never used on an
  endpoint that returns credentialed or authenticated data, and that combining
  `*` with `Access-Control-Allow-Credentials: true` is invalid — all three
  literal strings appear.
- The section requires an exact-origin `allowlist`: the matched origin is echoed
  back, an unmatched request gets no CORS header, and the request's `Origin` is
  never reflected unvalidated. Contains the literal `Vary: Origin`.
- The section states that preflight responses allow only the methods and headers
  the endpoint actually uses, and that a wildcard `Access-Control-Allow-Headers`
  is not combined with credentials.
- The section states that CORS is `not access control` (it does not protect
  against non-browser clients; authorization is enforced server-side).
- `scripts/check-security-hardening.sh` still exits 0.

## Task 4 — `docs/SECURITY.md`: password hashing section

Acceptance criteria:

- A new `## Password Hashing` section exists in the same insertion block.
- It names `Argon2id` as the preferred algorithm and `bcrypt` as the accepted
  alternative, and states that a password is never stored in plaintext or
  reversibly encrypted.
- It forbids fast general-purpose hashes for passwords and names `MD5`,
  `SHA-1`, and `SHA-256` as unacceptable for this use.
- It records concrete parameters: bcrypt work factor (`cost`) of at least `12`;
  Argon2id at least `19 MiB` of memory, at least 2 `iterations`, and
  `parallelism` of at least 1. All five literals appear.
- It requires verification through the library's `constant-time` compare
  function, and forbids comparing hashes with `==` or re-hashing the candidate
  with application code.
- It requires a `rehash` on the next successful login when the stored hash's
  parameters are below the current baseline, done transparently and without
  invalidating the session.
- `scripts/check-security-hardening.sh` still exits 0.

## Task 5 — `docs/SECURITY.md`: JWT validation checklist

Acceptance criteria:

- A new `## JWT Validation Checklist` section exists in the same insertion block,
  and it is the last of the five new sections.
- The section is a markdown task list: it contains at least five lines starting
  with `- [ ]`, one per check.
- The checklist covers, with these literal labels present: `Algorithm
  allowlist` (the accepted `alg` values are fixed in configuration and the
  token's header only selects from them; the header is never itself the source
  of trust), `Reject alg=none` (and any unlisted algorithm, before signature
  verification), `Key selection by kid` (verification key from a configured,
  trusted JWKS; `jku` and `x5u` are never fetched and the token never supplies
  its own key), `Signature before claims` (nothing is read before the signature
  verifies), `Time claims (exp, nbf, iat)` (`exp` required, `nbf`/`iat` honoured,
  bounded clock skew), and `Audience and issuer (aud, iss)` (both validated
  against expected values; missing or mismatched is a rejection).
- Each checklist item states the failure behaviour: reject the token.
- `scripts/check-security-hardening.sh` still exits 0.

## Task 6 — `docs/OFFICIAL_REFERENCES.md`: Java, Go, React Native pins

Acceptance criteria:

- The `## Version pins` table gains three rows, with the existing seven rows
  unchanged in content:
  - a row starting `| Java |` whose pinned version cell contains `21` and whose
    upstream authority links `docs.oracle.com` (Java SE 21 docs);
  - a row starting `| Go |` whose pinned version cell contains `go.mod` and
    states that the version is resolved from the module's `go`/`toolchain`
    line rather than pinned here, with an upstream authority linking `go.dev`
    (Go toolchains reference);
  - a row starting `| React Native |` whose pinned version cell contains
    `0.88.1`, whose floor cell records the Node engine range (`^22.13.0`,
    `^24.3.0`, `>= 26.0.0`) and React peer range (`^19.3.0`), and whose
    upstream authority links `registry.npmjs.org/react-native/0.88.1`.
- A sentence immediately below the table records that these three rows were
  added on `2026-11-01` (spec 042) and that the pre-existing rows keep the
  document's `2026-10-15` retrieval date.
- The `## Licences` table gains three rows for the same sources, each with `—`
  in the code-licence column and `Not reproduced — links only` in the
  documentation-licence column (the document's existing rule: paraphrased and
  linked, never reproduced).
- `make validate-docs` and `make validate-refs` exit 0.

## Task 7 — `AGENTS.md`: repair the `docs/CI_CD.md.md` reference

Acceptance criteria:

- The `Never create git version tags` bullet in `AGENTS.md` §General Rules cites
  `docs/CI_CD.md §Release Process` — the doubled extension is gone.
- No tracked Markdown under `AGENTS.md`, `README.md`, `docs/`, `language-specific/`,
  `templates/`, `skills/`, or `commands/` contains the literal `docs/CI_CD.md.md`.
  (`specs/**` is out of scope: the informal spec quotes the defect.)
- No other text in the bullet changes.
- `make validate-docs` and `scripts/check-orchestration.sh` exit 0.

## Task 8 — `docs/CI_CD.md`: bootstrap example opens a PR

The `### New Project` fenced block currently commits the submodule and ends with
a bare `git push`, which contradicts `AGENTS.md` and
`docs/GIT_WORKFLOW.md §Strategy: Trunk-Based Development`.

Acceptance criteria:

- The `### New Project` block creates a non-`main` branch before committing:
  it contains a `git checkout -b` line whose branch name is not `main` or
  `master`.
- It pushes with an explicit upstream: contains `git push -u origin`.
- It opens a pull request: contains `gh pr create`.
- The file contains no line that is exactly `git push` (the bare form), and no
  command pushing to `main` or `master`.
- The block's existing steps 1–2 (submodule add, bootstrap) are retained in
  substance; only the commit/push tail changes.
- The fenced block remains valid bash (balanced quotes, one command per line) and
  the surrounding `### CI Only (already bootstrapped)` section is unchanged.
- `make validate-docs` exits 0.

## Task 9 — `AGENTS.md`: mark the unenforced rules advisory (D1)

Acceptance criteria:

- The following four bullets in §General Rules each end with the exact suffix
  `— *advisory* (see §Enforcement status)`:
  the layered-architecture bullet (`controller → service → repository`), the
  `Business logic belongs in services` bullet, the `/health` bullet, and the
  `structured logging with trace IDs` bullet. All other bullets are unchanged
  and carry no such suffix.
- A new `### Enforcement status` subsection follows the §General Rules list and
  states that these rules are advisory: reviewed in PR, not enforced by a gate.
- That subsection contains a table with exactly three rows, one per rule
  (layering, `/health`, structured logging), each with status `advisory`.
- The subsection states, literally, that `no script check` exists today for any
  of the three, and that adding one is a `new spec` — not a silent promotion.
- The subsection distinguishes enforced rules: it states that rules citing a
  `scripts/check-*.sh` gate are mechanically enforced in self-ci.
- No claim that any of the three is mechanically enforced remains in `AGENTS.md`.
- `scripts/check-orchestration.sh` and `make validate-docs` exit 0.

## Task 10 — `scripts/check-skills.sh`: 200-line cap for language guides (D2)

Acceptance criteria:

- `scripts/check-skills.sh` defines a hard cap of `200` total lines (frontmatter
  included, the same count metric the existing 500-line check uses) for every
  `language-specific/**/SKILL.md`.
- A single grandfather map in the script caps the four existing oversized guides
  at their current counts and forbids growth: `language-specific/java/SKILL.md`
  at `282`, `language-specific/python/SKILL.md` at `271`,
  `language-specific/rust/SKILL.md` at `241`, `language-specific/go/SKILL.md` at
  `223`. A grandfathered file over its ceiling is a FAIL; at or under it, a
  PASS.
- A `language-specific/` SKILL.md not in the map that exceeds 200 lines is a
  `[FAIL]`, counted as an error, and the script exits `1`. The message names the
  file, the measured count, the 200-line limit, and the fix (move detail to a
  sibling file such as `PATTERNS.md` or `TESTING.md`).
- `skills/*/SKILL.md` behaviour is unchanged: over 500 lines stays a `[WARN]`
  and does not affect the exit code. `skills/hallmark/SKILL.md` (562 lines) still
  warns and the run still exits `0`.
- Running `./scripts/check-skills.sh` on this repo exits `0` (all four
  grandfathered files are at their ceilings).
- The script's header comment documents the new check (cap, grandfather map, and
  that `skills/` keeps the warning).
- `docs/AGENTS_AND_SKILLS.md` is updated so it cannot contradict the script:
  the Skills Checklist's line-count item states the 200-line cap for
  `language-specific/*/SKILL.md`, the grandfather rule, and the 500-line
  `skills/` warning; the `scripts/check-skills.sh` bullet under §Mechanical
  Enforcement no longer says "line-count warnings" as the only line rule.
- `docs/AGENTS_AND_SKILLS.md` names the follow-up split of the grandfathered
  guides as a separate spec.
- `make validate-all` exits 0.

## Task 11 — `opencode.json`: repo-level bash permission block

Acceptance criteria:

- `opencode.json` remains valid JSON and keeps the `$schema` line and all ten
  `agent.*.model` entries byte-identical (`spec-specifier`, `spec-ux`,
  `spec-verifier`, `spec-mutation-runner`, `spec-pr-opener`, `spec-deployer`,
  `spec-coder`, `spec-refactorer`, `spec-pipeline`, `pr-review`).
- A top-level `permission.bash` object exists whose **first** key is `"*":
  "allow"` and which sets these dispositions:
  - `deny`: `git push --force*`, `git push -f*`,
    `git push --force-with-lease*`, `git push * main*`,
    `git push * master*`, `git push --delete*`, `git push * --delete*`,
    `git push * :*`, `git branch -D*`, `git branch --delete --force*`,
    `git tag*`;
  - `ask`: `git push*`, `git commit*`.
- Every `ask` key appears before every `deny` key, and `"*"` appears before all
  of them. Rationale (documented, not implied): opencode evaluates permission
  patterns with **last matching rule wins**, so a deny placed before a broader
  ask would be overridden.
- The `main`/`master` patterns are deliberately prefix-broad: safety over
  precision, so a branch whose name begins with `main` or `master` after a space
  is denied too rather than risk a miss.
- No other permission category (`edit`, `read`, `webfetch`, …) is changed; no
  agent-level permission block in `agents/**` is touched.
- `docs/AGENTS_AND_SKILLS.md` gains a `### Repo-level permission block`
  subsection (under §Mechanical Enforcement or immediately after it) that
  states: the block lives in `opencode.json`; `last matching rule wins`; the
  catch-all comes first and the specific rules come after; the denied actions
  (force-push, push to `main`/`master`, remote-branch delete, `git branch -D`,
  any `git tag` invocation) and the asked actions (`git commit`, `git push`);
  and that agent frontmatter blocks merge over it and take precedence for that
  agent.
- `scripts/check-model-env.sh` exits 0; `python3 -m json.tool opencode.json`
  exits 0.

## Task 12 — `.gitignore` hardening and removal of tracked `rb_*` captures

Acceptance criteria:

- `.gitignore` gains a `.env.*` entry (all dotenv variants, not just `.env` and
  `.env.local`) and an `rb_*` entry, each under a comment naming spec 042.
- The tracked files `rb_check-governance`, `rb_check-model-env`,
  `rb_check-no-hardcoded-secrets`, `rb_check-orchestration`,
  `rb_check-pr-review`, `rb_check-skills`, `rb_cpr2`,
  `rb_model-env.selftest` are removed from the index and the worktree
  (`git rm`), not merely ignored.
- `git ls-files` returns no entry matching `rb_*`.
- `runs.jsonl` stays tracked: it is the long-lived gate-run telemetry ledger
  written by `scripts/record-gate-run.sh`, not a capture dump. The `.gitignore`
  comment states that boundary.
- Ignore behaviour is correct: `.env.staging`, `.env.production.local`, and
  `rb_check-skills` are ignored; `config/model.local.env.example`,
  `config/agent.local.env.example`, `templates/.envrc.example`, and `.envrc`
  are **not** ignored by the new patterns (`.envrc` remains covered by its own
  pre-existing entry).
- `scripts/guard-env.sh` and `scripts/check-no-hardcoded-secrets.sh` still exit
  0.

---

## Open questions

None blocking. One recorded assumption, decided by documented default and
visible at the human gate:

- **Q1 (non-blocking) — `ask` under headless runs.** Task 11 adds repo-wide
  `ask` for `git commit*`/`git push*`. Whether opencode's `ask` prompts or
  auto-rejects in `opencode run` is not verified here. Default taken: keep the
  dispositions the informal spec names, and do not edit `agents/**` (which would
  need an ADR). Mitigations already in the repo: agent frontmatter rules take
  precedence over the global block (`docs/AGENTS_AND_SKILLS.md`), and
  `agents/spec-pr-opener.md` already ships `git push*: ask` for the unattended
  push path, so `ask` on push is established convention, not new behavior.
  If the Verifier observes a headless regression, it is recorded as an
  out-of-scope finding with a follow-up spec — not fixed here.

## Out-of-scope findings (recorded, not fixed)

- `docs/GIT_WORKFLOW.md §Adding the Standards Submodule` (lines 179–182) has the
  same shape as the defect Task 8 fixes: `git submodule add` followed by
  `git commit` with no branch and no PR. The informal spec names only
  `docs/CI_CD.md`. Fixing both belongs in one follow-up doc-consistency spec so
  the two examples stay aligned.
- `make validate-docs` / `validate-refs` use the regex `docs/[A-Z_]+\.md`, which
  matches the valid prefix of `docs/CI_CD.md.md` and therefore cannot catch a
  doubled extension. That is why Task 7's defect survived. Tightening the regex
  is a gate change; propose a follow-up.
- `docs/OFFICIAL_REFERENCES.md` has no `## Pages consulted` sections for Java,
  Go, or React Native, so the guides' inline upstream citations are not indexed
  against the document's own rule. Adding them requires actually reading those
  upstream pages; the informal spec asks only for version pins. Follow-up spec.

## Acceptance scenarios

## AC-042-01-01 — Section exists and requires a default-deny destination allowlist
## AC-042-01-02 — Loopback, private, link-local, and metadata ranges are refused
## AC-042-01-03 — DNS rebinding cannot bypass the check
## AC-042-01-04 — Redirects are not followed blindly
## AC-042-02-01 — Cookie-authenticated state changes require a CSRF token
## AC-042-02-02 — Session cookies carry a SameSite policy
## AC-042-02-03 — Origin or Referer is checked against an allowlist
## AC-042-02-04 — Bearer-token APIs are distinguished from cookie APIs
## AC-042-03-01 — Wildcard origin is never combined with credentials
## AC-042-03-02 — Origins come from an exact allowlist, never reflection
## AC-042-03-03 — Preflight responses are minimal
## AC-042-03-04 — CORS is not treated as access control
## AC-042-04-01 — Only a password-hashing algorithm is used
## AC-042-04-02 — Fast general-purpose hashes are forbidden
## AC-042-04-03 — Work factors are recorded as minimums
## AC-042-04-04 — Verification is constant-time and hashes are upgraded
## AC-042-05-01 — The section is a checklist with one line per check
## AC-042-05-02 — Algorithm allowlist, and alg=none is rejected
## AC-042-05-03 — Key selection is bound to a trusted JWKS
## AC-042-05-04 — Signature is verified first, then time claims
## AC-042-05-05 — Audience and issuer are validated; the section closes the block
## AC-042-06-01 — Java is pinned at 21 with an Oracle authority link
## AC-042-06-02 — Go's pin is the module manifest, not a hardcoded version
## AC-042-06-03 — React Native is pinned at 0.88.1 with its runtime floors
## AC-042-06-04 — Existing rows are preserved and the new rows are dated
## AC-042-07-01 — The tag bullet cites the real document
## AC-042-07-02 — No doubled-extension reference remains
## AC-042-08-01 — The example branches before committing
## AC-042-08-02 — The example pushes the feature branch with an upstream
## AC-042-08-03 — The example opens a pull request
## AC-042-08-04 — No bare push or push to the default branch remains
## AC-042-09-01 — The four affected bullets carry the advisory suffix
## AC-042-09-02 — An Enforcement status subsection names the advisory set
## AC-042-09-03 — The advisory table has exactly three rows
## AC-042-09-04 — The subsection states no check exists and that adding one is a new spec
## AC-042-09-05 — No false enforcement claim remains
## AC-042-10-01 — This repo still passes the gate
## AC-042-10-02 — A new guide at exactly 200 lines passes
## AC-042-10-03 — A new guide at 201 lines fails with an actionable message
## AC-042-10-04 — A grandfathered guide at its ceiling passes
## AC-042-10-05 — A grandfathered guide that grows fails
## AC-042-10-06 — `skills/` keeps the 500-line warning
## AC-042-10-07 — The documented checklist matches the script
## AC-042-11-01 — The config stays valid and the model wiring is untouched
## AC-042-11-02 — The denied commands are blocked
## AC-042-11-03 — Commit and push are asked, not allowed silently
## AC-042-11-04 — Rule order preserves the last-matching-rule contract
## AC-042-11-05 — The block and its ordering rule are documented
## AC-042-12-01 — Dotenv variants are ignored
## AC-042-12-02 — Committed templates stay trackable
## AC-042-12-03 — Gate-run capture dumps are ignored and untracked
## AC-042-12-04 — The telemetry ledger is not swept up
## AC-042-12-05 — The secret gates still pass

## Verification

# 042-docs-security-hardening — verification

**attempt 1, phase 1 (pre-PR)**

Verifier: independent re-execution of the Coder's and Refactorer's claims.
Everything below was run in this worktree
(`/home/dbueno/.local/share/opencode/worktree/471827/spec-042`) at the timestamps
recorded. Nothing here is transcribed from a prior stage's self-report.

**Verdict: PASS.** No gate produced a finding; no gate failed to run.

| # | Gate | Verdict | Gate ID |
|---|---|---|---|
| 1 | Scenario traceability | PASS | `traceability` |
| 2 | Full test suite | PASS | `test-suite` |
| 3 | Complexity gate | PASS | `complexity` |
| 3.5 | Design-principles gate | PASS (0 FAIL / 58 pre-existing WARN) | `design-principles` |
| 4 | Scenario-to-behavior spot check | PASS | `spot-check` |
| 5 | No unaccounted behavior | PASS | `unaccounted` |

## Scope note — behavior vs structural

This spec is a documentation / repo-config / gate-config spec: it adds no
runtime code path. Its 12 tasks split as

- **behavior (content contract)** — tasks 1–9: new `docs/SECURITY.md` sections
  (AC-042-01…05), `docs/OFFICIAL_REFERENCES.md` pins (AC-042-06), the
  `docs/CI_CD.md.md` reference repair (AC-042-07), the PR-only bootstrap example
  (AC-042-08), and the advisory/enforced split in `AGENTS.md` (AC-042-09). "Behavior"
  here means the document states the rule, and the test reads the rule out of the
  document.
- **structural (gate + harness config)** — tasks 10–12: the 200-line cap and
  grandfather map in `scripts/check-skills.sh` (AC-042-10), the repo-level
  `permission.bash` block in `opencode.json` (AC-042-11), and the `.gitignore` +
  `git rm` hardening (AC-042-12). These change what an existing gate or the
  harness does, so they are verified behaviorally at the fixture level
  (temporary fixture roots, real `check-skills.sh` invocations, real
  `git check-ignore` / `git ls-files`), not by grepping the script source.

The three `opencode.json` / `.gitignore` / `git rm rb_*` edits the orchestrator
flagged are all AC-042-11/12 scope — see §Spot check and §Structural gates below.

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-01T15:05:45Z

{
  "checks": [1, 2],
  "passes": ["AC-042-01 — traced to a test", "AC-042-02 — traced to a test", "AC-042-03 — traced to a test", "AC-042-04 — traced to a test", "AC-042-05 — traced to a test", "AC-042-06 — traced to a test", "AC-042-07 — traced to a test", "AC-042-08 — traced to a test", "AC-042-09 — traced to a test", "AC-042-10 — traced to a test", "AC-042-11 — traced to a test", "AC-042-12 — traced to a test"],
  "fails": []
}

The script matches `AC-NNN-NN` granularity only, so it proves each *task* is
traced, not each *scenario*. Independently re-checked at 4-part granularity:

check: grep -h '^## AC-042-' specs/042-docs-security-hardening/20-acceptance/*.md | wc -l  →  53
check: grep -h '^@test "AC-042-' scripts/tests/ac-042-*.bats | wc -l              →  53
check: comm -23 <scenario IDs> <test IDs>   →  (empty: no scenario without a test)
check: comm -13 <scenario IDs> <test IDs>   →  (empty: no test citing a nonexistent scenario)
check: uniq -d over test IDs                →  (empty: no duplicate IDs)

All 53 scenarios in `20-acceptance/` map one-to-one onto 53 tests; no orphans in
either direction. AC-042-01…12 all present.

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-01T15:19:40Z
(run window 2026-11-01T15:13:51Z → 2026-11-01T15:19:40Z)

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..801
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
[... 795 more ok lines ...]
ok 213 AC-042-11-01: the config stays valid and the model wiring is untouched
ok 214 AC-042-11-02: the denied commands are blocked
ok 215 AC-042-11-03: commit and push are asked, not allowed silently
[...]
ok 799 unit: a cap smaller than the marker still never exceeds the cap
ok 800 unit: state exactly at the cap is not truncated and emits no reason
ok 801 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

Counted from that log: plan line `1..801`, `801` lines starting `ok `, and
`grep -E '^not ok|# skip'` → no matches. No test skipped, disabled, or silently
not run; the 801 total matches the Coder's claim. A second, earlier full run of
the same command (2026-11-01T15:05:51Z start) also exited 0; the block above is
the captured one.

## Evidence: complexity gate

command: shellcheck scripts/check-skills.sh
exit: 0
at: 2026-11-01T15:11:59Z

(no output)

`scripts/check-skills.sh` is the only `.sh` this spec changes (the rest of the
diff is Markdown, JSON, .gitignore and `.bats` files).

command: ./scripts/check-code-principles.sh --gates complexity --json
exit: 0
at: 2026-11-01T15:11:59Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}

Zero FAILs; the three WARNs name files this spec does not touch (`ci/templates/`,
`skills/hallmark/site/examples/`), so they are pre-existing and not attributable
to this diff.

Repo-wide `shellcheck scripts/*.sh templates/*.sh` exits `1` with 1162 lines of
pre-existing findings and **zero** findings naming `scripts/check-skills.sh`
(`grep -c 'check-skills' <log>` → 0). That CI step is `continue-on-error: true`
in `.github/workflows/self-ci.yml`, i.e. advisory, and is unchanged by this spec.

## Evidence: design-principles gate

command: ./scripts/check-code-principles.sh --json
exit: 0
at: 2026-11-01T15:11:42Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [ ...58 entries, reproduced verbatim below... ]
}

Summary line, verbatim:

✔ Design-principles check: 0 FAIL(s), 58 WARN(s).
  WARNs are review hints — verify each before merging.

Baseline comparison (run against a pristine `git archive HEAD` tree in
`/tmp/opencode/baseline042`, since deleted):

BASELINE fails=0 warns=58
diff <baseline WARN set> <current WARN set>   →  IDENTICAL_WARN_SETS

`jq '[.warns[] | select(.file|test("check-skills|ac-042|test_helper|test-helper"))] | length'`
→ `0`. **This spec introduces no design-principles finding of either severity.**
All 58 WARNs are pre-existing repo debt, reproduced verbatim for the Architect:

WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: "directBrokerCall", /data: { name }, /context.report({
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: "directBrokerCall", /data: { name }, /}); /node,
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
WARN Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)
WARN Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)
WARN Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)
WARN Comments: commented-out code (./scripts/check-bats-assertions.sh:21)
WARN Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)
WARN Comments: commented-out code (./scripts/verify-production-deploy.sh:30)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:58)
WARN Comments: commented-out code (./scripts/check-code-principles.sh:121)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)
WARN Comments: attribution comment (./scripts/check-code-principles.sh:59)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)
WARN Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)
WARN Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)
WARN Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)
WARN Comments: commented-out code (./scripts/check-loop-files.sh:10)
WARN Comments: section-divider comment (./scripts/init-ci.sh:6)
WARN Comments: section-divider comment (./scripts/init-ci.sh:43)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:39)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:49)
WARN Comments: commented-out code (./scripts/check-loop-triage.sh:67)
WARN Comments: commented-out code (./scripts/token-stats.sh:10)
WARN Comments: commented-out code (./scripts/guard-env.sh:21)
WARN Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)
WARN Comments: commented-out code (./scripts/check-security-hardening.sh:39)
WARN Comments: commented-out code (./scripts/judgment-preflight.sh:16)
WARN Comments: commented-out code (./scripts/check-model-env.sh:30)
WARN Comments: commented-out code (./scripts/gate-stats.sh:20)
WARN Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)
WARN Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)
WARN Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)
WARN Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
WARN Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)
WARN Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)
WARN Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)

WARN disposition per `docs/SPEC_PIPELINE.md §Stop-and-Ask`: recorded, not a stop;
flagged to the Architect. None is on a file this spec changed.

## Evidence: scenario-to-behavior spot check

command: bats --tap scripts/tests/ac-042-*.bats scripts/tests/test-helper.bats scripts/tests/check-skills.bats
exit: 0
at: 2026-11-01T15:12:36Z

1..68
ok 1 AC-042-07-01: the tag bullet cites the real document
[...]
ok 23 AC-042-12-03: gate-run capture dumps are ignored and untracked
ok 24 AC-042-12-04: the telemetry ledger is not swept up
ok 25 AC-042-12-05: the secret gates still pass
[...]
ok 48 AC-042-05-05: audience and issuer are validated; the section closes the block
ok 54 AC-042-10-05: a grandfathered guide that grows fails
ok 68 check-skills: a skills/ guide at exactly 500 lines is not warned

A passing test with the right ID proves nothing on its own. Two scenarios picked
and read line by line against their Given/When/Then, plus two more read during
the AC-042-11/12 review the orchestrator asked for:

**AC-042-12-03 — gate-run capture dumps are ignored and untracked.** Then-clauses:
`.gitignore` has a literal `rb_*` entry; `git check-ignore --no-index rb_check-skills`
succeeds; `git ls-files` returns no `rb_*`; none of the eight named files exists in
the worktree. The test asserts all four (`grep -qxF 'rb_*'`, `git check-ignore -q`,
`git ls-files` output checked against `rb_check`/`rb_cpr2`/`rb_model-env.selftest`,
and `[ ! -e ]` per file). Re-run myself, independently of the test:

run: git check-ignore --no-index --verbose rb_check-skills
  .gitignore:50:rb_*	rb_check-skills
run: git ls-files | grep -c '^rb_'
  0
run: ls rb_*
  ls: cannot access 'rb_*': No such file or directory
run: git ls-files -- runs.jsonl
  runs.jsonl
Plus the tracked-template guard AC-042-12-02 needs (a new `.env.*` pattern that
swallowed a template would be a real defect): every tracked dotenv-ish path —
`config/agent.local.env.example`, `config/model.local.env.example`,
`templates/.envrc.child`, `templates/.envrc.example` — returns "not ignored",
while `.env.staging`, `.env.production.local` and `rb_check-skills` are ignored.
`.envrc` remains ignored by its own pre-existing entry. **Assertions match the
scenario; no false green.**

**AC-042-10-05 — a grandfathered guide that grows fails.** Then-clauses: exit 1, a
`[FAIL]` line naming `language-specific/java/SKILL.md`, and the same ceiling for
python 271 / rust 241 / go 223. The test loops all four (`ceiling + 1` lines each)
asserting `status -eq 1`, the FAIL line, and the measured count. Re-ran the gate by
hand on a scratch fixture root (`/tmp/opencode/skillfix.*`, since deleted) holding a
283-line java guide and a 201-line new guide:

run: bash scripts/check-skills.sh /tmp/opencode/skillfix.XXXX
exit: 1
Checking SKILL.md files...
[FAIL] language-specific/java/SKILL.md — Body has 283 lines (> grandfathered ceiling of 282 for this guide — it is frozen at its current size and may not grow; move detail to a sibling file such as PATTERNS.md or TESTING.md, then remove its grandfather entry)
[FAIL] language-specific/foo/SKILL.md — Body has 201 lines (> 200-line limit for language-specific/*/SKILL.md — move detail to a sibling file such as PATTERNS.md or TESTING.md)

2 error(s) found in SKILL.md files (0 warning(s))!

The grandfather map is exact-path (`repo config`-adjacent unit test
`check-skills: the grandfather map is exact-path, not a wildcard` covers the
wildcard confusion), and the real guides measure exactly at their ceilings:
`wc -l language-specific/*/SKILL.md` → java 282, python 271, rust 241, go 223.
**Assertions match the scenario.**

Also read against their scenarios while reviewing the flagged edits:
`AC-042-11-04` (asserts `keys[0] == "*"` and `max(ask) < min(deny)` — a real
ordering assertion, not a presence check) and `AC-042-05-05` (asserts the JWT
heading's line number is after `## Input Validation` and the four sibling
sections and before `## Upstream Error Responses Must Not Reach the Client`).

## No unaccounted behavior

Finding line, not a command — `docs/SPEC_PIPELINE.md §The five Verifier
checks` says this skim is not a runnable check:

Finding: none. Every changed path maps to a task:

| Changed path | Task / AC |
|---|---|
| `docs/SECURITY.md` | 1–5 / AC-042-01…05 |
| `docs/OFFICIAL_REFERENCES.md` | 6 / AC-042-06 |
| `AGENTS.md` | 7 + 9 / AC-042-07, AC-042-09 |
| `docs/CI_CD.md` | 8 / AC-042-08 |
| `scripts/check-skills.sh` | 10 / AC-042-10 |
| `docs/AGENTS_AND_SKILLS.md` | 10 + 11 docs clauses / AC-042-10-07, AC-042-11-05 |
| `opencode.json` | 11 / AC-042-11 |
| `.gitignore`, 8 × `git rm rb_*` | 12 / AC-042-12 |
| `scripts/tests/ac-042-*.bats` (6 files) | the 53 scenario tests |
| `scripts/tests/check-skills.bats` (+5) | unit coverage for AC-042-10's cap (Refactorer) |
| `scripts/tests/test_helper.bash` (+`md_section`, `make_skill`) | Refactorer dedup of the doc-section / fixture extraction |
| `scripts/tests/test-helper.bats` (new) | unit tests for those two helpers |
| `specs/042-docs-security-hardening/` | spec artifacts |

Recorded, not findings:

- The Refactorer's `md_section` / `make_skill` helpers are test *infrastructure*
  shared by the doc assertions and the line-cap fixtures; `test-helper.bats` covers
  them (4 + 3 cases) so the extraction is itself verified.
- No file under `agents/` or `commands/` was touched (`git status --porcelain |
  grep -E '^[MADRU?]+ +(agents|commands)/'` → empty), which is the spec's global
  constraint; Task 9's `AGENTS.md` edits are the repo instruction file, not
  `agents/`, and need no ADR.
- Working tree is dirty only with this spec's own uncommitted work (the PR Opener
  commits later); nothing outside `specs/042-docs-security-hardening/` and the
  task-listed paths is touched.

## Supplementary gates (task-list global constraints)

All run at 2026-11-01T15:10Z–15:12Z in this worktree:

| Command | exit | Result |
|---|---|---|
| `make validate-all` | 0 | all 36 files present, cross-references valid, `All SKILL.md files valid (1 warning(s))` |
| `./scripts/check-bats-assertions.sh` | 0 | `77 bats file(s), no vacuous assertions` |
| `./scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `bash scripts/check-model-env.sh` | 0 | `PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired, bridge template checked.` |
| `./scripts/check-no-hardcoded-secrets.sh` | 0 | `PASS ... no hardcoded credential values in agents, commands, scripts, docs, .github, config, templates, ci.` |
| `./scripts/check-gate-consistency.sh` | 0 | `Gate consistency check: PASSED` |
| `./scripts/check-security-hardening.sh` | 0 | `Security hardening check: every check passed.` |
| `./scripts/check-skills.sh` | 0 | `All SKILL.md files valid (1 warning(s))` — the one warning is `skills/hallmark/SKILL.md` at 562 lines (>500), i.e. the `skills/` warning AC-042-10-06 says must be preserved |
| `bash scripts/guard-env.sh` | 0 | `PASS guard-env: no config/agent.local.env in the scanned set (tracked mode).` |
| `python3 -m json.tool opencode.json` | 0 | `opencode.json` parses |

Two tooling notes, both pre-existing and **not** spec-042 findings:

- `scripts/check-model-env.sh` and `scripts/guard-env.sh` are mode `100644` in the
  index (last touched in spec 031's commit), so `./scripts/x.sh` returns
  `126 Permission denied`; invoked as `bash scripts/x.sh` (the form the ACs and
  self-ci use) both exit 0. No agent may change file modes to work around this —
  it is a follow-up finding, not a gate failure here.
- `./scripts/check-audit-trail.sh 042-docs-security-hardening` currently exits 1
  naming `missing 25-verification.md` and `missing 30-report.md`. That is the
  expected in-flight state: this report supplies the first, the Mutation Runner
  supplies the second. It is recorded so the PR Opener's pre-push run of the same
  gate is expected to pass, not as a finding against the Coder.

## Out-of-scope findings carried from the task list (not fixed here)

Recorded so they are not lost, per `§Stop-and-Ask` "Out-of-scope finding":

- `docs/GIT_WORKFLOW.md §Adding the Standards Submodule` (lines 179–182) still has
  the commit-then-push shape Task 8 fixed in `docs/CI_CD.md`.
- `make validate-docs` / `validate-refs` use the regex `docs/[A-Z_]+\.md`, which
  matches the valid prefix of `docs/CI_CD.md.md` and therefore cannot catch the
  defect Task 7 repaired.
- `docs/OFFICIAL_REFERENCES.md` still has no `## Pages consulted` sections for
  Java, Go, or React Native.

One independent fact-check the ACs do not require but the pin's truth depends on:
`https://registry.npmjs.org/react-native/0.88.1` resolves, `version 0.88.1`,
`engines.node ^22.13.0 || ^24.3.0 || >= 26.0.0`, `peerDependencies.react ^19.3.0`.
The row in `docs/OFFICIAL_REFERENCES.md` states exactly that. Java 21 matches
`language-specific/java/SKILL.md` ("Java version: 21"); the Go row's "resolved from
`go.mod`" is the documented intent, not a version claim.

## Quality gates

# 042-docs-security-hardening — report (stage 5a, Mutation Runner)

Worktree: `/home/dbueno/.local/share/opencode/worktree/471827/spec-042`
Tier: **`mvp`** (no `Conformance tier:` declaration in `AGENTS.md` or any
`AGENTS_*.md`; the gate's own auto-detection and the Verifier's recorded run both
resolve `mvp` — see `docs/CONFORMANCE_TIERS.md`).
Verdict: **GREEN** (mutation testing skipped per tier; full suite green).

## Summary rows

| Row | Value |
|---|---|
| Verifier verdict (carried forward from `25-verification.md`) | **PASS** — attempt 1, phase 1 (pre-PR), no BLOCK; 801 tests green |
| Mutation score | **skipped — `mvp` tier** (mutation testing is a `production`-tier gate) |
| Mutants generated / killed / survived | 0 / 0 / 0 — no mutation run, no kill work, no tests written by this stage |
| Equivalent mutants | **none** — no mutants were generated, so none exist to name (see §Equivalent mutants) |
| Complexity summary (carried from Refactorer via `25-verification.md`) | 0 FAIL; `shellcheck scripts/check-skills.sh` exit 0; `check-code-principles.sh --gates complexity` exit 0; 3 pre-existing WARNs, none on a file this spec changed |
| Final test status | **green** — `make test` exit 0, plan `1..801`, 801 `ok`, 0 `not ok`, 0 skip |
| Remediation record | **none** — no BLOCK occurred in any phase |

Mutation testing is the only thing this stage would add; at `mvp` tier the stage
is a recorded skip by contract (`docs/spec-pipeline/coder.md §Conformance tiers`,
`docs/CONFORMANCE_TIERS.md` §Tier assignments), not a gap.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-11-01T15:40:55Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)

`make mutation` is the repo's own tier gate (`Makefile` target, `mutation:
Mutation testing (production tier, 80% threshold — skipped at mvp)`). It emits the
skip line above and exits 0 — a recorded skip, not a failing gate.

No mutation tool could have bitten this diff even at a higher tier, recorded for
the reviewer rather than acted on:

- The diff (`git diff --stat`, 11 tracked files + 7 untracked test files) contains
  **no Java, Go, JS/TS, Python or Rust source**. It is Markdown (6 files), JSON
  (`opencode.json`), `.gitignore`, one shell script (`scripts/check-skills.sh`)
  and `.bats` test files.
- The three mutators named by the tier rule (`docs/SPEC_PIPELINE.md §Tooling by
  language`) are language-specific: PiTest (Java), `gremlins`/`go-mutesting` (Go),
  Stryker (JS/TS). This repo has no root `pom.xml`, `go.mod` or `package.json`;
  the only Stryker config in the tree is the child-repo template
  `ci/templates/stryker.conf.json`, which is not a target here.
- No shell mutation tool is configured, and the tier rule does not name one.

## Evidence: final test status

command: make test
exit: 0
at: 2026-11-01T15:40:43Z
(run window 2026-11-01T15:40:43Z → 2026-11-01T15:46:19Z)

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
1..801
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
[... 797 more ok lines ...]
ok 799 unit: a cap smaller than the marker still never exceeds the cap
ok 800 unit: state exactly at the cap is not truncated and emits no reason
ok 801 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

Counted from the captured log: plan line `1..801`; `grep -c '^ok '` → `801`;
`grep -cE '^not ok|# skip'` → `0`. No test skipped, disabled or silently not run.
This is the post-Verifier re-run the contract requires: the Verifier's PASS cites a
different run (2026-11-01T15:13:51Z → 15:19:40Z, also 801/0), so the suite is
confirmed green twice on this tree.

Because this stage wrote no code and no tests, the suite this run executed is
byte-identical in scope to the one the Verifier saw. It is still re-run and
re-recorded here rather than carried forward.

## Complexity summary (carried forward from the Refactorer, re-measured by the Verifier)

Carried verbatim from `25-verification.md` §Evidence: complexity gate — this stage
ran no complexity gate of its own and changed nothing that would move these numbers.

| Measurement | Command | exit | Result |
|---|---|---|---|
| Changed shell script lint | `shellcheck scripts/check-skills.sh` | 0 | no output — the only `.sh` this spec changes |
| Complexity gate | `./scripts/check-code-principles.sh --gates complexity --json` | 0 | `"tier": "mvp"`, `fails: []`, 3 WARNs |
| Design-principles gate | `./scripts/check-code-principles.sh --json` | 0 | `✔ 0 FAIL(s), 58 WARN(s)` — identical WARN set to a pristine `git archive HEAD` baseline |

The three complexity WARNs are pre-existing debt on files this spec does not touch:
`ci/templates/go-saga-lint.go:45` (`KISS_LINES=28`), `ci/templates/go-saga-lint.go:101`
(`KISS_LINES=25`), `skills/hallmark/site/examples/cobalt-01/script.js:111`
(`KISS_LINES=38`). Repo-wide `shellcheck scripts/*.sh templates/*.sh` exits 1 with
1162 pre-existing lines and **zero** findings naming `scripts/check-skills.sh`; that
CI step is `continue-on-error: true` (advisory) and unchanged by this spec.

Per `docs/SPEC_PIPELINE.md §Stop-and-Ask` (design gate WARN, not FAIL): recorded,
not a stop. All 58 design-principles WARNs are pre-existing repo debt; none is on a
path this spec changed.

## Equivalent mutants

**None.** Mutation testing did not run at `mvp` tier, so no mutants were produced.
There is no survivor list to triage and nothing to name as equivalent or
un-killable. Consequently this stage added **zero** tests — inventing tests for
mutants that were never generated would be untraceable work.

## Remediation record

**none** — no BLOCK occurred during this stage or any stage carried into it.

Carried forward, not inferred: `25-verification.md` records a single
**attempt 1, phase 1 (pre-PR)** with verdict PASS, and no BLOCK entry in any gate
(§The five Verifier checks, all PASS; §Supplementary gates, all exit 0). There is no
phase-2 (post-PR CI) or phase-3 (deploy) entry in that artifact, and the
orchestrator's loop summary supplied to this stage reported no BLOCK either — so the
budget stands at 0 of 3 used in phase 1, and 0 of 3 in phase 2.

## Preconditions and scope discipline

- **Verifier precondition:** `25-verification.md` exists with `**Verdict: PASS.**`
  and `| 2 | Full test suite | PASS | test-suite |`. Checked before any work here;
  no gates were re-run as a substitute for it.
- **Information barrier:** `specs/042-docs-security-hardening/00-informal.md` was not
  read by this stage. No instruction in this session waived that.
- **Working tree:** dirty only with this spec's own uncommitted work — the 11
  modified tracked paths are the task-listed files in `25-verification.md`'s
  changed-path table, plus the `runs.jsonl` telemetry ledger that AC-042-12-04
  explicitly protects from sweeping; the 7 untracked test files and `specs/` are this
  spec's own artifacts. Nothing foreign is dirty, so the
  `§Stop-and-Ask` "working tree dirty" STOP does not fire on foreign dirt. No stash,
  no commit, no revert.
- **Not committed, not pushed, no PR.** Stage 5b's job. This stage wrote exactly one
  file: this report.

## Boundary note for stage 5b

`scripts/check-audit-trail.sh 042-docs-security-hardening` failed before this file
existed, naming `missing 25-verification.md` and `missing 30-report.md` — the
expected in-flight state recorded in `25-verification.md` §Supplementary gates. With
this report present the folder is complete; re-run here, not assumed:

command: ./scripts/check-audit-trail.sh 042-docs-security-hardening
exit: 0
at: 2026-11-01T15:46:46Z

PASS 042-docs-security-hardening: 10-tasks.md present and non-empty
PASS 042-docs-security-hardening: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 042-docs-security-hardening: 25-verification.md present and non-empty
PASS 042-docs-security-hardening: 30-report.md present and non-empty
PASS 042-docs-security-hardening: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-01T15:05:45Z
PASS 042-docs-security-hardening: evidence block 'full test suite' — command: make test, exit: 0, at: 2026-11-01T15:19:40Z
PASS 042-docs-security-hardening: evidence block 'complexity gate' — command: shellcheck scripts/check-skills.sh, exit: 0, at: 2026-11-01T15:11:59Z
PASS 042-docs-security-hardening: evidence block 'design-principles gate' — command: ./scripts/check-code-principles.sh --json, exit: 0, at: 2026-11-01T15:11:42Z
PASS 042-docs-security-hardening: evidence block 'scenario-to-behavior spot check' — command: bats --tap scripts/tests/ac-042-*.bats scripts/tests/test-helper.bats scripts/tests/check-skills.bats, exit: 0, at: 2026-11-01T15:12:36Z
✔ Audit-trail check: specs/042-docs-security-hardening complete, verifier evidence recorded.

## PR record

PR: https://github.com/RexiAI/my-engineering-standards/pull/112
Commit count: 14 (12 task commits + 1 spec-artifact commit + 1 record commit; the stage-5d archive commit is additional)

## 40-deploy.md

# 042-docs-security-hardening — deploy verification (stage 5c)

Repo classification: **non-frontend** (no `vercel.json` and no `package.json` at
the repo root; the repo is a standards/documentation repo, not a deployable
frontend). Deploy verification is not applicable, so this stage records a skip
and exits cleanly.

## Evidence: repo classification

command: test ! -f vercel.json && test ! -f package.json && echo "no vercel.json at repo root; no package.json at repo root -> non-frontend"
exit: 0
at: 2026-11-01T16:20:25Z

no vercel.json at repo root; no package.json at repo root -> non-frontend

## Deploy evidence

| Field | Value |
|---|---|
| Deploy URL | — (no deployment; non-frontend repo) |
| Build status | skip — no deployment lane ran |
| Health check status | skip — no deploy URL to check |
| E2E verdict | skip — no live preview URL |
| Timestamp | 2026-11-01T16:20:25Z |
| Phase-3 attempt count | 0 — phase 3 never started |

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

---

## Post-PR CI check (phase 2)

**Round 2 — attempt 1, phase 2 (post-PR) of this round; overall phase-2 round 2.**
Round-1 fix head `aa7a37e` (Self CI green) was followed by merge commit
`7dea0c2` (main merged into the spec branch), which is the head re-checked here.
Round 2 verdict: **FAIL**. The pipeline stops; no fix was applied by the Verifier.

PR: https://github.com/RexiAI/my-engineering-standards/pull/112
Head: `7dea0c2de38f916e10cd04b334f306318f3edd46`

| Check | Workflow / event | Bucket | Result | Check ID |
|---|---|---|---|---|
| Validate | Self CI / pull_request | fail | **FAIL** | 124914895804 |
| Validate | Self CI / push | fail | **FAIL** | 124914881702 |
| Review PR / Review PR | PR Review Agent / pull_request | fail | excluded — environmental (`Invalid credential`) | 124914894148 |

Whole-run status for `7dea0c2` (both Self CI runs): steps 1–29 passed (including
`make validate-all`, `make lint`, shellcheck, orchestration/skills/archive/audit-trail
checks); step 30 **"Run shell gate bats tests (spec 001 Track B)" failed**; steps
31–33 (gate selftests, live scenario traceability, YAML syntax) were skipped as a
consequence of the step-30 failure. The job's only failing assertion is:

- `scripts/tests/ac-037-references.bats:44` — `not ok 214 AC-037-03-01: moved-section references are repointed to the new file`
- Cause: `docs/changes/042-docs-security-hardening.md:914` cites the index path for
  `§Conformance tiers`. Spec 037 (merged into this branch by
  `7dea0c2`) moved `## Conformance tiers` to `docs/spec-pipeline/coder.md` and added
  AC-037-03-01, which forbids stale index citations, so the archived one-pager's
  citation is now a finding. The section and the test did not exist at the round-1
  head `aa7a37e` (`ac-037-references.bats` and `docs/spec-pipeline/` absent there),
  so this is a merge-integration failure, not a regression in the round-1 fix.
- Routed fix (not applied here): repoint line 914 to
  `docs/spec-pipeline/coder.md §Conformance tiers` (the destination the spec-037
  map records for that heading).

## Evidence: post-PR CI check (round 2)

command: gh pr checks 112 --json name,state,bucket,workflow,link
exit: 0
at: 2026-11-05T13:05:05Z

[{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41328990732/job/124914895804","name":"Validate","state":"FAILURE","workflow":"Self CI"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41328990653/job/124914894148","name":"Review PR / Review PR","state":"FAILURE","workflow":"PR Review Agent"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41328986368/job/124914881702","name":"Validate","state":"FAILURE","workflow":"Self CI"}]

## Evidence: failing CI check IDs

command: gh api repos/RexiAI/my-engineering-standards/commits/7dea0c2de38f916e10cd04b334f306318f3edd46/check-runs --jq '.check_runs[] | "\(.name) | id=\(.id) | \(.status)/\(.conclusion) | \(.details_url)"'
exit: 0
at: 2026-11-05T13:05:10Z

Validate | id=124914895804 | completed/failure | https://github.com/RexiAI/my-engineering-standards/actions/runs/41328990732/job/124914895804
Review PR / Review PR | id=124914894148 | completed/failure | https://github.com/RexiAI/my-engineering-standards/actions/runs/41328990653/job/124914894148
Validate | id=124914881702 | completed/failure | https://github.com/RexiAI/my-engineering-standards/actions/runs/41328986368/job/124914881702

## Evidence: failing CI log excerpt

command: gh run view 41328986368 --log-failed
exit: 0
at: 2026-11-05T13:05:18Z

Validate	UNKNOWN STEP	2026-11-01T16:59:57.5900843Z not ok 214 AC-037-03-01: moved-section references are repointed to the new file
Validate	UNKNOWN STEP	2026-11-01T16:59:57.5909086Z # (in test file scripts/tests/ac-037-references.bats, line 44)
Validate	UNKNOWN STEP	2026-11-01T16:59:57.5915317Z #   `return 1' failed
Validate	UNKNOWN STEP	2026-11-01T16:59:57.5924419Z # /home/runner/work/my-engineering-standards/my-engineering-standards/docs/changes/042-docs-security-hardening.md:914:is a recorded skip by contract (`docs/spec-pipeline/coder.md §Conformance tiers`,
Validate	UNKNOWN STEP	2026-11-01T16:59:57.5925525Z # stale reference to moved section: Conformance tiers
Validate	UNKNOWN STEP	2026-11-01T17:03:08.0620924Z make: *** [Makefile:116: test-scripts] Error 1
Validate	UNKNOWN STEP	2026-11-01T17:03:08.0627716Z ##[error]Process completed with exit code 2.

## Evidence: failing test reproduction (AC-037-03-01)

command: bats scripts/tests/ac-037-references.bats
exit: 1
at: 2026-11-05T13:05:05Z

1..5
not ok 1 AC-037-03-01: moved-section references are repointed to the new file
# (in test file scripts/tests/ac-037-references.bats, line 44)
#   `return 1' failed
# /tmp/opencode/verify042/docs/changes/042-docs-security-hardening.md:914:is a recorded skip by contract (`docs/spec-pipeline/coder.md §Conformance tiers`,
# stale reference to moved section: Conformance tiers
ok 2 AC-037-03-02: index-section references keep the index path
ok 3 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 4 unit: the orchestrator's full-index read is intentional and documented
ok 5 unit: no moved section is still linked from the AGENTS.md one-liner

## Round verdict

**FAIL** — Self CI `Validate` fails at `scripts/tests/ac-037-references.bats`
(AC-037-03-01) on head `7dea0c2`, reproduced locally with exit 1. `Review PR /
Review PR` is the repo-wide environmental `Invalid credential` failure and is
excluded from the verdict. Phase-2 budget status: round 2 of max 3 consumed.

---

## Post-PR CI check (phase 2) — round 3

**Round 3 — attempt 1, phase 2 (post-PR) of this round; overall phase-2 round 3 (final allowed round).**
Head re-checked: `64a5dc4ae6d1b64f3dfef35e67cc931d90cfe60e` — "fix(spec-042):
repoint archived citations after the pipeline doc split", which repointed the
archived citation at line 914 from the index's `§Conformance tiers` section to
`docs/spec-pipeline/coder.md §Conformance tiers` (the destination the spec-037
moved-section map records).

Round 3 verdict: **PASS**. The pipeline may proceed. `Review PR / Review PR`
remains the repo-wide environmental `Invalid credential` failure and is excluded
from the verdict per the orchestrator's instruction.

PR: https://github.com/RexiAI/my-engineering-standards/pull/112
Head: `64a5dc4ae6d1b64f3dfef35e67cc931d90cfe60e`

| Check | Workflow / event | Bucket | Result | Check ID |
|---|---|---|---|---|
| Validate | Self CI / pull_request | pass | **PASS** | 127298855391 |
| Validate | Self CI / push | pass | **PASS** | 127298812534 |
| Review PR / Review PR | PR Review Agent / pull_request | fail | excluded — environmental (`Invalid credential`) | 127298870220 |

**Whole-run verification (both Self CI `Validate` runs on `64a5dc4`):** all 36
reported steps succeeded; zero skipped or failed steps. That includes the
previously-failing step 30 "Run shell gate bats tests (spec 001 Track B)" as well
as steps 31–33 ("Run gate selftests", "Check scenario traceability (live tree)",
"Validate YAML syntax") that were skipped behind it in round 2. No step was
left unexecuted.

## Evidence: post-PR CI check (round 3)

command: gh pr checks 112 --json name,state,bucket,workflow,link
exit: 0
at: 2026-11-05T14:57:12Z

[{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/42043123552/job/127298870220","name":"Review PR / Review PR","state":"FAILURE","workflow":"PR Review Agent"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/42043123108/job/127298855391","name":"Validate","state":"SUCCESS","workflow":"Self CI"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/42043110582/job/127298812534","name":"Validate","state":"SUCCESS","workflow":"Self CI"}]

## Evidence: check IDs for head 64a5dc4

command: gh api repos/RexiAI/my-engineering-standards/commits/64a5dc4ae6d1b64f3dfef35e67cc931d90cfe60e/check-runs --jq '.check_runs[] | "\(.name) | id=\(.id) | \(.status)/\(.conclusion) | \(.details_url)"'
exit: 0
at: 2026-11-05T14:57:12Z

Review PR / Review PR | id=127298870220 | completed/failure | https://github.com/RexiAI/my-engineering-standards/actions/runs/42043123552/job/127298870220
Validate | id=127298855391 | completed/success | https://github.com/RexiAI/my-engineering-standards/actions/runs/42043123108/job/127298855391
Validate | id=127298812534 | completed/success | https://github.com/RexiAI/my-engineering-standards/actions/runs/42043110582/job/127298812534

## Evidence: whole Validate run step inventory (both events)

command: for r in 42043123108 42043110582; do gh run view $r --json headSha,event,conclusion,status,workflowName,jobs --jq '"sha=\(.headSha) event=\(.event) workflow=\(.workflowName) conclusion=\(.conclusion) status=\(.status)", (.jobs[] | "job=\(.name) conclusion=\(.conclusion) steps=\(.steps|length) non_success=\([.steps[]|select(.conclusion != "success")|"\(.number):\(.name):\(.conclusion)"]|join(", "))")'; done
exit: 0
at: 2026-11-05T14:57:16Z

--- run 42043123108 ---
sha=64a5dc4ae6d1b64f3dfef35e67cc931d90cfe60e event=pull_request workflow=Self CI conclusion=success status=completed
job=Validate conclusion=success steps=36 non_success=
--- run 42043110582 ---
sha=64a5dc4ae6d1b64f3dfef35e67cc931d90cfe60e event=push workflow=Self CI conclusion=success status=completed
job=Validate conclusion=success steps=36 non_success=

## Evidence: previously-failing test reproduction (AC-037-03-01)

command: bats scripts/tests/ac-037-references.bats
exit: 0
at: 2026-11-05T14:57:16Z

1..5
ok 1 AC-037-03-01: moved-section references are repointed to the new file
ok 2 AC-037-03-02: index-section references keep the index path
ok 3 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 4 unit: the orchestrator's full-index read is intentional and documented
ok 5 unit: no moved section is still linked from the AGENTS.md one-liner

## Evidence: previously-failing CI step re-run (make test-scripts)

command: make test-scripts
exit: 0
at: 2026-11-05T14:57:22Z

Checking bats assertions are not vacuous...
Running bats tests (TAP)...
ok 1 ... (848 passing assertions, 0 `not ok`)
ok 848 unit: successful under-cap call writes no reason line at all

## Round verdict

**PASS** — both Self CI `Validate` runs on head `64a5dc4` are fully green (36/36
steps success, including the previously-failing step 30 and the steps 31–33 that
were skipped in round 2). The round-2 finding is reproduced locally as fixed:
`bats scripts/tests/ac-037-references.bats` exits 0 and `make test-scripts` exits
0 with 848 passing / 0 failing assertions. `Review PR / Review PR`
(id `127298870220`) is the repo-wide environmental `Invalid credential` failure,
excluded. Phase-2 budget status: round 3 of max 3 consumed — PASS, no further
fix routed.
