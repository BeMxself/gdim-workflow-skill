#!/usr/bin/env bash
# sync-automation.sh
# Compares reference scripts against a target directory and reports/copies differences.
# Designed to be called by Claude Code skill — no interactive shell input.
#
# Usage: sync-automation.sh <reference-dir> <target-dir> [--auto-copy]
#
# Exit codes: 0=all in sync, 1=differences found
# Output: one line per file with status [OK], [COPY], [DIFF], [WARN]
set -euo pipefail

REFERENCE_DIR="${1:?Usage: sync-automation.sh <reference-dir> <target-dir> [--auto-copy]}"
TARGET_DIR="${2:?Usage: sync-automation.sh <reference-dir> <target-dir> [--auto-copy]}"
AUTO_COPY="${3:-}"

# Resolve to absolute paths
if [[ "$REFERENCE_DIR" != /* ]]; then
    REFERENCE_DIR="$(cd "$REFERENCE_DIR" && pwd)"
fi
if [[ "$TARGET_DIR" != /* ]]; then
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
fi

# Files to synchronize
FILES=(
    "run-gdim-flows.sh"
    "run-gdim-round.sh"
    "lib/log.sh"
    "lib/state.sh"
    "lib/validate.sh"
    "lib/prompt-builder.sh"
    "templates/round-prompt.md.tpl"
    "templates/gdim-rules-injection.md"
    "templates/retry/compile-failed.md"
    "templates/retry/test-failed.md"
    "templates/retry/malformed-output.md"
)

NEED_CONFIRM=0

for f in "${FILES[@]}"; do
    target="${TARGET_DIR}/${f}"
    source="${REFERENCE_DIR}/${f}"

    if [ ! -f "$source" ]; then
        echo "[WARN] Reference file missing: $f"
        continue
    fi

    if [ ! -f "$target" ]; then
        if [ "$AUTO_COPY" = "--auto-copy" ]; then
            mkdir -p "$(dirname "$target")"
            cp "$source" "$target"
            [ -x "$source" ] && chmod +x "$target"
            echo "[COPY] $f (created)"
        else
            echo "[MISS] $f (does not exist in target)"
            NEED_CONFIRM=1
        fi
    elif ! diff -q "$target" "$source" >/dev/null 2>&1; then
        if [ "$AUTO_COPY" = "--auto-copy" ]; then
            cp "$source" "$target"
            [ -x "$source" ] && chmod +x "$target"
            echo "[COPY] $f (replaced)"
        else
            echo "[DIFF] $f"
            NEED_CONFIRM=1
        fi
    else
        echo "[OK] $f"
    fi
done

exit ${NEED_CONFIRM}
