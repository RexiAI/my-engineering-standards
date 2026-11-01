# Harden standards docs and repo config

Findings (read-only audit, 2026-10-30):
1. docs/SECURITY.md lacks SSRF, CSRF, CORS, password hashing (argon2/bcrypt) and a JWT validation checklist (algorithm allowlist, reject alg=none, aud/iss/exp).
2. docs/OFFICIAL_REFERENCES.md has no pins for Java, Go, React Native.
3. AGENTS.md:23 cites docs/CI_CD.md.md (broken; should be docs/CI_CD.md).
4. docs/CI_CD.md:283-285 bootstrap example ends with a bare git push, contradicting the PR-only rule.
5. Unenforced AGENTS.md rules: /health checking all dependencies, structured logging with trace IDs, controller->service->repository layering. Either add a script check or mark advisory explicitly.
6. scripts/check-skills.sh:74 only warns above 500 lines; language-specific/*/SKILL.md has no real cap (java 282, python 271).
7. Repo config: add a permission block to opencode.json (deny force-push, push to main/master, git tag, branch -D, remote branch delete; ask for commit/push), .gitignore .env.* + rb_*, and remove the tracked rb_* capture files.

Want: items 1-4 and 7 applied; 5 and 6 decided (script or advisory) and recorded. All existing gate scripts stay green; changes to agents/ require an ADR.
