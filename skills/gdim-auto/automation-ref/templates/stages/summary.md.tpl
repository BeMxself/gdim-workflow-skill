你正在执行 GDIM 自动化工作流（单阶段会话）。

## Summary 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做执行结果总结，不做 gap
- 总结必须“反映现实”，不能复述设计意图充当结果
- 只允许事实记录，不做评价、辩护、改进建议、Gap 结论

## 必读输入文件（执行前必须逐个读取）
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Plan：`{{ROUND_PLAN_FILE}}`
- 实际代码改动结果（git diff / 文件变更）

## 可选补充输入（仅在必要时读取）
- 本轮执行日志：`{{ROUND_EXEC_LOG_FILE}}`（若存在）
- 编译/测试输出（若本轮有执行）
- 上一轮 Gap：`{{PREV_GAP_FILE}}`

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法形成单一事实结论”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 重构姿态上下文
{{REFACTOR_DISCIPLINE}}

## 本阶段输出文件
- Summary 文件：`{{ROUND_SUMMARY_FILE}}`

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
- 产出/更新本轮 execution-summary 文件：`{{ROUND_SUMMARY_FILE}}`
- 逐项对照计划，记录真实状态与证据（编译/测试/文件变更）
- 建议包含：Completed、Deviations from Plan、Discoveries、Temporary Decisions、Blockers、Files Changed
- 不得在本阶段引入新实现（仅允许纠错性文字修订）
