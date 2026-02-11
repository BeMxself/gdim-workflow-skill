# 更新日志

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
