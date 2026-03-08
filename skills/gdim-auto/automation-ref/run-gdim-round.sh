#!/usr/bin/env bash
set -euo pipefail

# Level 2: GDIM Round Dispatcher
# Runs iterative GDIM rounds for a single flow until gaps are closed or limits hit.
#
# Usage: ./automation/ai-coding/run-gdim-round.sh \
#          --flow-slug SLUG --max-rounds N \
#          --workflow-dir DIR --intent-file FILE \
#          --design-doc DOC --modules MODS \
#          [--allowed-paths PATHS] [--stage A|B|C] [--runner NAME|--executor NAME] \
#          [--runner-cmd CMD] [--kiro-agent NAME] [--stall-limit N] \
#          [--enforce-round-code-commit|--no-enforce-round-code-commit] \
#          [--skip-tests] [--auto-commit-gdim-docs|--no-auto-commit-gdim-docs] \
#          [--dry-run] [--timeout MIN]
#
# Exit codes: 0=all gaps closed, 1=BLOCKED, 2=max rounds, 3=stalled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AUTOMATION_ROOT="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse arguments ---
FLOW_SLUG=""
MAX_ROUNDS=4
WORKFLOW_DIR=""
INTENT_FILE=""
DESIGN_DOC=""
MODULES=""
ALLOWED_PATHS=""
STAGE="B"
DRY_RUN=0
TIMEOUT_MINUTES=45
SKIP_CLEAN_CHECK=0
TASK_DIR=""
RUNNER_OVERRIDE=""
RUNNER_CMD_OVERRIDE=""
KIRO_AGENT_OVERRIDE=""
REFACTOR_POSTURE=""
HEARTBEAT_SECONDS_RAW="${GDIM_HEARTBEAT_SECONDS:-20}"
HEARTBEAT_SECONDS=20
SKIP_TESTS_RAW="${GDIM_SKIP_TESTS:-0}"
SKIP_TESTS=0
STALL_LIMIT_RAW="${GDIM_STALL_LIMIT:-5}"
AUTO_COMMIT_GDIM_DOCS_RAW="${GDIM_AUTO_COMMIT_GDIM_DOCS:-1}"
AUTO_COMMIT_GDIM_DOCS=1
ENFORCE_ROUND_CODE_COMMIT_RAW="${GDIM_ENFORCE_ROUND_CODE_COMMIT:-0}"
ENFORCE_ROUND_CODE_COMMIT=0

case "${SKIP_TESTS_RAW}" in
    1|true|TRUE|yes|YES|on|ON) SKIP_TESTS=1 ;;
esac

case "${AUTO_COMMIT_GDIM_DOCS_RAW}" in
    0|false|FALSE|no|NO|off|OFF) AUTO_COMMIT_GDIM_DOCS=0 ;;
    1|true|TRUE|yes|YES|on|ON) AUTO_COMMIT_GDIM_DOCS=1 ;;
esac

case "${ENFORCE_ROUND_CODE_COMMIT_RAW}" in
    1|true|TRUE|yes|YES|on|ON) ENFORCE_ROUND_CODE_COMMIT=1 ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --flow-slug)      FLOW_SLUG="$2"; shift 2 ;;
        --max-rounds)     MAX_ROUNDS="$2"; shift 2 ;;
        --workflow-dir)   WORKFLOW_DIR="$2"; shift 2 ;;
        --intent-file)    INTENT_FILE="$2"; shift 2 ;;
        --design-doc)     DESIGN_DOC="$2"; shift 2 ;;
        --modules)        MODULES="$2"; shift 2 ;;
        --allowed-paths)  ALLOWED_PATHS="$2"; shift 2 ;;
        --stage)          STAGE="$2"; shift 2 ;;
        --dry-run)        DRY_RUN=1; shift ;;
        --timeout)        TIMEOUT_MINUTES="$2"; shift 2 ;;
        --skip-clean-check) SKIP_CLEAN_CHECK=1; shift ;;
        --skip-tests)     SKIP_TESTS=1; shift ;;
        --task-dir)       TASK_DIR="$2"; shift 2 ;;
        --runner|--executor) RUNNER_OVERRIDE="$2"; shift 2 ;;
        --runner-cmd)     RUNNER_CMD_OVERRIDE="$2"; shift 2 ;;
        --kiro-agent)     KIRO_AGENT_OVERRIDE="$2"; shift 2 ;;
        --refactor-posture) REFACTOR_POSTURE="$2"; shift 2 ;;
        --stall-limit)    STALL_LIMIT_RAW="$2"; shift 2 ;;
        --enforce-round-code-commit) ENFORCE_ROUND_CODE_COMMIT=1; shift ;;
        --no-enforce-round-code-commit) ENFORCE_ROUND_CODE_COMMIT=0; shift ;;
        --auto-commit-gdim-docs) AUTO_COMMIT_GDIM_DOCS=1; shift ;;
        --no-auto-commit-gdim-docs) AUTO_COMMIT_GDIM_DOCS=0; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$FLOW_SLUG" ] || [ -z "$WORKFLOW_DIR" ]; then
    echo "Usage: $0 --flow-slug SLUG --workflow-dir DIR [--runner NAME|--executor NAME] [--runner-cmd CMD] [--kiro-agent NAME] [--stall-limit N] [--enforce-round-code-commit|--no-enforce-round-code-commit] [--skip-tests] [--auto-commit-gdim-docs|--no-auto-commit-gdim-docs] [options]" >&2
    exit 1
fi

# --- Task-dir mode: export env vars for lib/state.sh and lib/log.sh ---
if [ -n "$TASK_DIR" ]; then
    TASK_DIR="$(cd "$TASK_DIR" && pwd)"
    export GDIM_STATE_DIR="${TASK_DIR}/state"
    export GDIM_LOG_DIR="${TASK_DIR}/logs"
fi

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/state.sh
source "$SCRIPT_DIR/lib/state.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=lib/prompt-builder.sh
source "$SCRIPT_DIR/lib/prompt-builder.sh"
# shellcheck source=lib/runner.sh
source "$SCRIPT_DIR/lib/runner.sh"

normalize_refactor_posture() {
    local posture
    posture=$(printf "%s" "${1:-balanced}" | tr '[:upper:]' '[:lower:]')
    case "$posture" in
        conservative|balanced|aggressive) printf "%s" "$posture" ;;
        *) printf "%s" "balanced" ;;
    esac
}

export CURRENT_FLOW="$FLOW_SLUG"
export GDIM_SKIP_TESTS="$SKIP_TESTS"
export GDIM_ENFORCE_ROUND_CODE_COMMIT="$ENFORCE_ROUND_CODE_COMMIT"

if [[ "$HEARTBEAT_SECONDS_RAW" =~ ^[0-9]+$ ]]; then
    HEARTBEAT_SECONDS="$HEARTBEAT_SECONDS_RAW"
else
    log_info "Invalid GDIM_HEARTBEAT_SECONDS=${HEARTBEAT_SECONDS_RAW}, fallback to 20s"
fi

# Stall threshold: default 5 rounds, override by --stall-limit or GDIM_STALL_LIMIT.
if [[ "$STALL_LIMIT_RAW" =~ ^[0-9]+$ ]] && [ "$STALL_LIMIT_RAW" -ge 1 ]; then
    STALL_LIMIT="$STALL_LIMIT_RAW"
