你正在执行 GDIM 自动化工作流（单阶段会话）。

## Gap 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做 Gap Analysis，不回头重做 scope/design/plan/execute/summary
- Gap 分类遵循 G1-G6，结论需可追溯到本轮事实
- Gap Analysis 是本轮唯一出口

## 必读输入文件（执行前必须逐个读取）
- 共享 Intent：`{{SHARED_INTENT_FILE}}`
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Summary：`{{ROUND_SUMMARY_FILE}}`
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`

## 本阶段输出文件
- Gap Analysis 文件：`{{ROUND_GAP_FILE}}`

## 当前上下文
- 流程: {{FLOW_SLUG}}
- 轮次: R{{ROUND}}
- 阶段: {{CURRENT_STAGE}}
- 设计文档: {{DESIGN_DOC}}
- 工作流目录: {{WORKFLOW_DIR}}
- 涉及模块: {{MODULES}}

## Intent（不可变基线）
{{INTENT_CONTENT}}

## 上一轮进展
{{PROGRESS_CONTENT}}

## 上一轮 Gap（仅 R2+ 参考）
{{PREV_GAPS}}

## 当前阶段任务
{{ROUND_TASK}}

## 输出要求
- 产出/更新本轮 gap-analysis 文件：`{{ROUND_GAP_FILE}}`
- 明确哪些 Gap 已关闭，哪些需进入下一轮
- Exit Decision 必须给出继续/收敛结论（下一轮参考：R{{NEXT_ROUND}}）
- 文末必须追加机器可解析决策行（单独一行）：
  - `GDIM_EXIT_DECISION: CONTINUE`
  - `GDIM_EXIT_DECISION: FINAL_REPORT`
  - `GDIM_EXIT_DECISION: BLOCKED`
