# GDIM Workflow — Claude Code 插件

[English](README.md) | [中文](README.zh-CN.md)

一个 Claude Code 插件，用于 **Gap-Driven Iteration Model（GDIM）** —— 一种面向 AI 辅助软件开发的纪律化工作流。

## 安装

### Claude Code（插件）

在 Claude Code 中把本 GitHub 仓库添加为插件市场（Marketplace）：

```text
/plugin marketplace add BeMxself/gdim-workflow-skill
```

然后安装插件：

```text
/plugin install gdim-workflow@BeMxself-gdim-workflow-skill
```

安装完成后，所有 `/gdim-*` 命令即可使用。

### Codex（Skills）

根据 Codex 官方 skills 文档，Codex 会从以下位置扫描 skills：
- 项目级 `.agents/skills/`（从当前目录向上到仓库根目录）
- 用户级 `$HOME/.agents/skills/`

用户级安装：

```bash
mkdir -p ~/.agents/skills
rsync -a skills/ ~/.agents/skills/
```

项目级安装（在你的目标项目目录执行）：

```bash
mkdir -p .agents/skills
rsync -a /path/to/gdim-workflow-skill/skills/ .agents/skills/
```

后续更新同样重复执行对应的 `rsync` 命令即可。

提示：
- 在 Codex app/IDE 中，匹配的 skill 可以自动触发。
- 你也可以显式要求 Codex 使用某个 skill（例如：`gdim-scope`）。
- 在 Codex 中使用 `/skills` 可查看当前生效的 skills。

### Kiro CLI（Skills）

Kiro CLI 可以从 `.kiro/skills/**/SKILL.md`（workspace 级别）加载 skills，并通过 agent profile 使用。

1) 将 skills 安装到当前仓库/workspace：

```bash
mkdir -p .kiro/skills
rsync -a skills/ .kiro/skills/
```

2) 创建一个包含 skills resources 的 agent（此命令会打开编辑器）：

```bash
mkdir -p .kiro/agents
kiro-cli agent create --name "GDIM Agent" --directory .kiro/agents
```

3) 在 `.kiro/agents/gdim_agent.json` 中加入 resources 配置（示例）：

```json
{ "resources": ["skill://.kiro/skills/**/SKILL.md"] }
```

4) 用该 agent 启动对话：

```bash
kiro-cli chat --agent "GDIM Agent"
```

## 与 GDIM 规范的关系

这些 skills 是 GDIM 规范文档的 **可执行伴侣**：

- **Skills**（`skills/`）：用于 Claude Code 的快速规则与工作流指令（调用 `/gdim-*`）
- **便携参考**（`skills/gdim/references/gdim-portable-reference.md`）：用于仅安装 skills 的场景
- **规范**（[`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md)）：完整方法论、模板与 rationale
- **快速指南**（[`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)）：更易读的入门介绍
- **提示词模板**（[`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)）：各阶段更详细的提示词模板
- **前端模板**（[`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)）：前端项目的额外约束

**什么时候用哪个：**
- 在 Claude Code 工作 → 用这些 skills（`/gdim-*` 命令）
- 学习 GDIM → 阅读 [`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)
- 需要详细模板 → 参考 [`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md) 或 [`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)
- 前端项目 → 也请看 [`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)

## 什么是 GDIM？

GDIM 通过以下方式约束 AI 的执行：
- **显式范围限制**：每一轮只做小而聚焦的一部分
- **偏差（Gap）驱动迭代**：偏差被显式记录为 Gap，并驱动下一轮工作
- **严格可追溯性**：每一个设计/计划必须声明其驱动依据

**核心原则**：小范围 → 可见偏差 → 可控迭代 → 稳定交付

## 快速开始

### 1) 初始化一个工作流

```bash
/gdim-init user-authentication
```

会创建 `.ai-workflows/YYYYMMDD-user-authentication/`

### 2) 定义 Intent

```bash
/gdim-intent
```

通过引导式问题创建 `00-intent.md`。Intent 可能来自：
- 外部文档（需求、PRD、设计稿等）
- 头脑风暴（建议先用 `/brainstorm`）
- 用户直接描述

### 3) 按轮次运行

每一轮遵循同样的循环：

```bash
/gdim-scope 1      # 定义“这一轮”要做什么（必须很小！）
/gdim-design 1     # 只为 scope 内内容产出设计
/gdim-plan 1       # 产出可执行计划
# 执行计划（写代码）
/gdim-execute 1    # 加载执行纪律规则
/gdim-summary 1    # 记录实际发生了什么
/gdim-gap 1        # 分析偏差，决定是否继续
```

### 4) 继续迭代或结束

