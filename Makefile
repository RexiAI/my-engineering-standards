.PHONY: help validate validate-docs validate-refs validate-all lint format stats

DOCS := AGENTS.md README.md \
  docs/ARCHITECTURE.md docs/CI_CD.md docs/CODING_CONVENTIONS.md \
  docs/CONFORMANCE_TIERS.md \
  docs/CONTRACT_TESTING.md docs/DATA_STORAGE_DECISIONS.md \
  docs/DEPLOYMENT.md docs/EVENTUAL_CONSISTENCY.md docs/GIT_WORKFLOW.md \
  docs/IDEMPOTENCY.md docs/MESSAGE_DELIVERY.md docs/OBSERVABILITY.md \
  docs/OUTBOX_PATTERN.md docs/RESILIENCE.md docs/SAGA_PATTERN.md \
  docs/SCALABILITY.md docs/SCHEMA_EVOLUTION.md docs/SECURITY.md \
  docs/STREAM_PROCESSING.md docs/TESTING.md docs/SPEC_PIPELINE.md

LANG_AGENTS := language-specific/java/AGENTS.md \
  language-specific/go/AGENTS.md \
  language-specific/javascript/AGENTS.md

TEMPLATES := templates/ADR.md templates/Kamalfile

ALL_FILES := $(DOCS) $(LANG_AGENTS) $(TEMPLATES)

help:
	@echo "my-engineering-standards - shared engineering standards"
	@echo ""
	@echo "Targets:"
	@echo "  validate       Check all required files exist"
	@echo "  validate-docs  Check cross-references between docs"
	@echo "  validate-refs  Check docs/XXX.md cross-refs exist"
	@echo "  validate-all   Run all validation targets"
	@echo "  lint           Lint YAML/JSON/TOML files"
	@echo "  format         Format with prettier"
	@echo "  stats          Show file sizes"
	@echo ""
	@echo "Releases: handled by Semantic Release CI after merge to main."
	@echo "  See docs/CI_CD.md §Release Process and ci/templates/releaserc.json."
	@echo ""

validate:
	@echo "Checking required files..."
	@errors=0; \
	for f in $(ALL_FILES); do \
		if [ -f "$$f" ]; then echo "  [OK] $$f"; \
		else echo "  [MISSING] $$f"; errors=$$((errors + 1)); fi; \
	done; \
	if [ $$errors -eq 0 ]; then echo "All $$(echo $(ALL_FILES) | wc -w) files present."; \
	else echo "$$errors file(s) missing!"; exit 1; fi

validate-docs:
	@echo "Checking cross-references..."
	@errors=0; \
	for src in $(DOCS) $(LANG_AGENTS) templates/ADR.md; do \
		for ref in $$(grep -oP 'docs/[A-Z_]+\.md' "$$src" 2>/dev/null || true); do \
			if [ ! -f "$$ref" ]; then \
				echo "  [BROKEN] $$src -> $$ref"; errors=$$((errors + 1)); \
			fi; \
		done; \
	done; \
	if [ $$errors -eq 0 ]; then echo "All cross-references valid."; \
	else echo "$$errors broken reference(s)!"; exit 1; fi

validate-refs:
	@echo "Checking all docs/ cross-refs exist..."
	@errors=0; \
	for src in $$(find . -name '*.md' -not -path './.git/*' -not -path '*/node_modules/*'); do \
		for ref in $$(grep -oP 'docs/[A-Z_]+\.md' "$$src" 2>/dev/null || true); do \
			if [ ! -f "$$ref" ]; then \
				echo "  [BROKEN] $$src -> $$ref"; errors=$$((errors + 1)); \
			fi; \
		done; \
	done; \
	if [ $$errors -eq 0 ]; then echo "All docs/ cross-references valid."; \
	else echo "$$errors broken reference(s)!"; exit 1; fi

validate-all: validate validate-docs validate-refs
	@echo "All validations passed."

lint:
	@echo "Validating JSON files..."
	@for f in language-specific/javascript/*.json; do \
		if [ -f "$$f" ]; then python3 -m json.tool "$$f" > /dev/null 2>&1 && echo "  [OK] $$f" || echo "  [FAIL] $$f"; fi; \
	done
	@echo "Validating YAML files..."
	@for f in $$(find .github ci -name '*.yml' -not -path './.git/*' 2>/dev/null || true); do \
		python3 -c "import yaml; yaml.safe_load(open('$$f'))" 2>/dev/null && echo "  [OK] $$f" || echo "  [FAIL] $$f"; \
	done
	@echo "Done."

format:
	@if command -v npx > /dev/null 2>&1; then \
		npx prettier --write "**/*.md" "**/*.json" "**/*.yml" 2>/dev/null || true; \
	else \
		echo "npx not available. Install Node.js to use formatter."; \
	fi

stats:
	@echo "File stats:"
	@echo "  Docs:        $$(wc -l docs/*.md | tail -1 | awk '{print $$1}') lines across $$(ls docs/*.md | wc -l) files"
	@echo "  Lang agents: $$(wc -l $(LANG_AGENTS) | tail -1 | awk '{print $$1}') lines across $$(echo $(LANG_AGENTS) | wc -w) files"
	@echo "  Templates:   $$(wc -l templates/* 2>/dev/null | tail -1 | awk '{print $$1}') lines across $$(ls templates/* 2>/dev/null | wc -l) files"
	@echo "  CI configs:  $$(find .github ci -name '*.yml' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $$1}') lines across $$(find .github ci -name '*.yml' 2>/dev/null | wc -l) files"
	@echo "  Total:       $$(find . -name '*.md' -not -path './.git/*' -exec cat {} + | wc -l) lines markdown"


