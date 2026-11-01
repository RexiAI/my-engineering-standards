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
