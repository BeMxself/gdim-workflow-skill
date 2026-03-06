#!/usr/bin/env bash
# Prompt builder: assembles per-round prompts from templates
# Usage: source automation/ai-coding/lib/prompt-builder.sh

_stage_skill_command() {
    local stage_name="$1"
    local round="$2"
    case "$stage_name" in
        scope)   echo "/gdim-scope ${round}" ;;
        design)  echo "/gdim-design ${round}" ;;
        plan)    echo "/gdim-plan ${round}" ;;
        execute) echo "/gdim-execute ${round}" ;;
        summary) echo "/gdim-summary ${round}" ;;
        gap)     echo "/gdim-gap ${round}" ;;
        *)       echo "/gdim-${stage_name} ${round}" ;;
    esac
}

build_prompt() {
    local template_file="$1"
    local intent_file="$2"
    local flow_slug="$3"
    local round="$4"
    local design_doc="$5"
    local workflow_dir="$6"
    local modules="$7"
    local progress_file="$8"
    local prev_gaps_file="${9}"
    local stage_name="${10:-scope}"
    local resume_phase="${11:-}"

    if [ ! -f "$template_file" ]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi

    # Read template
    local output
    output=$(cat "$template_file")

    # Build stage task section
    local workflow_base
    workflow_base=$(dirname "$workflow_dir")
    local shared_intent_file="${workflow_base}/00-intent.md"
    local flow_intent_file="$intent_file"
    local round_scope_file="${workflow_dir}/00-scope-definition.round${round}.md"
    local round_design_file="${workflow_dir}/01-design.round${round}.md"
    local round_plan_file="${workflow_dir}/02-plan.round${round}.md"
    local round_gap_file="${workflow_dir}/03-gap-analysis.round${round}.md"
    local round_exec_log_file="${workflow_dir}/04-execution-log.round${round}.md"
    local round_summary_file="${workflow_dir}/05-execution-summary.round${round}.md"
    local design_source_file="$design_doc"
    local prev_gap_file_ref="(R1 无上一轮 Gap 文件)"
    local next_round=$((round + 1))
    if [ "$round" -gt 1 ]; then
        if [ -n "$prev_gaps_file" ]; then
            prev_gap_file_ref="$prev_gaps_file"
        else
            prev_gap_file_ref="${workflow_dir}/03-gap-analysis.round$((round - 1)).md"
        fi
    fi
    local stage_cmd
    stage_cmd=$(_stage_skill_command "$stage_name" "$round")
    local resume_note="本轮无 phase 断点恢复，按当前阶段正常执行。"
    if [ -n "$resume_phase" ]; then
        resume_note="检测到本轮 phase 断点恢复：已通过阶段不要重做，只补齐当前阶段及后续阶段。"
    fi
    local round_task
    case "$stage_name" in
        scope)
            if [ "$round" -eq 1 ]; then
                round_task="1. 先读取共享 Intent 与流程 Intent，锁定本轮边界与不可突破约束。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，定义 R${round} Scope（建议 In Scope ≤3、核心类 ≤3）。
4. 如存在未决问题，按“可选输入读取闸门”按需读取设计来源文档 ${design_doc} 消歧。
5. 当前会话到此结束，不要执行 design/plan/execute/summary/gap。"
            else
                round_task="1. 先读取共享 Intent、流程 Intent 与上一轮 Gap Analysis，按未关闭 Gap 收敛本轮范围。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，定义 R${round} Scope。
4. 如存在未决问题，按“可选输入读取闸门”按需读取设计来源文档 ${design_doc} 消歧。
5. 当前会话到此结束，不要执行后续阶段。"
            fi
            ;;
        design)
            round_task="1. 先读取流程 Intent 与设计来源文档（${design_doc}），基于目标与外部约束产出设计。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，输出本轮设计并声明驱动的 GAP-ID（若有）。
4. 如有未决问题，按“可选输入读取闸门”按需读取 scope/上一轮 gap/共享 intent 消歧。
5. 当前会话到此结束，不要执行 plan/execute/summary/gap。"
            ;;
        plan)
            round_task="1. 先读取流程 Intent 与本轮 design 产物，确保计划与目标、约束保持一致。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，生成可执行计划。
4. 如有未决问题，按“可选输入读取闸门”按需读取 scope/gap/设计来源文档做风险消歧，但不替代 design→plan 主链路。
5. 当前会话到此结束，不要执行 execute/summary/gap。"
            ;;
        execute)
            round_task="1. 先读取流程 Intent 与本轮 plan 产物，按计划实现并对齐目标边界。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，并运行 \`mvn compile -pl ${modules} -am\`（若 modules 为空则按实际项目约束处理）。
