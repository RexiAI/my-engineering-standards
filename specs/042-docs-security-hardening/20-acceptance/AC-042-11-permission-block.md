# AC-042-11: Repo-level bash permission block

## AC-042-11-01 — The config stays valid and the model wiring is untouched
Given `opencode.json`
When it is parsed as JSON
Then parsing succeeds
And `$schema` is still `https://opencode.ai/config.json`
And the `agent` object still contains exactly the ten entries `spec-specifier`, `spec-ux`, `spec-verifier`, `spec-mutation-runner`, `spec-pr-opener`, `spec-deployer`, `spec-coder`, `spec-refactorer`, `spec-pipeline`, and `pr-review`
And every one of those entries still resolves its model from an `{env:SPEC_*_MODEL}` reference

## AC-042-11-02 — The denied commands are blocked
Given `permission.bash` in `opencode.json`
When the deny entries are read
Then each of these keys maps to `deny`: `git push --force*`, `git push -f*`, `git push --force-with-lease*`, `git push * main*`, `git push * master*`, `git push --delete*`, `git push * --delete*`, `git push * :*`, `git branch -D*`, `git branch --delete --force*`, `git tag*`

## AC-042-11-03 — Commit and push are asked, not allowed silently
Given `permission.bash` in `opencode.json`
When the ask entries are read
Then `git push*` maps to `ask`
And `git commit*` maps to `ask`
And the catch-all `*` maps to `allow`

## AC-042-11-04 — Rule order preserves the last-matching-rule contract
Given the key order of `permission.bash` in `opencode.json`
When the order is checked
Then `*` is the first key
And every key mapping to `ask` appears before every key mapping to `deny`
And therefore no broad `ask` pattern can override a `deny` pattern under opencode's last-matching-rule evaluation

## AC-042-11-05 — The block and its ordering rule are documented
Given `docs/AGENTS_AND_SKILLS.md`
When the repo-level permission block subsection is read
Then it contains the heading `### Repo-level permission block`
And it states `last matching rule wins`
And it states that the catch-all comes first and the specific rules come after
And it lists the denied actions: force-push, push to `main`/`master`, remote-branch delete, `git branch -D`, and `git tag`
And it lists the asked actions: `git commit` and `git push`
And it states that agent frontmatter permission blocks take precedence for that agent