else
    STALL_LIMIT=5
    log_info "Invalid stall limit=${STALL_LIMIT_RAW}, fallback to 5"
fi

if [ "$DRY_RUN" -eq 1 ] && [ "$AUTO_COMMIT_GDIM_DOCS" -eq 1 ]; then
    AUTO_COMMIT_GDIM_DOCS=0
fi

# Load retry limits from config
if [ -n "${TASK_DIR:-}" ]; then
    CONFIG_FILE="${TASK_DIR}/config/flows.json"
else
    CONFIG_FILE="${SCRIPT_DIR}/config/flows.json"
fi
RETRY_COMPILE=$(jq -r '.retry_limits.compile_failed // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
RETRY_TEST=$(jq -r '.retry_limits.test_failed // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
RETRY_MALFORMED=$(jq -r '.retry_limits.malformed_output // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
RETRY_COMMIT=$(jq -r '.retry_limits.commit_missing // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)

RUNNER="$(jq -r '.execution.runner // .executor // "claude"' "$CONFIG_FILE" 2>/dev/null || echo "claude")"
if [ -n "$RUNNER_OVERRIDE" ]; then
    RUNNER="$RUNNER_OVERRIDE"
fi
if ! validate_runner_name "$RUNNER"; then
    log_error "Invalid runner name: ${RUNNER}"
    exit 1
fi

RUNNER_CMD="$(runner_command_from_config "$CONFIG_FILE" "$RUNNER")"
if [ -n "$RUNNER_CMD_OVERRIDE" ]; then
    RUNNER_CMD="$RUNNER_CMD_OVERRIDE"
fi

KIRO_AGENT="$(runner_kiro_agent_from_config "$CONFIG_FILE")"
if [ -n "$KIRO_AGENT_OVERRIDE" ]; then
    KIRO_AGENT="$KIRO_AGENT_OVERRIDE"
fi

KIRO_MODEL_PREFERENCE="$(runner_preferred_model_from_config "$CONFIG_FILE")"
if [ -z "$KIRO_MODEL_PREFERENCE" ]; then
    KIRO_MODEL_PREFERENCE="${GDIM_KIRO_MODEL:-}"
fi

if [ -z "$KIRO_AGENT" ]; then
    if [[ "$KIRO_MODEL_PREFERENCE" =~ sonnet ]]; then
        KIRO_AGENT="${GDIM_KIRO_AGENT:-gdim-kiro-sonnet}"
    else
        KIRO_AGENT="${GDIM_KIRO_AGENT:-gdim-kiro-opus}"
    fi
fi

if [ -z "$REFACTOR_POSTURE" ]; then
    TASK_REFACTOR_POSTURE="$(jq -r '.refactor_posture // empty' "$CONFIG_FILE" 2>/dev/null || true)"
    FLOW_REFACTOR_POSTURE="$(jq -r --arg slug "$FLOW_SLUG" '.flows[]? | select(.slug == $slug) | .refactor_posture // empty' "$CONFIG_FILE" 2>/dev/null | head -1)"
    if [ -n "$FLOW_REFACTOR_POSTURE" ]; then
        REFACTOR_POSTURE="$FLOW_REFACTOR_POSTURE"
    elif [ -n "$TASK_REFACTOR_POSTURE" ]; then
        REFACTOR_POSTURE="$TASK_REFACTOR_POSTURE"
    else
        REFACTOR_POSTURE="balanced"
    fi
fi
REFACTOR_POSTURE="$(normalize_refactor_posture "$REFACTOR_POSTURE")"
export GDIM_REFACTOR_POSTURE="$REFACTOR_POSTURE"

# Resolve paths
WORKFLOW_DIR_ABS="${PROJECT_ROOT}/${WORKFLOW_DIR}"
# Intent file: if absolute or starts with /, use as-is; otherwise resolve relative to SCRIPT_DIR
if [[ "$INTENT_FILE" == /* ]]; then
    INTENT_FILE_ABS="$INTENT_FILE"
elif [ -n "${TASK_DIR:-}" ] && [ -f "${INTENT_FILE}" ]; then
    # Already an absolute or task-dir-relative path passed by run-gdim-flows.sh
    INTENT_FILE_ABS="$INTENT_FILE"
else
    INTENT_FILE_ABS="${SCRIPT_DIR}/${INTENT_FILE}"
fi
if [[ "$DESIGN_DOC" == /* ]]; then
    DESIGN_DOC_ABS="$DESIGN_DOC"
else
    DESIGN_DOC_ABS="${PROJECT_ROOT}/${DESIGN_DOC}"
    if [ ! -f "$DESIGN_DOC_ABS" ]; then
        GIT_TOPLEVEL="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$GIT_TOPLEVEL" ] && [ -f "${GIT_TOPLEVEL}/${DESIGN_DOC}" ]; then
            DESIGN_DOC_ABS="${GIT_TOPLEVEL}/${DESIGN_DOC}"
        fi
    fi
fi
TEMPLATE_DIR="${SCRIPT_DIR}/templates/stages"

mkdir -p "$WORKFLOW_DIR_ABS"
init_round_state "$FLOW_SLUG"

# Auto-commit docs is safest on clean workspace; disable automatically when
# skip-clean-check is used on a dirty workspace.
if [ "$AUTO_COMMIT_GDIM_DOCS" -eq 1 ]; then
    if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_warn "Auto-commit GDIM docs disabled: not inside a git repository"
        AUTO_COMMIT_GDIM_DOCS=0
    else
        _dirty_for_autocommit=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null || true)
        if [ -n "$_dirty_for_autocommit" ]; then
            log_warn "Auto-commit GDIM docs disabled: workspace has pre-existing changes"
            AUTO_COMMIT_GDIM_DOCS=0
        fi
    fi
fi

# --- Preflight: clean workspace check ---
if [ "$DRY_RUN" -eq 0 ] && [ "$SKIP_CLEAN_CHECK" -eq 0 ]; then
    _dirty=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null || true)
    if [ -n "$_dirty" ]; then
        log_error "Workspace is not clean. Commit or stash changes before running automation."
        log_error "Dirty files:"
        echo "$_dirty" | head -20 >&2
        log_error "Use --skip-clean-check to bypass (not recommended)."
        exit 1
    fi
fi

# --- Preflight: required commands ---
if [ "$DRY_RUN" -eq 0 ]; then
    for _cmd in timeout jq; do
        if ! command -v "$_cmd" &>/dev/null; then
            log_error "Required command not found: $_cmd"
            exit 1
        fi
    done

    if ! ensure_runner_ready "$RUNNER" "$RUNNER_CMD" "$PROJECT_ROOT" "${SCRIPT_DIR}/setup-kiro-agent.sh" "$KIRO_AGENT" "$KIRO_MODEL_PREFERENCE"; then
        if [ -n "$RUNNER_CMD" ]; then
            log_error "Runner preflight failed for ${RUNNER} (custom command configured)"
        elif [ "$RUNNER" = "kiro" ]; then
            log_error "Kiro runner preflight failed. Ensure kiro-cli and .kiro/agents/${KIRO_AGENT}.json are valid."
        else
            log_error "Runner preflight failed for ${RUNNER}. Ensure required CLI is installed."
        fi
        exit 1
    fi
fi

# --- Helper: invoke runner ---
invoke_runner() {
    local prompt_text="$1"
    local log_file="$2"
    local prompt_file=""
    local exit_code=0
    local runner_pid=0
    local elapsed=0
    local next_heartbeat=0
    local stage_label="${CURRENT_STAGE:-round}"

    mkdir -p "$(dirname "$log_file")"
    prompt_file="$(mktemp)"
    printf "%s" "$prompt_text" >"$prompt_file"

    log_info "Invoking runner=${RUNNER} stage=${stage_label} (timeout=${TIMEOUT_MINUTES}m)..."
    append_round_event "$FLOW_SLUG" "${CURRENT_ROUND:-0}" "runner_invoking" "runner=${RUNNER};stage=${stage_label};timeout=${TIMEOUT_MINUTES}m"
    run_runner "$RUNNER" "$prompt_file" "$log_file" "$TIMEOUT_MINUTES" "$PROJECT_ROOT" "$RUNNER_CMD" "$KIRO_AGENT" &
    runner_pid=$!

    if [ "$HEARTBEAT_SECONDS" -gt 0 ]; then
        next_heartbeat="$HEARTBEAT_SECONDS"
        while kill -0 "$runner_pid" 2>/dev/null; do
            sleep 1
            if kill -0 "$runner_pid" 2>/dev/null; then
                elapsed=$((elapsed + 1))
                if [ "$elapsed" -ge "$next_heartbeat" ]; then
                    next_heartbeat=$((next_heartbeat + HEARTBEAT_SECONDS))
                    log_info "Runner still running... elapsed=${elapsed}s"
                fi
            fi
        done
    fi

    wait "$runner_pid" || exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        append_round_event "$FLOW_SLUG" "${CURRENT_ROUND:-0}" "runner_completed" "runner=${RUNNER};stage=${stage_label}"
    else
        append_round_event "$FLOW_SLUG" "${CURRENT_ROUND:-0}" "runner_failed" "runner=${RUNNER};stage=${stage_label};exit=${exit_code}"
    fi

    rm -f "$prompt_file"
    return $exit_code
}

# --- Helper: path whitelist auto-expand ---
_trim_spaces() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf "%s" "$value"
}

_strip_surrounding_quotes() {
    local value="$1"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value#\"}"
        value="${value%\"}"
    fi
    printf "%s" "$value"
}

_csv_contains_item() {
    local csv="$1"
    local item="$2"
    local entry=""
    IFS=',' read -ra entries <<< "$csv"
    for entry in "${entries[@]}"; do
        entry=$(_trim_spaces "$entry")
        [ -z "$entry" ] && continue
        [ "$entry" = "$item" ] && return 0
    done
    return 1
}

_extract_path_violation_files() {
    local validate_result="$1"
    printf '%b' "$validate_result" | awk '
        /^\[FAIL\] path whitelist/ { in_block = 1; next }
        in_block == 1 {
            if ($0 ~ /^\[(PASS|FAIL|MISS|WARN|SKIP)\]/) { in_block = 0; next }
            if ($0 ~ /^[[:space:]]+/) {
                sub(/^[[:space:]]+/, "", $0)
                if (length($0) > 0) print $0
            }
        }
    '
}

PATH_EXPAND_ADDITIONS=""
PATH_EXPANDED_ALLOWED_PATHS=""
expand_allowed_paths_for_path_violation() {
    local current_paths="$1"
    local validate_result="$2"
    local updated_paths="$current_paths"
    local additions=""
    local file=""
    local path_prefix=""

    PATH_EXPAND_ADDITIONS=""

    while IFS= read -r file; do
        file=$(_trim_spaces "$file")
        file=$(_strip_surrounding_quotes "$file")
        [ -z "$file" ] && continue
        path_prefix="$file"
        if [[ "$file" == */* ]]; then
            path_prefix="${file%/*}/"
        fi

        if ! _csv_contains_item "$updated_paths" "$path_prefix"; then
            if [ -n "$updated_paths" ]; then
                updated_paths="${updated_paths},${path_prefix}"
            else
                updated_paths="${path_prefix}"
            fi
            if [ -n "$additions" ]; then
                additions="${additions},${path_prefix}"
            else
                additions="${path_prefix}"
            fi
        fi
    done < <(_extract_path_violation_files "$validate_result")

    PATH_EXPAND_ADDITIONS="$additions"
    PATH_EXPANDED_ALLOWED_PATHS="$updated_paths"
}

# --- Helper: detect if TTY is actually usable (not just exists) ---
_tty_usable() {
    # /dev/tty may exist in headless environments but not be readable
    if [ -t 0 ]; then
        return 0
    fi
    # Try an actual non-blocking read to verify /dev/tty works
    if read -r -t 0 < /dev/tty 2>/dev/null; then
        return 0
    fi
    return 1
}

has_any_execute_phase_passed() {
    local slug="$1"
    local upto_round="$2"
    local r=""
    for ((r=1; r<=upto_round; r++)); do
        if [ "$(get_phase_status "$slug" "$r" "execute")" = "passed" ]; then
            return 0
        fi
    done
    return 1
}

_to_project_relative_path() {
    local abs_path="$1"
    if [[ "$abs_path" == "$PROJECT_ROOT/"* ]]; then
        printf "%s" "${abs_path#"$PROJECT_ROOT"/}"
        return 0
    fi
    return 1
}

auto_commit_round_gdim_docs() {
    local round="$1"
    local doc_files=()
    local abs_file=""
    local rel_file=""
    local commit_msg=""
    local pending_flow_files=""
    local file=""

    [ "$AUTO_COMMIT_GDIM_DOCS" -eq 1 ] || return 0
    [ "$DRY_RUN" -eq 0 ] || return 0

    abs_file="$(resolve_phase_file_for_round "scope" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="$(resolve_phase_file_for_round "design" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="$(resolve_phase_file_for_round "plan" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="$(resolve_phase_file_for_round "execute-log" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="$(resolve_phase_file_for_round "summary" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="$(resolve_phase_file_for_round "gap-analysis" "$round")"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }
    abs_file="${WORKFLOW_DIR_ABS}/99-final-report.md"
    [ -f "$abs_file" ] && { rel_file="$(_to_project_relative_path "$abs_file" || true)"; [ -n "$rel_file" ] && doc_files+=("$rel_file"); }

    # Also include any pending files under this flow directory. This captures:
    # - files created outside the fixed naming list (e.g. 00-intent.md link/copy)
    # - prior-round docs modified in later rounds
    pending_flow_files="$(git -C "$PROJECT_ROOT" diff --name-only --cached -- "$WORKFLOW_DIR" 2>/dev/null || true)"
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        doc_files+=("$file")
    done <<< "$pending_flow_files"

    pending_flow_files="$(git -C "$PROJECT_ROOT" ls-files --others --modified --exclude-standard -- "$WORKFLOW_DIR" 2>/dev/null || true)"
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        doc_files+=("$file")
    done <<< "$pending_flow_files"

    [ "${#doc_files[@]}" -gt 0 ] || return 0

    if ! git -C "$PROJECT_ROOT" add -- "${doc_files[@]}" 2>/dev/null; then
        log_warn "Auto-commit GDIM docs: git add failed, skip this round"
        return 0
    fi

    if git -C "$PROJECT_ROOT" diff --cached --quiet -- "${doc_files[@]}" 2>/dev/null; then
        return 0
    fi

    commit_msg="gdim(${FLOW_SLUG}): R${round} docs checkpoint"
    if git -C "$PROJECT_ROOT" commit -m "$commit_msg" -- "${doc_files[@]}" >/dev/null 2>&1; then
        log_info "Auto-committed GDIM docs: ${commit_msg}"
        append_round_event "$FLOW_SLUG" "$round" "gdim_docs_committed" "message=${commit_msg}"
        append_progress "$FLOW_SLUG" "R${round}: auto-committed GDIM docs"
    else
        log_warn "Auto-commit GDIM docs failed (check git user/email or hooks)"
        append_round_event "$FLOW_SLUG" "$round" "gdim_docs_commit_failed" "message=${commit_msg}"
    fi
}

collect_flow_final_input_files() {
    local round="$1"
    local workflow_base_abs
    local shared_intent_abs
    local r=0
    local gap_file=""

    workflow_base_abs="$(dirname "$WORKFLOW_DIR_ABS")"
    shared_intent_abs="${workflow_base_abs}/00-intent.md"

    if [ -f "$shared_intent_abs" ]; then
        echo "$shared_intent_abs"
    fi
    if [ -f "$INTENT_FILE_ABS" ] && [ "$INTENT_FILE_ABS" != "$shared_intent_abs" ]; then
        echo "$INTENT_FILE_ABS"
    fi

    for ((r=1; r<=round; r++)); do
        gap_file="$(resolve_phase_file_for_round "gap-analysis" "$r")"
        [ -f "$gap_file" ] && echo "$gap_file"
    done
}

build_flow_final_prompt() {
    local round="$1"
    local final_report_file="${WORKFLOW_DIR_ABS}/99-final-report.md"
    local files_list=""
    local input_file=""

    while IFS= read -r input_file; do
        [ -z "$input_file" ] && continue
        files_list="${files_list}- ${input_file}"$'\n'
    done < <(collect_flow_final_input_files "$round")

    if [ -z "$files_list" ]; then
        files_list="- ${WORKFLOW_DIR_ABS}/ (flow 过程目录，至少包含 gap-analysis)\n"
    fi

    cat <<EOF
你正在执行 GDIM 自动化工作流的收敛步骤（Final Report）。

## Final 阶段专用规则
- 本会话只允许执行：\`/gdim-final\`
- 输入文件只允许使用：Intent + 每轮 Gap Analysis
- 必须先逐个读取下方“过程输入文件”，再生成最终报告
- 若有必要，可自行读取其他过程文件补充事实，但无需在输出中枚举这些文件名
- 最终报告必须写入：\`${final_report_file}\`

## 过程输入文件（必须读取）
${files_list}
## 当前上下文
- 流程: ${FLOW_SLUG}
- 收敛轮次: R${round}
- 设计来源文档（外部输入）: ${DESIGN_DOC}
- 工作流目录: ${WORKFLOW_DIR_ABS}
- 涉及模块: ${MODULES}

## 输出要求
- 调用 \`/gdim-final\` 生成本 flow 的最终报告
- 输出文件：\`${final_report_file}\`
- 不要再开启新一轮 scope/design/plan/execute/summary/gap
EOF
}

run_flow_final_stage() {
    local round="$1"
    local final_prompt=""
    local final_log=""
    local final_exit=0

    final_prompt="$(build_flow_final_prompt "$round")"
    if [ -n "${TASK_DIR:-}" ]; then
        final_log="${TASK_DIR}/logs/${FLOW_SLUG}-R${round}-final.log"
    else
        final_log="${SCRIPT_DIR}/../automation-logs/${FLOW_SLUG}-R${round}-final.log"
    fi

    append_round_event "$FLOW_SLUG" "$round" "final_stage_started" "flow=${FLOW_SLUG}"
    append_progress "$FLOW_SLUG" "R${round}: running gdim-final stage"
    export CURRENT_STAGE="final"
    invoke_runner "$final_prompt" "$final_log" || final_exit=$?
    export CURRENT_STAGE=""

    if [ "$final_exit" -ne 0 ]; then
        append_round_event "$FLOW_SLUG" "$round" "final_stage_failed" "exit=${final_exit}"
        append_progress "$FLOW_SLUG" "R${round}: gdim-final failed (exit=${final_exit})"
        return $final_exit
    fi

    # gdim-final runs after per-round auto-commit point; commit final artifacts
    # (notably 99-final-report.md) to keep workspace clean for next flow.
    auto_commit_round_gdim_docs "$round"

    append_round_event "$FLOW_SLUG" "$round" "final_stage_completed" "flow=${FLOW_SLUG}"
    append_progress "$FLOW_SLUG" "R${round}: gdim-final completed"
    return 0
}

readonly GDIM_STAGE_ORDER="scope design plan execute summary gap"

stage_index_of() {
    local target="$1"
    local idx=0
    local stage=""
    for stage in $GDIM_STAGE_ORDER; do
        if [ "$stage" = "$target" ]; then
            echo "$idx"
            return 0
        fi
        idx=$((idx + 1))
    done
    echo "-1"
    return 1
}

default_phase_file_for_round() {
    local phase="$1"
    local round="$2"
    case "$phase" in
        scope)        echo "${WORKFLOW_DIR_ABS}/00-scope-definition.round${round}.md" ;;
        design)       echo "${WORKFLOW_DIR_ABS}/01-design.round${round}.md" ;;
        plan)         echo "${WORKFLOW_DIR_ABS}/02-plan.round${round}.md" ;;
        summary)      echo "${WORKFLOW_DIR_ABS}/05-execution-summary.round${round}.md" ;;
        gap|gap-analysis) echo "${WORKFLOW_DIR_ABS}/03-gap-analysis.round${round}.md" ;;
        execute-log)  echo "${WORKFLOW_DIR_ABS}/04-execution-log.round${round}.md" ;;
        *)            echo "${WORKFLOW_DIR_ABS}/${phase}.round${round}.md" ;;
    esac
}

resolve_phase_file_for_round() {
    local phase="$1"
    local round="$2"
    local found=""
    found=$(_find_gdim_phase_file "$WORKFLOW_DIR_ABS" "$round" "$phase" 2>/dev/null || true)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    default_phase_file_for_round "$phase" "$round"
}

_add_missing_file_if_absent() {
    local path="$1"
    local var_name="$2"
    if [ ! -f "$path" ]; then
        eval "$var_name+=(\"\$path\")"
    fi
}

validate_stage_required_inputs() {
    local stage="$1"
    local round="$2"
    local workflow_base_abs
    workflow_base_abs="$(dirname "$WORKFLOW_DIR_ABS")"
    local shared_intent_abs="${workflow_base_abs}/00-intent.md"
    local flow_intent_abs="$INTENT_FILE_ABS"
    local scope_file
    local design_file
    local plan_file
    local summary_file
    local prev_gap_file_required
    local missing_files=()
    local item=""

    scope_file="$(resolve_phase_file_for_round "scope" "$round")"
    design_file="$(resolve_phase_file_for_round "design" "$round")"
    plan_file="$(resolve_phase_file_for_round "plan" "$round")"
    summary_file="$(resolve_phase_file_for_round "summary" "$round")"

    case "$stage" in
        scope)
            _add_missing_file_if_absent "$flow_intent_abs" missing_files
            if [ "$round" -gt 1 ]; then
                prev_gap_file_required="$(resolve_phase_file_for_round "gap-analysis" "$((round - 1))")"
                _add_missing_file_if_absent "$prev_gap_file_required" missing_files
            fi
            ;;
        design)
            _add_missing_file_if_absent "$flow_intent_abs" missing_files
            _add_missing_file_if_absent "$DESIGN_DOC_ABS" missing_files
            ;;
        plan)
            _add_missing_file_if_absent "$flow_intent_abs" missing_files
            _add_missing_file_if_absent "$design_file" missing_files
            ;;
        execute)
            _add_missing_file_if_absent "$flow_intent_abs" missing_files
            _add_missing_file_if_absent "$plan_file" missing_files
            ;;
        summary)
            _add_missing_file_if_absent "$design_file" missing_files
            _add_missing_file_if_absent "$plan_file" missing_files
            ;;
        gap)
            _add_missing_file_if_absent "$flow_intent_abs" missing_files
            _add_missing_file_if_absent "$design_file" missing_files
            _add_missing_file_if_absent "$summary_file" missing_files
            ;;
        *)
            ;;
    esac

    # Optional shared intent check: when present in workflow, enforce readability.
    if [ -e "$shared_intent_abs" ] && [ ! -f "$shared_intent_abs" ]; then
        _add_missing_file_if_absent "$shared_intent_abs" missing_files
    fi

    if [ "${#missing_files[@]}" -eq 0 ]; then
        return 0
    fi

    log_error "Missing required input files for stage=${stage}, round=R${round}:"
    for item in "${missing_files[@]}"; do
        log_error "  - ${item}"
    done

    local missing_joined
    missing_joined="$(IFS=','; echo "${missing_files[*]}")"
    append_round_event "$FLOW_SLUG" "$round" "stage_input_missing" "stage=${stage};files=${missing_joined}"
    append_progress "$FLOW_SLUG" "R${round}: stage=${stage} missing required inputs (${missing_joined})"
    return 1
}

# --- Helper: Stage A human confirmation (ack file + TTY fallback) ---
ACK_POLL_INTERVAL=10   # seconds between ack file checks
ACK_TIMEOUT=1800       # 30 minutes default

stage_a_confirm() {
    if [ "$STAGE" != "A" ] || [ "$DRY_RUN" -ne 0 ]; then
        return 0
    fi

    local wf
    wf=$(create_waiting_marker "$FLOW_SLUG" "$round")
    local af
    af=$(ack_file "$FLOW_SLUG" "$round")

    log_info "[STAGE-A] Round R${round} completed. Waiting for human confirmation..."
    log_info "[STAGE-A] Review logs: ${LOG_DIR}/${FLOW_SLUG}-R${round}-*.log"
    log_info "[STAGE-A] To approve: touch ${af}"

    # If TTY is actually usable, also accept ENTER
    if _tty_usable; then
        log_info "[STAGE-A] Or press ENTER in terminal to continue, Ctrl+C to abort."
        local elapsed=0
        while [ "$elapsed" -lt "$ACK_TIMEOUT" ]; do
            if check_ack_exists "$FLOW_SLUG" "$round"; then
                log_info "[STAGE-A] Ack file detected, continuing."
                cleanup_ack_files "$FLOW_SLUG" "$round"
                return 0
            fi
            if read -r -t "$ACK_POLL_INTERVAL" < /dev/tty 2>/dev/null; then
                log_info "[STAGE-A] ENTER received, continuing."
                cleanup_ack_files "$FLOW_SLUG" "$round"
                return 0
            fi
            elapsed=$((elapsed + ACK_POLL_INTERVAL))
        done
    else
        # Headless/CI mode: poll ack file only
        log_info "[STAGE-A] No usable TTY, polling for ack file (timeout=${ACK_TIMEOUT}s)..."
        local elapsed=0
        while [ "$elapsed" -lt "$ACK_TIMEOUT" ]; do
            if check_ack_exists "$FLOW_SLUG" "$round"; then
                log_info "[STAGE-A] Ack file detected, continuing."
                cleanup_ack_files "$FLOW_SLUG" "$round"
                return 0
            fi
            sleep "$ACK_POLL_INTERVAL"
            elapsed=$((elapsed + ACK_POLL_INTERVAL))
        done
    fi

    # Timeout reached
    log_error "[STAGE-A] Ack timeout (${ACK_TIMEOUT}s) for R${round}. Marking BLOCKED."
    append_progress "$FLOW_SLUG" "R${round}: BLOCKED (Stage A ack timeout)"
    cleanup_ack_files "$FLOW_SLUG" "$round"
    exit 1
}

# --- Main loop ---
# Resume from last attempted round if state exists (breakpoint recovery)
# Dry-run always starts from R1 to preview the full flow
if [ "$DRY_RUN" -eq 0 ]; then
    _saved_round=$(get_round_field "$FLOW_SLUG" "current_round" 2>/dev/null || echo "0")
    if [ "$_saved_round" -gt 1 ] && [ "$_saved_round" -le "$MAX_ROUNDS" ]; then
        round=$_saved_round
        log_info "Resuming from R${round} (breakpoint recovery from round-state.json)"
    else
        round=1
    fi
    stall_count=$(get_round_field "$FLOW_SLUG" "stall_count" 2>/dev/null || echo "0")
else
    round=1
    stall_count=0
fi
LAST_COMMIT_COUNT=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")

log_section "Starting rounds for flow: ${FLOW_SLUG} (max=${MAX_ROUNDS}, stage=${STAGE}, start=R${round})"

while [ "$round" -le "$MAX_ROUNDS" ]; do
    export CURRENT_ROUND="$round"
    log_info "--- Round R${round} for ${FLOW_SLUG} ---"
    set_round_field "$FLOW_SLUG" "current_round" "$round"
    append_round_event "$FLOW_SLUG" "$round" "round_started" "stage=${STAGE};max_rounds=${MAX_ROUNDS}"

    # Phase-granular checkpoint resume:
    # If this round already has phase state, continue from first non-passed phase.
    resume_phase=""
    resume_skip_runner=0
    if has_phase_checkpoint "$FLOW_SLUG" "$round"; then
        for _phase in scope design plan execute summary gap; do
            _status=$(get_phase_status "$FLOW_SLUG" "$round" "$_phase")
            if [ "$_status" != "passed" ]; then
                resume_phase="$_phase"
                break
            fi
        done
        if [ -n "$resume_phase" ]; then
            log_info "Phase-resume checkpoint for R${round}: start from ${resume_phase}"
        else
            resume_skip_runner=1
            log_info "Phase-resume checkpoint for R${round}: all phases passed"
            log_info "Skipping runner due phase checkpoint and resuming from quality gates"
            append_round_event "$FLOW_SLUG" "$round" "runner_skipped_by_resume" "reason=all_phases_passed"
        fi
    fi

    # Audit: record start time + baseline commit for path whitelist
    round_start=$(date '+%Y-%m-%dT%H:%M:%S')
    set_round_field "$FLOW_SLUG" "startAt" "\"${round_start}\""
    BASELINE_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")

    # 1. Find previous gap file (for R2+)
    prev_gap_file=""
    if [ "$round" -gt 1 ]; then
        prev_round=$((round - 1))
        prev_gap_file=$(find_latest_gap_file "$WORKFLOW_DIR_ABS" "$prev_round")
        log_info "Previous gap file: ${prev_gap_file:-none}"
    fi

    # 2. Stage-by-stage session prompts (one conversation per GDIM phase)
    local_progress=$(progress_file "$FLOW_SLUG")
    stage_start_index=0
    if [ -n "$resume_phase" ]; then
        stage_start_index=$(stage_index_of "$resume_phase")
        if [ "$stage_start_index" -lt 0 ]; then
            log_warn "Unknown resume phase=${resume_phase}, fallback to scope"
            stage_start_index=0
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        stage_index=0
        for stage_name in $GDIM_STAGE_ORDER; do
            if [ "$stage_index" -lt "$stage_start_index" ]; then
                stage_index=$((stage_index + 1))
                continue
            fi

            stage_template_file="${TEMPLATE_DIR}/${stage_name}.md.tpl"
            prompt=$(build_prompt \
                "$stage_template_file" \
                "$INTENT_FILE_ABS" \
                "$FLOW_SLUG" \
                "$round" \
                "$DESIGN_DOC" \
                "$WORKFLOW_DIR" \
                "$MODULES" \
                "$local_progress" \
                "$prev_gap_file" \
                "$stage_name" \
                "$REFACTOR_POSTURE" \
                "$resume_phase")
            log_info "[DRY-RUN] Would send stage=${stage_name} prompt (${#prompt} chars) to runner=${RUNNER}"
            stage_index=$((stage_index + 1))
        done
        log_info "[DRY-RUN] Skipping execution"
        round=$((round + 1))
        # If this was the last round in dry-run, exit 0 (not 2)
        if [ "$round" -gt "$MAX_ROUNDS" ]; then
            log_info "[DRY-RUN] All rounds previewed successfully"
            exit 0
        fi
        continue
    fi

    # 3. Execute stage sessions with timeout
    agent_exit=0
    if [ "$resume_skip_runner" -eq 1 ]; then
        append_progress "$FLOW_SLUG" "R${round}: runner skipped by phase checkpoint"
    else
        stage_index=0
        stage_input_blocked=0
        for stage_name in $GDIM_STAGE_ORDER; do
            if [ "$stage_index" -lt "$stage_start_index" ]; then
                stage_index=$((stage_index + 1))
                continue
            fi

            if ! validate_stage_required_inputs "$stage_name" "$round"; then
                stage_input_blocked=1
                agent_exit=1
                break
            fi

            stage_template_file="${TEMPLATE_DIR}/${stage_name}.md.tpl"
            prompt=$(build_prompt \
                "$stage_template_file" \
                "$INTENT_FILE_ABS" \
                "$FLOW_SLUG" \
                "$round" \
                "$DESIGN_DOC" \
                "$WORKFLOW_DIR" \
                "$MODULES" \
                "$local_progress" \
                "$prev_gap_file" \
                "$stage_name" \
                "$REFACTOR_POSTURE" \
                "$resume_phase")

            if [ -n "${TASK_DIR:-}" ]; then
                local_log="${TASK_DIR}/logs/${FLOW_SLUG}-R${round}-${stage_name}.log"
            else
                local_log="${SCRIPT_DIR}/../automation-logs/${FLOW_SLUG}-R${round}-${stage_name}.log"
            fi

            export CURRENT_STAGE="$stage_name"
            append_round_event "$FLOW_SLUG" "$round" "stage_started" "stage=${stage_name}"
            invoke_runner "$prompt" "$local_log" || agent_exit=$?

            if [ "$agent_exit" -ne 0 ]; then
                log_warn "Agent exited with code ${agent_exit} during stage=${stage_name}"
                append_round_event "$FLOW_SLUG" "$round" "stage_failed" "stage=${stage_name};exit=${agent_exit}"
                append_progress "$FLOW_SLUG" "R${round}: stage=${stage_name} exit=${agent_exit}"
                break
            fi

            log_info "Stage ${stage_name} completed successfully"
            append_round_event "$FLOW_SLUG" "$round" "stage_completed" "stage=${stage_name}"
            append_progress "$FLOW_SLUG" "R${round}: stage=${stage_name} completed"

            # Keep phase checkpoints up-to-date so interruptions can resume from next stage.
            detect_phase_status "$FLOW_SLUG" "$round" "$WORKFLOW_DIR_ABS" "$BASELINE_COMMIT"
            phase_summary=$(get_phase_summary "$FLOW_SLUG" "$round")
            append_progress "$FLOW_SLUG" "R${round} phases (mid-round): ${phase_summary}"

            stage_index=$((stage_index + 1))
        done
        export CURRENT_STAGE=""

        if [ "$stage_input_blocked" -eq 1 ]; then
            log_error "Stage input precheck failed, marking BLOCKED"
            append_round_event "$FLOW_SLUG" "$round" "round_blocked" "reason=stage_input_missing"
            append_progress "$FLOW_SLUG" "R${round}: BLOCKED (stage input precheck failed)"
            exit 1
        fi

        if [ "$agent_exit" -eq 0 ]; then
            append_progress "$FLOW_SLUG" "R${round}: all stage sessions completed"
        fi
    fi

    # 3.5 Auto-commit GDIM round docs (default on)
    auto_commit_round_gdim_docs "$round"

    # 4. Quality gates (external validation)
    log_info "Running quality gates..."
    if [ "$SKIP_TESTS" -eq 1 ]; then
        log_info "Quality gates configured with --skip-tests (mvn test will be skipped)"
    fi
    append_round_event "$FLOW_SLUG" "$round" "quality_gates_started" "modules=${MODULES};allowed_paths=${ALLOWED_PATHS}"
    cd "$PROJECT_ROOT"
    gate_result=0
    run_quality_gates "$FLOW_SLUG" "$round" "$MODULES" "$WORKFLOW_DIR_ABS" "$ALLOWED_PATHS" "$BASELINE_COMMIT" || gate_result=$?

    log_info "Validation results:"
    printf '%b' "$VALIDATE_RESULT" | while IFS= read -r line; do log_info "  $line"; done
    append_round_event "$FLOW_SLUG" "$round" "quality_gates_finished" "gate_result=${gate_result};failure_type=${FAILURE_TYPE};gate_failures=${GATE_FAILURES}"
    append_progress "$FLOW_SLUG" "R${round} validation:"
    printf '%b' "$VALIDATE_RESULT" >> "$(progress_file "$FLOW_SLUG")"

    # Audit: record gate results
    round_end=$(date '+%Y-%m-%dT%H:%M:%S')
    set_round_field "$FLOW_SLUG" "endAt" "\"${round_end}\""
    set_round_field "$FLOW_SLUG" "gate_failures" "$GATE_FAILURES"
    set_round_field "$FLOW_SLUG" "failure_type" "\"${FAILURE_TYPE}\""

    # Audit: changed files and diff stat (from round baseline)
    if [ -n "$BASELINE_COMMIT" ]; then
        diff_stat=$(git -C "$PROJECT_ROOT" diff --stat "$BASELINE_COMMIT" HEAD 2>/dev/null | tail -1 || echo "none")
        changed_files=$(git -C "$PROJECT_ROOT" diff --name-only "$BASELINE_COMMIT" HEAD 2>/dev/null | wc -l | awk '{print $1}' || echo "0")
    else
        diff_stat=$(git -C "$PROJECT_ROOT" diff --stat HEAD~1 HEAD 2>/dev/null | tail -1 || echo "none")
        changed_files=$(git -C "$PROJECT_ROOT" diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | awk '{print $1}' || echo "0")
    fi
    set_round_field "$FLOW_SLUG" "changed_files" "$changed_files"
    set_round_field "$FLOW_SLUG" "diff_stat" "\"${diff_stat}\""

    # Audit: detect and record phase completion status
    detect_phase_status "$FLOW_SLUG" "$round" "$WORKFLOW_DIR_ABS" "$BASELINE_COMMIT"
    phase_summary=$(get_phase_summary "$FLOW_SLUG" "$round")
    log_info "Phase status: ${phase_summary}"
    append_progress "$FLOW_SLUG" "R${round} phases: ${phase_summary}"

    # 5. Directed retry on gate failure
    if [ "$gate_result" -ne 0 ] && [ -n "$FAILURE_TYPE" ]; then
        local_retry_count=0
        local_retry_max=0
        retry_total_count=0
        retry_compile_count=0
        retry_test_count=0
        retry_malformed_count=0
        retry_commit_count=0
        while true; do
            case "$FAILURE_TYPE" in
                compile_failed)
                    local_retry_max=$RETRY_COMPILE
                    local_retry_count=$retry_compile_count
                    ;;
                test_failed)
                    local_retry_max=$RETRY_TEST
                    local_retry_count=$retry_test_count
                    ;;
                malformed_output)
                    local_retry_max=$RETRY_MALFORMED
                    local_retry_count=$retry_malformed_count
                    ;;
                commit_missing)
                    local_retry_max=$RETRY_COMMIT
                    local_retry_count=$retry_commit_count
                    ;;
                path_violation)
                    local_retry_max=0  # handled by allowed_paths auto-expand
                    local_retry_count=0
                    ;;
                *)
                    local_retry_max=0
                    local_retry_count=0
                    ;;
            esac

            if [ "$gate_result" -eq 0 ] || [ -z "$FAILURE_TYPE" ]; then
                break
            fi

            if [ "$FAILURE_TYPE" = "path_violation" ]; then
                expand_allowed_paths_for_path_violation "$ALLOWED_PATHS" "$VALIDATE_RESULT"
                expanded_allowed_paths="$PATH_EXPANDED_ALLOWED_PATHS"
                expanded_additions="$PATH_EXPAND_ADDITIONS"
                if [ -n "$expanded_additions" ]; then
                    ALLOWED_PATHS="$expanded_allowed_paths"
                    log_warn "Auto-expanded allowed_paths for path_violation: ${expanded_additions}"
                    append_round_event "$FLOW_SLUG" "$round" "path_violation_auto_expanded" "additions=${expanded_additions}"
                    append_progress "$FLOW_SLUG" "R${round}: auto-expand allowed_paths (${expanded_additions})"

                    gate_result=0
                    run_quality_gates "$FLOW_SLUG" "$round" "$MODULES" "$WORKFLOW_DIR_ABS" "$ALLOWED_PATHS" "$BASELINE_COMMIT" || gate_result=$?
                    log_info "Validation after path whitelist auto-expansion:"
                    printf '%b' "$VALIDATE_RESULT" | while IFS= read -r line; do log_info "  $line"; done
                    append_round_event "$FLOW_SLUG" "$round" "path_violation_revalidated" "gate_result=${gate_result};failure_type=${FAILURE_TYPE}"
                    [ "$gate_result" -eq 0 ] && log_info "Path whitelist auto-expansion succeeded"
                    continue
                fi

                log_warn "Path violation detected but no new paths parsed; bypassing BLOCK by default policy"
                append_round_event "$FLOW_SLUG" "$round" "path_violation_bypassed" "reason=no_new_paths_parsed"
                append_progress "$FLOW_SLUG" "R${round}: path_violation bypassed (no new paths parsed)"
                gate_result=0
                FAILURE_TYPE=""
                break
            fi

            if [ "$local_retry_count" -ge "$local_retry_max" ]; then
                break
            fi

            local_retry_count=$((local_retry_count + 1))
            retry_total_count=$((retry_total_count + 1))
            case "$FAILURE_TYPE" in
                compile_failed)   retry_compile_count=$local_retry_count ;;
                test_failed)      retry_test_count=$local_retry_count ;;
                malformed_output) retry_malformed_count=$local_retry_count ;;
                commit_missing)   retry_commit_count=$local_retry_count ;;
            esac
            log_warn "Retry ${local_retry_count}/${local_retry_max} for ${FAILURE_TYPE}"
            append_round_event "$FLOW_SLUG" "$round" "retry_started" "retry=${local_retry_count}/${local_retry_max};failure_type=${FAILURE_TYPE}"
            append_progress "$FLOW_SLUG" "R${round}: retry ${local_retry_count}/${local_retry_max} (${FAILURE_TYPE})"

            # Build retry prompt — pass the right error log per failure type
            error_log_for_retry="$COMPILE_ERROR_LOG"
            if [ "$FAILURE_TYPE" = "test_failed" ]; then
                error_log_for_retry="$TEST_ERROR_LOG"
            fi
            retry_prompt=$(build_retry_prompt \
                "$FAILURE_TYPE" "$round" "$MODULES" \
                "$error_log_for_retry" "$VALIDATE_RESULT")

            if [ -n "${TASK_DIR:-}" ]; then
                retry_log="${TASK_DIR}/logs/${FLOW_SLUG}-R${round}-retry-${FAILURE_TYPE}-${local_retry_count}.log"
            else
                retry_log="${SCRIPT_DIR}/../automation-logs/${FLOW_SLUG}-R${round}-retry-${FAILURE_TYPE}-${local_retry_count}.log"
            fi
            retry_exit=0
            export CURRENT_STAGE="retry-${FAILURE_TYPE}-${local_retry_count}"
            invoke_runner "$retry_prompt" "$retry_log" || retry_exit=$?
            export CURRENT_STAGE=""

            # Re-run gates (with baseline)
            gate_result=0
            run_quality_gates "$FLOW_SLUG" "$round" "$MODULES" "$WORKFLOW_DIR_ABS" "$ALLOWED_PATHS" "$BASELINE_COMMIT" || gate_result=$?
            log_info "Retry validation:"
            printf '%b' "$VALIDATE_RESULT" | while IFS= read -r line; do log_info "  $line"; done
            append_round_event "$FLOW_SLUG" "$round" "retry_finished" "retry=${local_retry_count}/${local_retry_max};gate_result=${gate_result};failure_type=${FAILURE_TYPE}"
            [ "$gate_result" -eq 0 ] && log_info "Retry succeeded — gates now pass"
        done

        # Audit: record retries
        set_round_field "$FLOW_SLUG" "retries" "$retry_total_count"
        set_round_field "$FLOW_SLUG" "retries_compile" "$retry_compile_count"
        set_round_field "$FLOW_SLUG" "retries_test" "$retry_test_count"
        set_round_field "$FLOW_SLUG" "retries_malformed" "$retry_malformed_count"
        set_round_field "$FLOW_SLUG" "retries_commit" "$retry_commit_count"

        # Refresh phase status after retries (Issue #5)
        detect_phase_status "$FLOW_SLUG" "$round" "$WORKFLOW_DIR_ABS" "$BASELINE_COMMIT"
        phase_summary=$(get_phase_summary "$FLOW_SLUG" "$round")
        log_info "Phase status (post-retry): ${phase_summary}"

        # If still failing after retries, mark blocked
        if [ "$gate_result" -ne 0 ] && [ -n "$FAILURE_TYPE" ]; then
            case "$FAILURE_TYPE" in
                compile_failed)
                    local_retry_max=$RETRY_COMPILE
                    local_retry_count=$retry_compile_count
                    ;;
                test_failed)
                    local_retry_max=$RETRY_TEST
                    local_retry_count=$retry_test_count
                    ;;
                malformed_output)
                    local_retry_max=$RETRY_MALFORMED
                    local_retry_count=$retry_malformed_count
                    ;;
                commit_missing)
                    local_retry_max=$RETRY_COMMIT
                    local_retry_count=$retry_commit_count
                    ;;
                path_violation)
                    local_retry_max=0
                    local_retry_count=0
                    ;;
                *)
                    local_retry_max=0
                    local_retry_count=0
                    ;;
            esac
            if [ "$FAILURE_TYPE" = "path_violation" ] || [ "$local_retry_count" -ge "$local_retry_max" ]; then
                log_error "Gate failure persists after ${local_retry_count} retries (${FAILURE_TYPE}), marking BLOCKED"
                append_round_event "$FLOW_SLUG" "$round" "round_blocked" "failure_type=${FAILURE_TYPE};retries=${local_retry_count}"
                append_progress "$FLOW_SLUG" "R${round}: BLOCKED (${FAILURE_TYPE} after ${local_retry_count} retries)"
                exit 1
            fi
        fi
    else
        set_round_field "$FLOW_SLUG" "retries" "0"
        set_round_field "$FLOW_SLUG" "retries_compile" "0"
        set_round_field "$FLOW_SLUG" "retries_test" "0"
        set_round_field "$FLOW_SLUG" "retries_malformed" "0"
        set_round_field "$FLOW_SLUG" "retries_commit" "0"
    fi

    # 6. Parse gap file
    gap_file=$(find_latest_gap_file "$WORKFLOW_DIR_ABS" "$round")
    if [ -n "$gap_file" ]; then
        log_info "Gap file found: ${gap_file}"

        # Audit: extract gap IDs
        gap_ids=$(grep -oE 'G[1-6]-[0-9]+' "$gap_file" 2>/dev/null | sort -u | tr '\n' ',' || echo "")
        set_round_field "$FLOW_SLUG" "gap_ids" "\"${gap_ids}\""

        if gap_fracture_needs_decision "$gap_file"; then
            log_warn "Gap analysis reports fracture needing decision; marking BLOCKED"
            append_round_event "$FLOW_SLUG" "$round" "round_blocked" "reason=fracture_needs_decision"
            append_progress "$FLOW_SLUG" "R${round}: BLOCKED (fracture needs decision)"
            exit 1
        fi

        if no_open_gaps "$gap_file"; then
            # Verify at least one commit exists since baseline before accepting closure
            current_commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
            if [ "$current_commit_count" -le "$LAST_COMMIT_COUNT" ]; then
                if gap_decision_is_final "$gap_file"; then
                    if ! run_flow_final_stage "$round"; then
                        log_error "Final stage failed for ${FLOW_SLUG}, marking BLOCKED"
                        append_round_event "$FLOW_SLUG" "$round" "round_blocked" "reason=final_stage_failed"
                        append_progress "$FLOW_SLUG" "R${round}: BLOCKED (final stage failed)"
                        exit 1
                    fi
                    log_warn "No new commit in R${round}, but accepting explicit final decision"
                    log_info "All gaps closed for ${FLOW_SLUG}"
                    append_round_event "$FLOW_SLUG" "$round" "round_completed" "reason=final_decision_without_new_commit"
                    append_progress "$FLOW_SLUG" "R${round}: ALL GAPS CLOSED (final decision, no new commit)"
                    exit 0
                fi
                log_warn "Gap claims closed but no new commit since baseline — treating as stall"
                append_progress "$FLOW_SLUG" "R${round}: gap-closed without commit, suspicious"
            else
                if gap_decision_is_final "$gap_file"; then
                    if ! run_flow_final_stage "$round"; then
                        log_error "Final stage failed for ${FLOW_SLUG}, marking BLOCKED"
                        append_round_event "$FLOW_SLUG" "$round" "round_blocked" "reason=final_stage_failed"
                        append_progress "$FLOW_SLUG" "R${round}: BLOCKED (final stage failed)"
                        exit 1
                    fi
                fi
                log_info "All gaps closed for ${FLOW_SLUG}"
                append_round_event "$FLOW_SLUG" "$round" "round_completed" "reason=all_gaps_closed"
                append_progress "$FLOW_SLUG" "R${round}: ALL GAPS CLOSED"
                exit 0
            fi
        fi

        if has_blocked_flag "$gap_file"; then
            log_warn "BLOCKED detected in gap analysis"
            append_round_event "$FLOW_SLUG" "$round" "round_blocked" "reason=gap_file_blocked"
            append_progress "$FLOW_SLUG" "R${round}: BLOCKED"
            exit 1
        fi
    else
        log_warn "No gap file found for R${round}"
    fi

    # 7. Stall detection
    current_commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
    if [ "$current_commit_count" -le "$LAST_COMMIT_COUNT" ]; then
        stall_count=$((stall_count + 1))
        log_warn "No new commits (stall_count=${stall_count})"
    else
        stall_count=0
        LAST_COMMIT_COUNT="$current_commit_count"
    fi
    set_round_field "$FLOW_SLUG" "stall_count" "$stall_count"

    if [ "$stall_count" -ge "$STALL_LIMIT" ]; then
        log_error "Stalled: ${STALL_LIMIT} consecutive rounds with no progress"
        append_round_event "$FLOW_SLUG" "$round" "round_stalled" "stall_count=${stall_count};stall_limit=${STALL_LIMIT}"
        append_progress "$FLOW_SLUG" "R${round}: STALLED"
        exit 3
    fi

    # 8. Stage A: human confirmation gate
    stage_a_confirm

    round=$((round + 1))
done

log_warn "Reached max rounds (${MAX_ROUNDS}) for ${FLOW_SLUG}"
append_round_event "$FLOW_SLUG" "${CURRENT_ROUND:-$MAX_ROUNDS}" "max_rounds_reached" "max_rounds=${MAX_ROUNDS}"
append_progress "$FLOW_SLUG" "Reached max rounds (${MAX_ROUNDS})"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] All rounds previewed successfully"
    exit 0
fi
exit 2
