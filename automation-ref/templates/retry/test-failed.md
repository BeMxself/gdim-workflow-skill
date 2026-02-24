## 测试修复任务（自动重试）

上一轮执行后测试失败。请修复测试错误后重新提交。

### 约束
- 只修复测试失败，不做任何功能变更
- 修复后运行 `mvn test -pl {{MODULES}} -am` 确认通过
- 将修复内容追加到上一轮的 execution summary 中
- git commit 修复改动，commit message 标注 "fix: test failure R{{ROUND}}"

### 测试错误日志
```
{{TEST_ERROR_LOG}}
```
