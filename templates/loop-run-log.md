# Loop Run Log

Append-only log. Each run appends exactly one JSON line; never edit or delete an
existing entry.

## Entry format

Each run appends one JSON line shaped as follows:

```json
{ "run_id": "...", "pattern": "...", "duration_s": 0, "items_found": 0, "actions_taken": 0, "escalations": 0, "tokens_estimate": 0, "outcome": "..." }
```

## Pruning

Entries older than 30 days are pruned. Append-only means append new entries and
prune old entries only — no in-place edits of a run's entry.
