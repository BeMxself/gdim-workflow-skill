你正在执行 GDIM 自动化工作流。本环境已安装 GDIM Skills，请通过 Skill 工具按阶段调用。

## 当前上下文
- 流程: {{FLOW_SLUG}}
- 轮次: R{{ROUND}}
- 设计文档: {{DESIGN_DOC}}
- 工作流目录: {{WORKFLOW_DIR}}
- 涉及模块: {{MODULES}}

## Intent（不可变）
{{INTENT_CONTENT}}

## 上一轮进展
{{PROGRESS_CONTENT}}

## 上一轮 Gap（仅 R2+ 注入）
{{PREV_GAPS}}

## 本轮执行流程（按顺序调用 Skills）

{{ROUND_TASK}}

## 各阶段 Skill 调用说明

按以下顺序依次调用 Skill 工具（每个阶段完成后再进入下一个）：

1. **Scope**: 调用 `/gdim-scope`，定义本轮工作边界（≤3 scope items, ≤3 core classes）
2. **Design**: 调用 `/gdim-design`，基于 scope 创建设计文档，声明驱动的 GAP-ID
3. **Plan**: 调用 `/gdim-plan`，从设计文档生成可执行计划
4. **Execute**: 调用 `/gdim-execute`，按计划实现代码，运行 `mvn compile -pl {{MODULES}} -am` 验证
5. **Summary**: 调用 `/gdim-summary`，如实记录执行结果（反映现实而非设计意图）
6. **Gap Analysis**: 调用 `/gdim-gap`，识别偏差，决定是否继续

## 关键约束
- 本轮只做一个 GDIM 轮次，完成后退出
- 每个阶段通过 Skill 调用执行，不要跳过任何阶段
- 必须运行 mvn compile 验证编译通过
- gap-analysis 是唯一的轮次出口，必须生成
- 遇到阻塞（缺凭据/外部依赖/需人工）→ 在 gap 中标记 BLOCKED 并停止
- 进展由自动化框架自动记录，无需手动创建或维护任何进展文件
- 一次性 git commit 所有改动（代码 + GDIM 文件）
- Treat 00-intent.md as immutable baseline truth
- Design 阶段必须先读取设计文档（{{DESIGN_DOC}}）中与本轮 scope 相关的章节，确保设计不偏离已评审通过的架构决策
- If information is missing or ambiguous: STOP and mark BLOCKED
