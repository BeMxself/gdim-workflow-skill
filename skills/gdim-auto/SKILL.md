---
name: gdim-auto
description: Use when starting automated GDIM execution from a design document. Analyzes the document, splits it into multiple GDIM flows, generates task directory with configs and entry script.
user_invocable: true
argument: "<design-doc-path>"
---

# GDIM Auto — 从设计文档生成自动执行环境

你是 GDIM 自动化任务生成器。用户提供一个设计文档路径，你需要：
1. 同步公共脚本
2. 分析设计文档并拆解为多个 GDIM 流程
3. 生成任务目录和所有配置文件
4. 输出启动/恢复指引

## 输入

用户通过 `/gdim-auto <design-doc-path>` 调用。`<design-doc-path>` 是相对于项目根目录的设计文档路径。

## 执行步骤

### Step 0: 定位路径

在执行任何操作前，先确定两个关键路径：

- **PROJECT_ROOT**: 当前工作目录（即用户运行 Claude Code 的项目根目录）
- **SKILL_DIR**: 本 skill 所在目录。不要硬编码某个 agent 的插件目录，按以下顺序自动发现：
  ```bash
  # 0) 可选显式覆盖（便于 CI/调试）
  if [ -n "${GDIM_AUTO_SKILL_DIR:-}" ] && [ -f "${GDIM_AUTO_SKILL_DIR}/SKILL.md" ]; then
    SKILL_DIR="$(cd "${GDIM_AUTO_SKILL_DIR}" && pwd)"
  else
    # 1) 常见安装位置优先（项目级 / 用户级）
    CANDIDATES=(
      "${PROJECT_ROOT}/skills/gdim-auto/SKILL.md"
      "${PROJECT_ROOT}/.claude/skills/gdim-auto/SKILL.md"
      "${PROJECT_ROOT}/.agents/skills/gdim-auto/SKILL.md"
      "${PROJECT_ROOT}/.kiro/skills/gdim-auto/SKILL.md"
      "${PROJECT_ROOT}/.codex/skills/gdim-auto/SKILL.md"
      "${HOME}/.claude/skills/gdim-auto/SKILL.md"
      "${HOME}/.agents/skills/gdim-auto/SKILL.md"
      "${HOME}/.kiro/skills/gdim-auto/SKILL.md"
      "${HOME}/.codex/skills/gdim-auto/SKILL.md"
      "${CODEX_HOME:-${HOME}/.codex}/skills/gdim-auto/SKILL.md"
    )

    SKILL_FILE=""
    for p in "${CANDIDATES[@]}"; do
      if [ -f "$p" ]; then
        SKILL_FILE="$p"
        break
      fi
    done

    # 2) fallback 扫描常见根目录（包含 Claude 插件缓存/安装目录）
    if [ -z "$SKILL_FILE" ]; then
      SEARCH_ROOTS=(
        "${PROJECT_ROOT}"
        "${HOME}/.claude/plugins"
        "${HOME}/.claude"
        "${HOME}/.agents"
        "${HOME}/.kiro"
        "${HOME}/.codex"
        "${CODEX_HOME:-${HOME}/.codex}"
      )
      for root in "${SEARCH_ROOTS[@]}"; do
        [ -d "$root" ] || continue
        found=$(find "$root" -type f -path "*/gdim-auto/SKILL.md" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
          SKILL_FILE="$found"
          break
        fi
      done
    fi

    [ -z "$SKILL_FILE" ] && echo "gdim-auto SKILL.md not found; check skill installation path for current agent." && exit 1
    SKILL_DIR="$(cd "$(dirname "$SKILL_FILE")" && pwd)"
  fi
  ```
  如果找不到，提示用户检查当前 agent 的 skill 安装目录（`.claude/skills`、`.agents/skills`、`.kiro/skills` 等）。

由此得出：
- **REFERENCE_DIR**: `${SKILL_DIR}/automation-ref` — 公共脚本的 source-of-truth
- **TARGET_DIR**: `${PROJECT_ROOT}/automation/ai-coding` — 项目中的公共脚本工作副本

### Step 1: 同步公共脚本

