// timeout.mjs — race a promise against a timer. The fallback value wins when
// the timer fires first; the raced promise keeps running unresolved.
export function withTimeout(promise, ms, fallback) {
  return Promise.race([
    promise,
    new Promise((resolve) => {
      setTimeout(() => resolve(fallback), ms);
    }),
  ]);
}
