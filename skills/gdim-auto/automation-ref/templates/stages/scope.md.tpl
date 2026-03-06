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
- 说明：若 R1 显示“无上一轮 Gap 文件”，可忽略该项

## 可选补充输入（仅在边界冲突或信息不足时读取）
- 设计来源文档：`{{DESIGN_SOURCE_FILE}}`
- 其他流程过程文件（仅按需）

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法收敛到单一决策”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 本阶段输出
- Scope 文件：`{{ROUND_SCOPE_FILE}}`

## 当前上下文
- 流程: {{FLOW_SLUG}}
- 轮次: R{{ROUND}}
- 阶段: {{CURRENT_STAGE}}
- 设计来源文档（外部输入）: {{DESIGN_SOURCE_FILE}}
- 工作流目录: {{WORKFLOW_DIR}}
- 涉及模块: {{MODULES}}

## 当前阶段任务
{{ROUND_TASK}}

## 输出要求
- 产出/更新本轮 scope 文件：`{{ROUND_SCOPE_FILE}}`
- 明确 In Scope / Out of Scope
- 明确 Scope Basis（Intent 与 R2+ 的 Gap Source）
- 如信息缺失或冲突：标记 BLOCKED 并停止