首先检查 `${TARGET_DIR}/sync-automation.sh` 是否存在：
- 不存在 → 用 Bash 工具从 REFERENCE_DIR 拷贝：
  ```bash
  mkdir -p automation/ai-coding
  cp "${REFERENCE_DIR}/sync-automation.sh" automation/ai-coding/sync-automation.sh
  chmod +x automation/ai-coding/sync-automation.sh
  ```

然后用 Bash 工具运行同步检查：

```bash
bash automation/ai-coding/sync-automation.sh "${REFERENCE_DIR}" automation/ai-coding
```

根据输出和退出码处理：

- **退出码 0**：所有脚本一致，继续 Step 2
- **退出码 1**：有不一致或缺失的文件。将脚本输出中的 `[DIFF]` 和 `[MISS]` 行展示给用户，然后用 **AskUserQuestion** 询问：
  - "以下公共脚本与插件参考版本不一致：\n{列出 DIFF/MISS 文件}\n是否强制同步（用插件版本覆盖项目中的副本）？"
  - 选项：「强制同步」/「跳过，使用现有版本」
  - 用户选择强制同步 → 用 Bash 工具重新运行：
    ```bash
    bash automation/ai-coding/sync-automation.sh "${REFERENCE_DIR}" automation/ai-coding --auto-copy
    ```
    这会将参考副本强制拷贝覆盖到项目中
  - 用户选择跳过 → 继续（使用现有脚本，可能存在版本差异）

**注意**：所有用户交互必须通过 AskUserQuestion 工具完成，不能依赖 shell 的 stdin/TTY 输入。

### Step 2: 分析设计文档

读取 `<design-doc-path>` 的完整内容，提取以下信息：

1. **项目名称和 slug**：从文档标题或内容推断，slug 用于目录命名（小写、连字符分隔）
2. **涉及的模块列表**：Maven 模块路径（如 `security/ouroboros-web-security`）
3. **功能分组**：将设计文档拆解为独立的 GDIM 流程，每个流程应：
   - 有明确的功能边界
   - 可独立编译和测试
   - 复杂度适中（每个流程 1-4 轮可完成）
4. **流程间依赖关系**：哪些流程必须在其他流程之后执行
5. **每个流程的 scope**：涉及的模块、allowed_paths、success criteria

#### 拆解原则

- 基础设施/前置条件作为第一个流程
- 核心功能按独立性拆分
- 有共同依赖的流程可以并行（depends_on 相同）
- 集成/非功能性需求放在最后
- 每个流程的 max_rounds 默认 12，stage 默认 "B"
- 最后一个流程（集成/收尾）stage 设为 "C"

### Step 3: 生成任务目录

任务目录路径：`.ai-workflows/<YYYYMMDD>-<task-slug>/`

其中 `<YYYYMMDD>` 是当天日期，`<task-slug>` 是从设计文档推断的 slug。

#### 3.1 生成 `config/flows.json`

```json
{
  "project": "<task-slug>",
  "workflow_dir": ".ai-workflows/<YYYYMMDD>-<task-slug>",
  "design_doc": "<design-doc-path>",
  "execution": {
    "runner": "claude",
    "kiro_agent": "gdim-kiro-opus",
    "kiro_model": "opus"
  },
  "runners": {
    "claude": { "command": "" },
    "codex": { "command": "" },
    "kiro": { "command": "", "agent": "gdim-kiro-opus" }
  },
  "retry_limits": {
    "compile_failed": 2,
    "test_failed": 2,
    "malformed_output": 1
  },
  "flows": [
    {
      "id": 1,
      "slug": "<flow-slug>",
      "intent_file": "01-<flow-slug>.md",
      "depends_on": [],
      "max_rounds": 12,
      "stage": "B",
      "runner": "claude",
      "runner_cmd": "",
      "kiro_agent": "gdim-kiro-opus",
      "modules": ["<module-path>"],
      "allowed_paths": [
        "<module-path>/",
        ".ai-workflows/<YYYYMMDD>-<task-slug>/<flow-slug>/",
        ".ai-workflows/<YYYYMMDD>-<task-slug>/00-intent.md"
      ]
    }
  ]
}
```

#### 3.2 生成 `00-intent.md`（共享 Intent）

从设计文档提取项目级 Intent，包含：
- 项目目标
- 整体架构决策
- 技术约束
- 质量要求

