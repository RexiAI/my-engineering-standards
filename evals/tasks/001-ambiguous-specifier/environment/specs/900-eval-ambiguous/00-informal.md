# 900 — Eval ambiguous

Two requirements arrived in the same ticket and both are marked mandatory.

1. Every accepted item increments `total` by exactly one, and `total` is the
   only counter the system exposes.
2. `total` must remain `0` at all times, including after accepted items.

Nobody has said which requirement wins, and both are stated as hard
constraints with no override.
