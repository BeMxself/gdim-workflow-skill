#!/usr/bin/env bash
set -euo pipefail

# Level 1: GDIM Flow Dispatcher
# Orchestrates multiple GDIM flows in dependency order.
#
# Usage: ./automation/ai-coding/run-gdim-flows.sh --task-dir DIR [--from N] [--only N] [--dry-run]
#          [--runner NAME|--executor NAME] [--runner-cmd CMD] [--kiro-agent NAME]
#          [--stall-limit N] [--skip-tests]
#          [--auto-commit-gdim-docs|--no-auto-commit-gdim-docs]
# Exit codes: 0=all done, 1=blocked, 2=max rounds, 3=stalled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AUTOMATION_ROOT="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse arguments ---
FROM_FLOW=0
ONLY_FLOW=0
DRY_RUN=0
UNBLOCK_SLUG=""
STAGE_OVERRIDE=""
SKIP_CLEAN_CHECK=0
TASK_DIR=""
RUNNER_OVERRIDE=""
RUNNER_CMD_OVERRIDE=""
KIRO_AGENT_OVERRIDE=""
STALL_LIMIT_OVERRIDE=""
AUTO_COMMIT_GDIM_DOCS_OVERRIDE=""
SKIP_TESTS_RAW="${GDIM_SKIP_TESTS:-0}"
SKIP_TESTS=0

case "${SKIP_TESTS_RAW}" in
    1|true|TRUE|yes|YES|on|ON) SKIP_TESTS=1 ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --task-dir) TASK_DIR="$2"; shift 2 ;;
        --from)    FROM_FLOW="$2"; shift 2 ;;
        --only)    ONLY_FLOW="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --unblock) UNBLOCK_SLUG="$2"; shift 2 ;;
        --stage)   STAGE_OVERRIDE="$2"; shift 2 ;;
        --skip-clean-check) SKIP_CLEAN_CHECK=1; shift ;;
        --skip-tests) SKIP_TESTS=1; shift ;;
        --runner|--executor) RUNNER_OVERRIDE="$2"; shift 2 ;;
        --runner-cmd) RUNNER_CMD_OVERRIDE="$2"; shift 2 ;;
        --kiro-agent) KIRO_AGENT_OVERRIDE="$2"; shift 2 ;;
        --stall-limit) STALL_LIMIT_OVERRIDE="$2"; shift 2 ;;
        --auto-commit-gdim-docs) AUTO_COMMIT_GDIM_DOCS_OVERRIDE="1"; shift ;;
        --no-auto-commit-gdim-docs) AUTO_COMMIT_GDIM_DOCS_OVERRIDE="0"; shift ;;
        -h|--help)
            echo "Usage: $0 --task-dir DIR [--from N] [--only N] [--dry-run] [--unblock SLUG] [--stage A|B|C] [--skip-clean-check] [--skip-tests] [--stall-limit N] [--auto-commit-gdim-docs|--no-auto-commit-gdim-docs] [--runner NAME|--executor NAME] [--runner-cmd CMD] [--kiro-agent NAME]"
            echo "  --task-dir DIR       Task directory (required; config/state/logs read from here)"
            echo "  --from N             Start from flow number N"
            echo "  --only N             Run only flow number N"
            echo "  --dry-run            Print what would be done without executing"
            echo "  --unblock SLUG       Reset a blocked flow to pending"
            echo "  --stage X            Override stage for all flows (A=semi-auto, B=full-auto, C=convergence)"
            echo "  --skip-clean-check   Skip clean workspace preflight check"
            echo "  --skip-tests         Skip mvn test gate (or set GDIM_SKIP_TESTS=1)"
            echo "  --stall-limit N      Stall threshold (consecutive rounds without commit, default 5)"
            echo "  --auto-commit-gdim-docs     Auto-commit per-round GDIM docs (default)"
            echo "  --no-auto-commit-gdim-docs  Disable per-round GDIM docs auto-commit"
            echo "  --runner NAME        Override runner for all flows (claude/codex/kiro/custom)"
            echo "  --executor NAME      Alias of --runner"
            echo "  --runner-cmd CMD     Override runner command for all flows"
            echo "  --kiro-agent NAME    Override kiro agent for all flows"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Require --task-dir ---
