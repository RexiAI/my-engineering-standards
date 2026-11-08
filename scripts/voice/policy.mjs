// policy.mjs — pure never-list classifier. No I/O imports: classification has
// no side effect on the working tree. The one metadata read (realpath, to catch
// a symlink escaping the repository) is obtained lazily from the runtime and
// never writes anything.
import { basename, dirname, isAbsolute, join, normalize, sep } from "node:path";
import { pathToFileURL } from "node:url";

export const RULES = [
  "merge",
  "tag",
  "push-main",
  "force-push",
  "delete-branch",
  "gate-threshold",
  "secret-rotate",
  "write-outside-repo",
  "git-init",
];

const READ_TOOLS = new Set(["read", "grep", "glob"]);
const WRITE_TOOLS = new Set(["edit", "write"]);
const PROTECTED = new Set(["main", "master", "refs/heads/main", "refs/heads/master"]);

function isWriteTool(tool) {
  return WRITE_TOOLS.has(tool);
}

function normalise(command) {
  if (!command) return "";
  return command.toLowerCase().trim().replace(/\s+/g, " ");
}

function tokensOf(command) {
  const text = normalise(command);
  if (text === "") return [];
  return text.split(" ");
}

function hasSequence(tokens, words) {
  let i = 0;
  while (i + words.length <= tokens.length) {
    if (words.every((word, j) => tokens[i + j] === word)) return true;
    i += 1;
  }
  return false;
}

function pushArgs(tokens) {
  const at = tokens.indexOf("push");
  if (at < 1) return null;
  if (tokens[at - 1] !== "git") return null;
  return tokens.slice(at + 1);
}

function isMirrorFlag(token) {
  return token === "--all" || token === "--mirror";
}

function isProtectedToken(token) {
  if (PROTECTED.has(token)) return true;
  return token.endsWith(":main") || token.endsWith(":master");
}

function isForceToken(token) {
  if (token === "-f" || token === "--force") return true;
  if (token === "--force-with-lease") return true;
  return token.startsWith("+");
}

function isDeleteRefspec(token) {
  if (!token.startsWith(":")) return false;
  return token.length > 1;
}

function mergeRule(tokens) {
  if (hasSequence(tokens, ["gh", "pr", "merge"])) return true;
  if (hasSequence(tokens, ["glab", "mr", "merge"])) return true;
  return hasSequence(tokens, ["git", "merge"]);
}

function tagRule(tokens) {
  if (hasSequence(tokens, ["git", "tag"])) return true;
  return hasSequence(tokens, ["gh", "release", "create"]);
}

function pushMainRule(tokens) {
  const args = pushArgs(tokens);
  if (!args) return false;
  return args.some(isProtectedToken) || args.some(isMirrorFlag);
}

function forcePushRule(tokens) {
  const args = pushArgs(tokens);
  if (!args) return false;
  return args.some(isForceToken);
}

function branchDeleteRule(tokens) {
  if (hasSequence(tokens, ["git", "branch", "-d"])) return true;
  return hasSequence(tokens, ["git", "branch", "-D"]);
}

function deleteBranchRule(tokens) {
  const args = pushArgs(tokens);
  if (args) {
    if (args.some(isMirrorDelete)) return true;
    if (args.some(isDeleteRefspec)) return true;
  }
  return branchDeleteRule(tokens);
}

function isMirrorDelete(token) {
  return token === "--delete";
}

const GATE_PATTERNS = [
  /^check-code-principles\.sh$/,
  /^pmd.*\.xml$/,
  /golangci.*\.yml$/,
  /^\.eslintrc/,
];

function isGatePath(path) {
  const name = basename(path);
  if (GATE_NAMES.has(name)) return true;
  return GATE_PATTERNS.some((pattern) => pattern.test(name));
}

const GATE_NAMES = new Set([
  "stryker.conf.json",
  "mutation.mk",
  "pitest-profile.xml",
  "mutmut-pyproject.toml",
]);

