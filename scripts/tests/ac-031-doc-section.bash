# ac-031-doc-section.bash — shared bats helper (refactorer stage 3, DRY
# consolidation). Loaded by ac-031-pipeline-doc-rewrite.bats and
# ac-031-phase3-budget-routing.bats, which previously carried this function as
# a byte-identical private copy. The extraction mirrors the awk section helper
# used by scripts/check-post-pr-ci-loop.sh, scoped to the docs file under test
# ($DOC, set by the loading test file before the call).
section() { # section <heading> — body of the `## <heading>` section of "$DOC" (up to the next `## `)
  awk -v want="## $1" '
    /^## / { if (found) exit; if ($0 == want) { found = 1; next } }
    found { print }
  ' "$DOC"
}
