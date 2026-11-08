// narrate.mjs — narrate mode. Speaks assistant text from the configured parent
// session, applies the speech budget, and drains deferred sentences on `more`.
// It constructs no capture adapter and no ASR adapter.
import { readFileSync, createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { createLedger, MissingRuntime } from "./config.mjs";
import { createChunker, takeWindow } from "./chunk.mjs";
import { createAudioOut, silentWav } from "./audio-out.mjs";
import { createPartFilter, createClient } from "./opencode-client.mjs";

const SAMPLE_RATE = 24000;

function synthesize(config, text) {
  if (config.tts.engine === "silent") return silentWav(text, SAMPLE_RATE);
  throw new MissingRuntime("pocket-tts worker is not available");
}

export function createSpeaker(config, ledger) {
  const sink = createAudioOut(config.audioOut);
  let last = [];
  async function speakSentences(sentences, turn) {
    const results = [];
    for (const sentence of sentences) {
      const result = await sink.write(synthesize(config, sentence));
      ledger.record("spoken", {
        turn,
        text: sentence,
        detail: result && result.path ? result.path : null,
      });
      results.push(result);
    }
    last = sentences.slice();
    return results;
  }
  return {
    speakSentences,
    cancel() {
      if (sink.cancel) return sink.cancel();
      return Promise.resolve({ cancelled: true });
    },
    get last() {
      return last;
    },
  };
}

export function readScript(path) {
  if (!path) return [];
  return readFileSync(path, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "");
}

function chunkerFor(state, id) {
  let chunker = state.chunkers.get(id);
  if (!chunker) {
    chunker = createChunker();
    state.chunkers.set(id, chunker);
  }
  return chunker;
}

export async function speakWindow(state, sentences) {
  const window = takeWindow(sentences, state.budget);
  await state.speaker.speakSentences(window.spoken, state.turn);
  if (window.deferred.length > 0) {
    state.ledger.record("deferred", { turn: state.turn, text: window.deferred.join(" ") });
  }
  state.deferred = window.deferred;
  return window;
}

async function finalizeTurn(state) {
  if (state.pending.length === 0) return;
  await speakWindow(state, state.pending);
  state.pending = [];
  state.turn += 1;
}

function lastSpoken(state) {
  if (state.speaker.last.length === 0) return null;
  return state.speaker.last[state.speaker.last.length - 1];
}

function recordCancelled(state) {
  state.ledger.record("cancelled", { turn: state.turn, text: lastSpoken(state) });
}

export async function speakDeferredWindow(state) {
  if (state.deferred.length === 0) {
    state.ledger.record("nothing-more", { turn: state.turn });
    return false;
  }
  state.ledger.record("resumed", { turn: state.turn, text: state.deferred.join(" ") });
  const window = takeWindow(state.deferred, state.budget);
  await state.speaker.speakSentences(window.spoken, state.turn);
  state.deferred = window.deferred;
  return true;
}

function consumeStop(state) {
  if (state.scriptAt >= state.script.length) return;
  if (state.script[state.scriptAt].toLowerCase() !== "stop") return;
  state.scriptAt += 1;
  recordCancelled(state);
}

async function handleEvent(state, event) {
  if (event.event === "idle") {
    await finalizeTurn(state);
    consumeStop(state);
    return;
  }
  if (event.event === "question.asked" || event.event === "permission.asked") {
    state.ledger.record("ignored", { turn: state.turn });
    return;
  }
  const accepted = state.filter.accept(event);
  if (!accepted) return;
  const chunker = chunkerFor(state, accepted.id);
  for (const sentence of chunker.feed(accepted.delta)) state.pending.push(sentence);
}

async function handleMore(state) {
  const spoke = await speakDeferredWindow(state);
  if (spoke) state.turn += 1;
}

async function drainCommands(state) {
  while (state.scriptAt < state.script.length) {
    const command = state.script[state.scriptAt].toLowerCase();
    state.scriptAt += 1;
    if (command === "stop") {
      recordCancelled(state);
      continue;
    }
    if (command === "repeat") {
      await state.speaker.speakSentences(state.speaker.last, state.turn);
      continue;
    }
    await handleMore(state);
  }
}

function installInterrupt(state) {
  process.on("SIGINT", () => {
    if (state.interrupts > 0) process.exit(130);
    state.interrupts += 1;
    recordCancelled(state);
    setTimeout(() => process.exit(0), 50);
  });
}

async function streamEvents(path, handler, paceMs) {
  const input = createReadStream(path);
  const lines = createInterface({ input, crlfDelay: Infinity });
  for await (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    await handler(JSON.parse(trimmed));
    if (paceMs > 0) await new Promise((resolve) => setTimeout(resolve, paceMs));
  }
}

async function collectFromServer(config, state) {
  const events = [];
  const client = createClient({ baseUrl: config.opencodeUrl, dryRun: config.dryRun });
  await client.connect((event) => {
    events.push(event);
  });
  client.close();
  for (const event of events) await handleEvent(state, event);
}

function createState(config) {
  const ledger = createLedger(config.artifacts);
  const state = {
    ledger,
    speaker: null,
    filter: createPartFilter({ session: config.session }),
    chunkers: new Map(),
    pending: [],
    deferred: [],
    turn: 1,
    script: readScript(config.inputScript),
    scriptAt: 0,
    budget: config.budget,
    interrupts: 0,
  };
  state.speaker = createSpeaker(config, ledger);
  return state;
}

export async function runNarrate(config) {
  const state = createState(config);
  installInterrupt(state);
  if (config.events) {
    await streamEvents(config.events, (event) => handleEvent(state, event), config.paceMs);
  } else {
    await collectFromServer(config, state);
  }
  await finalizeTurn(state);
  await drainCommands(state);
  return 0;
}
