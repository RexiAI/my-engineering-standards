// audio-out.mjs — playback sinks. The file sink numbers WAVs and never
// overwrites; the device sink plays one file at a time through ffplay and
// cancels promptly (SIGTERM, then SIGKILL after one second).
import {
  mkdirSync,
  readdirSync,
  writeFileSync,
  mkdtempSync,
} from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { MissingRuntime } from "./config.mjs";

export function encodeWav(options) {
  const sampleRate = options.sampleRate || 24000;
  const channels = options.channels || 1;
  const samples = options.samples;
  const dataBytes = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataBytes);
  buffer.write("RIFF", 0, "ascii");
  buffer.writeUInt32LE(36 + dataBytes, 4);
  buffer.write("WAVE", 8, "ascii");
  buffer.write("fmt ", 12, "ascii");
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(channels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * channels * 2, 28);
  buffer.writeUInt16LE(channels * 2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36, "ascii");
  buffer.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i += 1) buffer.writeInt16LE(samples[i], 44 + i * 2);
  return buffer;
}

export function silentWav(text, sampleRate) {
  const rate = sampleRate || 24000;
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  const seconds = Math.max(0.05, Math.min(2, words * 0.15));
  const frames = Math.max(1, Math.round(seconds * rate));
  return encodeWav({ sampleRate: rate, samples: new Int16Array(frames) });
}

function nextIndex(dir) {
  let max = 0;
  for (const name of readdirSync(dir)) {
    const match = /^(\d{4})\.wav$/.exec(name);
    if (match) max = Math.max(max, Number(match[1]));
  }
  return max + 1;
}

export function createFileSink(dir) {
  mkdirSync(dir, { recursive: true });
  return {
    kind: "file",
    async write(buffer) {
      const name = String(nextIndex(dir)).padStart(4, "0") + ".wav";
      const path = join(dir, name);
      writeFileSync(path, buffer);
      return { path };
    },
  };
}

function assertFfplay() {
  const probe = spawnSync("ffplay", ["-version"], { stdio: "ignore" });
  if (probe.error && probe.error.code === "ENOENT") {
    throw new MissingRuntime("ffplay not found on PATH");
  }
}

function waitForExit(child) {
  return new Promise((resolve) => {
    let settled = false;
    const finish = (reason) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(reason);
    };
    const timer = setTimeout(() => child.kill("SIGKILL"), 1000);
    child.on("exit", () => finish("exited"));
    child.kill("SIGTERM");
  });
}

export function createDeviceSink() {
  let active = null;
  let counter = 0;
  const scratch = mkdtempSync(join(tmpdir(), "voice-out-"));

  function supersede() {
    if (!active) return;
    const previous = active;
    active = null;
    previous.settle({ cancelled: "superseded" });
    previous.child.kill("SIGTERM");
  }

  function play(path) {
    assertFfplay();
    supersede();
    counter += 1;
    const id = counter;
    const child = spawn("ffplay", ["-nodisp", "-autoexit", "-loglevel", "quiet", path], {
      stdio: "ignore",
    });
    const result = new Promise((resolve, reject) => {
      child.on("error", (error) => reject(error));
      child.on("exit", () => {
        if (active && active.id === id) {
          const current = active;
          active = null;
          current.settle({ completed: true });
        }
      });
      active = { id, child, settle: resolve };
    });
    return result;
  }

  async function write(buffer) {
    const path = join(scratch, "utterance.wav");
    writeFileSync(path, buffer);
    return play(path);
  }

  async function cancel() {
    if (!active) return { cancelled: true };
    const current = active;
    active = null;
    current.settle({ cancelled: "stopped" });
    await waitForExit(current.child);
    return { cancelled: true };
  }

  return { kind: "device", write, play, cancel };
}

export function createAudioOut(spec) {
  if (spec.startsWith("file:")) return createFileSink(spec.slice("file:".length));
  return createDeviceSink();
}
