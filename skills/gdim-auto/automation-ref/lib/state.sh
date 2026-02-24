#!/usr/bin/env bash
# State file read/write for GDIM automation (requires jq)
# Usage: source automation/ai-coding/lib/state.sh

if [ -n "${GDIM_STATE_DIR:-}" ]; then
    readonly STATE_DIR="$GDIM_STATE_DIR"
else
    readonly STATE_DIR="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/state"
fi

# Safe jq write: validates output before replacing original file
_safe_jq_write() {
    local file="$1"; shift
    # remaining args are jq arguments
    local tmp="${file}.tmp"
    if jq "$@" "$file" > "$tmp" 2>/dev/null; then
        # Validate: tmp must be non-empty valid JSON
        if [ -s "$tmp" ] && jq empty "$tmp" 2>/dev/null; then
            mv "$tmp" "$file"
            return 0
        fi
    fi
    # jq failed or produced invalid output — keep original, remove tmp
    rm -f "$tmp"
    echo "ERROR: jq write failed for $file, original preserved" >&2
    return 1
}

_ensure_jq() {
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required but not installed." >&2
        exit 1
    fi
}

# --- Flows State ---

flows_state_file() {
    echo "${STATE_DIR}/flows-state.json"
}

init_flows_state() {
    _ensure_jq
    local file
    file=$(flows_state_file)
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ]; then
        echo '{}' > "$file"
    fi
}

get_flow_status() {
    local slug="$1"
    _ensure_jq
    jq -r --arg s "$slug" '.[$s] // "pending"' "$(flows_state_file)"
}

set_flow_status() {
    local slug="$1" status="$2"
    _ensure_jq
    local file
    file=$(flows_state_file)
    _safe_jq_write "$file" --arg s "$slug" --arg v "$status" '.[$s] = $v'
}

# --- Round State ---

round_state_file() {
    local slug="$1"
    echo "${STATE_DIR}/${slug}/round-state.json"
}

init_round_state() {
    local slug="$1"
    _ensure_jq
    local file
    file=$(round_state_file "$slug")
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ]; then
        echo '{"current_round":0,"stall_count":0}' > "$file"
    fi
}

get_round_field() {
    local slug="$1" field="$2"
    _ensure_jq
    jq -r --arg f "$field" '.[$f] // 0' "$(round_state_file "$slug")"
}

set_round_field() {
    local slug="$1" field="$2" value="$3"
    _ensure_jq
    local file
    file=$(round_state_file "$slug")
    _safe_jq_write "$file" --arg f "$field" --argjson v "$value" '.[$f] = $v'
}

# --- Progress ---

progress_file() {
    local slug="$1"
    echo "${STATE_DIR}/${slug}/progress.txt"
}

append_progress() {
    local slug="$1"; shift
    local file
    file=$(progress_file "$slug")
    mkdir -p "$(dirname "$file")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$file"
}

# --- Ack Files (Stage A human confirmation) ---

ack_dir() {
    echo "${STATE_DIR}/acks"
}

waiting_file() {
    local slug="$1" round="$2"
    echo "$(ack_dir)/${slug}-R${round}.waiting"
}

ack_file() {
    local slug="$1" round="$2"
    echo "$(ack_dir)/${slug}-R${round}.ack"
}

create_waiting_marker() {
    local slug="$1" round="$2"
    local dir
    dir=$(ack_dir)
    mkdir -p "$dir"
    local wf
    wf=$(waiting_file "$slug" "$round")
    echo "Waiting for human review since $(date '+%Y-%m-%dT%H:%M:%S')" > "$wf"
    echo "$wf"
}

check_ack_exists() {
    local slug="$1" round="$2"
    local af
    af=$(ack_file "$slug" "$round")
    [ -f "$af" ]
}

cleanup_ack_files() {
    local slug="$1" round="$2"
    rm -f "$(waiting_file "$slug" "$round")" "$(ack_file "$slug" "$round")"
}

# --- Task-Level Phase Tracking ---
# Tracks GDIM phases (scope/design/plan/execute/summary/gap) per round.
# States: todo | passed | missing

readonly GDIM_PHASES="scope design plan execute summary gap"

# Detect which GDIM phases produced files for a given round.
# Sets phase status in round-state.json under "phases.R{n}".
detect_phase_status() {
    local slug="$1" round="$2" workflow_dir="$3" baseline_commit="$4"
    _ensure_jq

    local file
    file=$(round_state_file "$slug")

    # Check file-based phases (supports both naming conventions)
    # Convention A (spec): {phase}.round{N}.md  e.g. 00-scope-definition.round1.md
    # Convention B (legacy): *round{N}*{phase}*  e.g. R1-00-scope.md
    local scope_status="missing" design_status="missing" plan_status="missing"
    local summary_status="missing" gap_status="missing" execute_status="missing"

    local _phases=("scope" "design" "plan" "summary" "gap-analysis")
    local _vars=("scope_status" "design_status" "plan_status" "summary_status" "gap_status")
    local _idx
    for _idx in "${!_phases[@]}"; do
        local _ph="${_phases[$_idx]}"
        # shellcheck disable=SC2086
        if ls ${workflow_dir}/*${_ph}*round${round}* 1>/dev/null 2>&1 \
        || ls ${workflow_dir}/*${_ph}*.round${round}.* 1>/dev/null 2>&1 \
        || ls ${workflow_dir}/*round${round}*${_ph}* 1>/dev/null 2>&1; then
            eval "${_vars[$_idx]}=passed"
        fi
    done

    # Execute phase: check if code changes exist (not just GDIM docs)
    if [ -n "$baseline_commit" ]; then
        local code_changes
        code_changes=$(git diff --name-only "$baseline_commit" HEAD 2>/dev/null \
            | grep -v '\.ai-workflows/' | grep -v 'automation/' | head -1 || true)
        if [ -n "$code_changes" ]; then
            execute_status="passed"
        fi
    fi

    # Write phases to round-state.json
    _safe_jq_write "$file" \
       --arg r "R${round}" \
       --arg sc "$scope_status" \
       --arg de "$design_status" \
       --arg pl "$plan_status" \
       --arg ex "$execute_status" \
       --arg su "$summary_status" \
       --arg ga "$gap_status" \
       '.phases[$r] = {scope:$sc, design:$de, plan:$pl, execute:$ex, summary:$su, gap:$ga}'
}

# Get phase status for a specific round and phase
get_phase_status() {
    local slug="$1" round="$2" phase="$3"
    _ensure_jq
    jq -r --arg r "R${round}" --arg p "$phase" \
        '.phases[$r][$p] // "todo"' "$(round_state_file "$slug")"
}

# Get summary of all phases for a round (for logging)
get_phase_summary() {
    local slug="$1" round="$2"
    _ensure_jq
    jq -r --arg r "R${round}" \
        '.phases[$r] // {} | to_entries | map("\(.key)=\(.value)") | join(" ")' \
        "$(round_state_file "$slug")"
}
