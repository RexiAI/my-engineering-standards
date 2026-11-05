# AC-043: Single-reward contract

## AC-043-17 — A passing verifier produces exactly one reward
Given a task verifier that writes `1` to `$EVAL_REWARD_FILE` and exits 0
When the harness grades it
Then `reward.txt` contains exactly one line, `1`
And the harness exits 0
And it prints `REWARD=1`
And it prints no `REASON=` line

## AC-043-18 — A non-zero verifier exit forces a zero reward
Given a task verifier that writes `1` and then exits 1
When the harness grades it
Then `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REWARD=0` and `REASON=verifier-exit-1`

## AC-043-19 — A crashed verifier scores zero
Given a task verifier that exits 1 without writing a reward
When the harness grades it
Then `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REASON=verifier-exit-1`

## AC-043-20 — A silent verifier scores zero
Given a task verifier that exits 0 without writing a reward
When the harness grades it
Then `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REASON=no-reward-value`
And it records a warning that the verifier wrote no reward

## AC-043-21 — Two reward values are rejected
Given a task verifier that writes `1` and then `0` as two lines
When the harness grades it
Then `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REASON=multiple-reward-values`

## AC-043-22 — An invalid reward value is rejected
Given a task verifier that writes `2`, `pass`, or an empty value
When the harness grades it
Then `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REASON=invalid-reward-value`

## AC-043-23 — Repeated grading overwrites, never appends
Given one workspace graded twice, first to `1` and then to `0`
When the second grading finishes
Then `reward.txt` contains exactly one line, `0`
And the file was replaced atomically, leaving no `*.tmp` sibling

## AC-043-24 — A verifier timeout scores zero
Given a task verifier that runs past its manifest `timeoutSec`
When the harness grades it
Then the verifier process is terminated
And `reward.txt` contains exactly one line, `0`
And the harness exits 1
And it prints `REASON=verifier-timeout`
And no temporary reward file remains
