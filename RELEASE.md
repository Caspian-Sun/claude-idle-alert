# 发布流程指南

## 概述

本项目采用语义化版本控制 (SemVer): `MAJOR.MINOR.PATCH`
- **MAJOR**: 破坏性变更 (不兼容的 API 改变)
- **MINOR**: 新功能，向后兼容
- **PATCH**: bug 修复，向后兼容

当前版本：v1.0.8

## 修改代码前

1. **确定版本号变更类型**
   - 新功能 (DingTalk 支持) → MINOR：1.0.8 → 1.1.0
   - bug 修复 → PATCH：1.0.8 → 1.0.9
   - 文档/注释 → 无需改版本

2. **创建新分支**（可选，但推荐）
   ```bash
   git checkout -b feature/my-feature
   ```

## 提交代码时

**关键原则：版本号更新必须与代码变更在同一个 commit 中**

### 步骤 1：修改功能代码
编辑所需的文件，如 `scripts/notify.sh`、`README.md` 等。

### 步骤 2：更新版本号
编辑 `.claude-plugin/plugin.json`，修改 `version` 字段：
```json
{
  "version": "1.0.9"
}
```

### 步骤 3：提交 (main 分支)
```bash
git add .
git commit -m "feat: 新功能描述 (v1.0.9)"
```

### 步骤 4：同步到中文分支 (zh)
```bash
git checkout zh
git cherry-pick main  # 或手动应用改动
git add .
git commit -m "feat: 新功能描述 (v1.0.9) [zh]"
```

### 步骤 5：推送两个分支
```bash
git push origin main zh
```

## 发布前检查清单

在执行下方的自动化发布脚本前，手动验证：

- [ ] `plugin.json` 版本号已更新
- [ ] main 分支：commit message 包含版本号
- [ ] zh 分支：commit message 包含版本号
- [ ] GitHub 上两个分支都可见最新 commit
- [ ] README 或 CHANGELOG 已记录变更（可选但推荐）

## 执行发布

### 自动化发布（推荐）

```bash
./scripts/release.sh 1.0.9
```

脚本会自动：
1. 验证本地没有未提交的改动
2. 验证两个分支都已推送到 GitHub
3. 卸载旧插件
4. 更新 marketplace
5. 重新安装插件
6. 验证缓存版本一致性

### 手动发布（如果脚本失败）

```bash
# 1. 卸载旧版本
claude plugin uninstall claude-idle-alert

# 2. 删除旧缓存
rm -rf ~/.claude/plugins/cache/claude-idle-alert/

# 3. 更新 marketplace
claude plugin marketplace update claude-idle-alert

# 4. 安装新版本
claude plugin install claude-idle-alert

# 5. 验证版本
ls ~/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/
```

## 发布后验证

1. **检查缓存版本**
   ```bash
   ls ~/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/
   # 应该看到最新版本目录（如 1.0.9）
   ```

2. **验证文件内容**
   ```bash
   # 检查缓存中的配置文件是否是最新的
   grep "DINGTALK_ENABLED" ~/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/1.0.9/scripts/config.example.sh
   ```

3. **Reload Window**
   在 Claude Code 中执行：`Cmd+Shift+P` → Reload Window

## 故障排除

### 问题：缓存版本与源代码不一致

**症状**：`ls ~/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/` 没有显示新版本

**解决方案**：
```bash
# 1. 清除所有旧缓存
rm -rf ~/.claude/plugins/cache/claude-idle-alert/

# 2. 重新安装
claude plugin marketplace update claude-idle-alert
claude plugin install claude-idle-alert
```

### 问题：push 后 marketplace 没有更新

**症状**：安装时仍然是旧版本

**解决方案**：
```bash
# 强制刷新 marketplace
claude plugin marketplace update claude-idle-alert --force
```

## 版本历史

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0.8 | 2026-06-09 | 添加 DingTalk 支持 + 显式启用开关 |
| 1.0.7 | 2026-06-04 | 空闲看门狗优化 |
| 1.0.0 | 2026-06-02 | 初始版本 |

## 常见问题

**Q：修改文档需要更新版本号吗？**  
A：不需要。仅当修改 `scripts/`、`hooks/` 或 `skills/` 中影响功能的文件时才更新。

**Q：可以跳过某个版本吗？**  
A：不建议。版本号应该线性递增，便于追踪。

**Q：版本号写在哪里？**  
A：只在 `.claude-plugin/plugin.json` 中。其他文件（README、CHANGELOG）可选记录，但不强制。
