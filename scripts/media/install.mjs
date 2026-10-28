#!/usr/bin/env node
// install.mjs — install the provider-agnostic media agent family into the
// opencode GLOBAL config dir, plus the backend-contract example. Same script
// on Linux and Windows (opencode resolves ~ to %USERPROFILE% there).
// Idempotent; safe to re-run after every `git pull` in this repo.
//
//   node scripts/media/install.mjs            # install / update
//   node scripts/media/install.mjs --uninstall
//
// Target layout:
//   ~/.config/opencode/agents/media-*.md
//   ~/.config/opencode/media/backends.json          (created from the example
//                                                    only when absent)
//   ~/.config/opencode/media/backends.example.json
//
// --uninstall removes the agents and the example. It never deletes a user's
// backends.json: that file is machine configuration, not repo state.

import { copyFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const GLOBAL = process.env.OPENCODE_CONFIG_DIR || join(homedir(), ".config", "opencode");
const uninstall = process.argv.includes("--uninstall");

const AGENTS = ["media-image.md", "media-video.md", "media-voice.md", "media-producer.md"];
const EXAMPLE = join(REPO, "scripts", "media", "backends.example.json");
const MEDIA_DIR = join(GLOBAL, "media");

if (uninstall) {
  for (const a of AGENTS) rmSync(join(GLOBAL, "agents", a), { force: true });
  rmSync(join(MEDIA_DIR, "backends.example.json"), { force: true });
  console.log(`uninstalled media agents from ${GLOBAL}`);
  console.log(`kept ${join(MEDIA_DIR, "backends.json")} (machine config)`);
  process.exit(0);
}

mkdirSync(join(GLOBAL, "agents"), { recursive: true });
for (const a of AGENTS) {
  const src = join(REPO, "agents", a);
  if (!existsSync(src)) {
    console.error(`missing ${src} — run from a full clone of the standards repo`);
    process.exit(1);
  }
  copyFileSync(src, join(GLOBAL, "agents", a));
}

mkdirSync(MEDIA_DIR, { recursive: true });
if (!existsSync(EXAMPLE)) {
  console.error(`missing ${EXAMPLE} — run from a full clone of the standards repo`);
  process.exit(1);
}
copyFileSync(EXAMPLE, join(MEDIA_DIR, "backends.example.json"));

const config = join(MEDIA_DIR, "backends.json");
if (!existsSync(config)) {
  copyFileSync(EXAMPLE, config);
  console.log(`created ${config} — edit it and replace the <angle-bracket> commands`);
} else {
  console.log(`kept existing ${config}`);
}

console.log(`installed ${AGENTS.length} agents -> ${join(GLOBAL, "agents")}`);
console.log("restart opencode (desktop or TUI) to load them.");
