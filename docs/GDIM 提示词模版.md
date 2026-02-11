# GDIM Prompt Templates (Complete · v1.5)

> 本文档汇总并规范化所有 GDIM（Gap-Driven Iteration Model）提示词模版，
> 按照 **GDIM 实际执行顺序** 编排，用于约束与引导大模型在复杂任务中的设计、计划、执行与复盘行为。
>
> **所有阶段均要求显式输出文件名，不允许隐式结果。**

---

## 0. Intent 持续生成与定稿（Intent Refinement Loop）

协助用户生成和完善 Intent。

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

你的目标不是一次性生成完整 Intent，而是：
- 整理用户输入的零散意图
- 从外部输入文件（需求文档、设计文档、Bug 报告等）中提取合适规模的任务
- 识别歧义、冲突或隐含假设
- 通过提问与总结不断收敛 Intent

规则：
- 每一轮只做 **整理与澄清**
- 不进入设计、计划或实现
- 如存在不明确之处，必须向用户提问
- 直到用户明确表示 Intent 定稿
- Intent 是外部输入的**精炼子集**，而非全量复制

输出文件：
- `00-intent.md`（草稿或定稿）

---

## 1. Scope Definition（Round 1 · 限速升级版）

你正在生成 Scope Definition 文档（第一轮）。

输入文件：
- `00-intent.md`

输出文件：
- `00-scope-definition.round1.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

目标：
- 明确 **本轮允许尝试的最小可行范围**
- 主动限制规模，防止第一轮过度实现

必须包含：
1. Scope Basis
2. In Scope
3. Out of Scope
4. Deferred Intent Mapping

强约束（限速条款）：
- 禁止覆盖全部 Intent
- 禁止为未来轮次预埋实现
- In Scope 条目 ≤3，涉及模块 =1

如 Scope 切分存在多种合理方案，必须向用户确认。

---

## 2. Scope Definition（Round N）

基于已确认的 Gap 与 Intent 生成第N轮 Scope Definition。

输入文件：
- `00-intent.md`
- `03-gap-analysis.round(N-1).md`

输出文件：
- `00-scope-definition.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

目标：
- 明确 **本轮允许尝试的最小可行范围**
- 主动限制规模，防止本轮过度实现

规则：
- Scope **只能**由已确认 Gap 或未完成的 Intent 驱动
- 不得引入全新 Intent
- 不得扩大到未被 Gap 指向的区域

必须包含：
1. Scope Basis（含 Intent、Gap Source、Gaps to Close）
2. In Scope
3. Out of Scope
4. Deferred Mapping

强约束（限速条款）：
- 禁止覆盖全部 Intent
- 禁止为未来轮次预埋实现
- 新增 Scope 1-2 项

如 Scope 切分存在多种合理方案，必须向用户确认。

N=

---

## 3. 设计生成（Round 1）

生成第一轮设计文档。

输入文件：
- `00-intent.md`
- `00-scope-definition.round1.md`
- 外部参考文档（如有，见 Intent 中的 External References）

输出文件：
- `01-design.round1.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

设计要求：
- **仅覆盖 In Scope 内容**
- 聚焦接口、职责与结构
- 避免实现细节（除非核心算法不可避免）
- 可引用外部文档作为设计依据
- 必须在头部声明 driven_by、scope、external_refs（如有）

**超范围即违规条款：**
- 任何 Out of Scope 的设计内容均视为违规
- 不允许"顺手多做一点"

如遇不明确之处，必须向用户提问。

---

## 4. 设计生成（Round N）

生成第 N 轮设计文档。

输入文件：
- `03-gap-analysis.round(N-1).md`
- `00-scope-definition.roundN.md`
- 外部参考文档（如有）

输出文件：
- `01-design.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

设计要求：
- **仅覆盖 In Scope 内容**
- 聚焦接口、职责与结构
- 避免实现细节（除非核心算法不可避免）
- 可引用外部文档作为设计依据
- 必须在头部声明 driven_by、source、scope、external_refs（如有）

**超范围即违规条款：**
- 任何 Out of Scope 的设计内容均视为违规
- 不允许"顺手多做一点"

如遇不明确之处，必须向用户提问。

N=

---

## 5. 设计审查（Round N）（可选）

审查第N轮设计文档。

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。
除非由已识别的 Gap 明确驱动，否则不要生成或扩展设计内容。

