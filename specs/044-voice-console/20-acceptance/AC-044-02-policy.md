# AC-044-02: Never-list policy classifier

## AC-044-02-01 — Merge is blocked
Given a bash intent with command `gh pr merge 42 --squash`
When `policy.classify` runs
Then the result is blocked with rule `merge`
And `git merge origin/main` and `glab mr merge 7` are blocked with rule `merge`

## AC-044-02-02 — Tag creation is blocked
Given a bash intent with command `git tag v1.2.3`
When `policy.classify` runs
Then the result is blocked with rule `tag`
And `gh release create v1.2.3` is blocked with rule `tag`

## AC-044-02-03 — Push to a protected branch is blocked
Given a bash intent with command `git push origin main`
When `policy.classify` runs
Then the result is blocked with rule `push-main`
And `git push origin HEAD:master`, `git push --all`, and `git push --mirror` are each blocked with rule `push-main`
And `git push origin spec/044-voice-console` is not blocked by this rule

## AC-044-02-04 — Force-push is blocked
Given a bash intent with command `git push --force origin spec/044-voice-console`
When `policy.classify` runs
Then the result is blocked with rule `force-push`
And `git push -f`, `git push --force-with-lease`, and `git push origin +spec/044-voice-console` are each blocked with rule `force-push`

## AC-044-02-05 — Branch deletion is blocked
Given a bash intent with command `git branch -D spec/044-voice-console`
When `policy.classify` runs
Then the result is blocked with rule `delete-branch`
And `git push origin --delete spec/044-voice-console` and `git push origin :spec/044-voice-console` are each blocked with rule `delete-branch`

## AC-044-02-06 — Gate-threshold edits are blocked
Given an edit intent with path `scripts/check-code-principles.sh`
When `policy.classify` runs
Then the result is blocked with rule `gate-threshold`
And paths matching `**/pmd*.xml`, `**/*golangci*.yml`, `**/.eslintrc*`, `**/stryker.conf.json`, `**/mutation.mk`, `**/pitest-profile.xml`, and `**/mutmut-pyproject.toml` are each blocked with rule `gate-threshold`

## AC-044-02-07 — Secret creation and rotation are blocked
Given a bash intent with command `gh secret set NPM_TOKEN`
When `policy.classify` runs
Then the result is blocked with rule `secret-rotate`
And `glab variable set FOO`, `security add-generic-password -a x -s y`, and an edit to `config/agent.local.env`, `config/model.local.env`, or `.envrc` are each blocked with rule `secret-rotate`

## AC-044-02-08 — Writes outside the repository are blocked
Given a repo root of `/tmp/repo` and a write intent with path `/tmp/elsewhere/out.txt`
When `policy.classify` runs
Then the result is blocked with rule `write-outside-repo`
And `/tmp/repo/../elsewhere/out.txt` is blocked with the same rule
And a symlink inside the repo pointing at `/tmp/elsewhere` is blocked with the same rule
And a write to `/tmp/repo/docs/VOICE_CONSOLE.md` is not blocked by this rule

## AC-044-02-09 — Git scaffolding is blocked
Given a bash intent with command `git init`
When `policy.classify` runs
Then the result is blocked with rule `git-init`
And `git submodule add https://example.invalid/x.git vendor/x` and `git submodule update --init` are each blocked with rule `git-init`

## AC-044-02-10 — Matching normalises case and whitespace
Given the commands `  GIT   PUSH   ORIGIN   MAIN  ` and `Git Push Origin Main`
When `policy.classify` runs on each
Then both are blocked with rule `push-main`

## AC-044-02-11 — Read-only intents are allowed without confirmation
Given an intent with tool `read` and path `/tmp/repo/docs/VOICE_CONSOLE.md`
When `policy.classify` runs
Then the result is `blocked:false`, `rule:null`, `requiresConfirmation:false`
And the same holds for tools `grep` and `glob`

## AC-044-02-12 — Unclassified intents require confirmation
Given an intent with tool `webfetch`, no command, and no paths
When `policy.classify` runs
Then the result is `blocked:false`, `rule:null`, `requiresConfirmation:true`

## AC-044-02-13 — Classification is pure
Given a git-clean working tree and a `policy.mjs` that imports no filesystem or network module
When `node policy.mjs --intent '{"tool":"bash","command":"git push origin main"}'` runs
Then exit code is 0
And stdout parses as one JSON object with `blocked` true and `rule` `push-main`
And the working tree is unchanged
