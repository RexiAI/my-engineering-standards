// voice-fixtures.mjs — deterministic audio fixtures for the voice-console
// tests. Every function is pure: identical arguments produce byte-identical
// output, so synthetic WAVs can be asserted without a sound card.

export function toneMs(ms, opts) {
  const o = opts || {};
  const sampleRate = o.sampleRate || 16000;
  const freq = o.freq === undefined ? 440 : o.freq;
  const amplitude = o.amplitude === undefined ? 8000 : o.amplitude;
  const count = Math.round((ms * sampleRate) / 1000);
  const samples = new Int16Array(count);
  for (let i = 0; i < count; i += 1) {
    samples[i] = Math.round(amplitude * Math.sin((2 * Math.PI * freq * i) / sampleRate));
  }
  return samples;
}

export function silenceMs(ms, opts) {
  const o = opts || {};
  const sampleRate = o.sampleRate || 16000;
  return new Int16Array(Math.round((ms * sampleRate) / 1000));
}

export function concatSamples(parts) {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Int16Array(total);
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

// wav — 16-bit PCM WAV buffer. `samples` is an Int16Array; multi-channel input
// is expected already interleaved.
export function wav(opts) {
  const sampleRate = opts.sampleRate || 16000;
  const channels = opts.channels || 1;
  const samples = opts.samples;
  const dataBytes = samples.length * 2;
  const buf = Buffer.alloc(44 + dataBytes);
  buf.write("RIFF", 0, "ascii");
  buf.writeUInt32LE(36 + dataBytes, 4);
  buf.write("WAVE", 8, "ascii");
  buf.write("fmt ", 12, "ascii");
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(channels, 22);
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(sampleRate * channels * 2, 28);
  buf.writeUInt16LE(channels * 2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36, "ascii");
  buf.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i += 1) {
    buf.writeInt16LE(samples[i], 44 + i * 2);
  }
  return buf;
}
