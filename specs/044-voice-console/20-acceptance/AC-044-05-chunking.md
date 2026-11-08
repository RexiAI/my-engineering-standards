# AC-044-05: Sentence chunking and speech budget

## AC-044-05-01 — Split on terminators
Given the text `Hello there. Next one! Really? Yes.`
When `splitSentences` runs
Then it returns four sentences
And each retains its terminator

## AC-044-05-02 — Decimals are not boundaries
Given the text `Pi is 3.14 exactly.`
When `splitSentences` runs
Then it returns one sentence

## AC-044-05-03 — Abbreviations are not boundaries
Given the text `Use e.g. this form. Then stop.`
When `splitSentences` runs
Then it returns two sentences
And the first contains `e.g. this form.`

## AC-044-05-04 — Question and exclamation boundaries need no capital
Given the text `Ready? go! done.`
When `splitSentences` runs
Then it returns three sentences

## AC-044-05-05 — Sentence cap
Given a budget of 3 sentences and 45 seconds
And five sentences of five words each
When `takeWindow` runs
Then `spoken` has 3 sentences
And `deferred` has 2 sentences

## AC-044-05-06 — Time cap wins when it is reached first
Given a budget of 3 sentences and 45 seconds
And four sentences of 80 words each at 2.5 words per second
When `takeWindow` runs
Then `spoken` has 1 sentence
And `deferred` has 3 sentences
And `estimatedSeconds` is at most 45

## AC-044-05-07 — The first sentence is always spoken whole
Given a budget of 3 sentences and 45 seconds
And one sentence of 200 words
When `takeWindow` runs
Then `spoken` contains that whole sentence
And no sentence is truncated anywhere in the output

## AC-044-05-08 — Deferred windows drain to empty
Given five one-sentence windows deferred from the first `takeWindow`
When `takeWindow` is applied repeatedly to the remainder
Then each call returns the next window
And the final call returns an empty `spoken` with an empty `deferred`

## AC-044-05-09 — Streaming emits each sentence once
Given a chunker fed `"Hello"`, then `"Hello world. Se"`, then `"cond."`, then `finish()`
When each `feed` result is collected
Then the composition is `Hello world.` then `Second.`
And no sentence appears twice
And `finish()` returns only the unterminated remainder
