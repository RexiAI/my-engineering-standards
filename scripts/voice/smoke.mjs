#!/usr/bin/env node
// smoke.mjs — zero-cost structural smoke for the voice console. No network, no
// model weights, no audio device. Python is optional: the worker check is a
// SKIP when python3 is absent.
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, basename } from "node:path";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { classify } from "./policy.mjs";

const VOICE_DIR = join(fileURLToPath(new URL(".", import.meta.url)));
const REPO = join(VOICE_DIR, "..", "..");

let failures = 0;

function report(ok, line) {
  process.stdout.write(line + "\n");
  if (!ok) failures += 1;
}

function checkAgent() {
  const path = join(REPO, "agents-optional", "voice-concierge.md");
  if (!existsSync(path)) return report(false, "[FAIL] agent voice-concierge.md");
  const text = readFileSync(path, "utf8");
  const noModel = !/^model:/m.test(text);
  report(noModel, "[OK] agent voice-concierge.md");
}

function checkPolicy() {
  const result = classify({ tool: "bash", command: "git push origin main", paths: [], repoRoot: REPO });
  report(result.blocked === true && result.rule === "push-main", "[OK] policy refuses");
}

function checkInstall() {
  const config = join(tmpdir(), `voice-smoke-${process.pid}`);
  const run = spawnSync(process.execPath, [join(VOICE_DIR, "install.mjs"), "--dry-run"], {
    env: Object.assign({}, process.env, { OPENCODE_CONFIG_DIR: config }),
    encoding: "utf8",
  });
  const wroteNothing = !existsSync(config);
  report(run.status === 0 && wroteNothing, "[OK] install dry-run");
}

function checkParses() {
  const files = readdirSync(VOICE_DIR).filter((name) => name.endsWith(".mjs")).sort();
  for (const name of files) {
    const run = spawnSync(process.execPath, ["--check", join(VOICE_DIR, name)], { stdio: "ignore" });
    report(run.status === 0, `[OK] ${name} parses`);
  }
}

function checkPrintConfig() {
  const run = spawnSync(process.execPath, [join(VOICE_DIR, "voice-console.mjs"), "--print-config"], {
    encoding: "utf8",
  });
  let parsed = null;
  try {
    parsed = JSON.parse(run.stdout);
  } catch {
    parsed = null;
  }
  report(run.status === 0 && parsed !== null, "[OK] print-config");
}

function checkWorker() {
  const probe = spawnSync("python3", ["--version"], { stdio: "ignore" });
  if (probe.error && probe.error.code === "ENOENT") {
    process.stdout.write("[SKIP] tts-worker.py\n");
    return;
  }
  const run = spawnSync("python3", [join(VOICE_DIR, "tts-worker.py"), "--self-check"], { encoding: "utf8" });
  report(run.status === 0, "[OK] tts-worker.py");
}

function main() {
  checkAgent();
  checkPolicy();
  checkInstall();
  checkParses();
  checkPrintConfig();
  checkWorker();
  return failures === 0 ? 0 : 1;
}

process.exitCode = main();
