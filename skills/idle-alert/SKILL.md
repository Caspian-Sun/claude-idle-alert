---
name: idle-alert
description: 配置 Claude Code 空闲/决策提醒 (dead-man's switch)。Claude 要你拍板 (问问题/计划待审批/权限弹窗) 立刻飞书; 停下没人回则延时升级 @你。用户说「配置空闲提醒 / 设置离开提醒 / 人不在时通知我 / 看门狗提醒 / idle alert / dead man switch / 配一下飞书提醒」时触发。本 skill 只负责填 webhook + 自检; 运行时机制由本插件的 hooks 自动接线 (装插件即生效, 不改 settings.json)。
---

# idle-alert — 提醒配置向导

帮当前用户在**本机**填好 webhook, 让本插件的提醒生效。运行时机制 (即时决策 hook +
延时空闲看门狗) 在**安装插件时已由 `hooks/hooks.json` 自动接线**, 任意项目都生效,
**不需要改任何项目的 settings.json**。本 skill 只做: **收集配置 → 写本地配置文件 → 自检**。

> 覆盖两层:
> - **即时**: Claude 问你问题 / 计划待审批 / 权限弹窗 → 立刻飞书
> - **延时**: Claude 停下没人回 → 默认 2 分钟提醒, 10 分钟升级 @你

## 职责边界

**做**: 问 webhook/阈值 → 写 `~/.claude/idle-alert/config.sh` (含密钥, 不入库) → 发测试消息
**不做**: ❌ 不碰任何 settings.json (插件自带接线) ❌ 不把 webhook 写进任何会入库的文件
❌ 不实现 tier-3 加急电话 (需飞书自建应用)

## 执行流程

### 第 1 步: 选配置文件位置 (主动问用户)

**先问用户配置文件放哪**, 给两个选项:

1. **默认 (推荐)**: `~/.claude/idle-alert/config.sh`
   —— 跟安装目录分离, `plugin update`/重装都不会丢; 大多数人选这个。
2. **自定义目录**: 用户给一个路径 (如团队共享盘 / 别的目录)。
   选这个时**必须**额外做一步: 把环境变量写进 user 级 `~/.claude/settings.json` 的 `env` 块,
   让所有项目的 hook 都能找到:
   ```jsonc
   { "env": { "CLAUDE_IDLE_CONFIG": "<用户给的绝对路径>" } }
   ```
   (合并进已有 `env`, 不要覆盖其它键。) 这一步改了 settings, **需要 Reload 才生效**。

记下最终路径, 记为 `<CFG>` 供后续步骤用 (默认即 `~/.claude/idle-alert/config.sh`)。

### 第 2 步: 收集配置

一句话说明配什么 (即时飞书 + 延时升级), 然后问 (有默认给默认):

| 配置项 | 说明 | 默认 |
|--------|------|------|
| `WEBHOOK_URL` | 飞书自定义机器人 webhook (必填) | 无 |
| `TIER1_DELAY` | 空闲多少秒发一级提醒 | 120 |
| `TIER2_DELAY` | 空闲多少秒升级 (须 > TIER1) | 600 |
| `AT_OPEN_ID` | 升级时 @ 的飞书 open_id (ou_xxx), 可空 | 空 |
| `KEYWORD` | 飞书自定义关键词 (消息须含) | Claude |

> 拿 webhook: 飞书群 → 设置 → 群机器人 → 添加「自定义机器人」→ 复制 webhook。

### 第 3 步: 写配置文件

`mkdir -p "$(dirname <CFG>)"`, 把值写到 `<CFG>` (格式见插件内 `scripts/config.example.sh`),
写完 `chmod 600`。**绝不**回显 webhook 全文 (可只显尾部 4 位确认)。

### 第 4 步: 发测试消息自检 (直接 curl, 不依赖插件路径)

```bash
source <CFG>
curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg t "🔔 ${KEYWORD:-Claude} idle-alert 测试 — 配置成功, 提醒已就绪" '{msg_type:"text",content:{text:$t}}')"
```

让用户去飞书群确认收到。没收到 → 排查 webhook / 关键词 / 机器人是否被禁。

### 第 5 步: 收尾

- 提醒 **Reload Window** (hook 在会话启动时加载; 自定义路径改了 env 也必须 reload)
- 一句话默认行为: "要你拍板 → 立刻飞书; 停下 2 分钟没回 → 提醒, 10 分钟没回 → 升级"
- 想要加急电话档 → 需建飞书自建应用, 以后再说

## 设计原则

- 密钥只落 `~/.claude/idle-alert/config.sh`, 永不入库/回显全文
- 没配 webhook → 整套静默, 任意项目零副作用
- 本 skill 只配置不改逻辑; 逻辑在插件 `scripts/`