- **存在 Gap 或 Intent 未完成** → `/gdim-scope 2`（进入下一轮）
- **没有 High 级 Gap 且 Intent 100% 覆盖** → `/gdim-final`

## 可用 Skills

| Skill | 用途 | 何时使用 |
|------|------|---------|
| `gdim` | 核心规则（自动加载） | 作为背景约束 |
| `gdim-init` | 初始化工作流目录 | 新建 GDIM 任务 |
| `gdim-intent` | 生成 Intent 文档 | 从文档/头脑风暴提炼目标 |
| `gdim-scope` | 定义本轮 scope | 每一轮开始时 |
| `gdim-design` | 生成设计文档 | scope 确认后 |
| `gdim-plan` | 生成执行计划 | 设计确认后 |
| `gdim-execute` | 执行纪律 | 编码实现阶段 |
| `gdim-summary` | 执行总结 | 实现后复盘 |
| `gdim-gap` | Gap 分析 | 执行总结后 |
| `gdim-final` | 最终报告 | 工作完成时 |

## 关键概念

### Scope 是“速度限制器”

Scope 的职责是 **防止过载**，不是列出所有 TODO。第 1 轮应该足够小，小到能“有意义地失败”。

**好的 R1 scope**：登录表单（邮箱/密码），不做校验、不做错误处理  
**坏的 R1 scope**：完整认证系统（OAuth、2FA、找回密码、会话管理……）

### Gap 是引擎

Gap 是“预期”与“实际”之间的 **结构性偏差**：
- 缺少错误处理 → Gap
- 未覆盖边界条件 → Gap
- 性能问题 → Gap
- 发现更好的方案 → Gap

**没有 Gap 就没有改进。** 第 2 轮及之后只能处理已记录的 Gap 或未完成的 Intent。

### 退出条件

只有同时满足以下两点，工作才结束：
1. ✅ 当前轮次没有 High Severity 的 Gap
2. ✅ Intent 100% 覆盖

## 常见误区

### “这就是一个功能，必须一次做完”

**错误**：“认证是一个功能，R1 直接全做了”  
**正确**：“R1：登录表单；R2：会话管理；R3：找回密码……”

功能永远可以拆分。拆分它。

### “这显然是必要的”

**错误**：计划写着“获取用户数据”，你因为“显然需要”而顺手加了错误处理  
**正确**：计划写着“获取用户数据”，你就只获取数据。没有错误处理 → 记录为 Gap

你觉得显然 ≠ 在 scope 内。把它记录成 Gap。

### “我是在遵循最佳实践”

**错误**：计划没提 TypeScript 类型，你因为“最佳实践”就顺手补齐  
**正确**：计划没提类型，你就不加。缺少类型若重要 → 记录为 Gap

超出 scope 的最佳实践 = Gap。

## 红旗

如果你在想这些，立刻停下：

- “我做 X 的时候顺便做一下 Y 吧”
- “这以后肯定需要 Z”
- “计划没写，所以我就……”
- “任何开发都会加……”
- “不加就不完整……”
- “我是在遵循计划的精神……”

**这些都意味着：你即将违反 scope。**

## 文件结构

```
.ai-workflows/YYYYMMDD-task-slug/
├── 00-intent.md                    # 目标（人类编写）
├── 00-intent.changelog.md          # Intent 变更（可选）
├── 00-scope-definition.round1.md   # R1 scope
├── 01-design.round1.md             # R1 设计
├── 02-plan.round1.md               # R1 计划
├── 04-execution-log.round1.md      # R1 过程日志（可选）
├── 05-execution-summary.round1.md  # R1 总结
├── 03-gap-analysis.round1.md       # R1 Gap 分析
├── 00-scope-definition.round2.md   # R2 scope
├── ...                             # R2 文件
└── 99-final-report.md              # 最终总结
```

## 测试状态

**已做 baseline 测试的核心 skills**（有记录的基线行为）：
- ✅ `gdim-scope` - Scope 过载场景
- ✅ `gdim-gap` - 忽略 Gap 的场景
- ✅ `gdim-execute` - “顺手改进”的场景

**其他 skills**：基于 GDIM 文档与常见模式设计。

## 反馈循环

这些 skills 目标是持续迭代改进：

1. 在真实项目中使用
2. 记录失败/不清晰之处
3. 反馈给维护者
4. 基于真实 rationalization 迭代更新

**你的反馈会让这些 skills 变得更好。**

## 参考资料

- 完整 GDIM 规范：[`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md)
- 快速参考指南：[`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)
- 提示词模板：[`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)
- 前端专项约束：[`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)

## 版本

**v1.1.0** - 基于 GDIM v1.5 规范的 Claude Code 插件发布版
