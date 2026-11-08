// asr.mjs — local speech-recognition adapter. The file adapter is the CI path;
// a real engine is loaded lazily and its absence is reported before any audio
// is read. There is no cloud path.
import { readFileSync } from "node:fs";
import { MissingRuntime } from "./config.mjs";

const ENGINE_MODULES = {
  "faster-whisper": "faster_whisper",
  "sherpa-onnx": "sherpa_onnx",
};

export function createFileAsr(path) {
  const raw = readFileSync(path, "utf8").split("\n");
  const lines = raw.map((line) => line.replace(/\r$/, ""));
  const usable = lines.filter((line) => line !== "");
  return {
    transcriptFor(index) {
      if (index >= usable.length) return null;
      return usable[index];
    },
  };
}

export async function assertLocalEngine(engine) {
  const name = ENGINE_MODULES[engine];
  try {
    await import(name);
  } catch {
    throw new MissingRuntime(`${engine}: missing-runtime`);
  }
}

export async function createAsr(config) {
  if (config.asr.kind === "file") return createFileAsr(config.asr.file);
  await assertLocalEngine(config.asr.engine);
  return {
    transcriptFor() {
      throw new MissingRuntime(`${config.asr.engine}: missing-runtime`);
    },
  };
}
