# 更新日志

## v1.6.0 - 2026-03-05

### /gdim-auto 轮次提交纪律与重试体系升级

- 新增“每轮代码必须提交”硬校验（默认开启，支持 `--no-enforce-round-code-commit` 关闭）：
  - 质量门禁新增 `commit_missing` 失败类型
  - 当检测到本轮代码未提交时，自动进入定向 retry
- 新增 `templates/retry/commit-missing.md`，要求 agent 仅修复提交问题并生成符合轮次标记的提交信息。
- Gap 阶段提示词增强：明确要求本轮末尾执行 `git add + git commit`，且提交信息需包含 `gdim(<flow>): R<round>`。
- `retry_limits` 默认值升级为 `5/5/5`（compile/test/malformed），并新增 `commit_missing: 5`。
- 重试计数改为按失败类型独立统计（compile/test/malformed/commit 各自计数），避免跨类型串扰。
- 修复 `FINAL_REPORT` 产物提交流程：`99-final-report.md` 纳入自动提交，且 final 阶段后补一次文档自动提交，避免后续 flow 因工作区不干净被阻塞。

### 测试补充

- 新增并通过：
  - `test-enforce-round-code-commit-retry.sh`
  - `test-retry-default-5-and-independent-counts.sh`
  - `test-final-report-auto-commit-keeps-workspace-clean.sh`

## v1.5.10 - 2026-03-05

### /gdim-auto FINAL_REPORT 收敛阶段强化

- 当 `gap-analysis` 明确给出 `GDIM_EXIT_DECISION: FINAL_REPORT` 时，`run-gdim-round.sh` 会在结束当前 flow 前强制执行一次 `gdim-final`。
- `gdim-final` 输入文件清单收敛为：`Intent + 各轮 gap-analysis`。
- Final 阶段提示词新增约束：必要时可读取其他过程文件补充事实，但无需在最终报告中枚举这些文件名。
- 新增回归测试：`test-gap-final-decision-triggers-gdim-final-stage.sh`，覆盖 FINAL_REPORT 触发 final 阶段与输入注入约束。

## v1.5.9 - 2026-03-05

### /gdim-auto Kiro skills 同步与 resources 路径调整

- `setup-kiro-agent.sh --ensure` 的 skills 同步目标从项目内 `.kiro/skills/` 调整为用户级 `~/.kiro/skills/`。
- 自动生成/修复的 Kiro agent 资源路径改为：
  - `skill://~/.kiro/skills/gdim/SKILL.md`
  - `skill://~/.kiro/skills/gdim-*/SKILL.md`
  - `skill://~/.kiro/skills/**/SKILL.md`
- 对应校验逻辑、README/REFERENCE 与 `gdim-auto` skill 文档同步更新，明确要求保证相关 skills 在 `~/.kiro/skills` 下。
- 修复 path whitelist 比对中的 `xargs` 引号解析问题，避免中文/带引号路径触发 `xargs: unterminated quote` 噪音。
- `STALLED` 默认阈值由 2 提升为 5，支持通过 `--stall-limit N`（或 `GDIM_STALL_LIMIT`）覆盖。
- 调整收敛逻辑：`GDIM_EXIT_DECISION: FINAL_REPORT` 与“无新 commit”不再互斥，显式 FINAL_REPORT 将直接收敛。
- 默认开启每轮 GDIM 文档自动提交（scope/design/plan/summary/gap 等）；支持 `--no-auto-commit-gdim-docs` 或 `GDIM_AUTO_COMMIT_GDIM_DOCS=0` 关闭。

### 测试补充与调整

- 更新并通过：
  - `test-setup-kiro-agent-defaults.sh`
  - `test-setup-kiro-agent-ensure-syncs-skills.sh`
  - `test-setup-kiro-agent-ensure-finds-home-skills.sh`
  - `test-setup-kiro-agent-copied-script-default-root.sh`
  - `test-stall-limit-default-and-flag.sh`
  - `test-gap-final-decision-closes-no-commit-with-modules.sh`
  - `test-auto-commit-gdim-docs-default.sh`

## v1.5.8 - 2026-03-05

### /gdim-auto setup-kiro-agent 默认项目根目录修复

- 修复 `setup-kiro-agent.sh` 在“脚本被拷贝到项目目录后直接执行”场景下的默认 `PROJECT_ROOT` 误判：
  - 默认优先使用 Git 根目录
  - 兼容 `automation/ai-coding` 打包布局
  - 非打包布局回退到脚本所在目录
- 避免 `--ensure` 将 `.kiro/agents` 与 `.kiro/skills` 写入错误路径（如临时目录上级）。

### 测试补充

- 新增并通过：
  - `test-setup-kiro-agent-copied-script-default-root.sh`

## v1.5.7 - 2026-03-04

### /gdim-auto 阶段输入文件硬校验

- `run-gdim-round.sh` 新增阶段输入 precheck：
  - 每阶段执行前校验必需输入文件是否存在（如 design 依赖 scope+intent+design source，execute 依赖 plan 等）
  - 缺失时立即标记 `BLOCKED`，不再继续后续阶段
- `lib/prompt-builder.sh` 增加阶段文件路径占位符注入（scope/design/plan/summary/gap 等）

### Kiro skills 源发现增强

- `setup-kiro-agent.sh --ensure` 的 skills 源发现新增目录扫描 fallback（含 `~/.claude/plugins` 等），提升脚本拷贝到项目目录后的可用性

### 测试补充

