<p align="right">
  <a href="https://github.com/Caspian-Sun/claude-idle-alert/blob/main/README.md">English</a> ·
  <strong>中文</strong>
</p>

# claude-idle-alert

**📞 离座太久、Claude 卡住等你?先飞书/钉钉发消息,再 @你,20 分钟还没回 —— 直接打电话念给你听。**

> Claude Code **离座提醒**插件:需要你拍板时**立刻**飞书/钉钉提醒,停下没人回则**延时升级**,还能**打电话叫你**。
> 装一次,**任意项目**生效,**不改任何 settings.json**。

## 快速开始(4 步,装完就能用)

```bash
# 1. 添加 marketplace (用 HTTPS 完整地址; owner/repo 简写默认走 SSH, 没配 key 会失败)
claude plugin marketplace add https://github.com/Caspian-Sun/claude-idle-alert.git

# 2. 安装插件 (hooks 自动接线, 不碰你项目的 settings.json)
claude plugin install claude-idle-alert

# 3. 在 Claude Code 里输入 /idle-alert, 按问答填飞书/钉钉 webhook (要打电话就跟着配 tier-3)

# 4. Reload Window
```

就这 4 步。配置只问你 webhook,运行机制插件自动接好。

> 前置:`jq` + `curl`(macOS/Linux 一般自带;缺 jq 就 `brew install jq`)。
> 更新:`claude plugin marketplace update claude-idle-alert && claude plugin install claude-idle-alert`
> 卸载:`claude plugin uninstall claude-idle-alert`

---

## 它能干什么

人离开电脑,Claude 跑到一半弹 Yes/No 或问个问题就干等,没人知道。用分级提醒解决:

| 级别 | 何时响 | 方式 |
|------|--------|------|
| **即时** | Claude 问你 / 计划待审批 / 权限弹窗 | 飞书 + 钉钉文本 (按配置) |
| **一级 / 二级** | Claude *卡在这个决策上*、你 2 / 10 分钟没回 | 飞书 + 钉钉文本 / 文本 + @你 |
| **tier-3(可选)** | 20 分钟还没回 | **飞书打电话** (仅飞书,语音念消息),见下方 |

> **功能差异**:
> - **飞书**: webhook 文本 (tier 0-2) + 可选电话加急 (tier 3, 需自建应用)
> - **钉钉**: webhook 文本 (tier 0-2) 仅,暂不支持电话加急

> 信号来源:两层都只在真正「需要你」的信号上触发 —— `PreToolUse(AskUserQuestion\|ExitPlanMode)`(任何环境都触发)+ `Notification(permission_prompt)`。即时层立刻发;延时层在同样的事件上布防看门狗,你不响应才升级。普通 `Stop`(Claude 只是答完一轮)**不布防任何东西**,所以正常结束绝不会误报空闲。你一响应(答完问题 / 工具完成 / 敲字)就撤防。

---

## 配置

真实配置放 `~/.claude/idle-alert/config.sh`(**个人本地,绝不入库**),对所有项目通用。
最省事是跑 `/idle-alert` 让向导写好;也可手动复制 [`scripts/config.example.sh`](scripts/config.example.sh):

| 项 | 说明 | 默认 |
|----|------|------|
| `FEISHU_ENABLED` | 启用飞书通知 (true/false, **至少一个为 true**) | false |
| `WEBHOOK_URL` | 飞书自定义机器人 webhook (仅 FEISHU_ENABLED=true 时使用) | 无 |
| `DINGTALK_ENABLED` | 启用钉钉通知 (true/false, **至少一个为 true**) | false |
| `DINGTALK_WEBHOOK_URL` | 钉钉自定义机器人 webhook (仅 DINGTALK_ENABLED=true 时使用) | 无 |
| `TIER1_DELAY` | 空闲多少秒发一级提醒 | 120 |
| `TIER2_DELAY` | 空闲多少秒升级(须 > TIER1) | 600 |
| `AT_OPEN_ID` | 升级时 @ 的飞书 open_id(可空) | 空 |
| `KEYWORD` | 飞书自定义关键词(消息须含) | Claude |

**两个服务都禁用 → 全程静默 `exit 0`,零副作用** —— 所以装了不配也不会打扰任何人。
至少一个服务 (设 `FEISHU_ENABLED=true` 或 `DINGTALK_ENABLED=true`) 须启用才能生效。
装了还没配时,每次开会话(每天一次)会**主动提醒**你去跑 `/idle-alert`(SessionStart 检测)。

**自定义配置位置**:默认 `~/.claude/idle-alert/config.sh`(和安装目录分离,升级不丢)。
想换路径:跑 `/idle-alert` 时选"自定义目录",或手动在 user 级 `~/.claude/settings.json` 加
`{ "env": { "CLAUDE_IDLE_CONFIG": "/你的路径/config.sh" } }`(改 env 需 Reload)。

---

## 工作原理 (dead-man's switch)

```
PreToolUse(AskUserQuestion|ExitPlanMode) / Notification(permission_prompt)
   ├──► decision.sh ──► 立刻发飞书/钉钉 (即时层)
   └──► arm.sh ─────► 写 per-session nonce + 后台 watcher.sh
                                        │ (睡 TIER1)
你响应 (PostToolUse / UserPromptSubmit) ─► disarm.sh ─► 删 nonce
                                        ▼
              watcher 醒来: nonce 还在且没变? ──否──► 退出 (你已响应/重新布防)
                                        │是 → 发一级, 再睡到 TIER2
                          仍布防? ──是──► 发二级升级 (@你)

普通 Stop (Claude 只是答完一轮, 没东西待办) 不布防 → 不报空闲。
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

## tier-3:加急电话(可选)

飞书「电话加急」= 飞书系统**拨打你绑定的手机号**,合成语音念出消息(真·来电,不是 App 内 VoIP)。
需**飞书自建应用**(**个人版也能建**,不一定要企业版;webhook 机器人做不到)。配齐 `config.sh` 里的
`LARK_APP_ID/SECRET/USER_OPEN_ID` 后,空闲超过 `TIER3_DELAY`(默认 20 分钟)仍没回 → 自动打电话。
流程:`tenant_access_token → 发消息拿 message_id → urgent_phone`(见 `scripts/urgent_phone.sh`)。

飞书侧前置(权限全选**「应用」身份**,加完必须**创建版本→发布**才生效):
1. 去 open.feishu.cn 建「自建应用」(**个人版/企业版均可**)→ 拿 `app_id` / `app_secret`
2. 开 3 个权限(确切标识,实测可用):
   - `contact:user.id:readonly`(用手机号查 open_id)
   - `im:message:send_as_bot`(发消息)
   - `im:message.urgent:phone`(电话加急)
3. 发布版本 → 你在可用范围 → 账号绑过手机号 → 拿到你的 `open_id`(ou_xxx)

## 路线图

- [x] tier-3 加急电话(飞书自建应用 `urgent_phone`)
- [x] 钉钉支持 —— 同时支持飞书和钉钉 webhook
- [ ] 多渠道(企微 / Telegram / Bark)—— 改 `notify.sh` 的 payload 即可

## License

MIT
