// control.mjs — opt-in gated control. Terminal confirmation is required before
// every mutating reply; a never-list refusal is not overridable. This module is
// the only caller of opencode-client's reply function, and every reply is
// preceded immediately by guard.authorize.
import { createLedger, EXIT } from "./config.mjs";
import { authorize, PolicyRefusal } from "./guard.mjs";
import { createClient } from "./opencode-client.mjs";
import { createSpeaker, readScript } from "./narrate.mjs";
import { withTimeout } from "./timeout.mjs";

function createInput(path) {
  const lines = readScript(path);
  let at = 0;
  return {
    async next() {
      if (at >= lines.length) return null;
      const line = lines[at];
      at += 1;
      return line;
    },
  };
}

function normaliseLabel(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function matchOption(answer, options) {
  if (answer === null) return null;
  const trimmed = answer.trim();
  if (/^[1-9]$/.test(trimmed)) {
    const at = Number(trimmed) - 1;
    if (at < options.length) return options[at].label;
    return null;
  }
  const target = normaliseLabel(trimmed);
  for (const option of options) {
    if (normaliseLabel(option.label) === target) return option.label;
  }
  return null;
}

function headerText(event) {
  const lines = [event.header || "Question"];
  event.options.forEach((option, index) => lines.push(`${index + 1}. ${option.label}`));
  return lines.join("\n");
}

function intentSummary(intent) {
  if (intent.command) return `${intent.tool}: ${intent.command}`;
  return `${intent.tool}: ${(intent.paths || []).join(", ")}`;
}

async function sendQuestionReply(state, id, body) {
  authorize({ tool: "read", command: null, paths: [], repoRoot: process.cwd() });
  await state.client.sendReply("question", id, body);
}

async function sendPermissionReply(state, id, body) {
  authorize({ tool: "read", command: null, paths: [], repoRoot: process.cwd() });
  await state.client.sendReply("permission", id, body);
}

async function sendConfirmedPrompt(state, text) {
  authorize({ tool: "read", command: null, paths: [], repoRoot: process.cwd() });
  await state.client.sendPrompt(state.session, text);
}

async function handleSlash(state, event, text) {
  const confirm = await withTimeout(state.input.next(), state.confirmMs, null);
  if (confirm !== null && confirm.trim().toLowerCase() === "y") {
    await sendConfirmedPrompt(state, text);
    state.didWork = true;
    return;
  }
  state.ledger.record("refused", { turn: state.turn, rule: "not-confirmed", detail: event.id });
}

async function handleFreeText(state, event) {
  const answer = await state.input.next();
  if (answer === null) {
    state.ledger.record("pending", { turn: state.turn, detail: event.id });
    return;
  }
  const text = answer.trim();
  if (text.startsWith("/")) {
    await handleSlash(state, event, text);
    return;
  }
  await sendQuestionReply(state, event.id, { text });
  state.didWork = true;
}

async function askOption(state, event) {
  const answer = await state.input.next();
  const label = matchOption(answer, event.options);
  if (label !== null) return label;
  await state.speaker.speakSentences(
    ["Please answer with a number or the option label."],
    state.turn,
  );
  return matchOption(await state.input.next(), event.options);
}

async function handleOptions(state, event) {
  await state.speaker.speakSentences([headerText(event)], state.turn);
  const label = await askOption(state, event);
  if (label !== null) {
    await sendQuestionReply(state, event.id, { label });
    state.didWork = true;
    return;
  }
  state.ledger.record("pending", { turn: state.turn, detail: event.id });
}

async function handleQuestion(state, event) {
  if (event.options && event.options.length > 0) {
    await handleOptions(state, event);
    return;
  }
  await handleFreeText(state, event);
}

async function handleReadOnly(state, event) {
  const answer = await state.input.next();
  if (answer !== null && answer.trim().toLowerCase() === "yes") {
    await sendPermissionReply(state, event.id, { reply: "once" });
    state.didWork = true;
    return;
  }
  state.ledger.record("pending", { turn: state.turn, detail: event.id });
}

async function handleMutating(state, event) {
  await state.speaker.speakSentences([intentSummary(event.intent)], state.turn);
  const confirm = await withTimeout(state.input.next(), state.confirmMs, null);
  if (confirm === null) {
    state.ledger.record("pending", { turn: state.turn, detail: event.id });
    return;
  }
  const answer = confirm.trim().toLowerCase();
  if (answer === "y") {
    await sendPermissionReply(state, event.id, { reply: "once" });
    state.didWork = true;
    return;
  }
  if (answer === "n") {
    state.ledger.record("refused", { turn: state.turn, rule: "not-confirmed", detail: event.id });
    return;
  }
  state.ledger.record("pending", { turn: state.turn, detail: event.id });
}

async function handlePermission(state, event) {
  let result;
  try {
    result = authorize(event.intent);
  } catch (error) {
    if (!(error instanceof PolicyRefusal)) throw error;
    state.ledger.record("refused", { turn: state.turn, rule: error.rule, detail: event.id });
    process.stderr.write(`refused: ${error.rule}\n`);
    state.sawRefusal = true;
    return;
  }
  if (result.requiresConfirmation) {
    await handleMutating(state, event);
    return;
  }
  await handleReadOnly(state, event);
}

async function handleEvent(state, event) {
  if (event.event === "question.asked") {
    await handleQuestion(state, event);
    return;
  }
  if (event.event === "permission.asked") {
    await handlePermission(state, event);
  }
}

async function readEvents(config) {
  const events = [];
  if (config.events) {
    const { readFileSync } = await import("node:fs");
    const lines = readFileSync(config.events, "utf8").split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed) events.push(JSON.parse(trimmed));
    }
    return events;
  }
  const client = createClient({ baseUrl: config.opencodeUrl, dryRun: config.dryRun });
  await client.connect((event) => events.push(event));
  client.close();
  return events;
}

function createState(config, ledger) {
  return {
    ledger,
    speaker: createSpeaker(config, ledger),
    client: createClient({ baseUrl: config.opencodeUrl, dryRun: config.dryRun }),
    input: createInput(config.inputScript),
    session: config.session,
    turn: 1,
    confirmMs: config.confirmTimeout * 1000,
    sawRefusal: false,
    didWork: false,
  };
}

export async function runControl(config) {
  const ledger = createLedger(config.artifacts);
  const state = createState(config, ledger);
  const events = await readEvents(config);
  for (const event of events) {
    await handleEvent(state, event);
    state.turn += 1;
  }
  state.client.close();
  if (state.sawRefusal && !state.didWork) return EXIT.REFUSED;
  return EXIT.OK;
}
