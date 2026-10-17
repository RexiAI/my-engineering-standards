#!/usr/bin/env node
// voice-chat.mjs — full-duplex realtime voice chat over the DashScope
// Qwen-Audio Realtime WebSocket API (OpenAI-realtime-style events).
//
// Transport facts (probed 2026-10-16, see docs/MEDIA_AGENTS.md):
//   * Token-Plan harness keys (sk-sp-...) are rejected by api-ws/v1/realtime
//     (InvalidApiKey). This app requires a standard DashScope key (sk-...).
//   * Singapore/intl: wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime
//     Beijing:         wss://dashscope.aliyuncs.com/api-ws/v1/realtime
//     Model is a URL query param; auth is a Bearer header on the handshake.
//   * Audio in: PCM s16le 16 kHz mono. Audio out: PCM s16le 24 kHz mono.
//
// Node >= 22 (global WebSocket). Zero runtime dependencies; ffmpeg/ffplay on PATH.

import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";

const args = parseArgs(process.argv.slice(2));
if (args.help) usage(0);

const MODEL = args.model ?? "qwen-audio-3.0-realtime-plus";
const VOICE = args.voice ?? "longanqian";
const KEY = args.apiKey ?? process.env.BAILIAN_API_KEY ?? process.env.DASHSCOPE_API_KEY ?? "";
if (!KEY) fail("No API key. Pass --api-key or set BAILIAN_API_KEY / DASHSCOPE_API_KEY (standard DashScope sk- key).");
if (KEY.startsWith("sk-sp-"))
  fail("Token-Plan harness keys (sk-sp-...) cannot authenticate the realtime WebSocket endpoint. Use a standard DashScope sk- key, or fall back to turn-based voice (agent media-voice / skill bailian-gen).");

const BASE = args.url
  ? args.url
  : args.beijing ? "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
                  : "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime";
const URL = `${BASE}?model=${encodeURIComponent(MODEL)}`;

if (args.listDevices) listDevices();

const recorder = startRecorder();
const player = startPlayer();

process.stdout.write(`voice-chat: ${MODEL}  voice=${VOICE}\nendpoint: ${BASE}\nSpeak; Ctrl-C to exit.\n`);

const ws = new WebSocket(URL, { headers: { Authorization: `Bearer ${KEY}`, "user-agent": "ecc-voice-chat/1" } });
ws.addEventListener("open", () => {
  ws.send(JSON.stringify({
    type: "session.update",
    session: {
      modalities: ["text", "audio"],
      voice: VOICE,
      input_audio_format: "pcm",
      output_audio_format: "pcm",
      ...(args.instructions ? { instructions: args.instructions } : {}),
    },
  }));
});
ws.addEventListener("message", (ev) => onEvent(String(ev.data)));
ws.addEventListener("close", (e) => { log(`socket closed (${e.code}${e.reason ? " " + e.reason : ""})`); shutdown(0); });
ws.addEventListener("error", () => log("socket error"));

recorder.stdout.on("data", (buf) => {
  if (ws.readyState === WebSocket.OPEN)
    ws.send(JSON.stringify({ type: "input_audio_buffer.append", audio: buf.toString("base64") }));
});
recorder.on("exit", (c) => { if (c) { log(`recorder exited (${c})`); shutdown(1); } });

function onEvent(raw) {
  let d; try { d = JSON.parse(raw); } catch { return; }
  const t = d.type ?? "";
  if (t === "response.audio.delta" || t === "response.output_audio.delta") {
    player.push(Buffer.from(d.delta ?? "", "base64"));
  } else if (t === "conversation.item.input_audio_transcription.text" || t === "conversation.item.input_audio_transcription.delta") {
    process.stdout.write(`  you: ${(d.text ?? d.delta ?? "")}\r`);
  } else if (t === "conversation.item.input_audio_transcription.completed") {
    log(`you: ${d.transcript ?? ""}`);
  } else if (t === "response.text.delta" || t === "response.output_text.delta") {
    process.stdout.write(` bot: ${(d.delta ?? "")}\r`);
  } else if (t === "error") {
    log(`error: ${JSON.stringify(d.error ?? d)}`);
  }
}

function startRecorder() {
  const plat = process.platform;
  let inputArgs;
  if (plat === "linux") inputArgs = ["-f", "alsa", "-i", args.device ?? "default"];
  else if (plat === "win32") {
    if (!args.device) fail('Windows needs an input device. Run --list-devices, then pass --device "<mic name>".');
    inputArgs = ["-f", "dshow", "-i", `audio=${args.device}`];
  } else inputArgs = ["-f", "avfoundation", "-i", args.device ?? "default"];
  return spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", ...inputArgs, "-ac", "1", "-ar", "16000", "-f", "s16le", "-"], { stdio: ["ignore", "pipe", "inherit"] });
}

function startPlayer() {
  const has = spawnSync("ffplay", ["-version"], { windowsHide: true });
  if (has.error || has.status !== 0) {
    log("ffplay not found — model audio will be saved to out/media/voice/last-reply.wav instead.");
    return fileSink();
  }
  const p = spawn("ffplay", ["-nodisp", "-loglevel", "error", "-f", "s16le", "-ar", "24000", "-"], { stdio: ["ignore", "pipe", "inherit"] });
  return { push(b) { if (p.stdin.writable) p.stdin.write(b); } };
}

function fileSink() {
  mkdirSync("out/media/voice", { recursive: true });
  return {
    push(b) {
      const data = b;
      const header = Buffer.alloc(44);
      header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4); header.write("WAVE", 8);
      header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
      header.writeUInt32LE(24000, 24); header.writeUInt32LE(48000, 28); header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34);
      header.write("data", 36); header.writeUInt32LE(data.length, 40);
      writeFileSync("out/media/voice/last-reply.wav", Buffer.concat([header, data]));
    },
  };
}

function listDevices() {
  if (process.platform !== "win32") {
    console.log("Linux uses --device with an ALSA name (default works); macOS uses an avfoundation device index/name.");
    process.exit(0);
  }
  const r = spawnSync("ffmpeg", ["-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"], { windowsHide: true, encoding: "utf8" });
  process.stdout.write((r.stderr || r.stdout || "no devices listed\n"));
  process.exit(0);
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--help" || a === "-h") out.help = true;
    else if (a === "--list-devices") out.listDevices = true;
    else if (a === "--beijing") out.beijing = true;
    else if (a.startsWith("--")) {
      const key = a.slice(2).replace(/-(\w)/g, (_, c) => c.toUpperCase());
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) fail(`flag ${a} needs a value`);
      out[key] = next;
      i++;
    } else fail(`unexpected argument: ${a}`);
  }
  return out;
}

function usage(code) {
  console.log(`Usage: node voice-chat.mjs [--model <id>] [--voice <id>] [--device <in>] [--url <wss://...>] [--beijing] [--api-key <k>] [--instructions <text>] [--list-devices]
Requires a standard DashScope sk- API key (NOT a sk-sp- Token-Plan harness key) and ffmpeg/ffplay on PATH.`);
  process.exit(code);
}
function fail(m) { console.error(m); process.exit(2); }
function log(m) { process.stdout.write("\n" + m + "\n"); }
function shutdown(code) { try { recorder.kill(); } catch {} process.exit(code); }
process.on("SIGINT", () => { log(""); shutdown(0); });
