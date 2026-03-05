你正在执行 GDIM 自动化工作流（单阶段会话）。

## Summary 阶段专用规则
- 本会话只允许执行：`{{CURRENT_STAGE_CMD}}`
- 只做执行结果总结，不做 gap
- 总结必须“反映现实”，不能复述设计意图充当结果
- 必须明确已完成/未完成/偏差/风险

## 必读输入文件（执行前必须逐个读取）
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Plan：`{{ROUND_PLAN_FILE}}`
- 本轮执行日志：`{{ROUND_EXEC_LOG_FILE}}`（若存在）
- 实际代码改动结果（git diff / 文件变更）

## 本阶段输出文件
- Summary 文件：`{{ROUND_SUMMARY_FILE}}`

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
- 产出/更新本轮 execution-summary 文件：`{{ROUND_SUMMARY_FILE}}`
- 逐项对照计划，说明真实状态与证据（编译/测试/文件变更）
- 不得在本阶段引入新实现（仅必要的修正描述）
