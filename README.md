# my-engineering-standards

Shared engineering standards used across all projects. This repo is designed to be added as a Git submodule (`.standards/`) in child repos, then bridged to OpenCode via `opencode.json` instructions.

## Usage in a Child Repo

```bash
git submodule add git@github.com:pucelano-95/my-engineering-standards.git .standards
./.standards/scripts/bootstrap.sh
```

This creates an `opencode.json` with `instructions` pointing into `.standards/` and symlinks `AGENTS.md` to the master rules file.

OpenCode then auto-discovers the rules and loads them from the submodule.

## Structure

```
my-engineering-standards/
├── AGENTS.md                    # Master OpenCode rules
├── docs/                        # Shared standards documentation
├── language-specific/           # Per-language rules, lint configs, templates
│   ├── java/
│   ├── go/
│   └── javascript/
├── templates/                   # Bridge files, Dockerfiles, gitignores
└── scripts/                     # Bootstrap and maintenance utilities
```

## Pinning Versions

Because child repos reference this repo as a Git submodule, each child repo pins a specific commit. To update:

```bash
cd .standards && git pull && cd ..
git add .standards && git commit -m "chore: bump engineering standards"
```
