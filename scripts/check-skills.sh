#!/bin/bash
# check-skills.sh — Validate all SKILL.md files against the Agent Skills spec.
#
# Standards reference:
#   docs/AGENTS_AND_SKILLS.md
#   Agent Skills Specification (https://agentskills.io/specification)
#
# Checks:
#   1. Frontmatter exists — bounded by '---' at top of file.
#   2. 'name' field — required, 1-64 chars, lowercase [a-z0-9-], no leading/trailing
#      or consecutive hyphens (regex: ^[a-z0-9]+(-[a-z0-9]+)*$).
#   3. 'name' matches directory — skills/<dir>/SKILL.md -> name == <dir>;
#      language-specific/<lang>/SKILL.md -> name == <lang>.
#   4. 'description' field — required, non-empty, 1-1024 chars.
#   5. 'compatibility' field — optional; if present, 1-500 chars.
#   6. Line count — skills/*/SKILL.md: WARN if >500 lines (Agent Skills spec
#      guidance, unchanged). language-specific/*/SKILL.md: hard FAIL above
#      200 lines. The four existing oversized language guides are grandfathered
#      at their current line count and may not grow (LANG_SKILL_GRANDFATHERED
#      in validate_skill); an entry is removed only after that guide is split
#      into an entry point plus sibling files.
#   7. Nested reference chains — WARN if reference files themselves contain
#      relative links to other reference files.
#
# Usage:
#   scripts/check-skills.sh [ROOT]
#
# Exit codes:
#   0 — all SKILL.md files valid
#   1 — at least one hard validation error
set -euo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(dirname "$SCRIPT_DIR")"
fi
ROOT="$(cd "$ROOT" && pwd)"

ERRORS=0
WARNINGS=0

error() { # error <file> <msg>
  printf '[FAIL] %s — %s\n' "$1" "$2"
  ERRORS=$((ERRORS + 1))
}

warn() { # warn <file> <msg>
  printf '[WARN] %s — %s\n' "$1" "$2"
  WARNINGS=$((WARNINGS + 1))
}

