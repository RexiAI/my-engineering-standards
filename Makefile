.PHONY: help validate validate-docs validate-refs validate-all lint format stats test test-scripts test-shell test-java test-go test-js mutation property-tests ci-fast ci ci-full

DOCS := AGENTS.md README.md \
  docs/AGENTS_AND_SKILLS.md \
  docs/ARCHITECTURE.md docs/CI_CD.md docs/CODING_CONVENTIONS.md \
  docs/CONFORMANCE_TIERS.md \
  docs/CONTRACT_TESTING.md docs/DATA_STORAGE_DECISIONS.md \
  docs/DEPLOYMENT.md docs/EVENTUAL_CONSISTENCY.md docs/GIT_WORKFLOW.md \
  docs/IDEMPOTENCY.md docs/LOOP_ENGINEERING.md docs/MESSAGE_DELIVERY.md docs/OBSERVABILITY.md \
  docs/OUTBOX_PATTERN.md docs/RESILIENCE.md docs/SAGA_PATTERN.md \
  docs/SCALABILITY.md docs/SCHEMA_EVOLUTION.md docs/SECURITY.md \
  docs/STREAM_PROCESSING.md docs/TESTING.md docs/SPEC_PIPELINE.md

LANG_AGENTS := language-specific/java/SKILL.md \
  language-specific/go/SKILL.md \
  language-specific/javascript/SKILL.md \
  language-specific/react-native/SKILL.md

TEMPLATES := templates/ADR.md templates/Kamalfile templates/docker-compose.prod.yml templates/nginx.conf \
  templates/agent.md templates/SKILL.md

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
	for src in $$(find . -name '*.md' -not -path './.git/*' -not -path '*/node_modules/*' -not -path './specs/*'); do \
		for ref in $$(grep -oP 'docs/[A-Z_]+\.md' "$$src" 2>/dev/null || true); do \
			if [ ! -f "$$ref" ]; then \
				echo "  [BROKEN] $$src -> $$ref"; errors=$$((errors + 1)); \
			fi; \
		done; \
	done; \
	if [ $$errors -eq 0 ]; then echo "All docs/ cross-references valid."; \
	else echo "$$errors broken reference(s)!"; exit 1; fi

validate-skills:
	@./scripts/check-skills.sh

validate-all: validate validate-docs validate-refs validate-skills
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

# --- TDD harness (spec 001) — shell track ---
test-scripts:   # Run bats shell gate tests (Track B, spec 001)
	@command -v bats >/dev/null 2>&1 || { echo "ERROR: bats not found on PATH — install bats-core >=1.10 (https://github.com/bats-core/bats-core)" >&2; echo "  e.g. git clone https://github.com/bats-core/bats-core.git && ./bats-core/install.sh \$$HOME/.local" >&2; exit 1; }
	@echo "Running bats tests (TAP)..."
	@bats --tap scripts/tests/*.bats

test-shell: test-scripts

test: test-scripts   # Unified entry (Track B; lang template validation is doc-linked smoke, not local)
	@echo "test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)"

test-java:   # Validate java-feature template smoke (no Maven build, just structural check)
	@test -f ci/templates/java-feature/pom-fragment.xml && echo "[OK] java-feature template present" || { echo "[FAIL] ci/templates/java-feature missing" >&2; exit 1; }
	@grep -q "junit-jupiter" ci/templates/java-feature/pom-fragment.xml && echo "[OK] junit-jupiter present" || { echo "[FAIL] junit-jupiter missing" >&2; exit 1; }

test-go:   # Validate go-feature template smoke
	@test -f ci/templates/go-feature/Makefile && echo "[OK] go-feature template present" || { echo "[FAIL] ci/templates/go-feature missing" >&2; exit 1; }
	@grep -q "go test -race -shuffle=on -count=1" ci/templates/go-feature/Makefile && echo "[OK] go test command correct" || { echo "[FAIL] go test command wrong" >&2; exit 1; }

test-js:   # Validate js-feature template smoke
	@test -f ci/templates/js-feature/package.json && echo "[OK] js-feature template present" || { echo "[FAIL] ci/templates/js-feature missing" >&2; exit 1; }
	@grep -q "vitest\|jest" ci/templates/js-feature/package.json && echo "[OK] test runner present" || { echo "[FAIL] test runner missing" >&2; exit 1; }

mutation:   # Mutation testing (production tier, 80% threshold — skipped at mvp)
	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
		echo "mutation: production tier — run tier-specific mutation (see ci/templates)"; \
		echo "  Java: mvn verify -Pmutation | Go: gremlins unleash --threshold-efficacy 80 | JS: npx stryker run"; \
	else \
		echo "skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)"; \
	fi

property-tests:   # Property tests (production tier — skipped at mvp)
	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
		echo "property-tests: production tier — run with tier's framework (jqwik / testing/quick / fast-check)"; \
	else \
		echo "skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)"; \
	fi

ci-fast: test-scripts validate-all   # Fast CI ladder: shell tests + validations, no Docker
	@echo "ci-fast: green"

ci: ci-fast   # Alias for ci-fast in this repo (no build artifact)
	@echo "ci: green"

ci-full: ci   # Full ladder (no E2E in this repo)
	@echo "ci-full: green"


