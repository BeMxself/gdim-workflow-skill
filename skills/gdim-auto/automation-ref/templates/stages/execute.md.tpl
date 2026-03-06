你正在执行 GDIM 自动化工作流（单阶段会话）。

## Execute 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做实现，不做 summary/gap
- 严格按 plan 落地，不做“顺手优化”范围外改动
- 所有改动必须落在允许路径与指定模块内

## 必读输入文件（执行前必须逐个读取）
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 本轮 Plan：`{{ROUND_PLAN_FILE}}`

## 可选补充输入（仅在必要时读取）
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法收敛到单一执行决策”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 本阶段产物
- 代码改动（受 allowed_paths 约束）
- 可选执行日志：`{{ROUND_EXEC_LOG_FILE}}`

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
- 完成计划内代码改动并落盘
- 运行编译验证：`mvn compile -pl {{MODULES}} -am`（无模块时按项目约束）
- 记录执行事实（建议写入 `{{ROUND_EXEC_LOG_FILE}}`，若未生成需在 summary 说明）
- 若遇阻塞（凭据/外部系统/人工决策）：标记 BLOCKED 并停止
