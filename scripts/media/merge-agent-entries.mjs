#!/usr/bin/env node
// merge-agent-entries.mjs — add the opt-in media agent family to a child repo's
// opencode.json (ADR 0018). Called by scripts/bootstrap-actions.sh when the
// `--with-media` capability is selected: the family lives in `agents-optional/`
// and is loaded only through these per-repo `agent.*` entries.
//
//   node scripts/media/merge-agent-entries.mjs <opencode.json>
//
// Exit codes are the caller's outcome contract — bootstrap-actions.sh reports
// each one differently, so they are load-bearing:
//   0  entries added, file written
//   1  every entry was already present, nothing written (idempotent re-run)
//   2  config is not a plain JSON object, file left untouched

import { existsSync, readFileSync, writeFileSync } from "node:fs";

const AGENTS = ["media-image", "media-video", "media-voice", "media-producer"];
const file = process.argv[2];

// loadConfig — the existing config, or a fresh one when the child has none.
// Throws (→ exit 2) for anything that is not a plain JSON object, so the
// caller can warn instead of overwriting a hand-edited or JSONC file.
function loadConfig() {
  if (!existsSync(file)) return { "$schema": "https://opencode.ai/config.json" };
  const cfg = JSON.parse(readFileSync(file, "utf8"));
  if (typeof cfg !== "object" || cfg === null || Array.isArray(cfg)) {
    throw new Error("not a JSON object");
  }
  return cfg;
}

let cfg;
try {
  cfg = loadConfig();
} catch {
  process.exit(2);
}

if (!cfg.agent || typeof cfg.agent !== "object") cfg.agent = {};

const missing = AGENTS.filter((name) => !cfg.agent[name]);
if (missing.length === 0) process.exit(1);

for (const name of missing) {
  cfg.agent[name] = { prompt: `{file:.standards/agents-optional/${name}.md}` };
}
writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
