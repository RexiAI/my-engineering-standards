#!/usr/bin/env node
// install.mjs — install the media agent family + voice-chat app into the
// opencode GLOBAL config dir. Same script on Linux and Windows (opencode
// resolves ~ to %USERPROFILE% there). Idempotent; safe to re-run after every
// `git pull` in this repo.
//
//   node scripts/media/install.mjs            # install / update
//   node scripts/media/install.mjs --uninstall
//
// Target layout:
//   ~/.config/opencode/agents/media-*.md
//   ~/.config/opencode/media/voice-chat/voice-chat.mjs

import { cpSync, mkdirSync, rmSync, existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const GLOBAL = process.env.OPENCODE_CONFIG_DIR || join(homedir(), ".config", "opencode");
const uninstall = process.argv.includes("--uninstall");

const AGENTS = ["media-image.md", "media-video.md", "media-voice.md", "media-producer.md"];

if (uninstall) {
  for (const a of AGENTS) rmSync(join(GLOBAL, "agents", a), { force: true });
  rmSync(join(GLOBAL, "media", "voice-chat"), { recursive: true, force: true });
  console.log(`uninstalled media agents from ${GLOBAL}`);
  process.exit(0);
}

mkdirSync(join(GLOBAL, "agents"), { recursive: true });
for (const a of AGENTS) {
  const src = join(REPO, "agents", a);
  if (!existsSync(src)) { console.error(`missing ${src} — run from a full clone of the standards repo`); process.exit(1); }
  cpSync(src, join(GLOBAL, "agents", a));
}
mkdirSync(join(GLOBAL, "media"), { recursive: true });
cpSync(join(REPO, "scripts", "media", "voice-chat"), join(GLOBAL, "media", "voice-chat"), { recursive: true });

console.log(`installed ${AGENTS.length} agents -> ${join(GLOBAL, "agents")}`);
console.log(`installed voice-chat   -> ${join(GLOBAL, "media", "voice-chat")}`);
console.log("restart opencode (desktop or TUI) to load them.");
