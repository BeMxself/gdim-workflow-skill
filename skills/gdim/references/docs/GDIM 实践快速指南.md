# GDIM 实践快速指南

> **GDIM = Gap-Driven Iteration Model（偏差驱动迭代模型）**
> 对齐规范版本：v1.5

你让 AI 帮你写代码，结果它一口气改了 20 个文件，其中一半你没要求，另一半跑不通——听起来熟悉吗？

GDIM 就是为了解决这个问题：**用"发现偏差 → 修正偏差"的循环，把 AI 的工程执行力关进笼子里，同时最大化它的产出。**

核心思路很简单：每一轮只做一小块，做完检查哪里有偏差（Gap），下一轮专门修。没有偏差就不许乱改。循环往复，直到任务完成。

---

## 一、谁干什么？（角色分工）

GDIM 里有三个角色，各司其职：

| 角色 | 干什么 | 打个比方 |
|------|--------|---------|
| **你（人类）** | 提需求、定 Intent、审 Scope、拍板决策 | 甲方 + 项目经理 |
| **AI** | 出设计、写计划、干活、分析偏差 | 乙方工程师 |
| **GDIM 流程** | 强制闭环、防止跑偏、确保可追溯 | 质量管理体系 |

**关键**：Intent（目标）只有你能改。AI 可以建议，但不能擅自修改目标。

---

## 二、什么时候该用 GDIM？

GDIM 不是万能药，它适合**有明确目标、需要可控交付**的工程任务：

| 场景 | 典型输入 | 推荐度 |
|------|---------|:------:|
| 新功能开发 | 需求文档、PRD、设计稿 | ★★★ |
| 代码重构 | 重构规范、技术债清单 | ★★★ |
| 技术迁移 | 迁移方案、兼容性要求 | ★★★ |
| Bug 修复 | Bug 报告、复现步骤 | ★★ |
| 性能优化 | 性能报告、基准数据 | ★★ |

**不适合**：探索性原型、一次性脚本、紧急热修复。这些场景追求速度，GDIM 的流程反而是累赘。

---

## 三、一轮迭代长什么样？

每一轮（Round）都走同样的路：

```
外部输入（需求文档 / 设计稿 / Bug 报告…）
  ↓
Intent — 你从外部输入中提炼出目标（人类写）
  ↓
Scope Definition — AI 划定"这一轮只做哪些"（限速器）
  ↓
Design — AI 出设计方案（可引用外部文档）
  ↓
Plan — AI 拆解成可执行步骤
  ↓
Execute — AI（或你）动手干活
  ↓
Execution Summary — AI 如实记录"做了什么、结果如何"
  ↓
Gap Analysis — AI 做双层检查（本轮偏差 + 总体进度）
  ↓
你来拍板 → 继续下一轮 / 调整方向 / 收工
```

**注意**：每次请求只产出一个阶段的一个文件。别让 AI 一口气从 Scope 写到 Summary——那就失控了。

---

## 四、两个最重要的概念

### Scope：限速器

Scope 在 Intent 之后、Design 之前产生。它的职责不是"列出要做的事"，而是**主动限制这一轮允许做多少**。

想象你在高速公路上开车：Intent 是目的地，Scope 是限速牌。没有限速牌，AI 会一脚油门踩到底，然后翻车。

- R1（第一轮）：Scope 只能从 Intent 里挑，不能加私货
- R2+（后续轮）：Scope = 未完成的 Intent + 上一轮发现的 Gap

> **铁律：Scope 里不允许出现 Intent 和 Gap 之外的任何东西。**

### Gap：发动机

Gap 是"期望"和"实际"之间的结构性偏差。做完一轮后，AI 要做两层检查：

1. **Round Gap**（本轮偏差）：这一轮的 Scope/Design 和实际执行结果对得上吗？
2. **Intent Coverage**（总体覆盖）：整个 Intent 完成了多少？还差什么？

Gap 是下一轮迭代的**唯一合法燃料**。没有 Gap，就不允许"顺手优化"或"我觉得可以改进"。

> **如果 R1 一个 Gap 都没产生，说明你的 Scope 定得太大了——大到 AI 都没机会犯错。**

---

## 五、Gap 的六种类型

发现偏差后，按类型归档，方便后续处理：

| 代号 | 类型 | 什么意思 | 举个例子 |
|------|------|---------|---------|
| G1 | Requirement | 需求理解偏差 | AI 把"用户列表"理解成了"管理员列表" |
| G2 | Design | 设计遗漏或错误 | 忘了考虑并发场景 |
| G3 | Plan | 计划不可执行 | 步骤 3 依赖步骤 5 的产出 |
| G4 | Implementation | 实现与设计不一致 | 设计说用 Redis，代码写了 localStorage |
| G5 | Quality | 质量问题 | 性能不达标、缺少错误处理 |
| G6 | Constraint | 违反硬约束 | 用了禁止使用的第三方库 |

---

## 六、什么时候能收工？（退出条件）

当且仅当同时满足以下两个条件，才能输出 Final Report 并结束：

- ✅ 本轮没有 High Severity 的 Gap
- ✅ Intent 的所有条目都已覆盖

只要有一条不满足，就得继续下一轮。这不是建议，是硬性规则。

---

## 七、七条铁律

这是 GDIM 的底线，不可商量：