审查重点：
- 修改既有类 / 接口是否与原设计冲突或重复
- 新增类 / 接口是否与现有能力重复
- 外部类或接口的使用是否基于真实定义，而非臆测
- 外部参考文档的引用是否准确

输出文件：
- `01-design-review.roundN.md`

如发现不确定性或信息缺失，必须向用户提问。

N=

---

## 6. 生成执行计划（Round N）

根据设计文档生成第N轮执行计划。

输入文件：
- `01-design.roundN.md`

输出文件：
- `02-plan.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

要求：
- 逐条映射设计内容
- 明确文件、修改点、依赖与工具
- 所有工具类与方法必须事先核查其存在性

N=

---

## 7. 可信执行总结（Round N）

核查执行事实，生成第N轮执行总结文档。

输入文件：
- `01-design.roundN.md`
- `02-plan.roundN.md`
- 实际代码变更结果

输出文件：
- `05-execution-summary.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

执行总结必须是 **事实性描述**，而非评价或辩护。

必须包含：
1. 实际完成内容
2. 完整实现的设计
3. 部分或未实现的设计
4. 执行中的偏差、限制或临时决策

禁止行为：
- 不评判好坏
- 不提出改进建议
- 不隐瞒事实

N=

---

## 8. Gap Analysis（基于非可信执行总结）

对执行总结进行事实核查以及设计完成情况审查，进行第N轮 Gap Analysis。

输入文件：
- `00-intent.md`
- `01-design.roundN.md`
- `05-execution-summary.roundN.md`

输出文件：
- `03-gap-analysis.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

Gap Analysis 包含**两个层次**的分析：

1. **Round Gap（本轮偏差）**：本轮 Scope/Design vs 执行结果
2. **Intent Coverage（Intent 覆盖度）**：Intent vs 累计完成状态

必须包含：
1. Round Gap（本轮偏差）
2. Intent Coverage（Intent 覆盖度）
3. Closure Strategy
4. Exit Decision

要求：
- 逐条比对设计与执行结果
- 执行结果必须经过核查验证
- 明确 Gap 类型与来源

**退出条件**：
- 本轮无 High Severity Gap **且** Intent 已完全覆盖 → Final Report
- 否则 → 进入下一轮

如未发现 Gap 且 Intent 未完全覆盖，必须解释原因并请求用户确认。

N=

---

## 9. Gap Analysis（基于可信执行总结）

基于执行总结对设计完成情况进行审查，进行第N轮 Gap Analysis。

输入文件：
- `00-intent.md`
- `01-design.roundN.md`
- `05-execution-summary.roundN.md`

输出文件：
- `03-gap-analysis.roundN.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

Gap Analysis 包含**两个层次**的分析：

1. **Round Gap（本轮偏差）**：本轮 Scope/Design vs 执行结果
2. **Intent Coverage（Intent 覆盖度）**：Intent vs 累计完成状态

必须包含：
1. Round Gap（本轮偏差）
2. Intent Coverage（Intent 覆盖度）
3. Closure Strategy
4. Exit Decision

要求：
- 逐条比对设计与执行结果
- 明确 Gap 类型与来源

**退出条件**：
- 本轮无 High Severity Gap **且** Intent 已完全覆盖 → Final Report
- 否则 → 进入下一轮

如未发现 Gap 且 Intent 未完全覆盖，必须解释原因并请求用户确认。

N=

---

## 10. Final Report（最终报告）

生成 GDIM Final Report。

输入文件：
- 所有已确认的 Intent / Scope / Gap / Execution Summary

输出文件：
- `99-final-report.md`

必须包含：
1. Gap Summary
2. Intent Coverage Summary
3. 终止说明

规则：
- 汇总事实
- 不引入新设计
- 不使用评价性语言

---

## 附录：GDIM 推荐规模表

| Round | 目标 | 规模限制 |
|-------|------|---------|
| R0 | 稳定 Intent | 仅 `00-intent.md` |
| R1 | 最小切口 | In Scope ≤3, 模块 =1 |
| R2+ | 关闭 Gap | 新增 Scope 1-2 项 |
| Rn | 收敛 | 仅 Quality/Constraint Gap |

**原则**：R1 未产生 Gap 视为设计超量。

---

> **核心原则**：
> Scope Definition 的职责不是减少 Gap，
> 而是确保 Gap 在可控范围内必然显性化。
>
> **退出条件**：
> 本轮无 High Severity Gap **且** Intent 已完全覆盖。
