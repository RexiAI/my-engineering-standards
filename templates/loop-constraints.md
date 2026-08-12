# Loop Constraints

Binding rules, loaded before every loop run. Constraints cannot change per-run —
a run must not edit this file. Changes require a human.

## Safety

- Never touch paths on the denylist without human approval (see
  `docs/LOOP_ENGINEERING.md §Safety`).
- Loops never auto-merge.

## Scope

- [what the loop does and does not do]

## Path denylist

```text
.env*, **/secrets/**, auth/**, payments/**, k8s/production/**, migrations/**
```

## Human-gate thresholds

- Security/auth, payments, infrastructure, dependency upgrades: always
  human-gated.
- File-count threshold `N` (default 10): any change larger than `N` files
  requires human sign-off.
- A third failed attempt on the same item requires a human.
