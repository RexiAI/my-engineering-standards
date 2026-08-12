# Agents and Skills Standards

This document defines the standards for authoring and modifying agents and
skills across all projects in this engineering ecosystem.

Standards sources:
- **Agent Skills specification**: [agentskills.io/specification](https://agentskills.io/specification)
- **Anthropic "Building Effective Agents" guide**: [anthropic.com/engineering/building-effective-agents](https://www.anthropic.com/engineering/building-effective-agents)

---

## Two-Tier Model

This ecosystem distinguishes between **Skills** and **Agents**:

| Tier | Directory | Format Standard | Purpose |
|---|---|---|---|
| **Skills** | `skills/<name>/SKILL.md`<br>`language-specific/<lang>/SKILL.md` | Agent Skills Specification (`SKILL.md` format) | Modular, reusable capabilities loaded progressively by agents on demand. |
| **Agents** | `agents/<name>.md` | OpenCode Agent Specification (`mode`/`permission` YAML frontmatter) | Autonomous execution roles and pipeline stage handlers with specific permissions. |

Both tiers must adhere to Anthropic's **Building Effective Agents** principles.

---

## Part 1: Agent Skills Specification (`SKILL.md`)

Skills reside in `skills/<skill-name>/SKILL.md` or `language-specific/<lang>/SKILL.md`.

### Directory Structure

```text
skills/<skill-name>/
├── SKILL.md          # Required: metadata + instructions (<500 lines)
├── scripts/          # Optional: executable code (self-contained, error handling)
├── references/       # Optional: focused documentation loaded on demand
└── assets/           # Optional: templates, schemas, static resources
```

### Frontmatter Schema

`SKILL.md` must start with YAML frontmatter bounded by `---`:

| Field | Required | Constraints |
|---|---|---|
| `name` | Yes | Max 64 chars. Lowercase `a-z`, `0-9`, and hyphens (`-`). No leading/trailing hyphens. No consecutive hyphens (`--`). **Must match the parent directory name exactly** (e.g., `skills/check-principles/SKILL.md` → `name: check-principles`). |
| `description` | Yes | Max 1024 chars. Non-empty. Must describe **what** the skill does AND **when to use it** (including explicit trigger keywords). |
| `license` | No | License name or reference (e.g., `See repo root`). |
| `compatibility` | No | Max 500 chars. Environment requirements (e.g., `Requires git, docker, jq`). |
| `metadata` | No | Key-value map of string key to string value (e.g., `version: "1.0"`). |
| `allowed-tools` | No | Space-separated string of pre-approved tool executions (experimental). |

#### Example Frontmatter

```yaml
---
name: check-principles
description: Run the design-principles audit (KISS, DRY, YAGNI, SOLID, cyclomatic complexity, property tests) against Java, Go, or JS/TS code. Use when checking code principles or auditing design.
license: See repo root
allowed-tools: Bash(.standards/scripts/check-code-principles.sh:*)
---
```

### Progressive Disclosure

To optimize context token usage:
1. **Metadata (~100 tokens)**: `name` and `description` are loaded at startup.
2. **Main Instructions (<500 lines)**: `SKILL.md` body is loaded when activated. Keep under 500 lines.
3. **Resources (on demand)**: Move detailed documentation into `references/`, scripts into `scripts/`, templates into `assets/`.

### File References

- Use relative paths from skill root (e.g., `references/DETAILS.md`, `scripts/run.sh`).
- Keep references one level deep from `SKILL.md`. Avoid nested reference chains (`A` → `B` → `C`).

### Recommended Body Sections

1. **# When to use**: Clear scenarios and trigger phrases.
2. **# Invocation**: Exact CLI / script command examples with flags.
3. **# What the script/tool does**: Step-by-step summary of execution.
4. **# What it is not**: Explicit non-goals or boundary limits.
5. **# Exit codes**: Document return codes (`0` pass, `1` fail, etc.).

---

## Part 2: OpenCode Agents (`agents/*.md`)

Agents reside in `agents/<agent-name>.md`.

### Frontmatter Schema

Agents use OpenCode subagent YAML frontmatter:

```yaml
---
description: Brief summary of the agent's role and stage.
mode: subagent
permission:
  read:
    "sensitive/path/*": deny
    "*": allow
  bash:
    "git push*": deny
    "*": allow
---
```

### Body Structure

Agent bodies must define clear operational boundaries:
1. **Role / Purpose**: Unambiguous assignment of pipeline responsibility.
2. **The One Rule / Primary Invariant**: What the agent MUST NOT do (e.g., never read informal specs, never push directly).
3. **Execution Steps**: Ordered, unambiguous sequence of operations.
4. **Constraints & Hand-off**: What files may or may not be edited, and how to pass control to the next stage.
5. **Output**: Expected termination summary.

---

## Part 3: Anthropic Agent Design Principles

Applied to **both** agents and skills during creation and modification:

### 1. Simplicity First
- Find the simplest solution possible. Do not add multi-step agent loops when a single prompt or simple workflow suffices.
- **Workflow vs. Agent**:
  - **Workflow**: Predefined code paths with LLM/tool nodes (prompt chaining, routing, parallel sectioning/voting, orchestrator-workers, evaluator-optimizer). Predictable, consistent.
  - **Agent**: LLM dynamically directs its own tool usage and iteration in a loop. Use only when required steps cannot be predefined.

### 2. Transparency
- Explicitly surface planning steps and reasoning in the agent's instructions and output.
- Log decision points and state transitions explicitly.

### 3. Agent-Computer Interface (ACI) / Tool Engineering
- Invest as much effort into ACI as HCI:
  - **Poka-yoke**: Design tool arguments and parameters so mistakes are difficult (e.g., require absolute filepaths instead of relative paths).
  - **Docstrings & Examples**: Include clear parameter descriptions, example inputs/outputs, and edge-case handling.
  - **No formatting overhead**: Avoid tools requiring complex line counts, manual diff header math, or deep string escaping.

### 4. Ground Truth per Step
- Force agents to gather ground truth from the environment at each step (e.g., test execution output, compiler logs, tool response).
- Never allow agents to assume a step succeeded without checking output.

### 5. Stopping Conditions & Guardrails
- Autonomous loops and agents MUST specify explicit stopping conditions (e.g., max iterations, green test suite, budget caps).
- Execute high-risk commands inside sandboxed environments with restrictive permissions.

---

## Authoring & Modification Checklist

Every time an agent (`agents/*.md`) or skill (`skills/*/SKILL.md`) is added or modified, verify this checklist:

### Skills Checklist (`skills/*/SKILL.md` & `language-specific/*/SKILL.md`)
- [ ] `name` field is lowercase `[a-z0-9-]`, ≤64 chars, no leading/trailing/consecutive hyphens.
- [ ] `name` field **matches the parent directory name** exactly.
- [ ] `description` is ≤1024 chars, non-empty, and includes **what** it does + **when to use it** (trigger keywords).
- [ ] `compatibility` (if present) is ≤500 chars.
- [ ] Body line count is ≤500 lines.
- [ ] File references are relative, one level deep, and do not create nested chains.
- [ ] Scripts in `scripts/` handle edge cases and provide helpful error messages.
- [ ] `scripts/check-skills.sh` passes with 0 errors.

### Agents Checklist (`agents/*.md`)
- [ ] YAML frontmatter contains valid `description`, `mode`, and `permission` blocks.
- [ ] Clear invariant rule ("The one rule that matters") and primary constraint defined.
- [ ] Workflow vs Agent model choice is justified.
- [ ] Ground-truth verification required after every mutation or action.
- [ ] Explicit stopping conditions defined.
- [ ] `scripts/check-orchestration.sh` passes with 0 broken references.

---

## Mechanical Enforcement

The standards are enforced automatically via scripts run in CI (`.github/workflows/self-ci.yml`):

- **`scripts/check-skills.sh`**: Hard CI gate validating frontmatter rules, directory name matching, length constraints, and line-count warnings for all skills.
- **`scripts/check-orchestration.sh`**: Hard CI gate asserting that all agent, skill, script, and documentation cross-references resolve.