function gateRule(intent) {
  if (!isWriteTool(intent.tool)) return false;
  return (intent.paths || []).some(isGatePath);
}

function isSecretPath(path) {
  const name = basename(path);
  if (name === ".envrc") return true;
  return path.endsWith("config/agent.local.env") || path.endsWith("config/model.local.env");
}

function secretRule(intent, tokens) {
  if (hasSequence(tokens, ["gh", "secret"])) return true;
  if (hasSequence(tokens, ["glab", "variable"])) return true;
  if (hasSequence(tokens, ["security", "add-generic-password"])) return true;
  if (!isWriteTool(intent.tool)) return false;
  return (intent.paths || []).some(isSecretPath);
}

function builtinFs() {
  if (typeof process.getBuiltinModule !== "function") return null;
  return process.getBuiltinModule("fs");
}

function tryReal(path) {
  const fs = builtinFs();
  if (!fs) return null;
  try {
    return fs.realpathSync(path);
  } catch {
    return null;
  }
}

function absoluteFrom(path, base) {
  if (isAbsolute(path)) return normalize(path);
  const root = base || process.cwd();
  return normalize(join(root, path));
}

function realpathLoose(path, base) {
  const abs = absoluteFrom(path, base);
  let current = abs;
  let rest = [];
  while (true) {
    const real = tryReal(current);
    if (real) {
      if (rest.length === 0) return real;
      return join(real, ...rest.reverse());
    }
    const parent = dirname(current);
    if (parent === current) return abs;
    rest = rest.concat([basename(current)]);
    current = parent;
  }
}

function isUnder(root, path) {
  const realRoot = realpathLoose(root, root);
  const realPath = realpathLoose(path, root);
  if (realPath === realRoot) return true;
  return realPath.startsWith(realRoot + sep);
}

function outsideRule(intent) {
  if (!isWriteTool(intent.tool)) return false;
  const root = intent.repoRoot || process.cwd();
  return (intent.paths || []).some((path) => !isUnder(root, path));
}

function gitInitRule(tokens) {
  if (hasSequence(tokens, ["git", "init"])) return true;
  if (hasSequence(tokens, ["git", "submodule", "add"])) return true;
  return hasSequence(tokens, ["git", "submodule", "update", "--init"]);
}

function pushRuleGroup(tokens) {
  if (pushMainRule(tokens)) return "push-main";
  if (forcePushRule(tokens)) return "force-push";
  if (deleteBranchRule(tokens)) return "delete-branch";
  return null;
}

function commandRule(tokens) {
  if (mergeRule(tokens)) return "merge";
  if (tagRule(tokens)) return "tag";
  const push = pushRuleGroup(tokens);
  if (push) return push;
  if (gitInitRule(tokens)) return "git-init";
  return null;
}

function pathRule(intent, tokens) {
  if (gateRule(intent)) return "gate-threshold";
  if (secretRule(intent, tokens)) return "secret-rotate";
  if (outsideRule(intent)) return "write-outside-repo";
  return null;
}

function firstRule(intent, tokens) {
  const command = commandRule(tokens);
  if (command) return command;
  return pathRule(intent, tokens);
}

export function classify(intent) {
  if (READ_TOOLS.has(intent.tool)) {
    return { blocked: false, rule: null, requiresConfirmation: false };
  }
  const rule = firstRule(intent, tokensOf(intent.command));
  if (rule) return { blocked: true, rule, requiresConfirmation: true };
  return { blocked: false, rule: null, requiresConfirmation: true };
}

function readIntent(argv) {
  const at = argv.indexOf("--intent");
  if (at === -1 || argv[at + 1] === undefined) {
    throw new Error("usage: policy.mjs --intent '<json>'");
  }
  return JSON.parse(argv[at + 1]);
}

function main() {
  const intent = readIntent(process.argv.slice(2));
  process.stdout.write(JSON.stringify(classify(intent)) + "\n");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    process.stderr.write(error.message + "\n");
    process.exitCode = 2;
  }
}
