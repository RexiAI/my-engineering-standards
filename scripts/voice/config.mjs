// config.mjs — argument parsing, configuration precedence, and the run
// ledger for the voice console. Precedence is flag > VOICE_* env > default.
import { mkdirSync, appendFileSync } from "node:fs";
import { join } from "node:path";

export const ASR_DEFAULT_ENGINE = "faster-whisper";
export const ASR_ENGINES = ["faster-whisper", "sherpa-onnx"];
export const MODES = ["narrate", "converse", "control"];
export const EXIT = { OK: 0, USAGE: 2, MISSING: 3, REFUSED: 4, UPSTREAM: 5 };

export const HELP = `Usage: voice-console.mjs [options]

Modes:
  narrate   speak assistant text from a parent session
  converse  capture speech, transcribe locally, prompt, speak the reply
  control   opt-in gated replies to questions and permission requests

Exit codes:
  0  ok
  2  usage error
  3  missing runtime or dependency
  4  policy refusal
  5  upstream or transport failure
`;

export class UsageError extends Error {
  constructor(message) {
    super(message);
    this.name = "UsageError";
    this.exitCode = EXIT.USAGE;
  }
}

export class MissingRuntime extends Error {
  constructor(message) {
    super(message);
    this.name = "MissingRuntime";
    this.exitCode = EXIT.MISSING;
  }
}

export class UpstreamError extends Error {
  constructor(message) {
    super(message);
    this.name = "UpstreamError";
    this.exitCode = EXIT.UPSTREAM;
  }
}

export class PolicyRefusal extends Error {
  constructor(rule) {
    super(`refused: ${rule}`);
    this.name = "PolicyRefusal";
    this.rule = rule;
    this.exitCode = EXIT.REFUSED;
  }
}

const VALUE_FLAGS = new Map([
  ["--mode", "mode"],
  ["--session", "session"],
  ["--agent", "agent"],
  ["--opencode-url", "opencodeUrl"],
  ["--audio-in", "audioIn"],
  ["--audio-out", "audioOut"],
  ["--asr", "asr"],
  ["--asr-engine", "asrEngine"],
  ["--tts-engine", "ttsEngine"],
  ["--artifacts", "artifacts"],
  ["--max-sentences", "maxSentences"],
  ["--max-seconds", "maxSeconds"],
  ["--input-script", "inputScript"],
  ["--events", "events"],
  ["--min-utterance-ms", "minUtteranceMs"],
  ["--silence-ms", "silenceMs"],
  ["--max-utterance-ms", "maxUtteranceMs"],
  ["--confirm-timeout", "confirmTimeout"],
  ["--pace-ms", "paceMs"],
]);

const BOOL_FLAGS = new Map([
  ["--help", "help"],
  ["--print-config", "printConfig"],
  ["--dry-run", "dryRun"],
]);

function splitFlag(token) {
  const at = token.indexOf("=");
  if (at === -1) return [token, undefined];
  return [token.slice(0, at), token.slice(at + 1)];
}

function missingValue(flag) {
  throw new UsageError(`${flag} requires a value`);
}

function takeValue(argv, index, flag, inline) {
  if (inline !== undefined) return [inline, index + 1];
  const next = argv[index + 1];
  if (next === undefined || next.startsWith("--")) missingValue(flag);
  return [next, index + 2];
}

export function parseArgs(argv) {
  const raw = {};
  let i = 0;
  while (i < argv.length) {
    const [flag, inline] = splitFlag(argv[i]);
    if (BOOL_FLAGS.has(flag)) {
      if (inline !== undefined) throw new UsageError(`${flag} takes no value`);
      raw[BOOL_FLAGS.get(flag)] = true;
      i += 1;
      continue;
    }
    if (!VALUE_FLAGS.has(flag)) throw new UsageError(`unknown flag: ${flag}`);
    const [value, next] = takeValue(argv, i, flag, inline);
    raw[VALUE_FLAGS.get(flag)] = value;
    i = next;
  }
  return raw;
}

function pick(flag, envValue, fallback) {
  if (flag !== undefined) return flag;
  if (envValue !== undefined && envValue !== "") return envValue;
  return fallback;
}

function defaultOr(value, fallback) {
  if (value === undefined) return fallback;
  return value;
}

function positiveInt(value, name) {
  if (!/^\d+$/.test(String(value))) throw new UsageError(`${name} must be an integer >= 1`);
  const n = Number(value);
  if (n < 1) throw new UsageError(`${name} must be an integer >= 1`);
  return n;
}

function positiveNumber(value, name) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) throw new UsageError(`${name} must be a positive number`);
  return n;
}

function nonNegativeInt(value, name) {
  if (!/^\d+$/.test(String(value))) throw new UsageError(`${name} must be an integer >= 0`);
  return Number(value);
}