- 新增并通过：
  - `test-stage-input-precheck-blocks-missing-files.sh`
  - `test-stage-prompts-inject-required-files.sh`
  - `test-setup-kiro-agent-ensure-finds-home-skills.sh`

## v1.5.6 - 2026-03-04

### /gdim-auto 阶段提示词按规范细化

- `run-gdim-round.sh` 改为按阶段读取 `templates/stages/<stage>.md.tpl`，不再使用单一 round 模板
- 新增 6 个阶段模板：`scope/design/plan/execute/summary/gap`
- 各阶段模板新增“必读输入文件”注入，按 GDIM 规范明确阶段输入依赖：
  - design: 注入 intent + scope + 设计来源文档
  - plan: 注入 design
  - execute: 注入 plan + design + scope
  - summary: 注入 design + plan + execution log
  - gap: 注入 intent + design + summary + scope

### 测试补充

- 新增并通过：
  - `test-round-uses-stage-specific-templates.sh`
  - `test-stage-prompts-inject-required-files.sh`

## v1.5.5 - 2026-03-04

### /gdim-auto 单阶段提示词收敛

- `templates/round-prompt.md.tpl` 移除整轮六阶段说明，避免阶段会话被误导为一次执行整轮
- 增加强约束：每次会话仅允许执行 `{{CURRENT_STAGE_CMD}}`，禁止调用其他 `/gdim-*`

## v1.5.4 - 2026-03-04

### /gdim-auto 清理未生效规则注入模板

- 删除未被 prompt 模板引用的 `templates/gdim-rules-injection.md`
- 移除 `run-gdim-round.sh` 与 `lib/prompt-builder.sh` 中对应的无效注入参数链路
- 同步更新 `sync-automation.sh` 与 `test-sync-copies-missing-by-default.sh` 文件清单

## v1.5.3 - 2026-03-04

### /gdim-auto Kiro 预检查自动同步 skills

- `setup-kiro-agent.sh --ensure` 新增 GDIM skills 自动同步：
  - 自动将 gdim 系列 skills 同步到 `.kiro/skills/`
  - 新增 `GDIM_SKILLS_SOURCE_DIR` 环境变量，可显式指定 skills 源目录
- 保持原有 agent 生成/修复逻辑不变（`gdim-kiro-opus` / `gdim-kiro-sonnet`）

### 测试补充

- 新增并通过：
  - `test-setup-kiro-agent-ensure-syncs-skills.sh`

## v1.5.2 - 2026-03-04

### /gdim-auto 每阶段独立会话执行

- `run-gdim-round.sh` 执行模型调整为“同一 round 内按阶段独立会话”：
  - 按 `scope → design → plan → execute → summary → gap` 顺序逐阶段调用 runner
  - 每阶段单独生成会话 prompt 与日志文件（`${flow}-R${round}-${stage}.log`）
- phase checkpoint 刷新粒度提升：
  - 每阶段完成后立即更新 phase 状态，异常中断后可从下一个未通过阶段恢复
- runner 事件明细增强：
  - `runner_invoking/runner_completed/runner_failed` 事件 detail 增加 `stage` 字段

### 文档与测试

- 更新 `skills/gdim-auto/SKILL.md` / `REFERENCE.md` / `templates/round-prompt.md.tpl` / `templates/gdim-rules-injection.md`：
  - 明确每轮每阶段独立会话执行语义
- 新增并通过自动化测试：
  - `test-round-runs-stage-by-stage-sessions.sh`

## v1.5.1 - 2026-03-03

### /gdim-auto Gap 退出判定稳定性增强

- Gap Analysis 提示词中新增强制机器决策标记（单独一行，严格格式）：
  - `GDIM_EXIT_DECISION: CONTINUE`
  - `GDIM_EXIT_DECISION: FINAL_REPORT`
  - `GDIM_EXIT_DECISION: BLOCKED`
- `lib/validate.sh` 判定逻辑升级：
  - 优先解析 `GDIM_EXIT_DECISION` 显式标记
  - 自然语言 `Decision` 作为兼容回退，降低不同模型表述造成的误判。
- `run-gdim-round.sh` 收敛逻辑增强：
  - 当 Gap 明确给出 `FINAL_REPORT` 且当前轮无新 commit 时，若已有执行进展（或纯文档流）可直接收敛，避免反复开启新轮次。

### 测试补充

- 新增并通过：
  - `test-gap-explicit-marker-priority-final.sh`
  - `test-gap-final-decision-closes-round.sh`
  - `test-gap-final-decision-closes-with-prior-execute-no-new-commit.sh`
  - `test-gap-blocked-keyword-does-not-force-block.sh`

## v1.5.0 - 2026-03-03

### /gdim-auto 测试门禁可配置

- 新增 `--skip-tests` 参数（`run-gdim-flows.sh` / `run-gdim-round.sh`）：
  - 跳过 `mvn test` 门禁
  - 保留 `mvn compile`、`path whitelist`、GDIM 文档完整性检查
- 新增环境变量 `GDIM_SKIP_TESTS=1`（等效于 `--skip-tests`），便于批量执行或 CI 场景统一控制。
- 日志增强：启用该模式时会显式输出测试门禁已跳过，避免长时间“无反馈”误判。

### 文档与测试

- 更新 `README.md` / `README.en.md` / `REFERENCE.md` / `skills/gdim-auto/SKILL.md`：
  - 增补 `--skip-tests` 用法与适用场景说明。
- 新增并通过自动化测试：
  - `test-skip-tests-flag.sh`

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
