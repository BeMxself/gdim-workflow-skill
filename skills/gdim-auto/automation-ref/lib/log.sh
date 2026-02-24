#!/usr/bin/env bash
# Structured logging for GDIM automation
# Usage: source automation/ai-coding/lib/log.sh

if [ -n "${GDIM_LOG_DIR:-}" ]; then
    readonly LOG_DIR="$GDIM_LOG_DIR"
else
    readonly LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/automation-logs"
fi

_log() {
    local level="$1"; shift
    local flow="${CURRENT_FLOW:-global}"
    local round="${CURRENT_ROUND:-0}"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[${ts}] [${level}] [${flow}/R${round}] $*"
    echo "$msg" >&2
    # Append to flow-specific log if flow is set
    if [ "$flow" != "global" ]; then
        local log_file="${LOG_DIR}/${flow}.log"
        mkdir -p "$(dirname "$log_file")"
        echo "$msg" >> "$log_file"
    fi
    # Always append to master log
    mkdir -p "$LOG_DIR"
    echo "$msg" >> "${LOG_DIR}/master.log"
}

log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }
log_debug() {
    if [ "${GDIM_DEBUG:-0}" = "1" ]; then
        _log "DEBUG" "$@"
    fi
}

log_section() {
    _log "INFO" "========================================"
    _log "INFO" "$@"
    _log "INFO" "========================================"
}
