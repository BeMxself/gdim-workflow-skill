你正在执行 GDIM 自动化工作流（单阶段会话）。

## Plan 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做计划，不做 execute/summary/gap
- 计划必须可执行、可验证、可回滚
- 任务拆分应与 design 产物一一对应，并持续对齐流程 Intent

## 必读输入文件（执行前必须逐个读取）
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`

## 可选补充输入（仅在必要时读取）
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`
- 设计来源文档：`{{DESIGN_SOURCE_FILE}}`

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法收敛到单一计划决策”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 本阶段输出文件
- Plan 文件：`{{ROUND_PLAN_FILE}}`

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
- 产出/更新本轮 plan 文件：`{{ROUND_PLAN_FILE}}`
- 每项任务包含：目标、变更点、验证命令、完成判据
- 明确 design→plan 的映射关系（哪些设计项对应哪些步骤）
- 禁止在 plan 阶段直接改代码（除必要脚手架说明外）
- 如信息缺失或冲突：标记 BLOCKED 并停止
