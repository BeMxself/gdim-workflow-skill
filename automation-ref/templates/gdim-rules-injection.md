# GDIM 自动化规则注入

本节从 GDIM.md 和 GDIM_PROMPT.md 提取，适用于自动化执行场景。

## 核心纪律（GDIM_PROMPT.md）

1. Do nothing unless driven by an identified Gap.
2. Treat 00-intent.md as immutable baseline truth.
3. Each round is isolated and traceable.
4. Every design must declare which GAP-IDs drive it.
5. Execution must reflect reality, not design intent.
6. Gap Analysis is the ONLY gateway to the next round.
7. If information is missing or ambiguous: STOP and mark BLOCKED.

## GDIM 文件命名规范

每轮产出文件（在 workflow-dir 下）：
- `00-scope-definition.round{N}.md` — Scope 定义
- `01-design.round{N}.md` — 设计文档
- `02-plan.round{N}.md` — 执行计划
- `04-execution-log.round{N}.md` — 执行日志（可选）
- `05-execution-summary.round{N}.md` — 执行总结
- `03-gap-analysis.round{N}.md` — Gap 分析（必须）

## Gap 分类法

| Code | Category | 描述 |
|------|----------|------|
| G1 | Requirement Gap | 需求理解偏差 |
| G2 | Design Gap | 架构/设计遗漏或错误 |
| G3 | Plan Gap | 计划不可执行 |
| G4 | Implementation Gap | 实现与设计不一致 |
| G5 | Quality Gap | 性能/安全/可维护性问题 |
| G6 | Constraint Gap | 未满足约束条件 |

## Round 规模限制

- R1: In Scope ≤ 3 条目, 涉及模块 1 个, 新增核心类 ≤ 3, 新增接口 ≤ 2
- R2+: 新增 Scope 1-2 项, 设计修改必须逐条对应 Gap
- 如果 R1 未产生清晰 Gap，视为设计超量

## 自动化场景特殊约束

- 每轮只执行一个完整 GDIM 闭环，完成后必须退出
- 必须运行 `mvn compile` 验证编译通过后再生成 summary
- gap-analysis.md 是唯一的轮次出口，必须生成
- 遇到阻塞（缺凭据/外部依赖/需人工决策）→ 在 gap 中标记 `BLOCKED` 并立即停止
- 不得跨轮次执行，不得在一次调用中完成多轮
- 所有改动必须在本轮结束时一次性 git commit
