#!/usr/bin/env bash

validate_runner_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]
}

runner_command_from_config() {
  local config_file="$1"
  local runner="$2"
  jq -er --arg runner "$runner" '.runners[$runner].command // empty' "$config_file" 2>/dev/null || true
}

runner_kiro_agent_from_config() {
  local config_file="$1"
  jq -er '.execution.kiro_agent // .kiro_agent // .runners.kiro.agent // empty' "$config_file" 2>/dev/null || true
}

runner_preferred_model_from_config() {
  local config_file="$1"
  jq -er '.execution.kiro_model // .kiro_model // empty' "$config_file" 2>/dev/null || true
}

validate_kiro_agent_file_tools() {
  local project_root="$1"
  local agent_name="$2"
  local agent_file="${project_root}/.kiro/agents/${agent_name}.json"
  local has_read=0
  local has_write=0
  local tool=""

  if [[ ! -f "$agent_file" ]]; then
    return 1
  fi

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

require_commands() {
  local cmd=""
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || return 1
  done
}

ensure_default_kiro_agents() {
  local setup_script="$1"
  local project_root="$2"
  local preferred_model="${3:-}"

  [[ -x "$setup_script" ]] || return 1
  if [[ -n "$preferred_model" ]]; then
    bash "$setup_script" --project-root "$project_root" --ensure >/dev/null
    case "$preferred_model" in
      *sonnet*)
        bash "$setup_script" --project-root "$project_root" --agent-name "gdim-kiro-sonnet" --model "claude-sonnet-4.6" --ensure >/dev/null
        ;;
      *opus*|*)
        bash "$setup_script" --project-root "$project_root" --agent-name "gdim-kiro-opus" --model "claude-opus-4.6" --ensure >/dev/null
        ;;
    esac
    return 0
  fi
  bash "$setup_script" --project-root "$project_root" --ensure >/dev/null
}

ensure_runner_ready() {
  local runner="$1"
  local custom_cmd="$2"
  local project_root="$3"
  local setup_script="$4"
  local kiro_agent="$5"
  local kiro_model="${6:-}"

  if [[ -n "$custom_cmd" ]]; then
    return 0
  fi

  case "$runner" in
    claude)
      require_commands claude || return 1
      ;;
    codex)
      require_commands codex || return 1
      ;;
    kiro)
      require_commands kiro-cli || return 1
      ensure_default_kiro_agents "$setup_script" "$project_root" "$kiro_model" || return 1
      validate_kiro_agent_file_tools "$project_root" "$kiro_agent" || return 1
      ;;
    *)
      return 1
      ;;
  esac
}

run_runner() {
  local runner="$1"
  local prompt_file="$2"
  local log_file="$3"
  local timeout_minutes="$4"
  local workdir="$5"
  local custom_cmd="${6:-}"
  local kiro_agent="${7:-gdim-kiro-opus}"
  local rc=0
  local prompt_text=""

  rm -f "$log_file"

  if [[ -n "$custom_cmd" ]]; then
    (
      cd "$workdir"
      timeout --foreground "${timeout_minutes}m" bash -lc "$custom_cmd" \
        <"$prompt_file" >"$log_file" 2>&1
    ) || rc=$?
  else
    case "$runner" in
      claude)
        (
          cd "$workdir"
          timeout --foreground "${timeout_minutes}m" \
            claude -p --dangerously-skip-permissions \
            --allowedTools "Bash,Edit,Read,Write,Glob,Grep,Task,Skill" - \
            <"$prompt_file" >"$log_file" 2>&1
        ) || rc=$?
        ;;
      codex)
        (
          cd "$workdir"
          timeout --foreground "${timeout_minutes}m" \
            codex exec - \
            --dangerously-bypass-approvals-and-sandbox \
            --skip-git-repo-check \
            <"$prompt_file" >"$log_file" 2>&1
        ) || rc=$?
        ;;
      kiro)
        prompt_text="$(cat "$prompt_file")"
        (
          cd "$workdir"
          timeout --foreground "${timeout_minutes}m" \
            kiro-cli chat --agent "$kiro_agent" --no-interactive --trust-all-tools "$prompt_text" \
            >"$log_file" 2>&1
        ) || rc=$?
        ;;
      *)
        return 2
        ;;
    esac
  fi

  if [[ "$rc" -ne 0 ]]; then
    return "$rc"
  fi
  return 0
}
