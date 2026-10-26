# Informal spec: bootstrap capability catalog

## The ask

"In the script bootstrap, you should offer all functionalities that have been
added for the backend, frontend, etc. — web, back, apps, all!"

## Current state (verified, not assumed)

`scripts/bootstrap.sh` is 356 lines. It hard-wires a fixed sequence and detects
three stacks.

**Detection today** — Java (`pom.xml`), Go (`*.go`), Node (`package.json`). It
then calls `init-ci.sh --backend "$LANG_DETECTED"`. A React app is detected as
`node` and wired as a **backend**; `--frontend` is never passed. Python and Rust
have guides (`language-specific/python`, `language-specific/rust`) and
**self-contained child templates** (`ci/templates/child-ci-python.yml`,
`child-ci-rust.yml`) — but no reusable `ci-python.yml` / `ci-rust.yml` exists,
and bootstrap does not detect or offer either. Angular, Ionic, and React Native
have guides and reusable workflows, but bootstrap cannot select them.

**Capabilities `init-ci.sh` already accepts but bootstrap never offers:**
`--with-saga`, `--with-deploy` (+ `--deploy-tool kamal|dokku|ssh`),
`--with-release`, `--with-pr-review`, `--frontend`, `--platform both`.
Its `--backend` accepts only `java,go,node`; `--frontend` accepts
`nextjs,react,angular,react-native,static` (no Ionic).

**Shipped by this repo, wired by neither script:** reusable workflows
`ci-e2e.yml`, `ci-e2e-weekly.yml`, `ci-contract.yml`, `ci-security.yml`,
`ci-sweeper.yml`, `ci-toolchain-bump.yml`, `ci-vercel-production-verify.yml`;
mutation configs (pitest, stryker, stryker-react-native, mutmut, mutants.toml);
Pact templates for five languages; TDD feature scaffolds (java/go/js); loop
engineering files (`LOOP.md`, `loop-budget.md`, `loop-constraints.md`,
`loop-run-log.md`); `templates/SKILL.md`, `agent.md`, `gate.yaml`, `STATE.md`;
`branch-protection.md`; Docker templates; the spec pipeline (only reachable via
the non-interactive `--copy-agents` flag).

**Missing:** `--help`, `--list`, `--dry-run`, and any non-interactive way to
choose capabilities other than `--copy-agents`. The only prompt is the CI
platform select.

## Required behavior

1. **One capability catalog.** A single table — id, label, category, files
   written, required stack, conflicts — is the only source of truth. `--list`
   prints it; the menu renders from it; `--all` iterates it. No second list that
   can drift.
2. **Interactive menu on a TTY.** Multi-select, grouped: Core wiring, Backend
   stacks, Frontend/mobile stacks, CI platform, Quality gates (saga/outbox,
   contract, mutation, security, e2e, sweeper), Deploy (VPS tool or Vercel lane),
   Agent pipeline (spec pipeline, PR review, deploy verifier), Loop engineering.
   Preselect what detection found.
3. **Every capability has a non-interactive flag.** `--stack
   java|go|node|python|rust`, `--frontend
   nextjs|react|angular|ionic|react-native|static`, `--with-saga`,
   `--with-contract`, `--with-mutation`, `--with-security`, `--with-e2e`,
   `--with-sweeper`, `--with-pr-review`, `--with-release`, `--with-deploy
   kamal|dokku|ssh|vercel`, `--with-spec-pipeline`, `--with-loop`,
   `--copy-agents`, `--all`, `--none`, `--dry-run`, `--help`, `--list`.
4. **`--all` and `--none`.** `--all` enables every catalog entry compatible with
   the detected/selected stacks. `--none` is core wiring only. Incompatible
   combinations are **refused with a named reason**, never silently dropped.
   Deploy is excluded from `--all` unless a tool is named, because it needs a
   host or a linked project.
5. **Detection covers the full matrix.** Python (`pyproject.toml` /
   `requirements.txt`), Rust (`Cargo.toml`), Angular (`@angular/core`), Ionic
   (`@ionic/*`), React Native, Next.js, React, static. Detection result is
   printed with the evidence file it came from.
6. **Correct stack routing.** A frontend project passes `--frontend`, not
   `--backend node`. A repo with both passes both.
7. **`init-ci.sh` extended** so `--backend` accepts `python` and `rust` (copying
   the self-contained `child-ci-python.yml` / `child-ci-rust.yml`; creating
   reusable workflows is out of scope) and `--frontend` accepts `ionic` as an
   alias that emits the existing Angular wiring. Usage line and error text
   updated together.
8. **Idempotent, explicit outcomes.** Every capability reports `CREATED`,
   `SKIPPED (exists)`, or `REFUSED (reason)`. Re-running writes nothing twice.
9. **`--dry-run` writes nothing** and prints the exact plan (capability, files,
   flags it would pass to `init-ci.sh`), exit 0. `--help` lists flags; `--list`
   lists capabilities.
10. **Non-TTY without flags preserves today's behavior** (core wiring, CI
    skipped) and prints the exact command to opt into the rest.
11. **Tests.** Bats fixtures prove: every catalog entry maps to a real flag;
    `--list` output equals the catalog; `--dry-run` creates zero files;
    detection works for all eight stacks; incompatible pairs are refused;
    `--all` skips deploy without a tool; a re-run is a no-op. No regression in
    the current bootstrap output or in `init-ci.sh`'s existing flags.

## Out of scope

- Creating GitHub/GitLab repositories, Vercel projects, or hosts.
- Prompting for or writing secrets.
- Rewriting the standards documents; this is wiring, not new standards.
- Changing the spec pipeline's stages.

## Open questions

Resolved by the owner's delegate on 2026-10-25. Override any at the human gate.

- OQ-1 — **Full menu preselected by detection.** `--none` is the escape.
- OQ-2 — **No media agents in `--all`.** Credentials-gated; informational only.
- OQ-3 — **Vercel only with explicit `--with-deploy vercel`.**
- OQ-4 — **`--with-loop` writes real files** (`LOOP.md`, `loop-budget.md`,
  `loop-constraints.md`, `loop-run-log.md`); `check-loop-files.sh` reads them.
- OQ-5 — **No new reusable workflows.** `--backend python|rust` copies the
  self-contained `ci/templates/child-ci-python.yml` / `child-ci-rust.yml`.
  ADR 0006 D4 scoped those to templates; the template header already records the
  collapse-to-delegator path. Creating `ci-python.yml` / `ci-rust.yml` is a
  separate spec.
- OQ-6 — **Ionic is an alias for Angular wiring.** No `ci-ionic.yml`; Ionic is
  only supported on Angular (see `language-specific/ionic/SKILL.md`), so a
  dedicated workflow would duplicate `ci-angular.yml`.
- OQ-7 — **Not aliases.** `--with-spec-pipeline` enables the agent wiring
  (default symlink); `--copy-agents` is the copy-vs-symlink modifier.
- OQ-8 — **Extend `init-ci.sh`.** Contract/e2e/security/sweeper flags emit
  callers of the existing reusable workflows. Mutation copies config only
  (pitest/stryker/mutmut/mutants.toml); there is no reusable mutation workflow.
- OQ-9 — **`--with-deploy vercel` adds the post-merge verification caller
  only.** It emits a caller for `ci-vercel-production-verify.yml` and prints
  that the project must be linked in the Vercel dashboard. It never claims to
  build or deploy.
- OQ-10 — **`static` is explicit only.** No marker auto-detects to it.
