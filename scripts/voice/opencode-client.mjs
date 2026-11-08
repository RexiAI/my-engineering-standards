// opencode-client.mjs — the only implementation of the HTTP surface in
// docs/VOICE_CONSOLE.md §API mapping, and the only module that sends a reply.
// Uses node:http with a fresh agent per request so no keep-alive socket keeps
// the CLI alive after its work is done.
import { request } from "node:http";
import { URL } from "node:url";
import { UpstreamError } from "./config.mjs";

function partOf(event) {
  if (event.part) return event.part;
  if (event.properties && event.properties.part) return event.properties.part;
  return null;
}

function roleOf(event) {
  if (event.role) return event.role;
  if (event.properties && event.properties.info) return event.properties.info.role;
  return null;
}

function messageIdOf(event) {
  if (event.messageID) return event.messageID;
  if (event.properties && event.properties.info) return event.properties.info.id;
  const part = partOf(event);
  if (part && part.messageID) return part.messageID;
  return null;
}

function hasSubtaskMarker(part) {
  if (part.type === "subtask") return true;
  if (part.synthetic === true) return true;
  if (part.parentID) return true;
  return false;
}

function acceptPart(part, session, role) {
  if (part.type !== "text") return false;
  if (part.sessionID !== session) return false;
  if (role !== "assistant") return false;
  return !hasSubtaskMarker(part);
}

function deltaFor(part, prefixes) {
  const previous = prefixes.get(part.id) || "";
  if (!part.text.startsWith(previous)) return null;
  if (part.text.length === previous.length) return null;
  prefixes.set(part.id, part.text);
  return { id: part.id, delta: part.text.slice(previous.length) };
}

export function createPartFilter(options) {
  const session = options.session;
  const roles = new Map();
  const prefixes = new Map();
  return {
    accept(event) {
      const role = roleOf(event);
      const messageID = messageIdOf(event);
      if (role && messageID) roles.set(messageID, role);
      const part = partOf(event);
      if (!part) return null;
      if (!acceptPart(part, session, roles.get(messageID))) return null;
      return deltaFor(part, prefixes);
    },
  };
}

function replyPath(kind, id) {
  if (kind === "question") return `/question/${id}/reply`;
  return `/permission/${id}/reply`;
}

function handleLine(line, handler) {
  const trimmed = line.trim();
  if (!trimmed) return false;
  let event = null;
  try {
    event = JSON.parse(trimmed);
  } catch {
    event = null;
  }
  if (!event) return false;
  handler(event);
  return true;
}

function requestOptions(method, url, body) {
  const parsed = new URL(url);
  const options = {
    hostname: parsed.hostname,
    port: parsed.port,
    path: parsed.pathname + parsed.search,
    method,
    agent: false,
    headers: { "content-type": "application/json", connection: "close" },
  };
  return { options, body };
}

function sendOnce(method, url, body) {
  return new Promise((resolve, reject) => {
    const prepared = requestOptions(method, url, body);
    const req = request(prepared.options, (res) => {
      let raw = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        raw += chunk;
      });
      res.on("end", () => {
        let data = null;
        try {
          data = raw ? JSON.parse(raw) : null;
        } catch {
          data = null;
        }
        resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, data });
      });
    });
    req.on("error", reject);
    if (prepared.body !== undefined) req.write(JSON.stringify(prepared.body));
    req.end();
  });
}

function streamOnce(url, handler, onOpen, onRequest) {
  return new Promise((resolve, reject) => {
    const prepared = requestOptions("GET", url, undefined);
    const req = request(prepared.options, (res) => {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        res.resume();
        resolve({ seen: 0, request: req });
        return;
      }
      if (onOpen) onOpen();
      let buffer = "";
      let seen = 0;
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        buffer += chunk;
        const lines = buffer.split("\n");
        buffer = lines.pop();
        for (const line of lines) {
          if (handleLine(line, handler)) seen += 1;
        }
      });
      res.on("end", () => resolve({ seen, request: req }));
    });
    req.on("error", reject);
    req.end();
    if (onRequest) onRequest(req);
  });
}

function retryPause(attemptNo) {
  if (attemptNo >= 3) return Promise.resolve();
  return new Promise((resolve) => setTimeout(resolve, 500 * 2 ** (attemptNo - 1)));
}

export function createClient(options) {
  const baseUrl = options.baseUrl;
  const dryRun = options.dryRun === true;
  const out = options.out || ((line) => process.stdout.write(line + "\n"));
  let closed = false;
  let activeStream = null;

  function emit(method, path, body) {
    if (!dryRun) return;
    out(JSON.stringify({ method, path, body }));
  }

  async function send(method, path, body) {
    emit(method, path, body);
    if (dryRun) return null;
    const first = await sendOnce(method, baseUrl + path, body);
    if (first.ok) return first.data;
    await new Promise((resolve) => setTimeout(resolve, 250));
    const second = await sendOnce(method, baseUrl + path, body);
    if (second.ok) return second.data;
    throw new UpstreamError(`upstream status ${second.status} on ${path}`);
  }

  async function connectOnce(handler, onOpen) {
    const onRequest = (req) => {
      activeStream = req;
    };
    try {
      const result = await streamOnce(baseUrl + "/event", handler, onOpen, onRequest);
      return { events: result.seen };
    } catch {
      return closed ? null : { events: 0 };
    }
  }

  async function connect(handler, onOpen) {
    if (dryRun) return { events: 0 };
    for (let attemptNo = 1; attemptNo <= 3 && !closed; attemptNo += 1) {
      const attempt = await connectOnce(handler, onOpen);
      if (attempt === null) return { events: 0 };
      if (attempt.events > 0) return { events: attempt.events };
      await retryPause(attemptNo);
    }
    throw new UpstreamError("event stream unavailable after 3 attempts");
  }

  function start(handler) {
    let resolveReady;
    const ready = new Promise((resolve) => {
      resolveReady = resolve;
    });
    const done = connect(handler, resolveReady);
    done.catch(() => {});
    return { ready, done };
  }

  return {
    sendPrompt(sessionID, text) {
      return send("POST", `/session/${sessionID}/message`, { parts: [{ type: "text", text }] });
    },
    sendReply(kind, id, body) {
      return send("POST", replyPath(kind, id), body);
    },
    createSession(agent) {
      return send("POST", "/session", { agent });
    },
    connect,
    start,
    close() {
      closed = true;
      if (activeStream) activeStream.destroy();
    },
  };
}
