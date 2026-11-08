// audio-in.mjs — capture and voice-activity endpointing. File mode is the CI
// path; device mode funnels arecord's raw stdout through exactly the same
// endpointing code.
import { readFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { MissingRuntime } from "./config.mjs";

const RMS_THRESHOLD = 500;
const FRAME_MS = 10;

function readFmt(buffer, body, state) {
  state.channels = buffer.readUInt16LE(body + 2);
  state.sampleRate = buffer.readUInt32LE(body + 4);
  state.bits = buffer.readUInt16LE(body + 14);
}

function readData(buffer, body, size, state) {
  state.dataAt = body;
  state.dataSize = Math.min(size, buffer.length - body);
}

function scanChunks(buffer, state) {
  let at = 12;
  while (at + 8 <= buffer.length) {
    const id = buffer.toString("ascii", at, at + 4);
    const size = buffer.readUInt32LE(at + 4);
    const body = at + 8;
    if (id === "fmt ") readFmt(buffer, body, state);
    if (id === "data") {
      readData(buffer, body, size, state);
      break;
    }
    at = body + size + (size % 2);
  }
}

export function parseWav(buffer) {
  if (buffer.toString("ascii", 0, 4) !== "RIFF") throw new Error("not a RIFF file");
  if (buffer.toString("ascii", 8, 12) !== "WAVE") throw new Error("not a WAVE file");
  const state = { channels: 1, sampleRate: 0, bits: 16, dataAt: 44, dataSize: 0 };
  scanChunks(buffer, state);
  if (state.bits !== 16) throw new Error("only 16-bit PCM is supported");
  const count = Math.floor(state.dataSize / 2);
  const samples = new Int16Array(count);
  for (let i = 0; i < count; i += 1) samples[i] = buffer.readInt16LE(state.dataAt + i * 2);
  return { sampleRate: state.sampleRate, channels: state.channels, samples };
}

function frameRms(samples, from, to) {
  let sum = 0;
  for (let i = from; i < to; i += 1) sum += samples[i] * samples[i];
  return Math.sqrt(sum / Math.max(1, to - from));
}

function beginRun(state, from, to) {
  if (state.start < 0) state.start = from;
  state.lastLoud = to;
  state.quiet = 0;
}

function noteSilence(state, runs, silenceFrames) {
  if (state.start < 0) return;
  state.quiet += 1;
  if (state.quiet < silenceFrames) return;
  runs.push(state.samples.slice(state.start, state.lastLoud));
  state.start = -1;
  state.quiet = 0;
}

function speechRuns(samples, frame, silenceFrames) {
  const runs = [];
  const state = { samples, start: -1, lastLoud: -1, quiet: 0 };
  for (let f = 0; f * frame < samples.length; f += 1) {
    const from = f * frame;
    const to = Math.min(samples.length, from + frame);
    if (frameRms(samples, from, to) >= RMS_THRESHOLD) beginRun(state, from, to);
    else noteSilence(state, runs, silenceFrames);
  }
  if (state.start >= 0) runs.push(samples.slice(state.start, state.lastLoud));
  return runs;
}

function splitRun(run, maxSamples) {
  if (run.length <= maxSamples) return [run];
  const parts = Math.ceil(run.length / maxSamples);
  const size = Math.floor(run.length / parts);
  const out = [];
  let at = 0;
  for (let i = 0; i < parts; i += 1) {
    const end = i === parts - 1 ? run.length : at + size;
    out.push(run.slice(at, end));
    at = end;
  }
  return out;
}

function defaultOr(value, fallback) {
  if (value === undefined) return fallback;
  return value;
}

function endpointOptions(options) {
  const o = options || {};
  return {
    sampleRate: o.sampleRate || 16000,
    minMs: defaultOr(o.minUtteranceMs, 300),
    silenceMs: defaultOr(o.silenceMs, 800),
    maxMs: defaultOr(o.maxUtteranceMs, 30000),
  };
}

export function endpointSamples(samples, options) {
  const o = endpointOptions(options);
  const frame = Math.max(1, Math.round((o.sampleRate * FRAME_MS) / 1000));
  const minSamples = Math.round((o.sampleRate * o.minMs) / 1000);
  const silenceFrames = Math.max(1, Math.ceil(o.silenceMs / FRAME_MS));
  const maxSamples = Math.round((o.sampleRate * o.maxMs) / 1000);
  const out = [];
  for (const run of speechRuns(samples, frame, silenceFrames)) {
    for (const piece of splitRun(run, maxSamples)) {
      if (piece.length >= minSamples) out.push(piece);
    }
  }
  return out;
}

export function captureFile(path, options, onUtterance) {
  const parsed = parseWav(readFileSync(path));
  const settings = Object.assign({}, options, { sampleRate: parsed.sampleRate });
  const utterances = endpointSamples(parsed.samples, settings);
  utterances.forEach((utterance) => onUtterance(utterance, parsed.sampleRate));
  return utterances.length;
}

function spawnArecord() {
  const child = spawn("arecord", ["-f", "S16_LE", "-r", "16000", "-c", "1", "-t", "raw"], {
    stdio: ["ignore", "pipe", "ignore"],
  });
  const chunks = [];
  return new Promise((resolve, reject) => {
    child.on("error", (error) => {
      if (error.code === "ENOENT") reject(new MissingRuntime("arecord not found on PATH"));
      else reject(error);
    });
    child.stdout.on("data", (chunk) => chunks.push(chunk));
    child.on("close", () => resolve(Buffer.concat(chunks)));
  });
}

export async function captureDevice(options, onUtterance) {
  const raw = await spawnArecord();
  const samples = new Int16Array(Math.floor(raw.length / 2));
  for (let i = 0; i < samples.length; i += 1) samples[i] = raw.readInt16LE(i * 2);
  const settings = Object.assign({}, options, { sampleRate: 16000 });
  const utterances = endpointSamples(samples, settings);
  utterances.forEach((utterance) => onUtterance(utterance, 16000));
  return utterances.length;
}

export async function capture(spec, options, onUtterance) {
  if (spec.startsWith("file:")) {
    return captureFile(spec.slice("file:".length), options, onUtterance);
  }
  return captureDevice(options, onUtterance);
}
