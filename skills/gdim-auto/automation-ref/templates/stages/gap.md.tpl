你正在执行 GDIM 自动化工作流（单阶段会话）。

## Gap 阶段专用规则
- 本会话只允许执行 GDIM 命令：`{{CURRENT_STAGE_CMD}}`（允许执行必要的 git 状态/提交命令）
- 只做 Gap Analysis，不回头重做 scope/design/plan/execute/summary
- 必须执行两层分析：Round Gap（本轮偏差）+ Intent Coverage（整体覆盖）
- Gap 分类遵循 G1-G6，结论需可追溯到本轮事实与文档证据

## 必读输入文件（执行前必须逐个读取）
- 共享 Intent：`{{SHARED_INTENT_FILE}}`（若存在）
- 流程 Intent：`{{FLOW_INTENT_FILE}}`
- 本轮 Design：`{{ROUND_DESIGN_FILE}}`
- 本轮 Summary：`{{ROUND_SUMMARY_FILE}}`

## 可选补充输入（仅在必要时读取）
- 本轮 Scope：`{{ROUND_SCOPE_FILE}}`
- 上一轮 Gap：`{{PREV_GAP_FILE}}`
- 其他过程文件（按需）

## 可选输入读取闸门（严格）
- 默认禁止读取可选补充输入
- 仅当“必读输入冲突”或“仅靠必读输入无法收敛到单一 Gap 结论”时，才允许读取
- 读取前必须先在响应中声明：未决问题、目标文件、读取目的
- 每次只允许新增读取 1 个可选输入；读取后必须回填：结论变化（收敛/无变化）
- 结论一旦收敛，立即停止继续读取可选输入
- 信息权重：Intent 与必读输入 > 可选输入；可选输入不得覆盖硬约束

## 重构姿态纪律
{{REFACTOR_DISCIPLINE}}

## 本阶段输出文件
- Gap Analysis 文件：`{{ROUND_GAP_FILE}}`

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
- 产出/更新本轮 gap-analysis 文件：`{{ROUND_GAP_FILE}}`
- Round Gap 必须给出 Expected/Actual/Category(G1-G6)/Severity/Impact
- Intent Coverage 必须明确总体覆盖状态，并给出 Closure Strategy
- Exit Decision 仅在“无 High Severity Gap 且 Intent 覆盖完成”时允许 FINAL_REPORT
- `conservative` 下，如兼容性被破坏但未提供补偿/迁移闭环，不允许 FINAL_REPORT
- `balanced` 下，如设计一致性与兼容性仍存在未解释的撕裂，不允许 FINAL_REPORT
- `aggressive` 下，若新设计落地后仍有无法自动愈合的撕裂，必须停止自动迭代并要求补充设计决策，不允许 FINAL_REPORT
- 若存在当前任务目录（`{{WORKFLOW_DIR}}` 所属任务目录）之外的代码改动，必须在本会话执行 `git add` + `git commit` 完成提交
- 提交信息由你生成，且必须包含轮次标记：`gdim({{FLOW_SLUG}}): R{{ROUND}}`
- 文末必须追加机器可解析决策行（单独一行）：
  - `GDIM_EXIT_DECISION: CONTINUE`
  - `GDIM_EXIT_DECISION: FINAL_REPORT`
  - `GDIM_EXIT_DECISION: BLOCKED`
- 文末必须追加机器可解析姿态/撕裂状态行（单独一行）：
  - `GDIM_REFACTOR_POSTURE: {{REFACTOR_POSTURE_UPPER}}`
  - `GDIM_FRACTURE_STATUS: HEALED`
  - `GDIM_FRACTURE_STATUS: ACCEPTED`
  - `GDIM_FRACTURE_STATUS: NEEDS_DECISION`
