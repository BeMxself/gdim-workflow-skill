# GDIM Skills - 深度参考指南

## Skills vs 规范文档的关系

### Skills（本目录）
- **目的**: 在 Claude Code 中快速执行 GDIM 工作流
- **优化**: Token 效率、快速查找、可执行性
- **内容**: 核心规则、红旗清单、快速参考表
- **使用**: `/gdim-*` 命令调用

### 规范文档（skills/gdim/references/docs/ 子目录）
- **目的**: 完整的方法论说明和教学
- **优化**: 可读性、完整性、示例丰富
- **内容**: 详细模板、设计理念、适用场景
- **使用**: 学习、参考、定制

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