格式遵循 GDIM Intent 规范（参考 `/gdim-intent` skill）。

#### 3.3 生成 `intents/<NN>-<flow-slug>.md`（每个流程的 Intent 片段）

每个流程一个 intent 文件，包含：
- 该流程的具体目标
- 涉及的模块和类
- Success criteria
- Hard constraints
- 与其他流程的接口约定

#### 3.4 生成 `run.sh`（入口脚本）

```bash
#!/usr/bin/env bash
# Auto-generated by /gdim-auto skill
# Task: <task-slug>
# Design doc: <design-doc-path>
# Generated: <YYYY-MM-DD>
set -euo pipefail

TASK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TASK_DIR/../.." && pwd)"
AUTOMATION_DIR="${PROJECT_ROOT}/automation/ai-coding"

if [ ! -f "${AUTOMATION_DIR}/run-gdim-flows.sh" ]; then
    echo "ERROR: automation/ai-coding/ public scripts not found. Run /gdim-auto to sync." >&2
    exit 1
fi

exec "${AUTOMATION_DIR}/run-gdim-flows.sh" --task-dir "$TASK_DIR" "$@"

# Usage:
#   Start all flows:     ./run.sh
#   Only flow N:         ./run.sh --only N
#   Start from flow N:   ./run.sh --from N
#   Resume (auto):       ./run.sh                    (resumes from last checkpoint)
#   Unblock a flow:      ./run.sh --unblock <slug>
#   Dry-run preview:     ./run.sh --dry-run
#   Semi-auto mode:      ./run.sh --stage A
#   Use codex runner:    ./run.sh --runner codex
#   Use kiro runner:     ./run.sh --runner kiro --kiro-agent gdim-kiro-sonnet
#   Custom executor cmd: ./run.sh --runner custom --runner-cmd 'my-runner --stdio'
```

生成后执行 `chmod +x` 使其可执行。

#### 3.5 创建空目录

- `state/` — 运行时状态，创建 `.gitignore` 内容为 `*\n!.gitignore`
- `logs/` — 执行日志，创建 `.gitignore` 内容为 `*\n!.gitignore`
- 每个流程的子目录（如 `<flow-slug>/`）— 空目录，GDIM 产出运行时填充

### Step 4: 输出指引

生成完成后，向用户输出以下信息：

```
✅ GDIM 自动执行环境已生成

📁 任务目录: .ai-workflows/<YYYYMMDD>-<task-slug>/
📄 设计文档: <design-doc-path>
🔄 流程数量: N 个

流程列表:
  #1 <flow-slug> (depends: none)
  #2 <flow-slug> (depends: #1)
  ...

启动方式:
  cd <project-root>
  .ai-workflows/<YYYYMMDD>-<task-slug>/run.sh

常用命令:
  ./run.sh                    # 启动全部流程（自动断点恢复）
  ./run.sh --dry-run          # 预览模式
  ./run.sh --only 1           # 只跑第 1 个流程
  ./run.sh --from 3           # 从第 3 个流程开始
  ./run.sh --unblock <slug>   # 解除阻塞
  ./run.sh --stage A          # 半自动模式（每轮人工确认）
  ./run.sh --runner codex     # 使用 codex 执行器
  ./run.sh --runner kiro --kiro-agent gdim-kiro-opus   # 使用 kiro + 指定 agent
  ./run.sh --runner custom --runner-cmd '<your command>' # 自定义执行器命令
```

## 注意事项

- 不要修改 `automation/ai-coding/` 下的公共脚本内容（除非 sync 检测到需要更新）
- `flows.json` 中的 `allowed_paths` 必须包含流程的工作流目录和涉及的模块目录
- Intent 文件应该足够详细，让自动化 agent 能独立完成每个流程
- 当 runner=kiro 时，运行前会自动检查并确保存在 `gdim-kiro-opus` 与 `gdim-kiro-sonnet` 两个 agent（包含 gdim skills 资源）
- 如果设计文档内容不足以拆解为多个流程，可以只生成一个流程
- 生成的所有文件使用 UTF-8 编码
- 不要自动执行工作流；只输出启动指引，后续由用户在终端手动运行
