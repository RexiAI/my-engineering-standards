# Cut token spend without weakening gates

Findings from a read-only audit (2026-10-30):
1. CODING_CONVENTIONS.md is 26 KB; spec-coder.md:63 and spec-refactorer.md:39 point at the whole file -> point at the relevant section only.
2. No output filtering: agents paste full make test / lint / principles logs into context. Add a helper (e.g. scripts/agent-test-summary.sh) that prints only failures + a one-line summary; the full log still goes to 25-verification.md evidence.
3. Redundant full-suite runs: coder, refactorer, verifier and mutation-runner each run make test. Keep the verifier's run as the gate; allow reuse when the diff hash is unchanged.
4. model.local.env.example sets effort xhigh for mechanical stages (deployer, pr-opener, pipeline); the mutation-runner uses a premium model. Reduce.

Want: each item implemented or explicitly rejected with a recorded reason, measured before/after (bytes an agent must read per stage). No gate may be removed or weakened. AGENTS.md rules for evidence files unchanged.
