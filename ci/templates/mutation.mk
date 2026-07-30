# mutation.mk — copy into the project's Makefile (or `include ci/mutation.mk`).
# Go mutation testing via Gremlins (https://gremlins.dev) — actively maintained,
# PITest-inspired, coverage-aware (skips lines with no test coverage instead of
# reporting noise for them).
#
# go-mutesting (github.com/zimmski/go-mutesting) was considered and rejected:
# fewer mutators, no coverage-aware skip, and largely unmaintained as of this
# writing. Re-evaluate if Gremlins' maintenance status changes — see
# docs/SPEC_PIPELINE.md §Tooling by language.
#
# Usage: make mutation
# Target: mutation score >= 80% (docs/CONFORMANCE_TIERS.md: production tier)
# Install: go install github.com/go-gremlins/gremlins/cmd/gremlins@latest

.PHONY: mutation

mutation:                # Mutation testing (production tier, see docs/CONFORMANCE_TIERS.md)
	@command -v gremlins >/dev/null 2>&1 || { \
		echo "gremlins not found. Install: go install github.com/go-gremlins/gremlins/cmd/gremlins@latest"; \
		exit 1; \
	}
	gremlins unleash --threshold-efficacy 80 --tags integration
