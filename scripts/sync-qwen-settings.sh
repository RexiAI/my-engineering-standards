#!/usr/bin/env bash
# sync-qwen-settings.sh — One-way sync: opencode.json Token Plan provider → ~/.qwen/settings.json
#
# Reads the bailian-token-plan-personal provider from opencode.json and adds matching
# model entries to the Qwen CLI settings file. Existing non-Token-Plan entries are preserved.
#
# Usage: ./scripts/sync-qwen-settings.sh [--dry-run]
#
# Prerequisites:
#   - opencode.json in the repo root must have a bailian-token-plan-personal provider
#   - ~/.qwen/settings.json must exist (Qwen CLI installed)

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENCODE_JSON="$REPO_ROOT/opencode.json"
QWEN_SETTINGS="${HOME}/.qwen/settings.json"
PROVIDER_NAME="bailian-token-plan-personal"

# --- Validate inputs ---
if [[ ! -f "$OPENCODE_JSON" ]]; then
  echo "ERROR: opencode.json not found at $OPENCODE_JSON" >&2
  exit 1
fi

if [[ ! -f "$QWEN_SETTINGS" ]]; then
  echo "ERROR: Qwen CLI settings not found at $QWEN_SETTINGS" >&2
  echo "  Install Qwen CLI first: npm install -g @anthropic-ai/qwen" >&2
  exit 1
fi

# --- Extract provider info from opencode.json using python3 ---
PROVIDER_JSON=$(python3 -c "
import json, sys
with open('$OPENCODE_JSON') as f:
    cfg = json.load(f)
provider = cfg.get('provider', {}).get('$PROVIDER_NAME')
if not provider:
    print('ERROR: provider $PROVIDER_NAME not found in opencode.json', file=sys.stderr)
    sys.exit(1)
base_url = provider.get('options', {}).get('baseURL', '')
# Convert Anthropic endpoint to OpenAI-compatible
openai_base = base_url.replace('/apps/anthropic/v1', '/compatible-mode/v1')
env_key = provider.get('env', ['DASHSCOPE_API_KEY'])[0]
models = provider.get('models', {})
result = []
for model_id, model_cfg in models.items():
    ctx = model_cfg.get('limit', {}).get('context', 983616)
    has_thinking = 'thinking' in model_cfg.get('options', {}) or model_cfg.get('reasoning', False)
    result.append({
        'id': model_id,
        'name': f'[Token Plan] {model_id}',
        'baseUrl': openai_base,
        'envKey': env_key,
        'contextWindowSize': ctx,
        'has_thinking': has_thinking
    })
print(json.dumps(result))
" 2>&1)

if [[ $? -ne 0 ]]; then
  echo "ERROR: Failed to parse opencode.json:" >&2
  echo "$PROVIDER_JSON" >&2
  exit 1
fi

MODEL_COUNT=$(echo "$PROVIDER_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
echo "Found $MODEL_COUNT Token Plan models in opencode.json"

# --- Merge into Qwen CLI settings ---
python3 -c "
import json, sys

# Read existing Qwen settings
with open('$QWEN_SETTINGS') as f:
    settings = json.load(f)

# Read new models from opencode.json
new_models = json.loads('''$PROVIDER_JSON''')

# Get existing openai provider list, or create it
providers = settings.get('modelProviders', {}).get('openai', [])

# Remove any existing Token Plan entries (same baseUrl pattern)
token_plan_base = 'token-plan.ap-southeast-1.maas.aliyuncs.com'
providers = [p for p in providers if token_plan_base not in p.get('baseUrl', '')]

# Add new Token Plan models
for m in new_models:
    entry = {
        'id': m['id'],
        'name': m['name'],
        'baseUrl': m['baseUrl'],
        'envKey': m['envKey'],
        'generationConfig': {
            'contextWindowSize': m['contextWindowSize']
        }
    }
    if m['has_thinking']:
        entry['generationConfig']['extra_body'] = {'enable_thinking': True}
    providers.append(entry)

# Write back
settings.setdefault('modelProviders', {})['openai'] = providers

if '$DRY_RUN' == 'True':
    print(json.dumps(settings, indent=2))
else:
    with open('$QWEN_SETTINGS', 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print(f'Updated {\"$QWEN_SETTINGS\"} with {len(new_models)} Token Plan models')
"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "(dry run — no changes written)"
fi