if [ -z "$TASK_DIR" ]; then
    echo "ERROR: --task-dir is required. Use run.sh in your task directory or pass --task-dir explicitly." >&2
    echo "Usage: $0 --task-dir DIR [--from N] [--only N] [--dry-run]" >&2
    exit 1
fi
# Resolve to absolute path and export env vars for lib/state.sh and lib/log.sh
TASK_DIR="$(cd "$TASK_DIR" && pwd)"
export GDIM_STATE_DIR="${TASK_DIR}/state"
export GDIM_LOG_DIR="${TASK_DIR}/logs"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/state.sh
source "$SCRIPT_DIR/lib/state.sh"

# --- Load config ---
CONFIG_FILE="${TASK_DIR}/config/flows.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed." >&2
    exit 1
fi

WORKFLOW_BASE=$(jq -r '.workflow_dir' "$CONFIG_FILE")
DESIGN_DOC=$(jq -r '.design_doc' "$CONFIG_FILE")
FLOW_COUNT=$(jq '.flows | length' "$CONFIG_FILE")

# --- Initialize state ---
init_flows_state

# --- Handle --unblock ---
if [ -n "$UNBLOCK_SLUG" ]; then
    current_status=$(get_flow_status "$UNBLOCK_SLUG")
    if [ "$current_status" = "blocked" ]; then
        set_flow_status "$UNBLOCK_SLUG" "pending"
        log_info "Unblocked flow: ${UNBLOCK_SLUG} (was: blocked → pending)"
        # Record human intervention
        append_progress "$UNBLOCK_SLUG" "HUMAN: unblocked via --unblock flag"
    else
        log_warn "Flow ${UNBLOCK_SLUG} is not blocked (status: ${current_status}), no action taken"
    fi
    if [ "$FROM_FLOW" -eq 0 ] && [ "$ONLY_FLOW" -eq 0 ]; then
        exit 0
    fi
fi

log_section "GDIM Flow Dispatcher started (flows=${FLOW_COUNT})"

