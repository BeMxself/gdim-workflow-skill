你正在执行 GDIM 自动化工作流（单阶段会话）。

## Design 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做设计，不做 plan/execute/summary/gap
- 设计必须绑定 scope，不得擅自扩 scope
- 设计修改必须可追溯到 Intent 与 Gap（R2+）

## 必读输入文件（执行前必须逐个读取）
- 共享 Intent：`{{SHARED_INTENT_FILE}}`
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`（仅 R2+ 强制）
- 设计来源文档（外部输入）：`{{DESIGN_SOURCE_FILE}}`

## 本阶段输出文件
- Design 文件：`{{ROUND_DESIGN_FILE}}`

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
- 产出/更新本轮 design 文件：`{{ROUND_DESIGN_FILE}}`
- 明确设计边界、关键接口、约束与风险
- Design 中必须声明驱动的 GAP-ID（若有）
- 头部必须声明 `round` / `driven_by` / `scope` / `external_refs`（如有）
- 如信息缺失或冲突：标记 BLOCKED 并停止
