# GDIM Workflow Plugin - 安装指南

## 快速安装（推荐）

### 方式 1：从本地路径安装

```bash
claude plugin add /path/to/gdim-workflow
```

### 方式 2：从 Git 仓库安装

```bash
claude plugin add https://github.com/songmingxu/gdim-workflow.git
```

安装后重启 Claude Code，所有 `/gdim-*` 命令即可使用。

## 验证安装

重启 Claude Code 后，输入 `/` 应该能看到：

- `/gdim-init`
- `/gdim-intent`
- `/gdim-scope`
- `/gdim-design`
- `/gdim-plan`
- `/gdim-execute`
- `/gdim-summary`
- `/gdim-gap`
- `/gdim-final`

## Plugin 目录结构

```
gdim-workflow/
├── .claude-plugin/
│   └── plugin.json              # Plugin 元数据
├── skills/                      # Skills 目录
│   ├── gdim/SKILL.md            # 核心规则（自动加载）
│   ├── gdim-init/SKILL.md
│   ├── gdim-intent/SKILL.md
│   ├── gdim-scope/SKILL.md
│   ├── gdim-design/SKILL.md
│   ├── gdim-plan/SKILL.md
│   ├── gdim-execute/SKILL.md
│   ├── gdim-summary/SKILL.md
│   ├── gdim-gap/SKILL.md
│   └── gdim-final/SKILL.md
├── docs/                        # 完整规范文档
│   ├── GDIM 规范.md
│   ├── GDIM 实践快速指南.md
│   ├── GDIM 提示词模版.md
│   └── GDIM 提示词模版（前端版）.md
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
- 包含所有 GDIM 规范文档（`docs/` 目录）
- 包含所有可执行 skills（`skills/` 目录）
- 包含使用指南和测试文档
- 无需依赖外部文件

## 更新

```bash
claude plugin update gdim-workflow
```

## 卸载

```bash
claude plugin remove gdim-workflow
```

重启 Claude Code 即可。

## 下一步

1. 阅读 `README.md` 了解使用方法
2. 阅读 `docs/GDIM 实践快速指南.md` 学习 GDIM
3. 运行 `TESTING.md` 中的测试场景
4. 在真实项目中使用 `/gdim-*` 命令