# --- Main loop ---
for (( i=0; i<FLOW_COUNT; i++ )); do
    flow_id=$(jq -r ".flows[$i].id" "$CONFIG_FILE")
    flow_slug=$(jq -r ".flows[$i].slug" "$CONFIG_FILE")
    intent_file=$(jq -r ".flows[$i].intent_file" "$CONFIG_FILE")
    max_rounds=$(jq -r ".flows[$i].max_rounds" "$CONFIG_FILE")
    modules=$(jq -r ".flows[$i].modules | join(\",\")" "$CONFIG_FILE")
    depends_on=$(jq -r ".flows[$i].depends_on | map(tostring) | join(\",\")" "$CONFIG_FILE")
    allowed_paths=$(jq -r ".flows[$i].allowed_paths | join(\",\")" "$CONFIG_FILE")
    flow_stage=$(jq -r ".flows[$i].stage // \"B\"" "$CONFIG_FILE")
    flow_runner=$(jq -r ".flows[$i].runner // .flows[$i].executor // empty" "$CONFIG_FILE")
    flow_runner_cmd=$(jq -r ".flows[$i].runner_cmd // empty" "$CONFIG_FILE")
    flow_kiro_agent=$(jq -r ".flows[$i].kiro_agent // empty" "$CONFIG_FILE")

    # Stage override from CLI takes precedence
    if [ -n "$STAGE_OVERRIDE" ]; then
        flow_stage="$STAGE_OVERRIDE"
    fi

    # Filter: --from
    if [ "$FROM_FLOW" -gt 0 ] && [ "$flow_id" -lt "$FROM_FLOW" ]; then
        log_info "Skipping flow #${flow_id} (before --from ${FROM_FLOW})"
        continue
    fi

    # Filter: --only
    if [ "$ONLY_FLOW" -gt 0 ] && [ "$flow_id" -ne "$ONLY_FLOW" ]; then
        continue
    fi

    # Check status
    status=$(get_flow_status "$flow_slug")
    if [ "$status" = "done" ]; then
        log_info "Flow #${flow_id} ${flow_slug}: already done, skipping"
        continue
    fi

    # Check dependencies
    deps_met=1
    if [ -n "$depends_on" ]; then
        IFS=',' read -ra dep_ids <<< "$depends_on"
        for dep_id in "${dep_ids[@]}"; do
            # Find the slug for this dependency id
            dep_slug=$(jq -r ".flows[] | select(.id == ${dep_id}) | .slug" "$CONFIG_FILE")
            dep_status=$(get_flow_status "$dep_slug")
            if [ "$dep_status" != "done" ]; then
                log_info "Flow #${flow_id} ${flow_slug}: dependency #${dep_id} (${dep_slug}) not done (${dep_status}), skipping"
                deps_met=0
                break
            fi
        done
    fi
    if [ "$deps_met" -eq 0 ]; then
        continue
    fi

    # Run flow
    log_section "Starting flow #${flow_id}: ${flow_slug}"
    if [ "$DRY_RUN" -eq 0 ]; then
        set_flow_status "$flow_slug" "running"
    fi

    workflow_dir="${WORKFLOW_BASE}/${flow_slug}"

    # Resolve intent file path
    intent_file_path="${TASK_DIR}/intents/${intent_file}"

    selected_runner="$RUNNER_OVERRIDE"
    if [ -z "$selected_runner" ]; then
        selected_runner="$flow_runner"
    fi
    selected_runner_cmd="$RUNNER_CMD_OVERRIDE"
    if [ -z "$selected_runner_cmd" ]; then
        selected_runner_cmd="$flow_runner_cmd"
    fi
    selected_kiro_agent="$KIRO_AGENT_OVERRIDE"
    if [ -z "$selected_kiro_agent" ]; then
        selected_kiro_agent="$flow_kiro_agent"
    fi

    exit_code=0
    round_cmd=(
        "$SCRIPT_DIR/run-gdim-round.sh"
        --flow-slug "$flow_slug"
        --max-rounds "$max_rounds"
        --workflow-dir "$workflow_dir"
        --intent-file "$intent_file_path"
        --design-doc "$DESIGN_DOC"
        --modules "$modules"
        --allowed-paths "$allowed_paths"
        --stage "$flow_stage"
        --task-dir "$TASK_DIR"
    )

    if [ "$DRY_RUN" -eq 1 ]; then
        round_cmd+=(--dry-run)
    fi
    if [ "$SKIP_CLEAN_CHECK" -eq 1 ]; then
        round_cmd+=(--skip-clean-check)
    fi
    if [ "$SKIP_TESTS" -eq 1 ]; then
        round_cmd+=(--skip-tests)
    fi
    if [ -n "$selected_runner" ]; then
        round_cmd+=(--runner "$selected_runner")
    fi
    if [ -n "$selected_runner_cmd" ]; then
        round_cmd+=(--runner-cmd "$selected_runner_cmd")
    fi
    if [ -n "$selected_kiro_agent" ]; then
        round_cmd+=(--kiro-agent "$selected_kiro_agent")
    fi
    if [ -n "$STALL_LIMIT_OVERRIDE" ]; then
        round_cmd+=(--stall-limit "$STALL_LIMIT_OVERRIDE")
    fi
    if [ "$AUTO_COMMIT_GDIM_DOCS_OVERRIDE" = "1" ]; then
        round_cmd+=(--auto-commit-gdim-docs)
    elif [ "$AUTO_COMMIT_GDIM_DOCS_OVERRIDE" = "0" ]; then
        round_cmd+=(--no-auto-commit-gdim-docs)
    fi

    "${round_cmd[@]}" || exit_code=$?

    # Dry-run: skip state updates entirely
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Flow #${flow_id} ${flow_slug}: preview exit=${exit_code}"
        continue
    fi

    case $exit_code in
        0)
            set_flow_status "$flow_slug" "done"
            log_info "Flow #${flow_id} ${flow_slug}: completed successfully"
            ;;
        1)
            set_flow_status "$flow_slug" "blocked"
            log_error "BLOCKED: Flow #${flow_id} ${flow_slug} requires human intervention"
            exit 1
            ;;
        2)
            set_flow_status "$flow_slug" "blocked"
            log_error "MAX ROUNDS: Flow #${flow_id} ${flow_slug} reached round limit"
            exit 2
            ;;
        3)
            set_flow_status "$flow_slug" "blocked"
            log_error "STALLED: Flow #${flow_id} ${flow_slug} no progress"
            exit 3
            ;;
        *)
            set_flow_status "$flow_slug" "blocked"
            log_error "UNEXPECTED: Flow #${flow_id} ${flow_slug} exit=${exit_code}"
            exit "$exit_code"
            ;;
    esac
done

log_section "All flows completed successfully"
exit 0
