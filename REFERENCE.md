# GDIM Skills - 深度参考指南

## Skills vs 规范文档的关系

### Skills（本目录）
- **目的**: 在 Claude Code 中快速执行 GDIM 工作流
- **优化**: Token 效率、快速查找、可执行性
- **内容**: 核心规则、红旗清单、快速参考表
- **使用**: `/gdim-*` 命令调用
- **Codex 支持**: 每个 skill 均包含 `agents/openai.yaml`，用于 Codex 的技能展示与触发提示

### 规范文档（skills/gdim/references/docs/ 子目录）
- **目的**: 完整的方法论说明和教学
- **优化**: 可读性、完整性、示例丰富
- **内容**: 详细模板、设计理念、适用场景
- **使用**: 学习、参考、定制

<a id="gdim-auto"></a>
## /gdim-auto 自动化执行

`/gdim-auto` 用于**从设计文档自动生成多流程 GDIM 任务目录**，并提供可直接运行的自动化入口。适用于已有设计文档、希望快速拆解并批量执行 GDIM 流程的场景。

### 支持范围
- 仅支持 Claude Code（依赖 AskUserQuestion/Skill 工具）。
- Codex 支持计划中（未来会增强）。

### 运行依赖
- `claude` CLI（自动化执行入口）
- `jq`（解析配置与状态）
- `timeout`（流程超时控制）
- `mvn`（Maven 项目的编译/测试门禁）

### 基本用法

```bash
/gdim-auto path/to/design-doc.md
```

说明：
- 设计文档路径是**相对于项目根目录**的路径。
- 自动化脚本的工作副本会同步到 `automation/ai-coding/`。
- 公共脚本的 source-of-truth 位于 `skills/gdim-auto/automation-ref/`，无需手动修改。

### 生成产物
生成一个任务目录：`.ai-workflows/YYYYMMDD-<task-slug>/`，包含：
- `config/flows.json`：流程定义、依赖关系、允许修改路径
- `00-intent.md`：共享 Intent
- `intents/*.md`：每个流程的 Intent 片段
- `run.sh`：自动化入口脚本
- `state/`、`logs/`：运行状态与日志
- 每个流程的工作目录（以 flow slug 命名）

### 运行方式
在项目根目录执行：

```bash
.ai-workflows/YYYYMMDD-<task-slug>/run.sh
```

常用参数：
- `--only N`：只跑第 N 个流程
- `--from N`：从第 N 个流程开始
- `--dry-run`：预览流程，不执行
- `--unblock <slug>`：解除阻塞流程
- `--stage A|B|C`：覆盖所有流程的执行模式
- `--skip-clean-check`：跳过工作区干净检查（不推荐）

### 速查表

常用命令：

| 命令 | 说明 |
|------|------|
| `.ai-workflows/YYYYMMDD-<task-slug>/run.sh` | 运行全部流程（自动断点恢复） |
| `./run.sh --dry-run` | 预览流程，不执行 |
| `./run.sh --only N` | 仅运行第 N 个流程 |
| `./run.sh --from N` | 从第 N 个流程开始 |
| `./run.sh --unblock <slug>` | 解除阻塞流程 |
| `./run.sh --stage A` | 半自动（每轮人工确认） |
| `./run.sh --stage B` | 全自动（默认） |
| `./run.sh --stage C` | 收敛阶段（更严格） |

关键产物速查：

| 产物 | 作用 |
|------|------|
| `config/flows.json` | 流程定义、依赖、allowed_paths |
| `00-intent.md` | 项目级 Intent（共享） |
| `intents/*.md` | 每个流程的 Intent |
| `run.sh` | 自动化入口脚本 |
| `state/` | 运行状态（断点恢复） |
| `logs/` | 运行日志 |

### 执行行为与约束
- 默认要求 Git 工作区干净（有未提交修改会阻塞）。
- 每个流程可配置 `allowed_paths`，越界修改会触发阻塞。
- 默认进行编译/测试门禁（Maven 项目使用 `mvn compile/test -pl ... -am`）。
- Stage A 需要人工确认继续；Stage B 全自动；Stage C 用于收敛阶段。

### 同步公共脚本（automation/ai-coding）
首次运行会复制 `sync-automation.sh` 到 `automation/ai-coding/`，随后执行同步检查。
如发现差异，会提示是否强制同步（覆盖项目侧脚本）。建议保持项目侧与插件版本一致。

