#!/usr/bin/env bash
# Prompt builder: assembles per-round prompts from templates
# Usage: source automation/lib/prompt-builder.sh

build_prompt() {
    local template_file="$1"
    local rules_file="$2"
    local intent_file="$3"
    local flow_slug="$4"
    local round="$5"
    local design_doc="$6"
    local workflow_dir="$7"
    local modules="$8"
    local progress_file="$9"
    local prev_gaps_file="${10}"

    if [ ! -f "$template_file" ]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi

    # Read template
    local output
    output=$(cat "$template_file")

    # Read rules content (optional — skill-driven mode may not use rules file)
    local rules_content=""
    if [ -n "$rules_file" ] && [ -f "$rules_file" ]; then
        rules_content=$(cat "$rules_file")
    fi

    # Read intent content
    local intent_content=""
    if [ -f "$intent_file" ]; then
        intent_content=$(cat "$intent_file")
    fi

    # Read progress content
    local progress_content="(首轮，无历史进展)"
    if [ -f "$progress_file" ] && [ -s "$progress_file" ]; then
        progress_content=$(cat "$progress_file")
    fi

    # Read previous gaps
    local prev_gaps=""
    if [ "$round" -gt 1 ] && [ -n "$prev_gaps_file" ] && [ -f "$prev_gaps_file" ]; then
        prev_gaps=$(cat "$prev_gaps_file")
    else
        prev_gaps="(首轮，无上一轮 Gap)"
    fi

    # Build round task section based on round number
    local workflow_base
    workflow_base=$(dirname "$workflow_dir")
    local round_task
    if [ "$round" -eq 1 ]; then
        round_task="1. 共享 Intent 已存在于 ${workflow_base}/00-intent.md，无需重建。如果本流程目录下没有 00-intent.md，创建一个符号链接或副本指向共享 Intent。
2. 调用 /gdim-scope 定义 R1 Scope（≤3 scope items, ≤3 core classes）
3. 依次调用 /gdim-design → /gdim-plan → /gdim-execute → /gdim-summary → /gdim-gap 完成全流程"
    else
        round_task="1. 读取上一轮 Gap Analysis，选择未关闭的 gap 作为本轮 scope
2. 调用 /gdim-scope 定义本轮 Scope
3. 依次调用 /gdim-design → /gdim-plan → /gdim-execute → /gdim-summary → /gdim-gap 完成全流程"
    fi

    # Perform substitutions using awk to handle multiline content safely
    # Write content blocks to temp files for awk processing
    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "$rules_content" > "$tmp_dir/rules"
    echo "$intent_content" > "$tmp_dir/intent"
    echo "$progress_content" > "$tmp_dir/progress"
    echo "$prev_gaps" > "$tmp_dir/gaps"
    echo "$round_task" > "$tmp_dir/task"

    # Simple sed replacements for single-line values
    output=$(echo "$output" | sed "s|{{FLOW_SLUG}}|${flow_slug}|g")
    output=$(echo "$output" | sed "s|{{ROUND}}|${round}|g")
    output=$(echo "$output" | sed "s|{{DESIGN_DOC}}|${design_doc}|g")
    output=$(echo "$output" | sed "s|{{WORKFLOW_DIR}}|${workflow_dir}|g")
    output=$(echo "$output" | sed "s|{{MODULES}}|${modules}|g")

    # For multiline blocks, use awk
    local result="$output"
    for placeholder in GDIM_RULES INTENT_CONTENT PROGRESS_CONTENT PREV_GAPS ROUND_TASK; do
        local content_file
        case "$placeholder" in
            GDIM_RULES)       content_file="$tmp_dir/rules" ;;
            INTENT_CONTENT)   content_file="$tmp_dir/intent" ;;
            PROGRESS_CONTENT) content_file="$tmp_dir/progress" ;;
            PREV_GAPS)        content_file="$tmp_dir/gaps" ;;
            ROUND_TASK)       content_file="$tmp_dir/task" ;;
        esac
        result=$(awk -v placeholder="{{${placeholder}}}" -v file="$content_file" '
            {
                idx = index($0, placeholder)
                if (idx > 0) {
                    prefix = substr($0, 1, idx - 1)
                    printf "%s", prefix
                    while ((getline line < file) > 0) print line
                    close(file)
                } else {
                    print
                }
            }
        ' <<< "$result")
    done

    rm -rf "$tmp_dir"
    echo "$result"
}

# Find the latest gap analysis file for a flow (supports both naming conventions)
find_latest_gap_file() {
    local workflow_dir="$1"
    local prev_round="$2"
    find "$workflow_dir" \( -name "*gap-analysis*round${prev_round}*" -o -name "*gap-analysis*.round${prev_round}.*" -o -name "*round${prev_round}*gap-analysis*" \) -type f 2>/dev/null | sort | tail -1
}

# Build a directed retry prompt from a failure-specific template.
# Args: failure_type, round, modules, error_log, missing_files
build_retry_prompt() {
    local failure_type="$1"
    local round="$2"
    local modules="$3"
    local error_log="$4"
    local missing_files="$5"

    # Normalize: underscores → hyphens to match template filenames
    local template_name="${failure_type//_/-}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local template_file="${script_dir}/templates/retry/${template_name}.md"

    if [ ! -f "$template_file" ]; then
        echo "ERROR: Retry template not found: $template_file" >&2
        return 1
    fi

    local output
    output=$(cat "$template_file")
    output=$(echo "$output" | sed "s|{{ROUND}}|${round}|g")
    output=$(echo "$output" | sed "s|{{MODULES}}|${modules}|g")

    # Inject error log or missing files via temp file + awk
    local tmp_dir
    tmp_dir=$(mktemp -d)

    if [ "$template_name" = "compile-failed" ]; then
        echo "$error_log" > "$tmp_dir/content"
        output=$(awk -v placeholder="{{COMPILE_ERROR_LOG}}" -v file="$tmp_dir/content" '
            { idx = index($0, placeholder); if (idx > 0) { prefix = substr($0, 1, idx - 1); printf "%s", prefix; while ((getline line < file) > 0) print line; close(file) } else { print } }
        ' <<< "$output")
    elif [ "$template_name" = "test-failed" ]; then
        echo "$error_log" > "$tmp_dir/content"
        output=$(awk -v placeholder="{{TEST_ERROR_LOG}}" -v file="$tmp_dir/content" '
            { idx = index($0, placeholder); if (idx > 0) { prefix = substr($0, 1, idx - 1); printf "%s", prefix; while ((getline line < file) > 0) print line; close(file) } else { print } }
        ' <<< "$output")
    elif [ "$template_name" = "malformed-output" ]; then
        echo "$missing_files" > "$tmp_dir/content"
        output=$(awk -v placeholder="{{MISSING_FILES}}" -v file="$tmp_dir/content" '
            { idx = index($0, placeholder); if (idx > 0) { prefix = substr($0, 1, idx - 1); printf "%s", prefix; while ((getline line < file) > 0) print line; close(file) } else { print } }
        ' <<< "$output")
    fi

    rm -rf "$tmp_dir"
    echo "$output"
}
