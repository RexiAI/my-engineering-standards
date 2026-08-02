# [1.11.0](https://github.com/RexiAI/my-engineering-standards/compare/v1.10.0...v1.11.0) (2026-08-02)


### Features

* **deploy:** production deployment via Kamal, Dokku, or SSH + Compose ([#9](https://github.com/RexiAI/my-engineering-standards/issues/9)) ([51b1a0b](https://github.com/RexiAI/my-engineering-standards/commit/51b1a0bc624d935420a6724338cfada9e978e4b6))

# [1.10.0](https://github.com/RexiAI/my-engineering-standards/compare/v1.9.0...v1.10.0) (2026-08-02)


### Features

* adopt trunk-based dev, semver via CI, PR-only workflow ([#7](https://github.com/RexiAI/my-engineering-standards/issues/7)) ([2441043](https://github.com/RexiAI/my-engineering-standards/commit/2441043d8328d30db36f982fed65cfb0b84aea7b))

# Changelog

## [1.9.0] — 2026-08-02

### Added

- **`skills/hallmark/`** — Hallmark anti-AI-slop design skill v1.2.0 vendored (108 files). Full design system for greenfield pages, audits, redesigns, and DNA extraction from URLs or screenshots. Features: 21 macrostructures, 20 catalog themes, 4 genres, 66-gate slop test, 50-archetype component cookbook, 14 nav archetypes, 8 footer archetypes, variable font + motion + upgrade-technique library.
- **`skills/hallmark/references/code-quality.md`** — new reference (merged from `redesign-existing-projects`). Covers semantic HTML (div soup, skip-to-content), CSS hygiene (inline styles, hardcoded pixels, z-index scale, `transition-all`), JS quality (import hallucinations, dead code), and `<head>` completeness (meta tags). Loaded by `hallmark audit` on existing-project targets only.
- **`skills/hallmark/references/strategic-omissions.md`** — new reference. Covers back navigation, active nav indicator, form validation, dead `#` links, legal links, cookie consent, custom 404, empty states, loading states. Loaded by `hallmark audit` on existing-project targets only.
- **`skills/hallmark/references/upgrade-techniques.md`** — new reference. 14 high-impact upgrade techniques across typography (variable font animation, outlined-to-fill, text mask reveals), layout (broken grid, whitespace maximisation, parallax card stacks, split-screen scroll), motion (Lenis smooth scroll, staggered entry, spring physics, scroll-driven reveals), and surface (true glassmorphism, spotlight borders, grain/noise overlays). Each technique includes when-to-use, when-NOT-to-use, implementation sketch, and `prefers-reduced-motion` fallback. Loaded during default Design flow and `hallmark redesign`.

### Changed

- `skills/hallmark/references/anti-patterns.md` — +200 lines of new named tells, merged from `redesign-existing-projects`: surface/depth tells (oversaturated accent, mixed warm/cool grays, generic box-shadow, lighting inconsistency, random dark-section inversion, empty flat sections); layout tells (`height: 100vh`, flexbox-% math, forced-equal-height cards, uniform border-radius, no overlap/depth, symmetrical vertical padding, dashboard always-left-sidebar, buttons not bottom-aligned in card groups, feature lists at different vertical positions, inconsistent vertical rhythm, optical vs mathematical alignment); typography tells (only 400/700 weights, all-caps subheaders everywhere, orphaned words, missing letter-spacing adjustments); component tells (rocketship/shield icon clichés, pill "New"/"Beta" badges, accordion FAQ as default, 3-card carousel testimonials, avatar circles only, sun/moon toggle cliché, modals for everything); iconography tells (inconsistent stroke widths, missing favicon); content tells (AI copywriting clichés, fake round numbers).
- `skills/hallmark/references/slop-test.md` — 58 → 66 gates. New gates 58–65: dark-section inversion (58), dead `#` links (59), `height: 100vh` (60), buttons not bottom-aligned in card groups (61), div soup (62), missing alt text on meaningful images (63), orphaned words without `text-wrap: balance` (64), oversaturated accent chroma (65).
- `skills/hallmark/references/verbs/audit.md` — added 7-step fix priority ordering (font → colour → hover states → layout → components → states → typography polish); added conditional load instructions for `code-quality.md` and `strategic-omissions.md` on existing-project audits.
- `skills/hallmark/references/verbs/redesign.md` — added `upgrade-techniques.md` load + 1–3 technique selection step for single-page redesigns.
- `skills/hallmark/SKILL.md` — version 1.1.0 → 1.2.0; gate count references 58 → 66; load inventory updated with three new conditional-load entries.
- `README.md` — `skills/` tree updated to include hallmark entry.

### Removed

- **`~/.agents/skills/redesign-existing-projects/`** — retired standalone skill. All unique content merged into `skills/hallmark/` (see above). No functionality lost.

## [1.8.0] — 2026-08-02

### Added

- **`agents/spec-ux.md`** — new stage 1.5 of the spec pipeline, between Specifier and the human gate. UX Designer: loads the `design-taste-frontend` skill, runs brief inference, sets three dial values (`DESIGN_VARIANCE`, `MOTION_INTENSITY`, `VISUAL_DENSITY`), and writes per-task layout/component/typography/motion/a11y directives to `specs/NNN-slug/15-design.md`. Skips automatically when the spec has no frontend surface (backend, CLI, API). Blocks with a single clarifying question when frontend surface is ambiguous. Never commits or pushes.
- **`skills/design-taste-frontend/SKILL.md`** — anti-slop frontend design skill vendored from local installation. Covers brief inference, dial configuration, design system selection, typography/color/layout rules, motion specs, accessibility guardrails, AI-tell bans, redesign protocol, and a 60-item pre-flight checklist. Vendored (not symlinked from `~/.opencode/skills/`) so the skill is versioned, distributed with the submodule, and consistent across all developer machines and CI environments.

### Changed

- `agents/spec-pipeline.md` — `/spec` flow now runs Specifier → `spec-ux` (conditional) → human gate. BLOCKED relayed as-is; SKIPPED noted. `15-design.md` path printed alongside `10-tasks.md` and `20-acceptance/` at the gate.
- `agents/spec-coder.md` — reads `15-design.md` when present and follows its per-task directives as requirements (same weight as acceptance criteria). Info barrier unchanged: `00-informal.md` still denied.
- `docs/SPEC_PIPELINE.md` — stage table, artifact layout (`15-design.md`), information-barrier table (`spec-ux` row), conformance-tier table, and model config example updated for the new stage. Model-split rationale updated: UX Designer added to the strong-model tier alongside Specifier/Verifier/Architect.
- `scripts/bootstrap.sh` — step 3c added: symlinks `skills/` → `.opencode/skills/` by default, or copies with `--copy-agents`, same guard pattern as agents/commands.
- `opencode.json` — `spec-ux` pinned to `github-copilot/claude-opus-5` (aesthetic judgment work, same tier as Specifier).
- `README.md` — structure tree updated: `agents/` section expanded with all seven agents; `skills/` section added.

## [1.7.0] — 2026-07-30

### Added

- **`agents/spec-verifier.md`** — new stage 4 of the spec pipeline, between Refactorer and Architect. Independent QA: re-runs the real test suite, real linter/complexity gate, and `scripts/check-scenario-traceability.sh` itself rather than trusting Coder/Refactorer's self-reported "green," and spot-checks that at least two acceptance tests' assertions actually match their scenario. Writes only `specs/NNN-slug/25-verification.md`; fixes nothing, never commits or pushes (`git commit*`/`git push*` denied in its permissions). Architect now requires the Verifier's PASS verdict before running mutation testing or any commit.
- **`opencode.json`** — this repo's own agent model pins (opus-5 for Specifier/Verifier/Architect, sonnet-5 for Coder/Refactorer/Pipeline). Not shipped to consumers; a worked example of the override pattern documented in `docs/SPEC_PIPELINE.md §Model configuration`.
- **`scripts/bootstrap.sh --copy-agents`**, **`templates/Makefile.bridge`'s `COPY_AGENTS=1 make init-ai`** — copies `agents/`/`commands/` as real, editable files instead of symlinking, for consumers who want to customize an agent's prompt/permissions (not just its model via `opencode.json`). Refuses to clobber an existing symlink or real directory; verified idempotent and correctly branching in a real sandbox run (both flag and no-flag paths, fresh and re-run).

### Changed

- `agents/spec-architect.md` — now stage 5 (was 4). Scenario traceability gate moved to the Verifier; Architect's own gates are mutation testing + a final full-suite re-run of its own new mutant-killing tests.
- `agents/spec-pipeline.md`, `commands/build.md` — orchestration updated to `spec-coder → spec-refactorer → spec-verifier → spec-architect`; `/build` stops if the Verifier's verdict is FAIL rather than running Architect anyway.
- `agent/` renamed to `agents/`, `command/` renamed to `commands/` (matches opencode's documented plural spelling; singular was soft-deprecated backwards-compat). All five original agents renamed with a `spec-` prefix (`spec-pipeline`, `spec-specifier`, `spec-coder`, `spec-refactorer`, `spec-architect`) to eliminate name collisions with unrelated global/project agents — this is what actually caused the v1.6.0 model-collision bug (an unpinned `architect` subagent silently inherited a stale model id from an unrelated pre-existing global `architect.md`; namespacing prevents the whole class instead of just this instance).
- **`model:` removed from all six shipped agents.** Verified via `opencode debug config` in a throwaway sandbox that an agent `.md` omitting `model:` lets a consumer's own `opencode.json` (`agent.<name>.model`) apply; a `.md` that pins `model:` silently wins over `opencode.json` instead (`.opencode/agents/` is loaded after `opencode.json` in precedence, so a pinned `.md` value cannot be overridden by project config — only `OPENCODE_CONFIG_CONTENT`/`OPENCODE_CONFIG_DIR` could). Shipping unpinned means subagents inherit the consumer's own primary model with zero vendor coupling, by default. This repo pins its own per-stage models locally in `opencode.json` (not shipped to consumers): `spec-specifier`, `spec-verifier`, `spec-architect` → `github-copilot/claude-opus-5` (ambiguity detection, adversarial QA, mutation reasoning + git authority); `spec-coder`, `spec-refactorer`, `spec-pipeline` → `github-copilot/claude-sonnet-5`.
- `docs/SPEC_PIPELINE.md` gains a **Model configuration** section documenting the above, including the explicit warning that pinning `model:` in a shipped agent file (rather than this repo's own local `opencode.json`) breaks consumer overrides.
- `docs/SPEC_PIPELINE.md` — stage table, artifact layout (`25-verification.md`), information-barrier table, conformance-tier table, and commit carve-out all updated for the five-agent (six-stage-counting-stage-0) pipeline. Added `§Why a separate Verifier stage`, explaining the gap this closes: no agent's sole job was independently re-checking a prior stage's claims — that verification was happening only because a human (this session) manually re-ran every tool by hand.

### Fixed

- **Dogfood symlinks (`.opencode/agent`, `.opencode/command`) left dangling by the rename** — pointed at the old `agent`/`command` directory names after `git mv agent agents` / `git mv command commands`; `opencode debug config` showed the model resolving but `permission`/`prompt` fields silently empty (broken symlink target, not a real merge failure). Caught only by actually running `opencode debug config` against the real resolved config, not by re-reading the renamed files. Recreated as `.opencode/agents -> ../agents`, `.opencode/commands -> ../commands`; re-verified full permission/prompt/model resolution afterward.

## [1.6.0] — 2026-07-29

### Added

- **Spec Pipeline** (`docs/SPEC_PIPELINE.md`) — a five-stage pipeline (Specifier, Coder, Refactorer, Architect, plus you writing stage 0) that turns an informal spec into a mutation-tested, gated draft PR, based on Robert C. Martin's agent-pipeline description. Adapted to this repo's languages: no Cucumber/Gherkin runner (structured markdown scenarios with `AC-NNN-NN` IDs instead — zero new dependencies, consistent with this repo's "prefer stdlib, justify each dependency" rule), no scenario-mutation harness (a traceability gate script instead — no such tooling exists for Java/Go/JS/TS). Runs fewer stages at lower conformance tiers instead of being all-or-nothing.
- **`agent/{pipeline,specifier,coder,refactorer,architect}.md`** — the pipeline's agents. The Coder and Architect cannot read `specs/*/00-informal.md`, and the Refactorer cannot read any of `specs/**`, enforced via `permission.read` deny rules (tool-level, not a prompt instruction) — the pipeline's core discipline that a Coder must reason from formalized tasks and scenarios, not fill ambiguity from your original loose prose.
- **`command/{spec,build}.md`** — `/spec` runs the Specifier and stops for human review (the pipeline's one designed interruption); `/build` runs Coder → Refactorer → Architect to a draft PR.
- **`scripts/check-scenario-traceability.sh`** — every acceptance scenario ID must be cited by a test, every test's cited ID must resolve to a real scenario. Catches an orphaned or never-implemented scenario without needing a scenario-mutation harness.
- **`ci/templates/pitest-profile.xml`**, **`ci/templates/stryker.conf.json`**, **`ci/templates/mutation.mk`** — mutation testing configs `docs/TESTING.md` had referenced since 1.0.0 but never actually shipped (it claimed PiTest was "configured in parent POM" — no parent POM exists in this repo). Go mutation testing now targets Gremlins, not `go-mutesting` — actively maintained and coverage-aware where `go-mutesting` is neither.
- **`docs/TESTING.md §Property Testing`** — jqwik (Java), stdlib `testing/quick` (Go, zero new dependency), fast-check (JS/TS). Tiered `production`, consumed by the Refactorer stage.
- **Cyclomatic complexity gate, ≤6** — PMD `CyclomaticComplexity`/`CognitiveComplexity` (Java), golangci `cyclop`/`gocognit` (Go), ESLint `complexity` (JS/TS), exempted for test files where table-driven tests legitimately run higher. Stated in `docs/CODING_CONVENTIONS.md`, consumed by the Refactorer stage.
- **Commit/push carve-out for pipeline agents** (`AGENTS.md`) — the Architect stage may commit, push, and open a draft PR unattended, narrowly scoped to a `spec/NNN-slug` branch and only after every configured gate is green. No other agent gets this exception.
- Testing's three-layer table becomes four: an **Acceptance** layer sits between Unit and Integration — the tests the Coder stage produces from acceptance scenarios, in the project's existing test framework, no new runtime.

### Changed

- `scripts/bootstrap.sh` now symlinks `.opencode/agent` and `.opencode/command` to this repo's `agent/` and `command/`, alongside the existing `AGENTS.md` and `okf/` symlinks — the pipeline ships to every child repo on submodule update, no per-repo setup.
- `templates/Makefile.bridge`'s `init-ai` target — the manual, non-`bootstrap.sh` setup path — updated to match: now also symlinks `okf/`, `.opencode/agent`, and `.opencode/command`. Found via `docs/SPEC_PIPELINE.md` live-fire testing that the two setup paths had drifted; both now deliver the same result.
- `templates/opencode.json.bridge` adds `docs/SPEC_PIPELINE.md` to `instructions`.
- `docs/CONFORMANCE_TIERS.md` gains a Property Testing row; the Mutation Testing row's tool list updated from `go-mutesting` to `Gremlins`.
- `templates/PULL_REQUEST_TEMPLATE.md` gains a checklist row for scenario traceability + mutation score, conditioned on the change having gone through the spec pipeline.

### Fixed

- **`typecheck` removed from `language-specific/go/golangci.yml`'s enabled linters** — invalid in golangci-lint v2 ("not a linter, cannot be enabled"), found via this release's live-fire testing (`docs/SPEC_PIPELINE.md` requires running the pipeline against a real repo, not just validating the diff). A larger pre-existing issue was also found and left for separate follow-up: `gofmt`/`gci`/`goimports` under `linters.enable` and the `gosimple`/`stylecheck` merge into `staticcheck` are both stale v2 migration gaps in the same file — see the comment left at the top of `golangci.yml`.
- **`ci/templates/stryker.conf.json` stripped of `//` comments** — `.json` is not JSONC; a real `npx stryker run` against the file as shipped failed with `SyntaxError: Unexpected token '/'` before running a single mutant. Usage/target guidance was already duplicated in `docs/TESTING.md`, so nothing was lost by removing the header block. Found and confirmed via live-fire testing (real `@stryker-mutator/core` install, not a syntax read).
- **`ci/templates/pitest-profile.xml` missing `pitest-junit5-plugin` dependency** — a real `mvn verify -Pmutation` against the file as shipped failed with `"Pitest could not run any tests"` (PIT does not detect JUnit 5 tests without this plugin; JUnit 4 works without it). Added the dependency (`org.pitest:pitest-junit5-plugin:1.2.1`) under the `pitest-maven` plugin's `<dependencies>`. Re-verified: real mutants generated, killed, and threshold correctly enforced (build fails below 80%, passes at/above it).
- **`language-specific/java/pmd-rules.xml` — three dead exclude patterns** — `DefaultPackage` (duplicate of the already-excluded `CommentDefaultAccessModifier`, removed), `BeanMembersShouldSerialize` → renamed `NonSerializableClass`, `DataflowAnomalyAnalysis` → renamed `UnusedAssignment` (moved category: `bestpractices`, not `errorprone`). All three were silently no-ops under real PMD 7.9.0 (`[WARN] Exclude pattern ... did not match any rule`) — found by running the shared ruleset with the actual `pmd` CLI, not by reading the XML.

## [1.5.0] — 2026-07-28

### Added

- **Conformance tiers** (`docs/CONFORMANCE_TIERS.md`) — `mvp` / `production` / `multi-service`. A project declares its tier once; rules tagged above that tier are out of scope, not a gap. Tagged: Pact contract testing (`multi-service`), mutation testing / ZAP DAST / weekly-E2E-against-staging / SonarQube gate / distributed tracing / full observability / circuit breaker+retry / secrets manager / mandatory-reviewer (`production`).
- **Toolchain version manifests replace hardcoded CI versions (GitHub side; GitLab deferred — no consumer yet)** — `go-version-file`/`node-version-file` inputs added to `backend/ci-{go,node}.yml`, `frontend/ci-{nextjs,react,angular}.yml`; `backend/ci-java.yml` gained a `resolve-version` job since `actions/setup-java` has no native version-file input; `shared/ci-contract.yml` now always resolves from `go.mod`/`.nvmrc`/`.java-version`. Existing hardcoded defaults (`"1.26"`/`"22"`/`"21"`) kept as fallback for consumers without a manifest file yet — only `go-version-file` changes the *default* behavior (every Go module already has a `go.mod`, so this is non-breaking); Node/Java keep opt-in until a consumer adds the manifest file. `templates/Dockerfile.{go,node,next}` gained `ARG GO_VERSION`/`ARG NODE_VERSION` build args instead of hardcoded `FROM` tags. See docs/CI_CD.md §Toolchain Versions.
- **`shared/ci-toolchain-bump.yml`** — new reusable workflow, weekly by default. Queries go.dev/nodejs.org/actions-python-versions for the latest stable/LTS release per manifest present in the consumer repo, rewrites the manifest, opens a PR. Skips any manifest that doesn't exist — safe to add regardless of which languages a consumer uses. The same automation model Dependabot uses for libraries, applied to the runtime itself. Verified end-to-end against live endpoints and against synthetic `go.mod` fixtures (both the plain-`go`-line and `go`+`toolchain`-line cases) before merge.
- **Upstream error responses must not reach the client** (`docs/SECURITY.md`) — a third-party provider's raw error body can leak partial credentials or account details; the existing "mask secrets in logs" rule doesn't cover forwarding the body to your own client.
- **Tri-state quality gate verdicts** (`docs/DEPLOYMENT.md`) — `0 APPROVED` / `1 CONDITIONAL` / `2 REJECTED`, replacing a binary pass/fail that forced every advisory signal to be either dropped or treated as a hard blocker.
- **Stale-compiled-artifact rule** (`docs/DEPLOYMENT.md`) — restarting a container doesn't rebuild the binary inside it; state the rebuild step explicitly wherever a runbook or Makefile target lives.
- **Git Hooks: Local Enforcement** (`docs/GIT_WORKFLOW.md`) — `core.hooksPath` over `.git/hooks/`, pre-commit/pre-push cost split with a stated time budget, pre-push against a detached worktree at the pushed SHA (not the working tree — eliminates dirty-tree false greens), correct pre-push stdin protocol handling (parse the real 4-field lines, skip ref deletions, dedup SHAs, fail-safe on new refs), path-pattern gating for expensive suites, `SKIP_HOOKS=1` over `--no-verify`.
- **E2E practices** (`docs/TESTING.md`) — one script run by both CI and local dev (the only CI/local difference expressible as a single env var), readiness polling instead of fixed sleeps, exit-status-preserving cleanup traps that dump logs only on failure, bounded and justified flake retries. E2E cadence is now tier-gated: `mvp` projects with no staging environment run E2E on every push; `production`+ projects keep it weekly and let contract tests cover PRs.
- **CI failure diagnostics for agent consumers** (`docs/TESTING.md`) — an AI agent driving CI fixes via an API can typically read PR comments but not raw Actions logs; post a byte-bounded, collapsed diagnostic comment on failure instead of leaving it opaque.
- **Comment the why** (`docs/CODING_CONVENTIONS.md`) — a one-line workaround earns a multi-line comment naming the incident or trap it avoids; a comment restating the code below it is noise.
- **Verify agent-delivered work against the live system** (`AGENTS.md`) — a diff that compiles and a diff that works are different claims; field-name mismatches and auth-header mistakes are exactly the class of bug that looks right in a diff and fails on the first real request.

### Changed

- **`log/slog` replaces `zerolog` as the default Go logging library** (`docs/CODING_CONVENTIONS.md`, `language-specific/go/AGENTS.md`) — `slog` has been in the stdlib since Go 1.21, so it's the "prefer stdlib" default rather than an added dependency. Existing zerolog projects don't need to migrate.
- **`cmd/<binary>/main.go` + `internal/` replaces `src/` as the standard Go project layout** (`language-specific/go/AGENTS.md`, `docs/DEPLOYMENT.md`, `templates/Dockerfile.go`) — `internal/` gives compiler-enforced encapsulation a plain `src/` tree can't; `cmd/` is the idiomatic layout for a module producing one or more binaries. `dependency_injection.go` moves under `internal/`.
- **`testify`/`gomock` demoted from default to optional** (`docs/TESTING.md`, `language-specific/go/AGENTS.md`) — the previous blanket "use testify/gomock" guidance contradicted `docs/CODING_CONVENTIONS.md`'s "prefer stdlib, justify each dependency" rule. Stdlib `testing` is now the default; either library remains a fine addition when a project's test complexity justifies it.
- **golangci-lint config absorbed hardening** (`language-specific/go/golangci.yml`) — `max-issues-per-linter: 0` / `max-same-issues: 0` (defaults of 50/3 hide work), `gosec.confidence: low` (widens, doesn't narrows, findings), `gochecknoglobals`/`gochecknoinits` enabled, `gofumpt extra-rules: true`, expanded `_test.go` linter relaxation set (`errcheck`, `gosec`, `gochecknoglobals`, `gochecknoinits` added to the existing `bodyclose`/`noctx`).
- **`make ci-fast` / `make ci` / `make ci-full` gate ladder documented as the standard Go command set** (`language-specific/go/AGENTS.md`) — each rung defined by the infrastructure it needs; CI and git hooks call the same targets instead of duplicating command lists in YAML.
- **`go test -race -shuffle=on -count=1`** is now the documented standard test invocation (`language-specific/go/AGENTS.md`).

## [1.4.1] — 2026-07-28

### Fixed

- **CRLF regression from v1.4.0** — the v1.3.1 "CRLF checkout" fix renormalized this repo while `core.autocrlf=true` was still set globally and `.gitattributes` covered only `*.sh`/`Makefile*`/`*.go`. Every other tracked file (`docs/`, `okf/`, all 13 reusable workflows, ArchUnit `.java`, integration test templates, `prettier.config.js` — which itself declares `endOfLine: 'lf'` — etc.) got committed as CRLF: 84/113 files, verified by inspecting raw committed blobs (v1.3.0 was 0/113). `.gitattributes` now reads `* text=auto eol=lf` first, `*.bat text eol=crlf` added; repo renormalized. Consumers who copied any of those 84 files out of `.standards` between v1.4.0 and this release should re-copy or strip `\r`.
- **Self-CI could not have caught this** — `bash -n` only touches `*.sh`, and PyYAML tolerates CRLF. Added a blob-level CRLF guard job to `self-ci.yml` that inspects `git cat-file blob` directly (bypasses local `core.autocrlf` smudging) so this class of regression fails CI going forward.

## [1.4.0] — 2026-07-28

### Added

- **Self-CI workflow** — `.github/workflows/self-ci.yml` (root-level, so GitHub Actions actually discovers it — the 13 existing workflows are all `workflow_call`-only reusables and never ran on this repo itself). Runs `bash -n` on every shell script, `make validate-all`, `make lint`, advisory `shellcheck`, and a scoped YAML syntax check on push/PR.
- **`templates/Dockerfile.next`** — Next.js standalone-output Dockerfile; the JS AGENTS.md documented ~150 lines of Next.js conventions with no corresponding Dockerfile.

### Fixed

- **Config drift** — `language-specific/javascript/eslint.config.js` rewritten as a real ESLint 9 flat config (was legacy `.eslintrc` schema under a flat-config filename); `language-specific/go/golangci.yml` migrated to v2 schema for Go 1.26 (dropped removed/deprecated linters); `templates/Dockerfile.spring` fixed for its actual Amazon Corretto/AL2023 base (`dnf` not `yum`, `useradd` not Debian `adduser`, `launch.JarLauncher` for Boot 3.2+, `/actuator/health`).
- **Doc contradictions reconciled against real CI** (not guessed) across `docs/MESSAGE_DELIVERY.md`, `docs/OUTBOX_PATTERN.md`, `docs/TESTING.md`, `docs/CI_CD.md`, `docs/DEPLOYMENT.md`, `docs/SECURITY.md`: retry defaults, dedup TTL rationale, E2E cadence, Java lint tool, coverage-gate strictness, artifact publishing target, security tooling table.
- **`templates/` bugs** — `Makefile.bridge`'s success message was tab-indented under the wrong target; its Go branch copied `golangci.yml` under the wrong filename; `init-ai` now copies the session hygiene scripts itself so `session-check`'s own error message is accurate; `session-end-check.sh`'s debug-artifact check now `warn()`s instead of unconditionally `pass()`-ing; `session-start-check.sh` no longer swallows npm lint failures; `PULL_REQUEST_TEMPLATE.md` checklist updated for saga/outbox gates, ADRs, and session-end-check.
- **Saga/outbox gate script precision** — `check-outbox-relay.sh` no longer counts test-file dedup mentions as production dedup; `check-saga-timeouts.sh`'s Go branch scoped from repo-wide to same-file-or-same-directory per handler; `lint-outbox-schema.sh` now isolates the outbox `CREATE TABLE` block before matching required columns instead of matching anywhere in the file; `check-saga-tests.sh`'s compensation-detection regex dropped overly generic alternatives that matched almost any failure-related text.
- **`VERSION`/`CHANGELOG.md` catch-up** and `AGENTS.md`'s stale `Saga+OutboxArchRules.java` reference (the two real files are named separately); `Makefile`'s malformed `help` output and missing `release` in `.PHONY`.

## [1.3.1] — 2026-07-28

### Fixes

- **CRLF checkout** — added `.gitattributes` (`*.sh`, `Makefile*`, `*.go` → LF), unset `core.autocrlf`, renormalized repo; all shell scripts were failing `bash -n` due to CRLF line endings
- **Saga gate GitHub/GitLab mismatch** — removed dead `with-saga-gates` input from `init-ci.sh` and `child-ci-*.yml` templates (GitHub Actions has no saga gate job; feature is GitLab-only); fixed `DEPLOYMENT.md`'s false claim; fixed duplicate `backend-ci:` YAML key bug
- **bootstrap.sh → init-ci.sh call** — fixed wrong `--languages` flag and mangled `CI_PLATFORM` string (`githubactions`) that matched no case arm
- **Missing GitLab jobs** — added missing `.java-lint` job (`mvn spotless:check`); fixed `init-ci.sh` `--frontend static` to only emit lint/docker jobs (unit/build are undefined for static)
- **Gate script arg-dropping** — `fail()`/`pass()`/`warn()` in the 4 gate scripts (`check-saga-timeouts.sh`, `check-saga-tests.sh`, `lint-outbox-schema.sh`, `check-outbox-relay.sh`) used `$1`, dropping every arg after the first; remediation guidance never printed. Switched to `$*`
- **check-saga-tests.sh false-PASS** — recovery/persistence check ran outside the `SAGA_TEST_FILES` guard, so an empty file list made `grep -r` default to `.` and false-PASS off an unrelated repo-wide scan; moved inside the guard and changed `grep -r` → `-l` to match its siblings
- **update-submodules.sh subshell bug** — `continue` inside a `( cd $repo; ... )` subshell is a no-op under bash, so repos without a `.standards` submodule (or with one uninitialized) fell through to submodule update/commit; changed to `exit 0`. Also fixed `get_repos`' error message and `exit 1` being swallowed by `$( )` command substitution
- **Non-interactive stdin hangs** — `init-ci.sh`/`bootstrap.sh`'s `collect_secrets()` and the backend/frontend `select` prompts blocked forever on closed/non-tty stdin; guarded all three on `[ -t 0 ]`, defaulting to skip/none. Also fixed `init-ci.sh`'s `[ -n "$FRONTEND" ] && info ...` returning 1 (under `set -e`) on the normal "no frontend" case

## [1.3.0] — 2026-07-12

### Features

- **Saga/Outbox CI quality gates** — `scripts/detect-saga-outbox.sh` (sets `SAGA_DETECTED`/`OUTBOX_DETECTED` from changed files) plus 4 gate scripts: `check-saga-timeouts.sh`, `check-saga-tests.sh`, `lint-outbox-schema.sh`, `check-outbox-relay.sh`
- **ArchUnit rules** — `ci/templates/archunit/SagaArchRules.java` + `ci/templates/archunit/OutboxArchRules.java` (9 structural rules: compensation, `@Transactional`, no direct broker, dedup)
- **Go AST lint** — `ci/templates/go-saga-lint.go` (checks compensation func, `WithTimeout`, no direct broker in saga files)
- **Node ESLint plugin** — `ci/templates/eslint-saga-rules/saga-compensation.js` (`sagaStep()` must declare `compensate` and `timeout`)
- **Integration test templates** — Java/Go/Node × Saga/Outbox under `ci/templates/tests/`
- **init-ci.sh --with-saga** — wires the gates into `ci-java.yml`/`ci-go.yml`/`ci-node.yml` and the child-ci templates
- Updated `docs/SAGA_PATTERN.md`, `docs/OUTBOX_PATTERN.md`, `docs/DEPLOYMENT.md` with CI Quality Gates sections; updated root and language-specific `AGENTS.md` with gate rules

## [1.2.0] — 2026-07-11

### Features

- **Session Hygiene** — `templates/session-start-check.sh` (fail-fast: git clean, lint, tests) and `templates/session-end-check.sh` (full suite, debug artifact scan, Talisman)
- **bootstrap.sh** — auto-copies session hygiene scripts to child projects
- **GIT_WORKFLOW.md** — new "Session Hygiene" section with start/end procedures
- **Makefile.bridge** — `make session-check` / `make session-end` targets

## [1.1.0] — 2026-07-11

### Features

- **OKF (Operational Knowledge Framework) v0.1** — `okf/` directory with 4 linked concept docs for AI-work practices
- **Context Window Policy** — caveman, RTK, headroom, ponytail: how we keep sessions viable 3-5x longer
- **RAG vs Context Stuffing decision** — default to stuffing <50KB, RAG for larger/fresher/semantic queries
- **Detect Context Rot runbook** — 4-metric table + recovery procedure for degrading sessions
- **MCP Server Connection runbook** — pattern + 3 worked examples (GitHub, MyInvestor, Headroom)
- **bootstrap.sh** — now symlinks `okf/` into child repos via `.standards/okf -> okf`
- **opencode.json.bridge** — includes 4 OKF instruction paths

### Refactors

- **bootstrap.sh** — renumbered steps, added OKF symlink, updated next-steps
- **README** — added OKF structure tree + usage section

## [1.0.0] — 2026-07-11

### Features

- **Initial engineering standards** — architecture, testing, deployment, security, and Git workflow
- **12 new architecture docs** — RESILIENCE, IDEMPOTENCY, OBSERVABILITY, SAGA, OUTBOX, SCHEMA_EVOLUTION, CONTRACT_TESTING, EVENTUAL_CONSISTENCY, MESSAGE_DELIVERY, DATA_STORAGE_DECISIONS, SCALABILITY, STREAM_PROCESSING
- **ADR template** — lightweight decision records (`templates/ADR.md`)
- **Composable CI/CD** — orthogonal backend + frontend + shared reusable workflows (GitHub Actions)
- **Frontend CI templates** — Next.js, React (Vite), Angular, Static HTML
- **Shared CI templates** — contract tests (Pact), security scan (CodeQL + Trivy), E2E (Docker Compose)
- **GitLab CI parity** — mirrored structure with backend, frontend, and shared templates
- **No-auto-push and plan-commit rules** — safety guards for agent-based workflows
- **Budget-friendly, vendor-neutral CI/CD** — GHCR default registry, no cloud lock-in

### Refactors

- **Composable CI architecture** — monolithic per-language workflows split into orthogonal backend/frontend/shared jobs
- **Testing standards** — inheritance → composition patterns, in-memory integration tests
- **Vendor references generalized** — company-specific names → generic
- **Express → NestJS** — backend convention switch
- **Correlation ID → Trace ID** — W3C trace context standard
- **Service tests → E2E** — consistent naming

### Chores

- Go 1.20 → 1.26 (LTS)
- Java 17 → 21 (LTS)
- Node.js 18 → 22 (LTS)
- `.serena` removed
- Company-specific and `sss` references cleaned
- golangci.yml: `enable-all` → explicit linter list
- Pact Broker URL moved from input to secret

### Fixes

- Service tests renamed to E2E
- Mutation testing added to validation pipeline

### Notes

- `@main` refs for `uses:` in child workflows
- No lock files committed — child projects manage their own
- Version file: `VERSION` (plaintext, semver)

[1.4.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.4.0
[1.3.1]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.3.1
[1.3.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.3.0
[1.2.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.2.0
[1.1.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.1.0
[1.0.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.0.0
