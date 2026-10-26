# AC-033: Detection across the full matrix

## AC-033-05 — java detected via pom.xml
Given a child repo containing only `pom.xml`
When `bootstrap.sh` detects the stack
Then the backend stack is `java` with evidence `pom.xml`

## AC-033-06 — go detected via a .go file
Given a child repo containing a `*.go` file and no `pom.xml`
When `bootstrap.sh` detects the stack
Then the backend stack is `go` with evidence the detected `*.go` file

## AC-033-07 — node backend detected via package.json
Given a child repo containing `package.json` with no frontend markers
When `bootstrap.sh` detects the stack
Then the backend stack is `node` with evidence `package.json`

## AC-033-08 — python detected via pyproject.toml
Given a child repo containing `pyproject.toml`
When `bootstrap.sh` detects the stack
Then the backend stack is `python` with evidence `pyproject.toml`

## AC-033-09 — python detected via requirements.txt
Given a child repo containing `requirements.txt` and no `pyproject.toml`
When `bootstrap.sh` detects the stack
Then the backend stack is `python` with evidence `requirements.txt`

## AC-033-10 — rust detected via Cargo.toml
Given a child repo containing `Cargo.toml`
When `bootstrap.sh` detects the stack
Then the backend stack is `rust` with evidence `Cargo.toml`

## AC-033-11 — angular detected via @angular/core
Given a `package.json` whose dependencies include `@angular/core`
When `bootstrap.sh` detects the frontend
Then the frontend stack is `angular`

## AC-033-12 — ionic detected via @ionic/*
Given a `package.json` whose dependencies include `@ionic/core`
When `bootstrap.sh` detects the frontend
Then the frontend stack is `ionic`

## AC-033-13 — react-native detected via expo or react-native
Given a `package.json` whose dependencies include `expo` or `react-native`
When `bootstrap.sh` detects the frontend
Then the frontend stack is `react-native`

## AC-033-14 — nextjs detected via next
Given a `package.json` whose dependencies include `next`
When `bootstrap.sh` detects the frontend
Then the frontend stack is `nextjs`

## AC-033-15 — react detected via react
Given a `package.json` whose dependencies include `react` and no next, expo, react-native, ionic, or angular marker
When `bootstrap.sh` detects the frontend
Then the frontend stack is `react`

## AC-033-16 — no framework marker yields frontend none
Given a `package.json` with no recognized framework marker
When `bootstrap.sh` detects the frontend
Then the frontend stack is `none`

## AC-033-17 — specific frontend markers win over react
Given a `package.json` listing both `react` and a more specific marker
When `bootstrap.sh` detects the frontend
Then `expo`/`react-native` wins over `next` wins over `@ionic/*` wins over `react` wins over `@angular/core`