function validateMode(mode) {
  if (MODES.includes(mode)) return mode;
  throw new UsageError(`--mode must be one of: ${MODES.join(", ")}`);
}

function validateEngine(engine) {
  if (ASR_ENGINES.includes(engine)) return engine;
  throw new UsageError(`--asr-engine must be one of: ${ASR_ENGINES.join(", ")}`);
}

const AUDIO_INPUT_KEYS = ["audioIn", "asr", "asrEngine", "minUtteranceMs", "silenceMs", "maxUtteranceMs"];

function rejectCapture(raw, mode) {
  if (mode !== "narrate") return;
  const inspectOnly = raw.printConfig === true && raw.mode === undefined;
  if (inspectOnly) return;
  const usesCapture = AUDIO_INPUT_KEYS.some((key) => raw[key] !== undefined);
  if (usesCapture) throw new UsageError("narrate performs no capture; remove the audio-input flags");
}

function sessionIsRequired(config) {
  if (config.mode === "converse") return false;
  return !config.session;
}

function asrBlock(raw, engine) {
  const useFile = raw.asr !== undefined && raw.asr.startsWith("file:");
  const kind = useFile ? "file" : "local";
  const file = useFile ? raw.asr.slice("file:".length) : null;
  return { engine, kind, file };
}

function budgetBlock(raw) {
  return {
    maxSentences: positiveInt(pick(raw.maxSentences, undefined, "3"), "--max-sentences"),
    maxSeconds: positiveNumber(pick(raw.maxSeconds, undefined, "45"), "--max-seconds"),
    wordsPerSecond: 2.5,
  };
}

function utteranceBlock(raw) {
  return {
    minUtteranceMs: positiveInt(defaultOr(raw.minUtteranceMs, "300"), "--min-utterance-ms"),
    silenceMs: positiveInt(defaultOr(raw.silenceMs, "800"), "--silence-ms"),
    maxUtteranceMs: positiveInt(defaultOr(raw.maxUtteranceMs, "30000"), "--max-utterance-ms"),
  };
}

function timingBlock(raw) {
  return {
    confirmTimeout: positiveNumber(defaultOr(raw.confirmTimeout, "60"), "--confirm-timeout"),
    paceMs: nonNegativeInt(defaultOr(raw.paceMs, "0"), "--pace-ms"),
  };
}

export function resolveConfig(raw, env) {
  const e = env || {};
  const mode = validateMode(pick(raw.mode, e.VOICE_MODE, "narrate"));
  rejectCapture(raw, mode);
  const config = {
    mode,
    control: mode === "control",
    session: pick(raw.session, e.VOICE_SESSION, null),
    agent: pick(raw.agent, undefined, "voice-concierge"),
    opencodeUrl: pick(raw.opencodeUrl, e.VOICE_OPENCODE_URL, "http://127.0.0.1:4096"),
    audioIn: pick(raw.audioIn, undefined, "device"),
    audioOut: pick(raw.audioOut, undefined, "device"),
    asr: asrBlock(raw, validateEngine(pick(raw.asrEngine, e.VOICE_ASR_ENGINE, ASR_DEFAULT_ENGINE))),
    tts: { engine: pick(raw.ttsEngine, undefined, "pocket-tts") },
    budget: budgetBlock(raw),
    ...utteranceBlock(raw),
    ...timingBlock(raw),
    artifacts: pick(raw.artifacts, e.VOICE_ARTIFACTS_DIR, ".cache/voice/runs/default"),
    modelCache: ".cache/voice/models",
    inputScript: raw.inputScript || null,
    events: raw.events || null,
    dryRun: raw.dryRun === true,
  };
  config.sessionRequired = sessionIsRequired(config);
  return config;
}

export function printConfig(config) {
  const publicConfig = {
    mode: config.mode,
    control: config.control,
    session: config.session,
    agent: config.agent,
    opencodeUrl: config.opencodeUrl,
    audioIn: config.audioIn,
    audioOut: config.audioOut,
    asr: config.asr,
    tts: config.tts,
    budget: config.budget,
    artifacts: config.artifacts,
    modelCache: config.modelCache,
  };
  return JSON.stringify(publicConfig);
}

// createLedger — append-only JSONL run ledger. Directories are created on the
// first write only. A record carries no clock value and no process id.
export function createLedger(dir) {
  let seq = 0;
  return {
    record(kind, fields) {
      const f = fields || {};
      seq += 1;
      const record = {
        seq,
        kind,
        turn: f.turn === undefined ? 1 : f.turn,
        text: f.text === undefined ? null : f.text,
        rule: f.rule === undefined ? null : f.rule,
        detail: f.detail === undefined ? null : f.detail,
      };
      mkdirSync(join(dir, "audio"), { recursive: true });
      appendFileSync(join(dir, "ledger.jsonl"), JSON.stringify(record) + "\n");
      return record;
    },
    get count() {
      return seq;
    },
  };
}
