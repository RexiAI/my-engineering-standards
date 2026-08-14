# AC-020-03: the real `config/model.local.env` is gitignored, the example is not

## AC-020-03-01 — The real env file path is gitignored even when absent on disk
Given `.gitignore` in the repo root
When `git check-ignore config/model.local.env` is run (the file need not exist on disk)
Then it exits 0

## AC-020-03-02 — The committed example stays trackable
Given `.gitignore` in the repo root
When `git check-ignore config/model.local.env.example` is run
Then it does not exit 0 (the template is not ignored and remains commitable)