4. 如有未决问题，按“可选输入读取闸门”按需读取 design/scope/上一轮 gap 辅助决策，但不得擅自扩 scope。
5. 当前会话到此结束，不要执行 summary/gap。"
            ;;
        summary)
            round_task="1. 读取本轮 design/plan、实际代码变更与执行结果证据（含可用执行日志）。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，输出事实性 summary：禁止评价、辩护、改进建议与 gap 结论。
4. summary 至少覆盖：Completed、Deviations from Plan、Discoveries、Temporary Decisions、Blockers、Files Changed。
5. 如有未决问题，按“可选输入读取闸门”按需读取执行日志/测试输出/上一轮 gap 消歧。
6. 当前会话到此结束，不要执行 gap。"
            ;;
        gap)
            round_task="1. 读取 intent/design/summary（必要时补充 scope 与上一轮 gap）。
2. ${resume_note}
3. 仅调用 ${stage_cmd}，输出两层 gap-analysis：Round Gap（本轮偏差）+ Intent Coverage（整体覆盖）。
4. 每个 Gap 必须包含分类（G1-G6）、Severity、Expected/Actual、Impact 与闭环策略。
5. Exit Decision 必须遵循：仅当“无 High Severity Gap 且 Intent 覆盖完成”时可给 FINAL_REPORT。
6. 如有未决问题，按“可选输入读取闸门”按需读取 scope/上一轮 gap/其他过程文件消歧。
7. gap-analysis 末尾必须追加机器可解析决策行（单独一行）：
   - \`GDIM_EXIT_DECISION: CONTINUE\`
   - \`GDIM_EXIT_DECISION: FINAL_REPORT\`
   - \`GDIM_EXIT_DECISION: BLOCKED\`
8. 本轮结束前必须提交代码变更：检查并提交当前任务目录（\`${workflow_base}\`）之外的代码文件。
9. 必须执行 \`git add\` + \`git commit\`，提交信息由你基于本轮改动生成，且需包含标记：\`gdim(${flow_slug}): R${round}\`。"
            ;;
        *)
            round_task="1. ${resume_note}
2. 仅调用 ${stage_cmd} 并完成当前阶段。
3. 当前会话结束，不要执行其他阶段。"
            ;;
    esac

    # Perform substitutions using awk to handle multiline content safely
    # Write content blocks to temp files for awk processing
    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "$round_task" > "$tmp_dir/task"

    # Simple sed replacements for single-line values
    output=$(echo "$output" | sed "s|{{FLOW_SLUG}}|${flow_slug}|g")
    output=$(echo "$output" | sed "s|{{ROUND}}|${round}|g")
    output=$(echo "$output" | sed "s|{{DESIGN_DOC}}|${design_doc}|g")
    output=$(echo "$output" | sed "s|{{WORKFLOW_DIR}}|${workflow_dir}|g")
    output=$(echo "$output" | sed "s|{{MODULES}}|${modules}|g")
    output=$(echo "$output" | sed "s|{{CURRENT_STAGE}}|${stage_name}|g")
    output=$(echo "$output" | sed "s|{{CURRENT_STAGE_CMD}}|${stage_cmd}|g")
    output=$(echo "$output" | sed "s|{{FLOW_INTENT_FILE}}|${flow_intent_file}|g")
    output=$(echo "$output" | sed "s|{{SHARED_INTENT_FILE}}|${shared_intent_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_SCOPE_FILE}}|${round_scope_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_DESIGN_FILE}}|${round_design_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_PLAN_FILE}}|${round_plan_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_GAP_FILE}}|${round_gap_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_EXEC_LOG_FILE}}|${round_exec_log_file}|g")
    output=$(echo "$output" | sed "s|{{ROUND_SUMMARY_FILE}}|${round_summary_file}|g")
    output=$(echo "$output" | sed "s|{{DESIGN_SOURCE_FILE}}|${design_source_file}|g")
    output=$(echo "$output" | sed "s|{{PREV_GAP_FILE}}|${prev_gap_file_ref}|g")
    output=$(echo "$output" | sed "s|{{NEXT_ROUND}}|${next_round}|g")

    # For multiline blocks, use awk
    local result="$output"
    for placeholder in ROUND_TASK; do
        local content_file
        case "$placeholder" in
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
    output=$(echo "$output" | sed "s|{{FLOW_SLUG}}|${FLOW_SLUG:-unknown-flow}|g")

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
