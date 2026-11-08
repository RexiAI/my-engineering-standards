#!/usr/bin/env node
// voice-fake-server.mjs — executable contract for the opencode HTTP surface
// documented in docs/VOICE_CONSOLE.md §API mapping. It implements exactly the
// five documented paths and nothing else. Test-only: never imported by
// production code.
//
//   node voice-fake-server.mjs --events FILE --record FILE --port 0
//                               [--reply-events FILE] [--fail prompt=500]
//
// Prints exactly `LISTENING <port>` on stdout. Only mutating requests (POST)
// are recorded, one JSON object per line, so "zero recorded requests" means
// zero replies or prompts were attempted. Exits 0 on SIGTERM.
import { createServer } from "node:http";
import { readFileSync, appendFileSync, existsSync } from "node:fs";

const argv = process.argv.slice(2);

function argValue(name) {
  const at = argv.indexOf(name);
  return at === -1 ? undefined : argv[at + 1];
}

const eventsFile = argValue("--events");
const replyEventsFile = argValue("--reply-events");
const recordFile = argValue("--record");
const port = Number(argValue("--port") || 0);
const failSpec = argValue("--fail") || "";
const failPrompt = failSpec === "prompt=500" ? 500 : 0;

function readLines(path) {
  if (!path || !existsSync(path)) return [];
  return readFileSync(path, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

const events = readLines(eventsFile);
const replyEvents = readLines(replyEventsFile);
const clients = new Set();
let promptCount = 0;

function record(req, body) {
  if (!recordFile) return;
  appendFileSync(recordFile, JSON.stringify({ method: req.method, path: req.url, body }) + "\n");
}

function readBody(req) {
  return new Promise((resolve) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
    });
    req.on("end", () => {
      let parsed = null;
      try {
        parsed = raw ? JSON.parse(raw) : null;
      } catch {
        parsed = raw;
      }
      resolve(parsed);
    });
  });
}

function reply(res, status, body) {
  res.writeHead(status, { "content-type": "application/json", connection: "close" });
  res.end(JSON.stringify(body));
}

function broadcast(lines) {
  for (const client of clients) {
    for (const line of lines) client.write(line + "\n");
  }
}

function handleEventStream(res) {
  res.writeHead(200, { "content-type": "application/x-ndjson", connection: "close" });
  res.flushHeaders();
  if (events.length === 1 && events[0] === '{"close":true}') {
    res.end();
    return;
  }
  for (const line of events) res.write(line + "\n");
  if (replyEvents.length === 0) {
    res.end();
    return;
  }
  clients.add(res);
  res.on("close", () => clients.delete(res));
}

async function handlePost(req, res) {
  const body = await readBody(req);
  record(req, body);
  if (failPrompt && req.url.endsWith("/message")) {
    reply(res, failPrompt, { error: "injected failure" });
    return;
  }
  if (req.url === "/session") {
    reply(res, 200, { id: "ses_created" });
    return;
  }
  if (req.url.endsWith("/message")) {
    reply(res, 200, { ok: true });
    promptCount += 1;
    broadcast(replyEvents.map((line) => line.replaceAll("__TURN__", String(promptCount))));
    return;
  }
  reply(res, 200, { ok: true });
}

const server = createServer((req, res) => {
  if (req.method === "GET" && req.url === "/event") {
    handleEventStream(res);
    return;
  }
  if (req.method === "POST") {
    handlePost(req, res).catch(() => reply(res, 500, { error: "bad request" }));
    return;
  }
  reply(res, 404, { error: "not found" });
});

server.listen(port, "127.0.0.1", () => {
  process.stdout.write(`LISTENING ${server.address().port}\n`);
});

process.on("SIGTERM", () => {
  server.close();
  process.exit(0);
});
process.on("SIGINT", () => {
  server.close();
  process.exit(0);
});
