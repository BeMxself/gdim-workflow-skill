#!/usr/bin/env bash
set -euo pipefail

# Level 2: GDIM Round Dispatcher
# Runs iterative GDIM rounds for a single flow until gaps are closed or limits hit.
#
# Usage: ./automation/ai-coding/run-gdim-round.sh \
#          --flow-slug SLUG --max-rounds N \
#          --workflow-dir DIR --intent-file FILE \
#          --design-doc DOC --modules MODS \
#          [--allowed-paths PATHS] [--stage A|B|C] [--dry-run] [--timeout MIN]
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
        --task-dir)       TASK_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$FLOW_SLUG" ] || [ -z "$WORKFLOW_DIR" ]; then
    echo "Usage: $0 --flow-slug SLUG --workflow-dir DIR [options]" >&2
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

export CURRENT_FLOW="$FLOW_SLUG"

# Stall threshold: Stage C is tighter (1 round), others 2
STALL_LIMIT=2
if [ "$STAGE" = "C" ]; then
    STALL_LIMIT=1
fi

# Load retry limits from config
if [ -n "${TASK_DIR:-}" ]; then
    CONFIG_FILE="${TASK_DIR}/config/flows.json"
else
    CONFIG_FILE="${SCRIPT_DIR}/config/flows.json"
fi
RETRY_COMPILE=$(jq -r '.retry_limits.compile_failed // 2' "$CONFIG_FILE" 2>/dev/null || echo 2)
RETRY_TEST=$(jq -r '.retry_limits.test_failed // 2' "$CONFIG_FILE" 2>/dev/null || echo 2)
RETRY_MALFORMED=$(jq -r '.retry_limits.malformed_output // 1' "$CONFIG_FILE" 2>/dev/null || echo 1)

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
TEMPLATE_FILE="${SCRIPT_DIR}/templates/round-prompt.md.tpl"
RULES_FILE="${SCRIPT_DIR}/templates/gdim-rules-injection.md"

mkdir -p "$WORKFLOW_DIR_ABS"
init_round_state "$FLOW_SLUG"

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
    for _cmd in claude timeout jq; do
        if ! command -v "$_cmd" &>/dev/null; then
            log_error "Required command not found: $_cmd"
            exit 1
        fi
    done
fi

