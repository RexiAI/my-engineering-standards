// e2e.config.example.ts — worked agentic-E2E config template for child repos
// (spec 030 standard). Copy to `e2e.config.ts` at the project root and adapt.
//
// Governance rules this file demonstrates:
//   1. Model ids arrive from the environment — never hardcoded here.
//      The framework does NOT load .env files; export these in the launching
//      shell (direnv / CI job env). See the e2e-testing skill's setup guide.
//   2. Telemetry is opted out: E2E_TELEMETRY_DISABLED=1 must be set in the
//      same environment layer as the model ids (repo policy).
//   3. App launch is shell-less: argv arrays under targets[].app.command.
//   4. The dev server binds port 0 (OS-assigned); {port} substitutes the real
//      port into URLs, so parallel runs never collide.
//   5. Budgets bound every run (model calls / actions / timeout) — defaults
//      plus a per-agent override shape.
//   6. Replay cache is explicit: "read-write" | "read-only" | "off".
//
// This is a template — the illustrative numbers below are examples, not
// recommended defaults.

const agentModel = process.env.E2E_AGENT_MODEL; // actor model id (env-sourced)
const judgeModel = process.env.E2E_JUDGE_MODEL; // judge model id (env-sourced)
// E2E_TELEMETRY_DISABLED=1 is expected in the environment; the config cannot
// set it, and a run without it violates repo policy (see references/setup.md).

export default {
  // Journey discovery glob — the standard for this repo family:
  tests: "tests/**/*.e2e.ts",

  // Models come from the environment; naming a provider or model id here is
  // a standards violation (same indirection rule as docs/SPEC_PIPELINE.md
  // §Model configuration).
  models: {
    agent: agentModel,
    judge: judgeModel,
  },

  targets: [
    {
      id: "web",
      app: {
        // shell-less launch: argv array, never "npm run dev" through a shell
        command: ["npm", "run", "dev", "--", "--port", "0"],
        ready: "server listening",
      },
      // Port-0 pattern: bind port 0 so the OS assigns a free port; {port}
      // substitutes the actual port once the app is up.
      url: "http://localhost:0",
      callbackUrl: "http://localhost:{port}/callback",
    },
  ],

  // Budgets — the inner bound of every run. Exhaustion exits 3; shrinking
  // the journey is the fix, raising the number is not.
  budget: {
    default: {
      modelCalls: 100, // illustrative
      actions: 200, // illustrative
      timeout: 300_000, // ms; illustrative
    },
    // Per-agent override example (the judge is cheaper per call than the
    // actor's planning loop, so it often wants a different cap):
    agent: {
      modelCalls: 80, // illustrative per-agent budget
    },
  },

  // Replay cache mode: "read-write" (local default posture),
  // "read-only" (CI — combine with the --strict-cache flag so a cache miss
  // fails loudly), or "off" (investigating cache-induced drift).
  cache: "read-write",

  // Parallelism and flake policy (see the CI reference): workers = cores/2
  // locally, 1 in CI; retries = 0 locally, 1 in CI. test.only is rejected in
  // CI (ONLY_IN_CI) — leave focused runs to local debugging only.

  // Artifacts consumed by CI uploads and by the e2e-runner agent:
  // .e2e/report.json plus junit.xml and the .e2e/failures/ captures.
  artifacts: {
    report: ".e2e/report.json",
    junit: "junit.xml",
    failures: ".e2e/failures/",
  },
} as const;
