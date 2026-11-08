# AC-044-14: Opt-in installer, make targets, structural smoke

## AC-044-14-01 — Install writes the complete tree
Given a temp `OPENCODE_CONFIG_DIR`
When `node scripts/voice/install.mjs` runs
Then exit code is 0
And `<cfg>/agents/voice-concierge.md` exists
And `<cfg>/voice/` contains every `scripts/voice/*.mjs` and `scripts/voice/tts-worker.py` by the same basenames

## AC-044-14-02 — Re-running is idempotent
Given the tree is already installed
When the installer runs a second time
Then exit code is 0
And the recursive file list of `<cfg>` is unchanged

## AC-044-14-03 — Uninstall removes exactly what was installed
Given a sentinel file `<cfg>/sentinel.txt`
And the tree installed
When `install.mjs --uninstall` runs
Then exit code is 0
And `<cfg>/agents/voice-concierge.md` is gone
And `<cfg>/voice/` is gone
And `<cfg>/sentinel.txt` still exists

## AC-044-14-04 — Dry run writes nothing
Given a non-existent temp `OPENCODE_CONFIG_DIR`
When `install.mjs --dry-run` runs
Then exit code is 0
And stdout lists each destination path, one per line
And the config directory still does not exist

## AC-044-14-05 — A missing source aborts without partial copies
Given a repository copy with `agents-optional/voice-concierge.md` removed
When the installer runs against a temp config dir
Then exit code is 3
And stderr names the missing path
And the config dir contains no `voice` directory

## AC-044-14-06 — No writes outside the config directory
Given a temp `HOME` and a temp `OPENCODE_CONFIG_DIR` outside it
When the installer runs
Then every created file is under the config directory
And no file is created under the temp `HOME`

## AC-044-14-07 — Make targets exist
Given the Makefile
When `make -n install-voice`, `make -n uninstall-voice`, and `make -n smoke-voice` run
Then each resolves to a command naming `scripts/voice/`
And `.PHONY` names all three targets
And `make help` output mentions them

## AC-044-14-08 — Smoke output is checkable
Given a machine with Node and no Python, PyTorch, or Pocket TTS
When `node scripts/voice/smoke.mjs` runs
Then exit code is 0
And stdout contains `[OK] agent voice-concierge.md`
And stdout contains `[OK] policy refuses`
And stdout contains `[OK] install dry-run`
And stdout contains `[OK] print-config`
And stdout contains one `[OK] <file> parses` line for every `.mjs` under `scripts/voice/`

## AC-044-14-09 — Smoke is offline and Python-optional
Given `scripts/voice/smoke.mjs`
When it is searched for `node:http`, `node:https`, and `fetch(`
Then none is present
And on a machine with no `python3` it prints `[SKIP] tts-worker.py` and still exits 0
And it downloads no model weights