# --- Helper: invoke claude CLI ---
invoke_claude() {
    local prompt_text="$1"
    local log_file="$2"
    mkdir -p "$(dirname "$log_file")"
    log_info "Invoking claude CLI (timeout=${TIMEOUT_MINUTES}m)..."
    local exit_code=0
    echo "$prompt_text" | timeout "${TIMEOUT_MINUTES}m" claude -p \
        --dangerously-skip-permissions \
        --allowedTools "Bash,Edit,Read,Write,Glob,Grep,Task,Skill" \
        > "$log_file" 2>&1 || exit_code=$?
    return $exit_code
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
    log_info "[STAGE-A] Review logs: ${LOG_DIR}/${FLOW_SLUG}-R${round}.log"
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

    # 2. Build prompt
    local_progress=$(progress_file "$FLOW_SLUG")
    prompt=$(build_prompt \
        "$TEMPLATE_FILE" \
        "$RULES_FILE" \
        "$INTENT_FILE_ABS" \
        "$FLOW_SLUG" \
        "$round" \
        "$DESIGN_DOC" \
        "$WORKFLOW_DIR" \
        "$MODULES" \
        "$local_progress" \
        "$prev_gap_file")

    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would send prompt (${#prompt} chars) to claude"
        log_info "[DRY-RUN] Skipping execution"
        round=$((round + 1))
        # If this was the last round in dry-run, exit 0 (not 2)
        if [ "$round" -gt "$MAX_ROUNDS" ]; then
            log_info "[DRY-RUN] All rounds previewed successfully"
            exit 0
        fi
        continue
    fi

    # 3. Execute Claude CLI with timeout
    if [ -n "${TASK_DIR:-}" ]; then
        local_log="${TASK_DIR}/logs/${FLOW_SLUG}-R${round}.log"
    else
        local_log="${SCRIPT_DIR}/../automation-logs/${FLOW_SLUG}-R${round}.log"
    fi
    agent_exit=0
    invoke_claude "$prompt" "$local_log" || agent_exit=$?

    if [ "$agent_exit" -ne 0 ]; then
        log_warn "Agent exited with code ${agent_exit}"
        append_progress "$FLOW_SLUG" "R${round}: agent exit=${agent_exit}"
    else
        log_info "Agent completed successfully"
        append_progress "$FLOW_SLUG" "R${round}: agent completed"
    fi

    # 4. Quality gates (external validation)
    log_info "Running quality gates..."
    cd "$PROJECT_ROOT"
    gate_result=0
    run_quality_gates "$FLOW_SLUG" "$round" "$MODULES" "$WORKFLOW_DIR_ABS" "$ALLOWED_PATHS" "$BASELINE_COMMIT" || gate_result=$?

    log_info "Validation results:"
    printf '%b' "$VALIDATE_RESULT" | while IFS= read -r line; do log_info "  $line"; done
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
        changed_files=$(git -C "$PROJECT_ROOT" diff --name-only "$BASELINE_COMMIT" HEAD 2>/dev/null | wc -l | xargs || echo "0")
    else
        diff_stat=$(git -C "$PROJECT_ROOT" diff --stat HEAD~1 HEAD 2>/dev/null | tail -1 || echo "none")
        changed_files=$(git -C "$PROJECT_ROOT" diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | xargs || echo "0")
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
        case "$FAILURE_TYPE" in
            compile_failed)    local_retry_max=$RETRY_COMPILE ;;
            test_failed)       local_retry_max=$RETRY_TEST ;;
            malformed_output)  local_retry_max=$RETRY_MALFORMED ;;
            path_violation)    local_retry_max=0 ;;  # no auto-retry for path violations
        esac

        while [ "$local_retry_count" -lt "$local_retry_max" ]; do
            local_retry_count=$((local_retry_count + 1))
            log_warn "Retry ${local_retry_count}/${local_retry_max} for ${FAILURE_TYPE}"
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
                retry_log="${TASK_DIR}/logs/${FLOW_SLUG}-R${round}-retry${local_retry_count}.log"
            else
                retry_log="${SCRIPT_DIR}/../automation-logs/${FLOW_SLUG}-R${round}-retry${local_retry_count}.log"
            fi
            retry_exit=0
            invoke_claude "$retry_prompt" "$retry_log" || retry_exit=$?

            # Re-run gates (with baseline)
            gate_result=0
            run_quality_gates "$FLOW_SLUG" "$round" "$MODULES" "$WORKFLOW_DIR_ABS" "$ALLOWED_PATHS" "$BASELINE_COMMIT" || gate_result=$?
            log_info "Retry validation:"
            printf '%b' "$VALIDATE_RESULT" | while IFS= read -r line; do log_info "  $line"; done

            if [ "$gate_result" -eq 0 ] || [ -z "$FAILURE_TYPE" ]; then
                log_info "Retry succeeded — gates now pass"
                break
            fi
        done

        # Audit: record retries
        set_round_field "$FLOW_SLUG" "retries" "$local_retry_count"

        # Refresh phase status after retries (Issue #5)
        detect_phase_status "$FLOW_SLUG" "$round" "$WORKFLOW_DIR_ABS" "$BASELINE_COMMIT"
        phase_summary=$(get_phase_summary "$FLOW_SLUG" "$round")
        log_info "Phase status (post-retry): ${phase_summary}"

        # If still failing after retries, mark blocked
        if [ "$gate_result" -ne 0 ] && [ -n "$FAILURE_TYPE" ]; then
            if [ "$FAILURE_TYPE" = "path_violation" ] || [ "$local_retry_count" -ge "$local_retry_max" ]; then
                log_error "Gate failure persists after ${local_retry_count} retries (${FAILURE_TYPE}), marking BLOCKED"
                append_progress "$FLOW_SLUG" "R${round}: BLOCKED (${FAILURE_TYPE} after ${local_retry_count} retries)"
                exit 1
            fi
        fi
    else
        set_round_field "$FLOW_SLUG" "retries" "0"
    fi

    # 6. Parse gap file
    gap_file=$(find_latest_gap_file "$WORKFLOW_DIR_ABS" "$round")
    if [ -n "$gap_file" ]; then
        log_info "Gap file found: ${gap_file}"

        # Audit: extract gap IDs
        gap_ids=$(grep -oE 'G[1-6]-[0-9]+' "$gap_file" 2>/dev/null | sort -u | tr '\n' ',' || echo "")
        set_round_field "$FLOW_SLUG" "gap_ids" "\"${gap_ids}\""

        if no_open_gaps "$gap_file"; then
            # Verify at least one commit exists since baseline before accepting closure
            current_commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
            if [ "$current_commit_count" -le "$LAST_COMMIT_COUNT" ]; then
                log_warn "Gap claims closed but no new commit since baseline — treating as stall"
                append_progress "$FLOW_SLUG" "R${round}: gap-closed without commit, suspicious"
            else
                log_info "All gaps closed for ${FLOW_SLUG}"
                append_progress "$FLOW_SLUG" "R${round}: ALL GAPS CLOSED"
                exit 0
            fi
        fi

        if has_blocked_flag "$gap_file"; then
            log_warn "BLOCKED detected in gap analysis"
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
        append_progress "$FLOW_SLUG" "R${round}: STALLED"
        exit 3
    fi

    # 8. Stage A: human confirmation gate
    stage_a_confirm

    round=$((round + 1))
done

log_warn "Reached max rounds (${MAX_ROUNDS}) for ${FLOW_SLUG}"
append_progress "$FLOW_SLUG" "Reached max rounds (${MAX_ROUNDS})"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] All rounds previewed successfully"
    exit 0
fi
exit 2
