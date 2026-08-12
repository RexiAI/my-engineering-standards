# AC-008-03: Coder and Refactorer encode the re-fix cap

## AC-008-03-01 — Coder stops re-fixing after 3 (AC-002)
Given `agents/spec-coder.md` is edited per task 3
When the prompt is read
Then it states the Coder stops re-fixing after **3** attempts per BLOCK
And it states that on the 3rd fix that still fails, the Coder does not accept another re-fix request

## AC-008-03-02 — Coder hands back with failing gate IDs and last evidence
Given `agents/spec-coder.md` is edited per task 3
When the prompt is read
Then it instructs the Coder, at the cap, to hand back with the failing gate IDs and the last evidence for escalation

## AC-008-03-03 — Refactorer mirrors the cap
Given `agents/spec-refactorer.md` is edited per task 3
When the prompt is read
Then it states the Refactorer performs at most **3** structural re-fixes per BLOCK
And it states that at the cap the Refactorer reports and does not accept further re-fix requests

## AC-008-03-04 — No frontmatter or permission changes
Given `agents/spec-coder.md` and `agents/spec-refactorer.md` are edited per task 3
When both prompts' frontmatter is read
Then the read/edit/bash permission rules are unchanged from before the edit
And both prompts still forbid committing and pushing

## AC-008-03-05 — No open-ended re-run phrasing in either fixer prompt
Given `agents/spec-coder.md` and `agents/spec-refactorer.md` are edited per task 3
When both prompts are read
Then neither contains `re-run until green`
And neither contains any equivalent instruction to re-fix without a stated cap
