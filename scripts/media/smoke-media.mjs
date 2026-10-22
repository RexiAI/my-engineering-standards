#!/usr/bin/env node
// smoke-media.mjs — no-cost structural smoke for the media agent family.
// Validates agent files, voice-chat syntax, and bl command construction
// (--dry-run only; consumes zero credits). Exit 0 = green.

import { spawnSync } from "node:child_process";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
let fails = 0;
const ok = (name) => console.log(`[OK] ${name}`);
const bad = (name, why) => { console.log(`[FAIL] ${name}: ${why}`); fails++; };

// On POSIX `bl` is a real binary; on Windows it is an npm `.cmd` shim, which
// Node cannot exec without a command interpreter (spawning it directly yields
// ENOENT). Route through cmd.exe there so the check works on both platforms.
const runBl = (argv) =>
  process.platform === "win32"
    ? spawnSync(process.env.ComSpec || "cmd.exe", ["/d", "/s", "/c", "bl", ...argv], { encoding: "utf8", timeout: 30000 })
    : spawnSync("bl", argv, { encoding: "utf8", timeout: 30000 });

// 1. agent files: exist, have description + mode frontmatter, no pinned model
for (const f of readdirSync(join(REPO, "agents")).filter((n) => n.startsWith("media-"))) {
  const txt = readFileSync(join(REPO, "agents", f), "utf8");
  const fm = txt.split("---")[1] ?? "";
  if (!/^description:/m.test(fm)) bad(f, "missing description in frontmatter");
  else if (!/^mode:/m.test(fm)) bad(f, "missing mode in frontmatter");
  else if (/^model:/m.test(fm)) bad(f, "model: pinned in frontmatter (governance: must not pin)");
  else ok(`agent ${f}`);
}
for (const need of ["media-image.md", "media-video.md", "media-voice.md", "media-producer.md"])
  if (!existsSync(join(REPO, "agents", need))) bad(need, "missing");

// 2. voice-chat parses
const chk = spawnSync(process.execPath, ["--check", join(REPO, "scripts", "media", "voice-chat", "voice-chat.mjs")], { encoding: "utf8" });
chk.status === 0 ? ok("voice-chat.mjs parses") : bad("voice-chat.mjs", chk.stderr);

// 3. bl command construction (dry-run only) — skip cleanly if bl absent
const which = spawnSync(process.platform === "win32" ? "where" : "which", ["bl"], { encoding: "utf8" });
if (which.status !== 0) {
  console.log("[SKIP] bl CLI not on PATH — install via bootstrap or `npm i -g bailian-cli`");
} else {
  const cases = [
    ["image", ["image", "generate", "--prompt", "smoke", "--dry-run"]],
    ["video", ["video", "generate", "--prompt", "smoke", "--model", "happyhorse-1.1-t2v", "--dry-run"]],
    ["tts", ["speech", "synthesize", "--text", "smoke", "--model", "qwen-audio-3.0-tts-plus", "--voice", "longanqian", "--dry-run"]],
    ["asr", ["speech", "recognize", "--url", "https://example.invalid/a.wav", "--model", "qwen-audio-3.0-asr-flash", "--dry-run"]],
  ];
  for (const [name, argv] of cases) {
    const r = runBl(argv);
    r.status === 0 ? ok(`bl ${name} dry-run`) : bad(`bl ${name} dry-run`, (r.stderr || r.stdout || "").split("\n").slice(-1)[0]);
  }
}

process.exit(fails ? 1 : 0);
