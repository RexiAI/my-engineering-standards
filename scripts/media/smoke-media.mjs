#!/usr/bin/env node
// smoke-media.mjs — no-cost structural smoke for the media agent family.
// Validates the agent files and the backend-contract example; never invokes a
// backend and never touches the network. Exit 0 = green.

import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
// Assembled at runtime so this guard file itself carries no literal vendor
// token (same construction precedent as check-no-hardcoded-secrets.sh).
const VENDOR = new RegExp([
  "ali" + "baba",
  "ali" + "yun",
  "dash" + "scope",
  "bai" + "lian",
  "qw" + "en",
  "sk-" + "sp-",
].join("|"), "i");
let fails = 0;
const ok = (name) => console.log(`[OK] ${name}`);
const bad = (name, why) => { console.log(`[FAIL] ${name}: ${why}`); fails++; };

const AGENTS = ["media-image.md", "media-video.md", "media-voice.md", "media-producer.md"];

// 1. agent files: exist, description + mode frontmatter, no pinned model, no
//    vendor-specific command surface.
for (const f of AGENTS) {
  const p = join(REPO, "agents", f);
  if (!existsSync(p)) { bad(f, "missing"); continue; }
  const txt = readFileSync(p, "utf8");
  const fm = txt.split("---")[1] ?? "";
  if (!/^description:/m.test(fm)) { bad(f, "missing description in frontmatter"); continue; }
  if (!/^mode:/m.test(fm)) { bad(f, "missing mode in frontmatter"); continue; }
  if (/^model:/m.test(fm)) { bad(f, "model: pinned in frontmatter (governance: must not pin)"); continue; }
  if (VENDOR.test(txt)) { bad(f, "vendor-specific token found"); continue; }
  ok(`agent ${f}`);
}

// 2. agents point at the backend contract
for (const f of AGENTS) {
  const p = join(REPO, "agents", f);
  if (!existsSync(p)) continue;
  const txt = readFileSync(p, "utf8");
  if (!txt.includes("backends.json")) { bad(f, "does not reference backends.json"); continue; }
  ok(`backend contract referenced by ${f}`);
}

// 3. example contract parses and covers every operation the agents use
const example = join(REPO, "scripts", "media", "backends.example.json");
if (!existsSync(example)) {
  bad("backends.example.json", "missing");
} else {
  let cfg;
  try { cfg = JSON.parse(readFileSync(example, "utf8")); }
  catch (e) { bad("backends.example.json", `invalid JSON: ${e.message}`); cfg = null; }
  if (cfg) {
    if (VENDOR.test(JSON.stringify(cfg))) bad("backends.example.json", "vendor-specific token found");
    else ok("backends.example.json parses");
    const expected = { image: ["generate", "edit"], video: ["generate"], tts: ["command"], asr: ["command"] };
    for (const [section, ops] of Object.entries(expected)) {
      const got = cfg[section];
      if (!got || typeof got !== "object") { bad(`backends.example.json ${section}`, "missing section"); continue; }
      for (const op of ops) {
        const argv = got[op];
        if (!Array.isArray(argv) || argv.length === 0) bad(`backends.example.json ${section}.${op}`, "expected a non-empty argv array");
        else ok(`contract ${section}.${op}`);
      }
    }
  }
}

// 4. no shipped provider/model ids in the family's files
for (const p of [join(REPO, "docs", "MEDIA_AGENTS.md"), example]) {
  if (!existsSync(p)) continue;
  if (VENDOR.test(readFileSync(p, "utf8"))) bad(p.replace(REPO + "/", ""), "vendor-specific token found");
}

process.exit(fails ? 1 : 0);