1. **Intent 是你的地盘** — AI 不能改 Intent，想改得通过你
2. **没有 Gap 就别动** — R2+ 的 Scope 必须由 Gap 驱动，不许"顺便优化"
3. **没有 Plan 就别写代码** — 先想清楚再动手
4. **每个设计和计划都要说清楚"为什么做"** — 必须声明 `driven_by`（R1 来自 Intent，R2+ 来自 Gap）
5. **超出 Scope 的发现 → 记成 Gap** — 别偷偷塞进去
6. **一次请求 = 一个文件** — 别贪多
7. **拿不准就问** — 不确定的事情，问人类，别猜

---

## 八、每轮该做多大？（Round 规模指南）

贪多是 AI 编程最常见的翻车原因。GDIM 对每轮的规模有明确建议：

| Round | 目标 | 规模上限 | 心法 |
|-------|------|---------|------|
| R0 | 把 Intent 写清楚 | 只产出 `00-intent.md` | 磨刀不误砍柴工 |
| R1 | 最小切口验证 | In Scope ≤ 3 项，只动 1 个模块 | 小到能失败 |
| R2+ | 关闭上轮 Gap | 每轮新增 1-2 项 Scope | 稳步推进 |
| Rn | 收敛 | 只处理 Quality/Constraint 类 Gap | 打磨细节 |

**R1 的黄金法则**：如果 R1 一个 Gap 都没产生，说明你的 Scope 太大了。好的 R1 应该小到"允许失败"，这样才能在早期暴露问题。

---

## 九、踩坑指南（常见翻车 → 正确姿势）

| 你看到了什么 | 哪里出了问题 | 怎么救 |
|-------------|-------------|--------|
| AI 一口气改了十几个文件 | Scope 太大，没限住 | 收紧 Scope，一次只做一小块 |
| 设计很花哨但没有依据 | 缺少 `driven_by` 声明 | 要求 AI 说清楚这个设计是为了解决哪个 Gap |
| 实现结果和设计对不上 | 缺少 Execution Summary | 让 AI 先写 Summary，再做 Gap Analysis |
| AI 偷偷加了你没要求的功能 | Scope 违规 | 立即中止，把多余的部分记为 Gap |
| 第二轮突然冒出新能力 | 可能没有 Gap 驱动 | 检查 R2 的 Scope Basis 里有没有对应的 Gap |
| 需求变了 | Intent 需要更新 | 你来改 Intent，同时写 Changelog |
| AI 说"我觉得可以顺便改一下" | 典型的 Scope 漂移 | 拒绝，让它记成 Gap 留到下一轮 |

---

## 十、三种违规行为

GDIM 规范明确定义了什么算"犯规"：

| 违规类型 | 具体表现 | 后果 |
|---------|---------|------|
| **Scope 违规** | 引入了 Intent 和 Gap 之外的内容 | 回退，重新定义 Scope |
| **设计违规** | 设计内容无法映射到 Scope 或 Gap | 要求重写设计 |
| **禁止行为** | 预留设计、占位结构、推测性设计 | 立即删除，记录为 Gap |

**底线**：不确定的时候，问人类。猜错的代价远大于问一句的成本。

---

## 十一、文件目录结构

每个任务在 `.ai-workflows/` 下建一个目录，所有过程文件都放在里面：

```text
.ai-workflows/YYYYMMDD-task-slug/
├── 00-intent.md                    # 目标定义（你写的）
├── 00-intent.changelog.md          # Intent 变更记录（可选）
├── 00-scope-definition.roundN.md   # 本轮范围
├── 01-design.roundN.md             # 设计方案
├── 02-plan.roundN.md               # 执行计划
├── 03-gap-analysis.roundN.md       # 偏差分析
├── 04-execution-log.roundN.md      # 执行日志（可选）
├── 05-execution-summary.roundN.md  # 执行摘要
└── 99-final-report.md              # 终局报告
```

外部输入文件（需求文档、设计稿等）直接引用原始路径，不用复制进来。

---

## 十二、Runtime Contract（给 AI 的系统提示词）

把下面这段直接复制到你的 AI 对话开头，它就知道该按 GDIM 规则办事了：

```text
You are operating under the Gap-Driven Iteration Model (GDIM).

Scope:
- Repository root: <module-or-root-path>
- Workflow directory: <.ai-workflows/task-dir>

Rules:
1. Do not modify Intent.
2. R1 Scope from Intent only; R2+ Scope from Intent + Gap.
3. Every design/plan must declare driven_by.
4. Missing info → declare a Gap, do not guess.
5. Out-of-scope issues → record as Gap.
6. No implementation without a Plan.
7. Produce ONLY the requested file.
8. When uncertain, ask the user.

Process:
Scope → Design → Plan → Execute → Summary → Gap Analysis
One step per request.

Exit Condition:
No High Severity Gap AND Intent fully covered → Final Report
Otherwise → Next Round
```

---

## 十三、一句话记住 GDIM

> **Intent 定锚点，Scope 限速，Gap 当发动机，Round 是刹车。**
>
> **收工条件：没有严重偏差，且目标全部达成。**

---

*完整规范请参阅 [GDIM 规范.md](./GDIM%20规范.md)；大型任务的拆解方法请参阅 [GDIM 层级化扩展.md](./GDIM%20层级化扩展.md)。*
