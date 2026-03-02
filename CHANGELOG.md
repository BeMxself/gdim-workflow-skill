# 更新日志

## v1.4.0 - 2026-03-02

### /gdim-auto 执行与恢复增强

- `run-gdim-round.sh` 新增 runner 心跳日志：
  - 周期输出 `Runner still running... elapsed=<N>s`
  - 支持 `GDIM_HEARTBEAT_SECONDS` 配置（`0` 可关闭）
- `path_violation` 默认自动扩展 `allowed_paths`（按越界文件目录前缀），避免因该类型失败直接 BLOCK。
- 断点恢复增强：
  - 当同一 round 的 phase checkpoint 全部为 `passed` 时，自动跳过 runner，直接从 quality gates 继续。
- 状态记录增强：
  - `state/<flow>/round-state.json` 增加细颗粒度 `events` 与 `last_event`，记录 round/runner/gates/retry/block 等关键事件。

### 文档更新

- 更新 `README.md` / `README.en.md` / `REFERENCE.md` / `INSTALL.md` / `TESTING.md` / `DELIVERY.md`：
  - 明确 `gdim-auto` 在 Claude/Codex/kiro-cli 的触发方式
  - 明确 Codex 的 `$gdim-*` 用法与 `~/.codex/skills` 安装路径
  - 补充 path_violation 自动扩范围与细颗粒度状态记录说明

### 测试补充

- 新增并通过：
  - `test-runner-heartbeat-log.sh`
  - `test-path-violation-auto-expand-no-block.sh`
  - `test-round-state-granular-progress-events.sh`
  - `test-resume-skips-runner-when-phases-passed.sh`

## v1.3.0 - 2026-03-02

### /gdim-auto 多执行器支持

- `run-gdim-flows.sh` / `run-gdim-round.sh` 新增执行器参数：
  - `--runner` / `--executor`
  - `--runner-cmd`
  - `--kiro-agent`
- 自动化执行支持 `claude` / `codex` / `kiro` / 自定义命令。

### Kiro Agent 预检查与自动创建

- 新增 `automation-ref/setup-kiro-agent.sh`：
  - 默认确保并创建 `gdim-kiro-opus`（`claude-opus-4.6`）
  - 默认确保并创建 `gdim-kiro-sonnet`（`claude-sonnet-4.5`）
- `runner=kiro` 时自动执行 agent 预检查，缺失或不符合要求时自动修复（`--ensure` 语义）。

### 文档与测试更新

- 更新 `README.md` / `README.en.md` / `REFERENCE.md` / `INSTALL.md` / `TESTING.md`：
  - 明确 `/gdim-auto` 命令与执行脚本的支持边界
  - 增补多执行器与 Kiro 双 agent 行为说明
  - 增补多执行器 dry-run 与 Kiro agent 自检测试场景
- `skills/gdim-auto/SKILL.md` 的路径定位改为“自动发现”：
  - 不再硬编码 `~/.claude/plugins`
  - 支持按当前 agent 环境从 `.claude/.agents/.kiro` 等目录解析 skill 位置
- 修复 `sync-automation.sh`：
  - 目标目录缺失文件默认自动复制（不再仅报 `[MISS]`）
  - 仅对内容差异文件（`[DIFF]`）保留人工确认/`--auto-copy` 覆盖流程
- 增加执行器字段兼容：
  - 顶层 `executor` 兼容映射到 `execution.runner`
  - `flows[].executor` 兼容映射到 `flows[].runner`
- 默认恢复粒度升级为 phase 级：
  - 同一轮次重跑时，若已存在 phase checkpoint，会从首个未通过 phase 继续（而非整轮从头）

## v1.2.2 - 2026-02-24

### /gdim-auto 行为约束

- 明确禁止自动执行工作流，仅输出启动指引，后续由用户在终端手动运行

## v1.2.1 - 2026-02-24

### /gdim-auto 自动化执行

- 新增 `/gdim-auto` skill：从设计文档生成多流程自动化任务目录
- 自动化公共脚本迁移到 `skills/gdim-auto/automation-ref/`（随插件分发）
- 完善 README/REFERENCE/INSTALL/TESTING/DELIVERY 的 `/gdim-auto` 说明与依赖

## v1.2.0 - 2026-02-14

### Codex 技能支持增强

- 每个 skill 新增 `agents/openai.yaml`，补充 Codex 展示与默认调用元数据
- 根据 Codex 官方 skills 文档，更新 README 中的 Codex 安装路径为 `$HOME/.agents/skills`
- 补充项目级安装方式（在目标项目创建 `.agents/skills/` 并同步 skills）
- 补充 Codex 使用说明：自动触发、按名称显式调用、`/skills` 查看已加载技能

### 技能资源可移植性增强

- 将完整规范文档移动到 `skills/gdim/references/docs/`，随 skills 一起分发
- 更新 `gdim` 核心技能与配套文档中的引用路径，避免对仓库根目录 `docs/` 的依赖

---

## v1.1.0 - 2026-02-11

### Plugin 化

- 重构为 Claude Code Plugin 格式
- 添加 `.claude-plugin/plugin.json` 元数据
- Skills 移至 `skills/` 目录（符合 plugin 标准结构）
- 支持通过 Claude Code `/plugin marketplace add` + `/plugin install` 安装
- 添加 MIT LICENSE
- 更新 INSTALL.md 为 plugin 安装指南
- 更新 README.md 为 plugin 说明

---

## v1.0.1 - 2026-02-10

### 移除内容
- ❌ 删除 `docs/GDIM 层级化扩展.md` - 该部分仍在完善中，暂不包含

### 更新内容
- ✅ 更新所有文档中对层级化扩展的引用
- ✅ `README.md` - 移除层级化扩展相关说明
- ✅ `REFERENCE.md` - 移除层级化扩展章节
- ✅ `DELIVERY.md` - 标注不包含层级化扩展
- ✅ `INSTALL.md` - 更新目录结构示例

### 当前包含的文档

**Skills（10个）**：
- gdim（核心规则）
- gdim-init
- gdim-intent
- gdim-scope
- gdim-design
- gdim-plan
- gdim-execute
- gdim-summary
- gdim-gap
- gdim-final

**规范文档（4个）**：
- GDIM 规范.md
- GDIM 实践快速指南.md
- GDIM 提示词模版.md
- GDIM 提示词模版（前端版）.md

**支持文档（5个）**：
- README.md
- REFERENCE.md
- TESTING.md
- INSTALL.md
- DELIVERY.md

### 总文件数
- 10 个 skills
- 4 个规范文档
- 5 个支持文档
- **总计 19 个文件**

---

## v1.0.0 - 2026-02-10

### 初始发布
- ✅ 10 个核心 GDIM skills
- ✅ 完整规范文档（包含在 docs/ 目录）
- ✅ 3 个核心 skills 的 baseline 测试
- ✅ 完整的使用指南和测试文档
- ✅ 完全自包含，无外部依赖
