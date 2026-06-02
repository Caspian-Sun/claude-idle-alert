# claude-idle-alert

> Claude Code 的**决策提醒 + 空闲看门狗** (dead-man's switch)。
> Claude 需要你拍板时**立刻**飞书提醒;停下后没人回则**延时升级**。
> **任意项目可用,安装即自动接线,不改任何 settings.json。**

人离开电脑,Claude 跑到一半弹 Yes/No 或问个问题就干等,没人知道。这个插件用两层提醒解决:

| 层 | 何时响 | 靠什么信号 |
|----|--------|-----------|
| **即时** | Claude 问你问题 / 计划待审批 / 权限弹窗 | `PreToolUse(AskUserQuestion\|ExitPlanMode)`(任何环境都触发)+ `Notification(permission_prompt)` |
| **延时** | Claude 停下后,你 N 分钟没回 | `Stop` 布防 → 看门狗 → 你没回就升级 |

---

## 安装

```bash
# 1. 添加 marketplace (用 HTTPS 完整地址; 不要用 owner/repo 简写, 它默认走 SSH, 没配 key 会失败)
claude plugin marketplace add https://github.com/Caspian-Sun/claude-idle-alert.git
# 2. 安装插件 (hooks 自动接线, 不碰你项目的 settings.json)
claude plugin install claude-idle-alert
# 3. 配置你的飞书 webhook (跑 skill 向导)
#    在 Claude Code 里输入: /idle-alert
# 4. Reload Window
```

> 前置:`jq` 和 `curl`(macOS/Linux 一般自带;`jq` 没有就 `brew install jq`)。
> 更新到新版本:`claude plugin marketplace update claude-idle-alert && claude plugin install claude-idle-alert`。

---

## 配置

真实配置放 `~/.claude/idle-alert/config.sh`(**个人本地,绝不入库**),对所有项目通用。
最省事是跑 `/idle-alert` 让向导写好;也可手动复制 [`scripts/config.example.sh`](scripts/config.example.sh):

| 项 | 说明 | 默认 |
|----|------|------|
| `WEBHOOK_URL` | 飞书自定义机器人 webhook(必填,**留空 = 整套静默**) | 无 |
| `TIER1_DELAY` | 空闲多少秒发一级提醒 | 120 |
| `TIER2_DELAY` | 空闲多少秒升级(须 > TIER1) | 600 |
| `AT_OPEN_ID` | 升级时 @ 的飞书 open_id(可空) | 空 |
| `KEYWORD` | 飞书自定义关键词(消息须含) | Claude |

**没配 webhook → 全程静默 `exit 0`,零副作用** —— 所以装了不配也不会打扰任何人。
装了还没配时,每次开会话(每天一次)会**主动提醒**你去跑 `/idle-alert`(SessionStart 检测)。

**自定义配置位置**:默认 `~/.claude/idle-alert/config.sh`(和安装目录分离,升级不丢)。
想换路径:跑 `/idle-alert` 时选"自定义目录",或手动在 user 级 `~/.claude/settings.json` 加
`{ "env": { "CLAUDE_IDLE_CONFIG": "/你的路径/config.sh" } }`(改 env 需 Reload)。

---

## 工作原理 (dead-man's switch)

```
Stop / Notification ──► arm.sh ──► 写 per-session nonce + 后台 watcher.sh
                                        │ (睡 TIER1)
用户敲字 UserPromptSubmit ─► disarm.sh ─► 删 nonce
                                        ▼
              watcher 醒来: nonce 还在且没变? ──否──► 退出 (人回来了/重新布防)
                                        │是 → 发一级, 再睡到 TIER2
                          仍布防? ──是──► 发二级升级 (@你)

PreToolUse(AskUserQuestion|ExitPlanMode) / Notification(permission_prompt)
                    └──► decision.sh ──► 立刻发飞书 (即时层)
```

- **per-session**:nonce 按 `session_id` 区分,多会话互不干扰。
- **重新布防天然失效旧 watcher**:每次 arm 换新 nonce,旧 watcher 醒来对不上就退出,不用杀进程。
- **只发元数据**:通知里只有项目名 + 空闲时长/原因类型,**绝不含对话内容**。

---

## 隐私

- webhook 只存 `~/.claude/idle-alert/config.sh`,不入库、不外传。
- 通知文本只含「项目名 + 时长 + 档位」,不读不发 transcript / 对话内容。
- 会话内容不出本机(区别于会把会话镜像上云的方案)。

---

## 文件结构

```
claude-idle-alert/
├── .claude-plugin/
│   ├── plugin.json          # 插件清单
│   └── marketplace.json     # marketplace 清单 (供 marketplace add)
├── hooks/hooks.json         # hook 接线 (安装时自动注册, ${CLAUDE_PLUGIN_ROOT})
├── scripts/                 # 运行时脚本
│   ├── decision.sh          # 即时决策提醒
│   ├── arm.sh / disarm.sh   # 布防 / 撤防
│   ├── watcher.sh           # 后台看门狗 (两级)
│   ├── notify.sh            # 飞书发送 (tier 0/1/2)
│   └── config.example.sh    # 配置模板
└── skills/idle-alert/SKILL.md  # 配置向导 (/idle-alert)
```

---

## 路线图

- [ ] tier-3 加急电话(飞书自建应用 `urgent_phone`,扩展点已在 `notify.sh` 留好)
- [ ] 多渠道(钉钉 / 企微 / Telegram / Bark)—— 改 `notify.sh` 的 payload 即可

## License

MIT
