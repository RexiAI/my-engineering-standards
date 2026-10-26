# AC-033: init-ci.sh extension — backend python/rust, frontend ionic

## AC-033-31 — usage and error text updated together
Given `init-ci.sh` is invoked with an unknown flag
When the error path runs
Then the printed usage lists `--backend java,go,node,python,rust` and `--frontend nextjs,react,angular,ionic,react-native,static`

## AC-033-32 — `--backend python` is accepted
Given `init-ci.sh --backend python`
When the script runs
Then no unknown-flag or invalid-backend error is raised
And a python backend CI reference is emitted

## AC-033-33 — `--backend rust` is accepted
Given `init-ci.sh --backend rust`
When the script runs
Then no unknown-flag or invalid-backend error is raised
And a rust backend CI reference is emitted

## AC-033-34 — `--frontend ionic` is accepted
Given `init-ci.sh --frontend ionic`
When the script runs
Then no unknown-flag error is raised
And an ionic frontend CI reference is emitted
