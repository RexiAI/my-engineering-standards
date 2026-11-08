// chunk.mjs — deterministic sentence splitting and the speech budget. Pure:
// no imports, no I/O.

const ABBREVIATIONS = new Set([
  "e.g",
  "i.e",
  "etc",
  "vs",
  "dr",
  "mr",
  "mrs",
  "ms",
  "no",
  "fig",
  "cf",
]);

function isTerminator(ch) {
  return ch === "!" || ch === "?" || ch === ".";
}

function isDigit(ch) {
  if (ch === undefined) return false;
  return ch >= "0" && ch <= "9";
}

function followedBySpace(text, at) {
  const next = text[at + 1];
  if (next === undefined) return true;
  return /\s/.test(next);
}

function wordBefore(text, at) {
  const match = /[A-Za-z.]+$/.exec(text.slice(0, at));
  if (!match) return "";
  return match[0].replace(/\.+$/, "").toLowerCase();
}

function isAbbreviation(text, at) {
  return ABBREVIATIONS.has(wordBefore(text, at));
}

function periodIsDecimal(text, at) {
  if (!isDigit(text[at - 1])) return false;
  return isDigit(text[at + 1]);
}

function endsSentence(text, at) {
  const ch = text[at];
  if (!isTerminator(ch)) return false;
  if (!followedBySpace(text, at)) return false;
  if (ch !== ".") return true;
  if (periodIsDecimal(text, at)) return false;
  return !isAbbreviation(text, at);
}

export function splitSentences(text) {
  const out = [];
  let start = 0;
  for (let at = 0; at < text.length; at += 1) {
    if (!endsSentence(text, at)) continue;
    const piece = text.slice(start, at + 1).trim();
    if (piece) out.push(piece);
    start = at + 1;
  }
  const rest = text.slice(start).trim();
  if (rest) out.push(rest);
  return out;
}

function countWords(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

export function takeWindow(sentences, budget) {
  const spoken = [];
  let words = 0;
  let seconds = 0;
  for (const sentence of sentences) {
    const width = countWords(sentence) / budget.wordsPerSecond;
    const tooMany = spoken.length >= budget.maxSentences;
    const tooLong = spoken.length > 0 && seconds + width > budget.maxSeconds;
    if (tooMany || tooLong) break;
    spoken.push(sentence);
    words += countWords(sentence);
    seconds = words / budget.wordsPerSecond;
  }
  return {
    spoken,
    deferred: sentences.slice(spoken.length),
    estimatedSeconds: seconds,
  };
}

function completedSentences(text) {
  return splitSentences(text).filter((sentence) => /[.!?]$/.test(sentence));
}

export function createChunker() {
  let source = "";
  let returned = 0;
  return {
    feed(text) {
      if (text.startsWith(source)) {
        source = text;
      } else {
        source += text;
      }
      const done = completedSentences(source);
      const fresh = done.slice(returned);
      returned = done.length;
      return fresh;
    },
    finish() {
      const all = splitSentences(source);
      const done = completedSentences(source);
      return all.slice(done.length).join(" ").trim();
    },
  };
}
