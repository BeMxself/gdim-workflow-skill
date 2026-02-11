# GDIM Prompt Templates · Frontend Edition (v1.5)

> 本文档是 **GDIM Prompt Templates 的 Web 前端特化版**
> 适用于 React / Vue / Angular / 原生前端等工程场景
> 在通用 GDIM 约束基础上，针对前端"易超范围、易假完成、易隐性缺陷"的特点进行强化约束
>
> **所有阶段必须显式生成文件，不允许隐式结果**

---

## 0. Intent 持续生成与定稿（Frontend Intent Refinement）

你的角色是 **前端需求澄清与结构化助手**。

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

目标不是一次性生成完整 Intent，而是通过多轮交互逐步定稿。

外部输入来源（如有）：
- 设计稿 / UI 原型
- 需求文档 / PRD
- 交互说明文档
- API 文档

前端 Intent 必须明确（如不明确必须提问）：

- 用户角色 / 使用场景
- 页面、视图或组件边界
- 核心交互路径（Happy Path）
- 是否涉及以下复杂度：
  - 状态管理（本地 / 全局）
  - 路由
  - 表单与校验
  - 国际化（i18n）
  - 响应式 / 主题
  - 可访问性（a11y）
  - 性能要求

规则：

- 不讨论实现方案
- 不假设已有组件、样式或基础设施存在
- 不进入设计、计划或实现
- 每一轮只做整理与澄清
- Intent 是外部输入的**精炼子集**，而非全量复制

输出文件：

- `00-intent.md`（草稿或定稿）

---

## 1. Scope Definition（Round 1 · Frontend 限速升级版）

你正在生成 **前端任务的第一轮 Scope Definition**。

输入文件：

- `00-intent.md`

输出文件：

