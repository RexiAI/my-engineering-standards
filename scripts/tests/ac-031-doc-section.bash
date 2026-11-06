# ac-031-doc-section.bash — shared bats helper (refactorer stage 3, DRY
# consolidation). Loaded by ac-031-pipeline-doc-rewrite.bats and
# ac-031-phase3-budget-routing.bats, which previously carried this function as
# a byte-identical private copy. The extraction mirrors the awk section helper
# used by scripts/check-post-pr-ci-loop.sh, scoped to the docs file under test
# ($DOC, set by the loading test file before the call).
section_of() { # section_of <file> <heading> — body of that file's `## <heading>` section
  awk -v want="## $2" '
    /^## / { if (found) exit; if ($0 == want) { found = 1; next } }
    found { print }
  ' "$1"
}

section() { # section <heading> — body of the `## <heading>` section, from "$DOC" or a split doc
  local f out
  for f in "$DOC" "$REPO_ROOT"/docs/spec-pipeline/*.md; do
    [ -f "$f" ] || continue
    out="$(section_of "$f" "$1")"
    if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  done
  return 0
}

# docs/SPEC_PIPELINE.md is the index since spec 037; each stage's sections live
# under docs/spec-pipeline/. pipeline_docs lists every split doc, pipeline_cat
# concatenates them — use these for assertions that are about *a* pipeline rule
# rather than a specific file's section.
pipeline_docs() { printf '%s\n' "$DOC" "$REPO_ROOT"/docs/spec-pipeline/*.md; }
pipeline_cat() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] && cat "$f"
  done < <(pipeline_docs)
}
