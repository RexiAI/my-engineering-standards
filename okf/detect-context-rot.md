---
type: runbook
title: Detect Context Rot
description: How to detect when LLM context has degraded and recover it
tags: [context, maintenance, rot, caveman-stats, headroom]
timestamp: 2026-07-11T00:00:00Z
related:
  - context-window-policy.md
  - log.md
---

# Detect Context Rot

Context rot is the gradual degradation of AI output quality as the conversation window fills with noise: repeated tool outputs, stale artifacts, low-signal exchanges. The AI starts to miss instructions, hallucinate file paths, or produce incomplete code.

## Detection

### Automatic Triggers

Run `/caveman-stats` every 20-30 messages. Signs of rot:

| Metric | Healthy | Rotting | Critical |
|--------|---------|---------|----------|
| Session tokens | <30k | 30-45k | >50k |
| Compression ratio | >50% | 30-50% | <30% |
| AI response length | ≤4 lines | 5-15 lines | >15 lines of prose |
| Instruction adherence | +1 repeat | 2-3 repeats | >3 repeats per instruction |

### Manual Signs

- AI asks "what file was that again?" after you already said it
- AI re-reads the same AGENTS.md instructions mid-session
- AI produces code for a different framework than the project uses
- AI starts apologising or hedging ("I think", "perhaps", "it might be better to")
- Tool outputs appear multiple times in the window

## Recovery Procedure

### Step 1: Compress

```bash
# Compress last 5 large tool outputs
headroom_compress "$(cat /tmp/last-output-1.log)"
headroom_compress "$(cat /tmp/last-output-2.log)"
# ...
```

### Step 2: Verify compression ratio

```bash
/caveman-stats
# Target: >50% compression ratio
```

### Step 3: Strip stale artifacts

If compression alone is not enough, start a new turn with the current files re-read:

```bash
rtk read src/main.go | headroom_compress /dev/stdin
rtk read src/service/service.go | headroom_compress /dev/stdin
```

### Step 4: Log the incident

Record the rot event in `log.md` so patterns emerge:

```markdown
## 2026-07-11 — v0.1.0
**Author:** @pucelano-95
**Tags:** [context-rot, session-recovery]
**Summary:** Detected rot at ~42k tokens. Compression ratio 28%. Recovered via headroom compress of 3 outputs.
```

### Step 5: Prevent next time

- Keep responses under 4 lines (caveman enforces this)
- Prefix every command with `rtk` to auto-filter noise
- Compress large tool outputs as they arrive, not when rot sets in

## Prevention Checklist (Pre-Session)

- [ ] Started with `/caveman-stats` baseline?
- [ ] Configured `rtk` prefix loaded in AGENTS.md?
- [ ] Headroom hook active for auto-compression?
- [ ] Token ceiling (50k) known and visible?