- `00-scope-definition.round1.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

目标（前端特化）：

- 明确 **本轮允许尝试的最小可行前端范围**
- 主动限制页面数量、交互深度与状态复杂度
- 为 Gap 的显性化创造条件

必须包含：

### 1. Scope Basis
- Intent: 00-intent.md

### 2. In Scope
- 明确到：
  - 页面 / 组件名称
  - 仅限 **静态展示** 或 **单一交互**
- 明确"做到什么程度即算完成"

### 3. Out of Scope
- 状态联动
- 完整用户流程
- 表单校验
- i18n / 主题 / 响应式（除非 Intent 明确要求）
- 动效与视觉精修

### 4. Deferred Intent Mapping
- 标注被明确延后的 Intent 点
- 简要说明延后原因（复杂度 / 风险 / 验证价值）

强约束（前端限速条款）：

- 禁止覆盖全部 Intent
- 第一轮禁止完整用户流程
- 禁止同时引入「新组件 + 新状态模型」
- 禁止"顺手把样式也做好"
- In Scope 条目 ≤3，涉及模块 =1

如存在多种合理 Scope 切分方案，必须向用户确认。

---

## 2. Scope Definition（Round N · Frontend）

基于已确认 Gap 与 Intent 生成第 N 轮 Scope Definition。

输入文件：

- `00-intent.md`
- `03-gap-analysis.round(N-1).md`

输出文件：

- `00-scope-definition.roundN.md`

规则（前端特化）：

- Scope **只能**由以下驱动：
  - 已确认的 UI / 交互 / 状态 Gap
  - 尚未开始、但已存在于 Intent 中的内容
- 不得引入全新 Intent
- 不得扩大到未被 Gap 指向的页面或组件

必须包含：

1. Scope Basis（含 Intent、Gap Source、Gaps to Close）
2. In Scope
3. Out of Scope
4. Deferred Mapping

强约束（限速）：

- 禁止一轮同时推进多个页面
- 禁止为未来轮次预埋实现
- 新增 Scope 1-2 项

如存在多种合理 Scope 切分方案，必须向用户确认。

N=

---

## 3. 设计生成（Round 1 · Frontend）

生成第一轮前端设计文档。

输入文件：

- `00-intent.md`
- `00-scope-definition.round1.md`
- 外部参考文档（如有，见 Intent 中的 External References）

输出文件：

- `01-design.round1.md`

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。

设计要求（前端特化）：

- **仅覆盖 In Scope 内容**
- 聚焦结构性设计：
  - 组件拆分与层级
  - 组件职责
  - Props / Events / Slots（或等价机制）
- 明确组件边界与复用意图
- 可引用外部文档（设计稿、API 文档等）作为设计依据
- 必须在头部声明 driven_by、scope、external_refs（如有）

禁止：

- CSS / 样式细节
- 状态管理实现细节
- API 结构臆测
- 非 Scope 内交互

### 超范围即违规条款

- 任何 Out of Scope 的页面、组件、交互或状态设计，均视为违规
- 不允许"顺手多做一点"

如遇不明确之处，必须向用户提问。

---

## 4. 设计生成（Round N · Frontend）

生成第 N 轮前端设计文档。

输入文件：

- `03-gap-analysis.round(N-1).md`
- `00-scope-definition.roundN.md`
- 外部参考文档（如有）

输出文件：

- `01-design.roundN.md`

设计要求：

- **仅覆盖 In Scope 内容**
- 每一项新增或变更设计必须显式标注：
  - `driven_by: GAP-XX`
- 聚焦修正偏差，不进行结构性重构（除非 Gap 明确指向）
- 可引用外部文档作为设计依据
- 必须在头部声明 driven_by、source、scope、external_refs（如有）

禁止：

- 合并多个 Gap 为模糊设计
- 借 Gap 名义顺手重构组件结构
- 引入未被 Gap 指向的新能力

如遇不明确之处，必须向用户提问。

N=

---

## 5. 设计审查（Round N · Frontend）（可选）

审查第 N 轮前端设计文档。

本任务严格遵循 Gap-Driven Iteration Model（GDIM）。
除非由已识别的 Gap 明确驱动，否则不要生成或扩展设计内容。

审查重点（前端）：

- 是否重复已有组件能力
- 是否隐性引入全局状态
- 是否假设某 UI 库或基础组件已存在
- 是否存在"设计合理但无法实现"的交互
- 外部参考文档的引用是否准确

输出文件：

- `01-design-review.roundN.md`

如发现不确定性或信息缺失，必须向用户提问。

N=

---

## 6. 执行计划（Round N · Frontend）

根据设计文档生成第 N 轮前端执行计划。

输入文件：

- `01-design.roundN.md`

输出文件：

- `02-plan.roundN.md`

要求：

- 逐条映射设计内容
- 明确到：
  - 文件路径
  - 组件名称
  - 样式方案（即使是"暂不处理"也要写明）
- 明确是否涉及：
  - 新增组件
  - 修改既有组件
  - 状态 / 副作用 / 路由

禁止：

- 使用"实现页面""完成 UI"等不可执行描述

如遇不明确之处，必须向用户提问。

N=

---

## 7. 可信执行总结（Round N · Frontend）

核查执行事实，生成第 N 轮前端执行总结。

输入文件：

- `01-design.roundN.md`
- `02-plan.roundN.md`
- 实际代码变更结果

输出文件：

- `05-execution-summary.roundN.md`

执行总结必须是 **事实性描述**。

必须包含（前端特化）：

1. 实际完成的组件 / 页面
2. 哪些组件可以真实渲染
3. 哪些交互不可用或未连通
4. 是否存在：
   - 假数据
   - 临时 mock
   - 仅视觉完成的部分
5. 执行中的偏差、限制或临时决策

禁止：

- 评价好坏
- 提出改进建议
- 使用"基本完成""看起来可用"等模糊表述

如遇不明确之处，必须向用户提问。

N=

---

## 8. Gap Analysis（Round N · Frontend）

基于执行总结对设计完成情况进行审查，生成第 N 轮 Gap Analysis。

输入文件：

- `00-intent.md`
- `01-design.roundN.md`
- `05-execution-summary.roundN.md`

输出文件：

- `03-gap-analysis.roundN.md`

Gap Analysis 包含**两个层次**的分析：

1. **Round Gap（本轮偏差）**：本轮 Scope/Design vs 执行结果
2. **Intent Coverage（Intent 覆盖度）**：Intent vs 累计完成状态

必须包含：

1. Round Gap（本轮偏差）
2. Intent Coverage（Intent 覆盖度）
3. Closure Strategy
4. Exit Decision

前端 Gap 必须分类：

- UI Gap（结构 / 视觉不一致）
- Interaction Gap（交互未闭合）
- State Gap（状态缺失或错误）
- Integration Gap（数据 / API 未连通）
- Scope Violation（超范围实现）

要求：

- 逐条比对设计与执行结果
- 明确 Gap 类型与来源
- 不引入解决方案

**退出条件**：
- 本轮无 High Severity Gap **且** Intent 已完全覆盖 → Final Report
- 否则 → 进入下一轮

如未发现 Gap 且 Intent 未完全覆盖，必须解释原因并请求用户确认。

N=

---

## 9. Final Report（Frontend）

生成前端 GDIM 最终报告。

输入文件：

- 所有已确认的 Intent / Scope / Gap / Execution Summary

输出文件：

- `99-final-report.md`

必须包含：

1. Gap Summary
2. Intent Coverage Summary
3. 终止说明

必须回答：

- 哪些前端能力 **真实可用**
- 哪些仅为结构或视觉占位
- 哪些 Intent 被明确延后或放弃

禁止：

- 引入新设计
- 使用评价性语言（如"体验更好""更优雅"）

---

## 附录：前端 GDIM 推荐规模表

| Round | 目标 | 规模限制 |
|-------|------|---------|
| R0 | 稳定 Intent | 仅 `00-intent.md` |
| R1 | 最小切口 | In Scope ≤3, 模块 =1 |
| R2+ | 关闭 Gap | 新增 Scope 1-2 项 |
| Rn | 收敛 | 仅 Quality/Constraint Gap |

**原则**：R1 未产生 Gap 视为设计超量。

---

## 前端 GDIM 口诀

> **前端最怕"看起来完成"。
> Scope 负责限速，Gap 负责戳穿。**
>
> **退出条件**：
> 本轮无 High Severity Gap **且** Intent 已完全覆盖。
