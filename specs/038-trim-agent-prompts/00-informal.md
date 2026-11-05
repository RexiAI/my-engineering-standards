# Trim agent prompts: move procedure into scripts

Problem: agents/*.md total ~2.9k lines; largest spec-verifier (243), spec-ux (218), spec-pr-opener (171). Much is step-by-step procedure that a script could run deterministically.

Want: each spec-* agent file <=120 lines. Procedural sequences (command lists, gate runs, file-format templates) move into scripts/ or skill reference files; agent prose keeps decisions, stop conditions, and outputs. No gate is removed or weakened. check-skills.sh and check-orchestration.sh stay green; add a line-cap check for agents/spec-*.md.
Depends on 037 (agents will reference new per-stage docs).