### 示例：从设计文档到自动化目录

示例设计文档片段（路径示例：`docs/design/user-profile.md`）：

```text
# User Profile v1

目标：
- 用户可查看与编辑个人资料（姓名、头像、简介）
- 支持头像上传与基础校验

模块：
- backend/user-profile
- frontends/web

功能拆解建议：
- Flow A：后端 API 与数据模型
- Flow B：前端页面与交互
```

运行：

```bash
/gdim-auto docs/design/user-profile.md
```

生成目录（示例日期：20260224）：

```text
.ai-workflows/20260224-user-profile/
├── config/flows.json
├── 00-intent.md
├── intents/
│   ├── 01-profile-api.md
│   └── 02-profile-ui.md
├── run.sh
├── state/
└── logs/
```

`config/flows.json` 关键片段（示意）：

```json
{
  "project": "user-profile",
  "workflow_dir": ".ai-workflows/20260224-user-profile",
  "design_doc": "docs/design/user-profile.md",
  "flows": [
    {
      "id": 1,
      "slug": "profile-api",
      "intent_file": "01-profile-api.md",
      "depends_on": [],
      "max_rounds": 12,
      "stage": "B",
      "modules": ["backend/user-profile"],
      "allowed_paths": [
        "backend/user-profile/",
        ".ai-workflows/20260224-user-profile/profile-api/",
        ".ai-workflows/20260224-user-profile/00-intent.md"
      ]
    },
    {
      "id": 2,
      "slug": "profile-ui",
      "intent_file": "02-profile-ui.md",
      "depends_on": [1],
      "max_rounds": 12,
      "stage": "B",
      "modules": ["frontends/web"],
      "allowed_paths": [
        "frontends/web/",
        ".ai-workflows/20260224-user-profile/profile-ui/",
        ".ai-workflows/20260224-user-profile/00-intent.md"
      ]
    }
  ]
}
```

常用运行命令（示例）：

```bash
.ai-workflows/20260224-user-profile/run.sh
./run.sh --only 1
./run.sh --dry-run
```

## 何时查阅规范文档

### 1. 学习 GDIM
**首次接触** → 阅读 `skills/gdim/references/docs/GDIM 实践快速指南.md`
- 通俗易懂的介绍
- 生动的比喻和例子
- 常见陷阱和解决方法

**深入理解** → 阅读 `skills/gdim/references/docs/GDIM 规范.md`
- 完整的方法论
- 详细的模板
- 违规判定标准

### 2. 需要完整模板
Skills 提供的是**简化模板**，如果需要：
- 完整的 YAML frontmatter 示例
- 详细的章节结构
- 多种场景的模板变体

→ 查阅 `skills/gdim/references/docs/GDIM 提示词模版.md`

### 3. 前端项目
Skills 是通用版本，前端项目有特殊约束：
- UI/交互/状态的特殊 Gap 分类
- 前端特有的"假完成"问题
- 组件级别的 Scope 定义

→ 查阅 `skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`

### 4. 定制工作流
想修改 GDIM 流程以适应团队需求：
- 理解每个阶段的设计理念
- 了解哪些是核心约束（不可变）
- 了解哪些是推荐实践（可调整）

→ 查阅 `skills/gdim/references/docs/GDIM 规范.md` 的"模型定位"和"核心规则"章节

## 规范文档快速索引

### GDIM 规范.md
| 章节 | 内容 | 何时查阅 |
|------|------|---------|
| §1 模型定位 | 职责划分、适用场景 | 判断是否适合用 GDIM |
| §2 核心规则 | Gap 定义、迭代驱动 | 理解基本原则 |
| §3 工作流 | 流程图、阶段说明 | 理解整体流程 |
| §4 Gap Analysis 双层结构 | Round Gap vs Intent Coverage | 写 Gap Analysis 时 |
| §5 Gap 分类 | G1-G6 类型定义 | 分类 Gap 时 |
| §6 文件规范 | 目录结构、文件职责 | 设置工作流目录时 |
| §7 模板 | Intent、Scope、Design 等 | 需要完整模板时 |
| §8 外部输入类型 | 不同任务类型的 Intent 提取 | 从外部文档提取 Intent 时 |
| §9 Round 规模 | R0-Rn 的规模建议 | 规划 Round 大小时 |
| §10 违规判定 | Scope/设计/禁止行为 | 判断是否违规时 |

