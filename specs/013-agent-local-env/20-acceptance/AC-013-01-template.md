# AC-013-01: committed `config/agent.local.env.example` template

## AC-013-01-01 — The template file exists and is committed
Given the repo root
When `config/agent.local.env.example` is checked
Then the file exists
And it is tracked by git (`git ls-files --error-unmatch config/agent.local.env.example` exits 0)

## AC-013-01-02 — Every credential has a placeholder value and a comment
Given `config/agent.local.env.example` exists
When its contents are read
Then every non-empty, non-comment `KEY=value` line has a placeholder value of the `<...>` form
And the line immediately above it is a comment describing the credential, its consumer, and how to create it

## AC-013-01-03 — The template enumerates exactly the real credentials
Given `config/agent.local.env.example` exists
When its variable names are listed
Then the set is exactly {`GITHUB_TOKEN`, `GH_TOKEN`}
And no line references Jira, Confluence, Jenkins, Bitbucket, or kubeconfig credentials

## AC-013-01-04 — The template header states the per-machine copy-fill workflow
Given `config/agent.local.env.example` exists
When its header comment block is read
Then it instructs copying the file to `config/agent.local.env`, filling real values, and never committing the real file
