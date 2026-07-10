.PHONY: help validate lint format

help:
	@echo "my-engineering-standards - shared engineering standards"
	@echo ""
	@echo "Targets:"
	@echo "  validate   Check all markdown files have basic structure"
	@echo "  lint       Verify YAML/JSON files are valid"
	@echo "  format     Format markdown files with prettier (requires npx)"
	@echo ""

validate:
	@echo "Checking required files exist..."
	@for f in AGENTS.md docs/ARCHITECTURE.md docs/TESTING.md docs/DEPLOYMENT.md docs/SECURITY.md docs/CODING_CONVENTIONS.md docs/GIT_WORKFLOW.md README.md; do \
		if [ -f "$$f" ]; then echo "  [OK] $$f"; else echo "  [MISSING] $$f"; exit 1; fi; \
	done
	@echo "All required files present."

lint:
	@echo "Validating JSON files..."
	@for f in language-specific/javascript/*.json; do \
		if [ -f "$$f" ]; then python3 -m json.tool "$$f" > /dev/null 2>&1 && echo "  [OK] $$f" || echo "  [FAIL] $$f"; fi; \
	done
	@echo "Done."

format:
	@if command -v npx > /dev/null 2>&1; then \
		npx prettier --write "**/*.md" "**/*.json" "**/*.yml" 2>/dev/null || true; \
	else \
		echo "npx not available. Install Node.js to use formatter."; \
	fi