### GDIM 实践快速指南.md
| 章节 | 内容 | 何时查阅 |
|------|------|---------|
| 一、谁干什么 | 角色分工 | 理解人类 vs AI 职责 |
| 二、什么时候该用 | 适用场景 | 判断项目是否适合 |
| 四、两个最重要的概念 | Scope 和 Gap 的比喻 | 理解核心机制 |
| 五、Gap 的六种类型 | G1-G6 + 例子 | 分类 Gap 时 |
| 九、踩坑指南 | 常见翻车场景 | 遇到问题时 |
| 十、三种违规行为 | 违规类型 + 后果 | 判断违规时 |

### GDIM 提示词模版.md
| 模板 | 用途 | 何时使用 |
|------|------|---------|
| §0 Intent Refinement | Intent 生成 | 需要详细的 Intent 生成流程 |
| §1-2 Scope Definition | R1/RN Scope | 需要完整的 Scope 模板 |
| §3-4 Design | R1/RN Design | 需要完整的 Design 模板 |
| §5 Design Review | 设计审查 | 需要设计审查流程 |
| §6 Plan | 执行计划 | 需要完整的 Plan 模板 |
| §7 Execution Summary | 执行总结 | 需要详细的 Summary 要求 |
| §8-9 Gap Analysis | Gap 分析 | 需要完整的 Gap Analysis 模板 |
| §10 Final Report | 最终报告 | 需要完整的 Final Report 模板 |

### GDIM 提示词模版（前端版）.md
| 特化内容 | 用途 | 何时使用 |
|---------|------|---------|
| 前端 Intent 必须明确项 | 用户角色、交互路径、复杂度 | 前端项目定义 Intent |
| 前端 Scope 限速升级版 | 禁止完整用户流程、状态联动 | 前端项目定义 Scope |
| 前端 Gap 分类 | UI/Interaction/State/Integration Gap | 前端项目 Gap 分析 |
| 前端执行总结要求 | 真实渲染、假数据、临时 mock | 前端项目写 Summary |

### GDIM 层级化扩展.md
| 内容 | 用途 | 何时使用 |
|------|------|---------|
| Macro/Micro 层级定义 | 总体 vs 子任务 | 大型项目拆解 |
| Gap 层级作用域 | Macro/Micro/Escalated | 跨层级 Gap 管理 |
| Gap 流动规则 | 层级间 Gap 传播 | Gap 影响多个子任务时 |
| 文件命名规范 | macro/micro 文件命名 | 层级化项目文件组织 |

## 实践建议

### 初学者路径
1. 读 `skills/gdim/references/docs/GDIM 实践快速指南.md`（30 分钟）
2. 用 skills 跑一个小项目（2-3 小时）
3. 遇到问题时查阅 `skills/gdim/references/docs/GDIM 规范.md` 对应章节

### 熟练使用者
1. 日常工作只用 skills（`/gdim-*` 命令）
2. 遇到边界情况时查阅规范文档
3. 定制工作流时参考规范的设计理念

### 团队推广
1. 让团队读 `skills/gdim/references/docs/GDIM 实践快速指南.md`
2. 提供 skills 作为执行工具
3. 建立团队的 GDIM 最佳实践文档（基于规范定制）

## Skills 的设计权衡

### 为什么 Skills 不包含完整模板？

**Token 效率**：
- Skills 会加载到每个会话
- 完整模板 300+ 行会消耗大量 token
- Skills 提供"够用"的模板，详细版在规范文档

**可读性**：
- Skills 优化为"快速查找"
- 规范文档优化为"完整理解"
- 两者互补，不重复

**维护性**：
- Skills 是"执行版"，变化少
- 规范文档是"教学版"，可以详细扩展
- 分离关注点

### 何时需要查阅规范？

**Skills 够用的场景**（90%）：
- 标准的 GDIM 工作流
- 常见的 Gap 类型
- 典型的违规场景

**需要查阅规范的场景**（10%）：
- 边界情况判断
- 定制工作流
- 教学和推广
- 深入理解设计理念

## 总结

**Skills = 执行工具**（快、精简、可调用）
**规范 = 知识库**（全、详细、可学习）

两者配合使用，效果最佳。
