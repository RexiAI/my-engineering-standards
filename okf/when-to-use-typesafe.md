---
type: decision
title: When to Use Typed Judgment (TypeSafe-style) vs Deterministic Code vs Full LLM
description: Decision matrix for routing a decision to deterministic code, a small typed-judgment primitive, or a full LLM procedure — with the primitives cheat-sheet and the jaggedness caveat
tags: [typed-judgment, typesafe, classification, confidence, fallback, agent]
timestamp: 2026-09-28T00:00:00Z
related:
  - when-to-use-rag.md
  - context-window-policy.md
---

# When to Use Typed Judgment vs Deterministic Code vs Full LLM

## The three ways to make a decision in an agent workflow

| Kind of decision | Use | Why |
|---|---|---|
| Rule expressible in code (thresholds, path matching, schema checks, retries, caps) | **Deterministic code** | Exact, testable, free, and it is the only thing allowed to be a gate |
| Small categorical judgment over bounded options with rubrics (classify a CI failure, is there a frontend surface, is this message an error) | **Typed judgment** (TypeSafe "System One" style units) | Cheap, fast, returns a confidence you can threshold; no free-form prose |
| Open-ended generation or multi-step reasoning (write a design spec, formulate a question, fix code) | **Full LLM procedure** | Needs judgment-shaped output a primitive cannot produce |

Rule of thumb: if you can name the output options in one line, it is typed-
judgment work; if you cannot, it is full-LLM work; if a `case` statement would
do it, it is deterministic code and must stay that way.

## Primitives cheat-sheet

| Primitive | Shape | Use it for | Watch out |
|---|---|---|---|
| **Choice** | state + N labelled options + rubric → option + per-option probabilities | classification, routing, applicability decisions (both pilot consumers use exactly one Choice question) | options must be exhaustive and mutually exclusive; add an explicit `ambiguous` escape hatch when guessing would be costly |
| **Noul** | natural-language judgment over application state → typed result | extraction / normalization of fuzzy signals into structured fields (severity, intent, sentiment) | keep the instructions narrow; Noul on a big vague state blob reproduces prompt-slop at lower cost |
| **Score** | rank/quantify candidates against criteria | ordering log excerpts by relevance, ranking fix candidates | treat scores as advisory; bind them to a deterministic tie-break before anything acts on them |

## How we wire it here

The repo's mechanism is deliberately small and provider-agnostic:
`scripts/typed-judgment.sh` (curl+jq wrapper, env-var config, `--dry-run`
for offline testing) with a hard exit-code contract — `0` usable, `10`
fallback, `2` usage error. See `docs/SPEC_PIPELINE.md §Typed-judgment layer`
and ADR 0004 for the contract, the confidence threshold (default 0.6), the
daily cap, and the rule that a judgment never overrides a deterministic gate.

### Cookbook pointers

- **Adopt the fast-path in a consumer** — copy the ci-triage pattern: check
  both credential vars; build state JSON from evidence you already gathered;
  ask exactly one Choice question; on exit 0 take the answer, on exit 10 run
  the stock procedure; record telemetry either way.
- **Test a wrapper offline** — see `scripts/tests/typed-judgment.bats`:
  inject a fake transport on `PATH`, never a real host.
- **Choose threshold vs cap** — threshold (`JUDGMENT_MIN_CONFIDENCE`) guards
  per-call quality; cap (`JUDGMENT_DAILY_CAP`) guards spend. Tune threshold
  first; a cap you routinely hit is a wrong-triage-rate bug elsewhere.

## Local backends

The wrapper in `scripts/typed-judgment.sh` can point at a **local judgment
backend** you run yourself instead of the hosted TypeSafe API — free, offline,
on your own hardware (`JUDGMENT_BACKEND=local`, spec 029 / ADR 0005 evidence).
Operator content: the two open-weight backends the spec 029 spike evaluated
by name —

- **Kev** (`github.com/jaredpalmer/kev`, Apache-2.0): a family of small
  decision models (0.8B–27B) with a TypeSafe-compatible `/v1/systemone` API.
  One process, `python -m kev.serve`; on CUDA it serves in bf16. This is the
  recipe `scripts/judgment-local-up.sh` ships (spike winner, Kev-4B on an
  RTX 5060 Ti 16GB).
- **CLM** (`github.com/Contrastive-LM/CLM`, Apache-2.0): bi-encoder decision
  model (Qwen3-8B encoder + a hot-swappable projection head). Two processes
  (a vLLM pooling encoder on :8090 and `clm-serve` on :8700); responses carry
  `billing_units` and an `X-CLM-Latency-Ms` header instead of a body latency.

Both speak the wire format the wrapper's normalizer expects; local mode makes
the API key optional (the servers are open by default) and the model id
optional (a default alias is sent). Start/stop/status/health:
`make judgment-up` / `make judgment-down`, or
`scripts/judgment-local-up.sh {up|down|status|health}`. Set
`JUDGMENT_BACKEND=local` plus the printed `JUDGMENT_API_URL` line in your
gitignored `config/model.local.env`; recalibrate `JUDGMENT_MIN_CONFIDENCE`
per backend (see the spike report method). General docs stay
provider-agnostic — the names above belong here and in the ADR evidence
section only.

## The jaggedness caveat

Typed-judgment units are **jagged**: strong on the shapes they were built
for, silently weak just outside them, with no graceful-degradation curve.
A confident wrong Choice is the normal failure mode, not a rare one. That is
why the contract is replace-with-fallback, why every consumer must keep its
stock procedure, and why confidence below threshold must produce the same
outcome as the service being down: the deterministic path, a human, or the
full LLM — never the judgment itself.

## Compliance

Review habit: a PR that makes a typed judgment authoritative, adds a
consumer without an exit-10 fallback, or moves the product name outside
`okf/` is rejected. The bats suite `scripts/tests/typed-judgment-integration.bats`
enforces the scoping mechanically.
