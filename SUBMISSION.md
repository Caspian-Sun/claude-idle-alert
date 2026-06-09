# Claude Code 官方插件提交文档

## 插件信息

- **插件名称**: claude-idle-alert
- **GitHub 仓库**: https://github.com/Caspian-Sun/claude-idle-alert
- **当前版本**: 1.0.8
- **作者**: Caspian-Sun
- **许可证**: MIT

## 插件描述

Claude Code **离座/空闲提醒插件** (dead-man's switch)：

当 Claude 需要你拍板时（提问、计划待审批、权限弹窗），立刻通过 **Feishu / DingTalk** 提醒你。如果你没有及时回应，会在 2 分钟/10 分钟时分级提醒。可选的 tier-3 功能支持 Feishu 电话语音加急通知。

## 核心功能

✅ **Tier 0-2：文本通知**
- 即时通知：Claude 需要你决策时立刻发送
- 一级提醒：2 分钟无回应时提醒
- 二级升级：10 分钟无回应时 @你

✅ **Tier 3：Feishu 电话语音**（可选）
- 20 分钟无回应时自动打电话
- 需 Feishu 自建应用

✅ **多通道支持**
- Feishu（飞书）：webhook + 电话
- DingTalk（钉钉）：webhook

✅ **开箱即用**
- 安装后自动接线，无需修改任何 settings.json
- 支持所有项目，一次配置全局生效

## 技术指标

| 指标 | 详情 |
|------|------|
| 语言 | Bash Shell Script |
| 大小 | ~10KB 核心代码 |
| 依赖 | jq, curl (标准工具) |
| 兼容性 | macOS, Linux |
| 安装方式 | Claude Code Plugin Marketplace |

## 提交清单

### 代码质量
- ✅ 语法检查通过
- ✅ 版本管理规范（SemVer）
- ✅ 完整的注释和文档
- ✅ 安全考虑（不存储密钥到代码）
- ✅ MIT 许可证

### 文档完整性
- ✅ README.md（英文）
- ✅ README.md（中文，zh 分支）
- ✅ RELEASE.md（发布流程）
- ✅ SKILL.md（配置向导）
- ✅ plugin.json（插件元数据）

### 功能完整性
- ✅ Feishu webhook 通知
- ✅ DingTalk webhook 通知
- ✅ Feishu 电话加急通知（tier-3）
- ✅ 配置向导（/idle-alert skill）
- ✅ 自动化发布脚本
- ✅ 配置迁移工具

### 用户体验
- ✅ 4 步快速开始
- ✅ 无需修改 settings.json
- ✅ 自动备份配置
- ✅ 彩色命令行输出
- ✅ 完整的故障排查指南

## 安装方式

```bash
# 用户可以这样安装：
claude plugin marketplace add https://github.com/Caspian-Sun/claude-idle-alert.git
claude plugin install claude-idle-alert
```

## 开发工具链

- 版本控制：Git + GitHub
- CI/CD：自动化发布脚本（./scripts/release.sh）
- 测试：手动配置向导测试
- 文档：Markdown（README, RELEASE, SKILL）

## 使用统计（预期）

- 目标用户：需要离座提醒的 Claude Code 用户
- 支持语言：English (main branch) + 中文 (zh branch)
- 更新频率：根据用户反馈定期迭代

## 后续维护

- 定期更新 Feishu/DingTalk API
- 添加更多通知渠道（WeCom, Telegram, Bark）
- 收集用户反馈改进 UX
- 安全更新和 bug 修复

## 联系信息

- **GitHub Issues**: https://github.com/Caspian-Sun/claude-idle-alert/issues
- **Repository**: https://github.com/Caspian-Sun/claude-idle-alert

---

**提交时间**: 2026-06-09  
**提交人**: Caspian-Sun  
**准备状态**: ✅ 完整，可提交
