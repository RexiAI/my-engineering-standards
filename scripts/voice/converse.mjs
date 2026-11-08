// converse.mjs — converse mode: capture, transcribe locally, prompt the parent
// session, and speak the reply. Capture and ASR are file-based in CI.
import { createLedger } from "./config.mjs";
import { createAsr } from "./asr.mjs";
import { capture } from "./audio-in.mjs";
import { createChunker } from "./chunk.mjs";
import { createClient, createPartFilter } from "./opencode-client.mjs";
import { createSpeaker, readScript, speakDeferredWindow, speakWindow } from "./narrate.mjs";
import { withTimeout } from "./timeout.mjs";

// A real assistant turn can take tens of seconds to emit `idle`; the window is
// a fail-open guard against a dead stream, not a latency budget. Default 120 s,
// overridable with VOICE_REPLY_TIMEOUT_MS (positive integer, ignored otherwise).
const DEFAULT_REPLY_TIMEOUT_MS = 120000;

export function resolveReplyTimeoutMs(value) {
  if (value === undefined || !/^\d+$/.test(String(value))) return DEFAULT_REPLY_TIMEOUT_MS;
  const ms = Number(value);
  return ms > 0 ? ms : DEFAULT_REPLY_TIMEOUT_MS;
}

const REPLY_TIMEOUT_MS = resolveReplyTimeoutMs(process.env.VOICE_REPLY_TIMEOUT_MS);

function createReplyCollector(session, ledger, onNotice) {
  const filter = createPartFilter({ session });
  const chunkers = new Map();
  let sentences = [];
  let waiter = null;
  let idle = false;

  function deliver() {
    idle = true;
    if (!waiter) return;
    const resolve = waiter;
    waiter = null;
    idle = false;
    resolve(sentences);
    sentences = [];
  }

  return {
    push(event) {
      if (event.event === "idle") {
        deliver();
        return;
      }
      if (onNotice(event)) return;
      const accepted = filter.accept(event);
      if (!accepted) return;
      let chunker = chunkers.get(accepted.id);
      if (!chunker) {
        chunker = createChunker();
        chunkers.set(accepted.id, chunker);
      }
      for (const sentence of chunker.feed(accepted.delta)) sentences.push(sentence);
    },
    nextTurn() {
      // A fast turn can emit text and `idle` before sendPrompt() resolves. The
      // buffered turn is handed to the first nextTurn() instead of waiting for
      // an idle that already happened.
      if (idle) {
        idle = false;
        const buffered = sentences;
        sentences = [];
        return Promise.resolve(buffered);
      }
      return new Promise((resolve) => {
        waiter = resolve;
      });
    },
  };
}

async function collectUtterances(config) {
  const utterances = [];
  await capture(
    config.audioIn,
    {
      minUtteranceMs: config.minUtteranceMs,
      silenceMs: config.silenceMs,
      maxUtteranceMs: config.maxUtteranceMs,
    },
    (utterance) => utterances.push(utterance),
  );
  return utterances;
}

function takeScriptCommand(state) {
  if (state.scriptAt >= state.script.length) return null;
  const command = state.script[state.scriptAt].toLowerCase();
  state.scriptAt += 1;
  return command;
}

async function runTurn(state, transcript) {
  state.ledger.record("prompt-sent", {
    turn: state.turn,
    text: transcript,
    detail: state.firstPromptDetail,
  });
  state.firstPromptDetail = null;
  await state.client.sendPrompt(state.session, transcript);
  const reply = await withTimeout(state.collector.nextTurn(), REPLY_TIMEOUT_MS, []);
  await speakWindow(state, reply);
}

async function ensureSession(client, config) {
  if (config.session) return { session: config.session, detail: null };
  const created = await client.createSession(config.agent);
  const session = created && created.id ? created.id : "dry-run-session";
  return { session, detail: session };
}

function ignoreNotice(state) {
  return (event) => {
    if (event.event !== "question.asked" && event.event !== "permission.asked") return false;
    state.ledger.record("ignored", { turn: state.turn });
    return true;
  };
}

async function processUtterance(state, asr) {
  const transcript = asr.transcriptFor(state.turn - 1);
  if (transcript === null || transcript.trim() === "") {
    state.ledger.record("skipped-utterance", { turn: state.turn });
    return;
  }
  await runTurn(state, transcript);
  const command = takeScriptCommand(state);
  if (command === "m" || command === "more") await speakDeferredWindow(state);
}

function createState(config, parts) {
  return {
    ledger: parts.ledger,
    speaker: parts.speaker,
    client: parts.client,
    session: parts.session,
    collector: null,
    turn: 1,
    budget: config.budget,
    deferred: [],
    script: readScript(config.inputScript),
    scriptAt: 0,
    firstPromptDetail: parts.detail,
  };
}

export async function runConverse(config) {
  const ledger = createLedger(config.artifacts);
  const speaker = createSpeaker(config, ledger);
  const asr = await createAsr(config);
  const utterances = await collectUtterances(config);
  const client = createClient({ baseUrl: config.opencodeUrl, dryRun: config.dryRun });
  const { session, detail } = await ensureSession(client, config);
  const state = createState(config, { ledger, speaker, client, session, detail });
  state.collector = createReplyCollector(session, ledger, ignoreNotice(state));
  const stream = client.start((event) => state.collector.push(event));
  await stream.ready;
  for (let index = 0; index < utterances.length; index += 1) {
    await processUtterance(state, asr);
    state.turn += 1;
  }
  client.close();
  return 0;
}
