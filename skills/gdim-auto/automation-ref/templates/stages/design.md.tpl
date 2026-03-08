你正在执行 GDIM 自动化工作流（单阶段会话）。

## Design 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做设计，不做 plan/execute/summary/gap
- 设计主链路是“流程 Intent + 设计来源文档”
- 不得擅自扩 scope；需要越界时必须显式标记并停止

## 必读输入文件（执行前必须逐个读取）
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 设计来源文档（外部输入）：`{{DESIGN_SOURCE_FILE}}`

## 可选补充输入（仅在必要时读取）
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`
- 共享 Intent：`{{SHARED_INTENT_FILE}}`

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法收敛到单一设计决策”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 重构姿态纪律
{{REFACTOR_DISCIPLINE}}

## 本阶段输出文件
- Design 文件：`{{ROUND_DESIGN_FILE}}`

## 当前上下文
- 流程: {{FLOW_SLUG}}
- 轮次: R{{ROUND}}
- 阶段: {{CURRENT_STAGE}}
- 重构姿态: {{REFACTOR_POSTURE}}
- 设计来源文档（外部输入）: {{DESIGN_SOURCE_FILE}}
- 工作流目录: {{WORKFLOW_DIR}}
- 涉及模块: {{MODULES}}

## 当前阶段任务
{{ROUND_TASK}}

## 输出要求
- 产出/更新本轮 design 文件：`{{ROUND_DESIGN_FILE}}`
- 明确设计边界、关键接口、约束与风险
- Design 中必须声明驱动的 GAP-ID（若有）
- 头部必须声明 `round` / `driven_by` / `scope` / `external_refs`（如有）
- 如信息缺失或冲突：标记 BLOCKED 并停止
