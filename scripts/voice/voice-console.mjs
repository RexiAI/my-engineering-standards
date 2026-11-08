#!/usr/bin/env node
// voice-console.mjs — entry point for the voice console. Parses arguments,
// resolves configuration, and dispatches to one of the three modes. The mode
// modules are imported lazily so --help and --print-config stay inert: they
// open no socket, load no model, and write no file.
import {
  HELP,
  UsageError,
  MissingRuntime,
  UpstreamError,
  parseArgs,
  resolveConfig,
  printConfig,
  EXIT,
  PolicyRefusal,
} from "./config.mjs";

async function dispatch(config) {
  if (config.mode === "narrate") {
    const { runNarrate } = await import("./narrate.mjs");
    return runNarrate(config);
  }
  if (config.mode === "converse") {
    const { runConverse } = await import("./converse.mjs");
    return runConverse(config);
  }
  const { runControl } = await import("./control.mjs");
  return runControl(config);
}

function exitCodeFor(error) {
  if (error instanceof UsageError) return EXIT.USAGE;
  if (error instanceof MissingRuntime) return EXIT.MISSING;
  if (error instanceof PolicyRefusal) return EXIT.REFUSED;
  if (error instanceof UpstreamError) return EXIT.UPSTREAM;
  return 1;
}

function finish(code) {
  process.exitCode = code;
  const guard = setTimeout(() => process.exit(code), 200);
  guard.unref();
  process.stdout.write("", () => process.exit(code));
}

function printConfigExit(config, raw) {
  process.stdout.write(printConfig(config) + "\n");
  if (config.sessionRequired && raw.mode !== undefined) {
    process.stderr.write(`--session is required for --mode ${config.mode}\n`);
    return EXIT.USAGE;
  }
  return EXIT.OK;
}

async function main() {
  const raw = parseArgs(process.argv.slice(2));
  if (raw.help) {
    process.stdout.write(HELP);
    return EXIT.OK;
  }
  const config = resolveConfig(raw, process.env);
  if (raw.printConfig) return printConfigExit(config, raw);
  if (config.sessionRequired) {
    throw new UsageError(`--session is required for --mode ${config.mode}`);
  }
  return dispatch(config);
}

main()
  .then((code) => {
    finish(code);
  })
  .catch((error) => {
    process.stderr.write(error.message + "\n", () => process.exit(exitCodeFor(error)));
  });
