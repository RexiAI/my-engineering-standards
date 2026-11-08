// guard.mjs — enforcement at the outbound boundary. Every reply path calls
// authorize immediately before sending; a blocked intent throws and the caller
// turns that into exit 4. There is no override flag.
import { classify } from "./policy.mjs";
import { PolicyRefusal } from "./config.mjs";

export { PolicyRefusal };

export function authorize(intent) {
  const result = classify(intent);
  if (result.blocked) throw new PolicyRefusal(result.rule);
  return result;
}
