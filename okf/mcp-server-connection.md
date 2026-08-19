---
type: runbook
title: MCP Server Connection
description: How we configure and connect MCP servers in opencode projects
tags: [mcp, configuration, servers, integration]
timestamp: 2026-07-11T00:00:00Z
related:
  - context-window-policy.md
---

# MCP Server Connection

## Pattern

Every MCP server is configured declaratively in `opencode.json` under `mcp.servers[]`. No manual env setup, no global installs, no shell sourcing.

```json
{
  "mcp": {
    "servers": {
      "<server-name>": {
        "command": "<executable>",
        "args": ["<arg1>", "<arg2>"]
      }
    }
  }
}
```

Servers are auto-started by opencode on session init. Stderr goes to `~/.opencode/logs/mcp-<server-name>.log`.

## Verification

```bash
# List all MCP servers and their status
opencode mcp list

# Expected output:
#   github       ● running
#   myinvestor   ● running
```

## Troubleshooting

```bash
# View server logs
opencode mcp logs github

# Restart a server
opencode mcp restart myinvestor

# Common issues:
# - "command not found" → install the npm/uvx package globally
# - "auth failed" → check tokens in env or config
```

## Worked Examples

### 1. GitHub

File operations, PRs, issues, code search. Uses the official `@modelcontextprotocol/server-github` package.

```json
{
  "mcp": {
    "servers": {
      "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"]
      }
    }
  }
}
```

**Auth**: Requires `GITHUB_TOKEN` env var (personal access token with `repo` scope).

```bash
export GITHUB_TOKEN=<your-github-personal-access-token>
```

**Uses**: PR review, issue triage, commit inspection, code search across repos.

### 2. MyInvestor

Fund catalogue and portfolio queries for the MyInvestor wealth platform. Custom MCP server.

```json
{
  "mcp": {
    "servers": {
      "myinvestor": {
        "command": "node",
        "args": ["path/to/myinvestor-mcp-server/index.js"]
      }
    }
  }
}
```

**Auth**: None (public catalogue data).

**Uses**: Search funds by ISIN/name/category, compare portfolios, list facets (gestoras, asset classes, categories).

### 3. RTK (Rust Token Killer)

Filters shell command output to save tokens. Configured as a shell wrapper, not an MCP server — but documented here because it is part of the context toolchain. See [context-window-policy.md](context-window-policy.md) for usage.

**Install**: Global npm package.

```bash
npm install -g @dietrichgebert/rtk
```

### 4. Headroom

Compresses large content on demand. Runs as an MCP tool, not a server.

**Config**: Auto-discovered by opencode. No manual config needed if listed in `opencode.json` `mcp.servers`.

## Dependencies Map

| Tool | Type | Install | Config |
|------|------|---------|--------|
| MCP GitHub | npm package | `npx -y @modelcontextprotocol/server-github` | env `GITHUB_TOKEN` |
| MCP MyInvestor | Node script | bundled with repo | none |
| RTK | npm package | `npm i -g @dietrichgebert/rtk` | shell prefix |
| Headroom | opencode built-in | auto | hook threshold |

## Open Questions

- [ ] Should we add an MCP health-check script that runs on bootstrap?
- [ ] CI integration for MCP: spin up a test server in pipeline?
