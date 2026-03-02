#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_OPUS_AGENT="gdim-kiro-opus"
DEFAULT_OPUS_MODEL="claude-opus-4.6"
DEFAULT_SONNET_AGENT="gdim-kiro-sonnet"
DEFAULT_SONNET_MODEL="claude-sonnet-4.5"

TARGET_AGENT_NAME=""
TARGET_MODEL_NAME=""
FORCE=0
ENSURE=0

usage() {
  cat <<'USAGE'
Usage:
  automation/ai-coding/setup-kiro-agent.sh [options]

Behavior:
  - No --agent-name: ensure default dual agents (opus + sonnet).
  - With --agent-name: manage one specific agent.

Options:
  --project-root <dir>  Target project root (default: automation script repo root)
  --agent-name <name>   Single-agent mode: target agent name
  --model <model-id>    Single-agent mode: model id (default: claude-opus-4.6)
  --ensure              Create or repair when missing/invalid (idempotent)
  --force               Always overwrite target file(s)
  -h, --help            Show help
USAGE
}

agent_has_required_tools() {
  local agent_file="$1"
  local has_read=0
  local has_write=0
  local tool=""

  if jq -er '.tools // [] | index("*") != null' "$agent_file" >/dev/null 2>&1; then
    return 0
  fi

  for tool in fs_read read_file file_read; do
    if jq -er --arg t "$tool" '.tools // [] | index($t) != null' "$agent_file" >/dev/null 2>&1; then
      has_read=1
      break
    fi
  done

  for tool in fs_write write_file file_write; do
    if jq -er --arg t "$tool" '.tools // [] | index($t) != null' "$agent_file" >/dev/null 2>&1; then
      has_write=1
      break
    fi
  done

  if [[ "$has_read" -eq 1 && "$has_write" -eq 1 ]]; then
    return 0
  fi

  return 1
}

agent_has_gdim_resources() {
  local agent_file="$1"
  jq -er '
    .resources // []
    | any(.[]; . == "skill://.kiro/skills/**/SKILL.md" or test("skill://\\.kiro/skills/gdim"))
  ' "$agent_file" >/dev/null 2>&1
}

agent_file_valid() {
  local agent_file="$1"
  local expected_name="$2"
  local expected_model="$3"
  local name=""
  local model=""

  [[ -f "$agent_file" ]] || return 1
  name="$(jq -r '.name // ""' "$agent_file" 2>/dev/null || true)"
  model="$(jq -r '.model // ""' "$agent_file" 2>/dev/null || true)"

  [[ "$name" == "$expected_name" ]] || return 1
  [[ "$model" == "$expected_model" ]] || return 1
  agent_has_required_tools "$agent_file" || return 1
  agent_has_gdim_resources "$agent_file" || return 1
  return 0
}

write_agent_file() {
  local agent_file="$1"
  local agent_name="$2"
  local model_name="$3"

  mkdir -p "$(dirname "$agent_file")"

  cat >"$agent_file" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/aws/amazon-q-developer-cli/refs/heads/main/schemas/agent-v1.json",
  "name": "${agent_name}",
  "description": "GDIM automation agent (Kiro CLI).",
  "prompt": "You are a pragmatic software engineer focused on implementing GDIM workflow tasks with strong execution discipline.",
  "mcpServers": {},
  "tools": [
    "*"
  ],
  "toolAliases": {},
  "allowedTools": [],
  "model": "${model_name}",
  "resources": [
    "skill://.kiro/skills/gdim/SKILL.md",
    "skill://.kiro/skills/gdim-*/SKILL.md",
    "skill://.kiro/skills/**/SKILL.md"
  ],
  "hooks": {},
  "toolsSettings": {},
  "useLegacyMcpJson": true
}
EOF
}

ensure_agent() {
  local agent_name="$1"
  local model_name="$2"
  local agent_file="${PROJECT_ROOT}/.kiro/agents/${agent_name}.json"

  if [[ -f "$agent_file" && "$FORCE" -ne 1 ]]; then
    if agent_file_valid "$agent_file" "$agent_name" "$model_name"; then
      echo "Kiro agent already valid: ${agent_file}"
      return 0
    fi
    if [[ "$ENSURE" -eq 1 ]]; then
      write_agent_file "$agent_file" "$agent_name" "$model_name"
      echo "Kiro agent repaired: ${agent_file}"
      return 0
    fi
    echo "Agent file exists but invalid: ${agent_file} (use --ensure or --force)" >&2
    return 1
  fi

  write_agent_file "$agent_file" "$agent_name" "$model_name"
  echo "Kiro agent written: ${agent_file}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --agent-name)
      TARGET_AGENT_NAME="$2"
      shift 2
      ;;
    --model)
      TARGET_MODEL_NAME="$2"
      shift 2
      ;;
    --ensure)
      ENSURE=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$PROJECT_ROOT" != /* ]]; then
  PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
fi

if [[ -n "$TARGET_AGENT_NAME" ]]; then
  [[ -n "$TARGET_MODEL_NAME" ]] || TARGET_MODEL_NAME="$DEFAULT_OPUS_MODEL"
  ensure_agent "$TARGET_AGENT_NAME" "$TARGET_MODEL_NAME"
  exit 0
fi

ensure_agent "$DEFAULT_OPUS_AGENT" "$DEFAULT_OPUS_MODEL"
ensure_agent "$DEFAULT_SONNET_AGENT" "$DEFAULT_SONNET_MODEL"