# Python helper to validate YAML frontmatter and rules
validate_skill() {
  local file="$1"
  local relpath="${file#"$ROOT"/}"
  
  python3 - "$file" "$relpath" << 'EOF'
import sys
import os
import re

file_path = sys.argv[1]
rel_path = sys.argv[2]

errors = []
warnings = []

# 1. Read file
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
except Exception as e:
    print(f"FAIL:{rel_path}:Cannot read file: {e}")
    sys.exit(0)

# Check line count: skills/ keeps the Agent Skills spec's 500-line guidance as a
# warning; a language-specific/ entry point has a hard 200-line cap, because it
# exists to be small and to point at siblings. The four guides already over the
# cap are grandfathered at their current count — frozen, not permitted to grow —
# until a follow-up spec splits them.
LANG_SKILL_MAX_LINES = 200
LANG_SKILL_GRANDFATHERED = {
    "language-specific/java/SKILL.md": 282,
    "language-specific/python/SKILL.md": 271,
    "language-specific/rust/SKILL.md": 241,
    "language-specific/go/SKILL.md": 223,
}
LANG_SKILL_MOVE_HINT = "move detail to a sibling file such as PATTERNS.md or TESTING.md"


def line_count_finding(rel_path, total_lines):
    """The line-count rule for one SKILL.md.

    Returns ('error'|'warning', message), or None when the file is within its
    limit. Each ceiling is one early-return branch, so no branch nests.
    """
    if not rel_path.startswith("language-specific/"):
        if total_lines <= 500:
            return None
        return ("warning", f"Body has {total_lines} lines (>500 limit recommended "
                           f"by Agent Skills spec; move details to references/)")
    ceiling = LANG_SKILL_GRANDFATHERED.get(rel_path, LANG_SKILL_MAX_LINES)
    if total_lines <= ceiling:
        return None
    if rel_path in LANG_SKILL_GRANDFATHERED:
        return ("error", f"Body has {total_lines} lines (> grandfathered ceiling of "
                         f"{ceiling} for this guide — it is frozen at its current "
                         f"size and may not grow; {LANG_SKILL_MOVE_HINT}, then remove "
                         f"its grandfather entry)")
    return ("error", f"Body has {total_lines} lines (> {LANG_SKILL_MAX_LINES}-line "
                     f"limit for language-specific/*/SKILL.md — {LANG_SKILL_MOVE_HINT})")


total_lines = len(lines)
finding = line_count_finding(rel_path, total_lines)
if finding is not None:
    severity, message = finding
    if severity == "error":
        errors.append(message)
    else:
        warnings.append(message)

content = "".join(lines)

# 2. Check frontmatter bounds
if not content.startswith("---"):
    errors.append("Missing frontmatter opening '---'")
    for err in errors:
        print(f"FAIL:{rel_path}:{err}")
    sys.exit(0)

parts = content.split("---", 2)
if len(parts) < 3:
    errors.append("Malformed frontmatter; missing closing '---'")
    for err in errors:
        print(f"FAIL:{rel_path}:{err}")
    sys.exit(0)

frontmatter_raw = parts[1]

# Try parsing YAML frontmatter
try:
    import yaml
    fm = yaml.safe_load(frontmatter_raw)
    if not isinstance(fm, dict):
        errors.append("Frontmatter must be a YAML mapping")
        fm = {}
except Exception:
    # Fallback basic key-value extraction if PyYAML fails or isn't formatted as dict
    fm = {}
    for line in frontmatter_raw.splitlines():
        if ":" in line and not line.strip().startswith("#"):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip("'\"")

# 3. Check 'name' field
name = fm.get("name")
if not name or not isinstance(name, str) or not name.strip():
    errors.append("Missing or empty 'name' field in frontmatter")
else:
    name = str(name).strip()
    if len(name) > 64:
        errors.append(f"'name' is {len(name)} chars (max 64 allowed)")
    
    name_regex = r'^[a-z0-9]+(-[a-z0-9]+)*$'
    if not re.match(name_regex, name):
        errors.append(f"'name' '{name}' invalid (must be lowercase alphanumeric with single hyphens, no leading/trailing/consecutive hyphens)")

    # 4. Check name matches directory name
    # Expected parent directory name
    parent_dir = os.path.basename(os.path.dirname(os.path.abspath(file_path)))
    if name != parent_dir:
        errors.append(f"'name' '{name}' does not match directory name '{parent_dir}'")

# 5. Check 'description' field
description = fm.get("description")
if not description or not str(description).strip():
    errors.append("Missing or empty 'description' field in frontmatter")
else:
    desc_str = str(description).strip()
    if len(desc_str) > 1024:
        errors.append(f"'description' is {len(desc_str)} chars (max 1024 allowed)")

# 6. Check 'compatibility' field if present
compatibility = fm.get("compatibility")
if compatibility is not None:
    comp_str = str(compatibility).strip()
    if len(comp_str) > 500:
        errors.append(f"'compatibility' is {len(comp_str)} chars (max 500 allowed)")

# 7. Check for nested reference chains in references/ directory if references/ exists
skill_dir = os.path.dirname(file_path)
refs_dir = os.path.join(skill_dir, "references")
if os.path.isdir(refs_dir):
    for root, _, files in os.walk(refs_dir):
        for ref_file in files:
            if ref_file.endswith(".md"):
                ref_path = os.path.join(root, ref_file)
                try:
                    with open(ref_path, "r", encoding="utf-8") as rf:
                        ref_content = rf.read()
                        # Look for relative links to other reference files
                        if re.search(r'\]\((?!http|\/)[^)]*references\/', ref_content):
                            warnings.append(f"Nested reference link found in {os.path.relpath(ref_path, skill_dir)} (avoid deep reference chains)")
                except Exception:
                    pass

for err in errors:
    print(f"FAIL:{rel_path}:{err}")
for w in warnings:
    print(f"WARN:{rel_path}:{w}")

EOF
}

echo "Checking SKILL.md files..."

while IFS= read -r -d '' skill_file; do
  output=$(validate_skill "$skill_file")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      FAIL:*)
        path=$(echo "$line" | cut -d: -f2)
        msg=$(echo "$line" | cut -d: -f3-)
        error "$path" "$msg"
        ;;
      WARN:*)
        path=$(echo "$line" | cut -d: -f2)
        msg=$(echo "$line" | cut -d: -f3-)
        warn "$path" "$msg"
        ;;
    esac
  done <<< "$output"
done < <(find "$ROOT/skills" "$ROOT/language-specific" -name 'SKILL.md' -type f -print0 2>/dev/null || true)

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "All SKILL.md files valid ($WARNINGS warning(s))."
  exit 0
else
  echo "$ERRORS error(s) found in SKILL.md files ($WARNINGS warning(s))!"
  exit 1
fi
