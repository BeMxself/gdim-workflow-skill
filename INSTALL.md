# GDIM Workflow Plugin - 安装指南

## 快速安装（推荐）

在 Claude Code 中把本仓库添加为插件市场（Marketplace）：

```text
/plugin marketplace add BeMxself/gdim-workflow-skill
```

然后安装插件：

```text
/plugin install gdim-workflow@BeMxself-gdim-workflow-skill
```

安装后，所有 `/gdim-*` 命令即可使用（包含 `/gdim-auto`）。

补充说明：
- Codex 中同名 skill 使用 `$gdim-*` 调用（例如 `$gdim-auto docs/design/foo.md`）
- kiro-cli 中通常不使用 `/` 或 `$` 前缀，需在对话里显式要求使用 `gdim-*` / `gdim-auto` skill

## 验证安装

重启 Claude Code 后，输入 `/` 应该能看到：

- `/gdim-init`
- `/gdim-auto`
- `/gdim-intent`
- `/gdim-scope`
- `/gdim-design`
- `/gdim-plan`
- `/gdim-execute`
- `/gdim-summary`
- `/gdim-gap`
- `/gdim-final`

## /gdim-auto 运行依赖（执行阶段）

当你通过 `/gdim-auto` 生成任务目录后，`run.sh` 在终端运行时依赖：

- `jq`
- `timeout`
- `mvn`（仅 Maven 项目需要编译/测试门禁时）
- 执行器二选一或多选：
  - `claude`（runner=claude）
  - `codex`（runner=codex）
  - `kiro-cli`（runner=kiro）

`runner=kiro` 时会在运行前自动检查并确保以下 agent 存在：
- `.kiro/agents/gdim-kiro-opus.json`
- `.kiro/agents/gdim-kiro-sonnet.json`

## Plugin 目录结构

```
gdim-workflow/
├── .claude-plugin/
│   └── plugin.json              # Plugin 元数据
├── skills/                      # Skills 目录
│   ├── gdim/SKILL.md            # 核心规则（自动加载）
│   ├── gdim-init/SKILL.md
│   ├── gdim-auto/SKILL.md
│   ├── gdim-auto/automation-ref/ # /gdim-auto 公共脚本模板（含 run-gdim-*.sh、lib/runner.sh、setup-kiro-agent.sh）
│   ├── gdim-intent/SKILL.md
│   ├── gdim-scope/SKILL.md
│   ├── gdim-design/SKILL.md
│   ├── gdim-plan/SKILL.md
│   ├── gdim-execute/SKILL.md
│   ├── gdim-summary/SKILL.md
│   ├── gdim-gap/SKILL.md
│   ├── gdim-final/SKILL.md
│   └── gdim/references/docs/    # 完整规范文档（随 skills 一起安装）
│       ├── GDIM 规范.md
│       ├── GDIM 实践快速指南.md
│       ├── GDIM 提示词模版.md
│       └── GDIM 提示词模版（前端版）.md
├── README.md
├── REFERENCE.md
├── TESTING.md
├── INSTALL.md
├── DELIVERY.md
├── CHANGELOG.md
└── LICENSE
```

## 完全自包含

这个 plugin 是完全自包含的：
- 包含所有 GDIM 规范文档（`skills/gdim/references/docs/` 目录）
- 包含所有可执行 skills（`skills/` 目录）
- 包含 `/gdim-auto` 所需的公共脚本与模板（`skills/gdim-auto/automation-ref/`）
- 包含使用指南和测试文档
- 无需依赖外部文件

## 更新

在 Claude Code 输入 `/plugin`，在已安装插件列表中选择 `gdim-workflow` 进行更新。

## 卸载

在 Claude Code 输入 `/plugin`，在已安装插件列表中卸载 `gdim-workflow`。

重启 Claude Code 即可。

## 下一步

1. 阅读 `README.md` 了解使用方法
2. 阅读 `skills/gdim/references/docs/GDIM 实践快速指南.md` 学习 GDIM
3. 运行 `TESTING.md` 中的测试场景
4. 在真实项目中使用对应命令前缀（Claude：`/gdim-*`，Codex：`$gdim-*`，kiro-cli：对话显式点名 skill）
