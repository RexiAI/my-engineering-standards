#!/usr/bin/env node
// install.mjs — opt-in installer for the voice console. Mirrors
// scripts/media/install.mjs: it copies the concierge agent and the bridge into
// $OPENCODE_CONFIG_DIR, is idempotent, and removes exactly the installed paths
// on --uninstall. It writes nothing outside the config dir.
import { copyFileSync, mkdirSync, readdirSync, rmSync, existsSync, unlinkSync, rmdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const CONFIG = process.env.OPENCODE_CONFIG_DIR || join(homedir(), ".config", "opencode");
const VOICE_DIR = join(CONFIG, "voice");
const AGENT_DEST = join(CONFIG, "agents", "voice-concierge.md");
const AGENT_SRC = join(REPO, "agents-optional", "voice-concierge.md");
const SOURCE_DIR = join(REPO, "scripts", "voice");

const MODES = ["--uninstall", "--dry-run"];

function mode() {
  for (const flag of MODES) {
    if (process.argv.includes(flag)) return flag;
  }
  return "";
}

function voiceSources() {
  const names = readdirSync(SOURCE_DIR).filter((name) => name.endsWith(".mjs") || name === "tts-worker.py");
  names.sort();
  return names.map((name) => ({ src: join(SOURCE_DIR, name), dest: join(VOICE_DIR, name) }));
}

function destinations() {
  return [{ src: AGENT_SRC, dest: AGENT_DEST }].concat(voiceSources());
}

function missingSource(entries) {
  for (const entry of entries) {
    if (!existsSync(entry.src)) return entry.src;
  }
  return null;
}

function ensureDir(path) {
  mkdirSync(path, { recursive: true });
}

function dryRun(entries) {
  for (const entry of entries) process.stdout.write(entry.dest + "\n");
  return 0;
}

function install(entries) {
  ensureDir(join(CONFIG, "agents"));
  ensureDir(VOICE_DIR);
  for (const entry of entries) copyFileSync(entry.src, entry.dest);
  process.stdout.write(`installed voice console -> ${CONFIG}\n`);
  return 0;
}

function uninstall(entries) {
  for (const entry of entries) {
    if (existsSync(entry.dest)) unlinkSync(entry.dest);
  }
  if (existsSync(VOICE_DIR)) {
    const names = readdirSync(VOICE_DIR);
    if (names.length === 0) rmdirSync(VOICE_DIR);
  }
  process.stdout.write(`uninstalled voice console from ${CONFIG}\n`);
  return 0;
}

function main() {
  const selected = mode();
  const entries = destinations();
  const missing = missingSource(entries);
  if (missing) {
    process.stderr.write(`missing ${missing} — run from a full clone of the standards repo\n`);
    return 3;
  }
  if (selected === "--dry-run") return dryRun(entries);
  if (selected === "--uninstall") return uninstall(entries);
  return install(entries);
}

process.exitCode = main();
