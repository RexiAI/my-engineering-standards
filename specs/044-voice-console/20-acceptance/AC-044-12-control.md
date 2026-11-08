# AC-044-12: Gated control

## AC-044-12-01 — Control is opt-in
Given `--mode narrate` or `--mode converse`
When a `question.asked` or `permission.asked` event arrives
Then one `ignored` record is written
And the recorder holds zero reply requests

## AC-044-12-02 — Questions surface numbered options
Given `--mode control` and a `question.asked` event with three labelled options
When the event is handled
Then one `spoken` record is written containing the header and all three labels
And each label is preceded by its number

## AC-044-12-03 — Answers by number or label
Given the three-option question is pending
When the spoken transcript is `2`
Then the second option's label is sent as the reply
And when the spoken transcript is `approve` for a question with label `Approve`
Then that label is sent as the reply

## AC-044-12-04 — Unmatched answers re-prompt once, then stay pending
Given the question is pending
When the spoken transcript is `banana`
Then the bridge speaks the reprompt once
And the recorder still holds zero replies
And a second unmatched transcript writes a `pending` record and sends nothing

## AC-044-12-05 — Free-text questions send the transcript verbatim
Given a `question.asked` event with no options
When the spoken transcript is `stage four`
Then the reply body carries `stage four` verbatim

## AC-044-12-06 — Read-only permissions are answerable by voice
Given a `permission.asked` event for tool `read`
When the spoken transcript is `yes`
Then exactly one permission reply is recorded
And no terminal confirmation was read

## AC-044-12-07 — Mutating permissions wait for the terminal
Given a `permission.asked` event for bash `rm -rf build`
When the bridge speaks its summary
Then no reply is recorded yet
And when `--input-script` supplies `y`
Then exactly one permission reply with `reply: "once"` is recorded

## AC-044-12-08 — Declined or abandoned confirmations send nothing
Given the same mutating permission
When `--input-script` supplies `n`
Then no reply is recorded and one `refused` record with rule `not-confirmed` is written
And when the script reaches EOF instead, or `--confirm-timeout` expires
Then no reply is recorded and one `pending` record is written

## AC-044-12-09 — Blocked permissions are refused and not overridable
Given a `permission.asked` event whose bash command is `git push origin main`
When `--input-script` supplies `y`
Then no request is recorded
And one `refused` record with rule `push-main` is written

## AC-044-12-10 — Slash prompts need terminal confirmation
Given `--mode control` and a spoken transcript of `/build 044-voice-console`
When the confirmation is answered `y`
Then exactly one prompt request carrying `/build 044-voice-console` is recorded
And when it is answered `n` or the script reaches EOF
Then no prompt request is recorded and one `refused` record with rule `not-confirmed` is written
