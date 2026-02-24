## 编译修复任务（自动重试）

上一轮执行后 `mvn compile` 失败。请修复编译错误后重新提交。

### 约束
- 只修复编译错误，不做任何功能变更或新增代码
- 修复后运行 `mvn compile -pl {{MODULES}} -am` 确认通过
- 将修复内容追加到上一轮的 execution summary 中
- git commit 修复改动，commit message 标注 "fix: compile error R{{ROUND}}"

### 编译错误日志
```
{{COMPILE_ERROR_LOG}}
```
