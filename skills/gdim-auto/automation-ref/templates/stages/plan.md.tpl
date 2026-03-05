你正在执行 GDIM 自动化工作流（单阶段会话）。

## Plan 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做计划，不做 execute/summary/gap
- 计划必须可执行、可验证、可回滚
- 任务拆分应与 scope/design 一一对应

## 必读输入文件（执行前必须逐个读取）
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`

## 本阶段输出文件
- Plan 文件：`{{ROUND_PLAN_FILE}}`

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
- 产出/更新本轮 plan 文件：`{{ROUND_PLAN_FILE}}`
- 每项任务包含：目标、变更点、验证命令、完成判据
- 明确 design→plan 的映射关系（哪些设计项对应哪些步骤）
- 禁止在 plan 阶段直接改代码（除必要脚手架说明外）
- 如信息缺失或冲突：标记 BLOCKED 并停止
