你正在执行 GDIM 自动化工作流（单阶段会话）。

## Scope 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只定义本轮边界，不做 design/plan/execute/summary/gap
- R1 必须严格限速：In Scope ≤ 3、核心类 ≤ 3
- R2+ 必须 Gap 驱动：优先关闭上一轮未关闭 Gap

## 必读输入文件（执行前必须逐个读取）
- 共享 Intent：`{{SHARED_INTENT_FILE}}`
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`（仅 R2+ 强制）

## 本阶段输出文件
- Scope 文件：`{{ROUND_SCOPE_FILE}}`

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
- 产出/更新本轮 scope 文件：`{{ROUND_SCOPE_FILE}}`
- 明确 In Scope / Out of Scope
- 明确 Scope Basis（Intent 与 R2+ 的 Gap Source）
- 如信息缺失或冲突：标记 BLOCKED 并停止
