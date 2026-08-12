# Blame scoping for design gates

The design gates judge the author for the code they wrote. Touching one line of
a legacy class must never block delivery on debt someone else introduced —
otherwise the gate gets switched off, which is worse than not having it.

Update check-code-principles.sh to accept a `-BaseRef <ref>` (like acdc-civ's
design-checker) and, for every finding, classify it:
- **introduced by this change** (the finding's line range overlaps the diff) → FAIL (blocking)
- **pre-existing in a touched file** → WARN (non-blocking, still reported)

Rules:
- Complexity/size (D1): only diff-introduced violations block.
- Naming (D6), test-delta (D10): always blocking (they're objective).
- All judgment checks (SRP, ISP, DIP, DRY, YAGNI, dead code, KISS composite):
  warn only.

## Acceptance criteria

- AC-001: check-code-principles.sh accepts `-BaseRef` and applies blame scoping.
- AC-002: a scratch repo where a pre-existing bad class is touched by one line
  exits 0 (WARN not FAIL); a diff-introduced violation exits 1.
- AC-003: only objective checks block; the blocking set is configurable and
  documented in the script header and design-gates defaults.
