## GDIM 文档补全任务（自动重试）

上一轮执行后缺少必要的 GDIM 文档。请补全缺失文件。

### 缺失文件
{{MISSING_FILES}}

### 约束
- 只补全缺失的 GDIM 文档，不做代码变更
- 文件命名遵循 GDIM 规范：`{NN}-{phase}.round{N}.md`
- gap-analysis.md 必须包含 Gap 分类（G1-G6）和状态（已关闭/未关闭/BLOCKED）
- git commit 补全的文件
