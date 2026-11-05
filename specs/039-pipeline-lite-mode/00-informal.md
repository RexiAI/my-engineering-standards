# Lite mode for small specs

Problem: every /build runs coder, refactorer, verifier, mutation runner, PR opener (+ deployer, ux, two remediation loops up to 3 rounds each). For a small spec (docs-only, single script, <N lines changed) this is mostly overhead.

Want: a `lite` mode (argument token or auto-classified by a deterministic script on spec size/surface) that runs coder -> verifier -> PR opener, skipping refactorer, mutation runner, ux, deployer. Verifier gates that are hard requirements (tests green, secrets scan, principles FAIL) still run. Classification is mechanical, logged in 45-decisions.md, and overridable by the human. Never usable on conformance tier `production` code paths. Requires an ADR per docs/GOVERNANCE.md (changes pipeline roles).
