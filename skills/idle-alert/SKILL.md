---
name: idle-alert
description: 配置 Claude Code 空闲/决策提醒 (dead-man's switch)。Claude 要你拍板 (问问题/计划待审批/权限弹窗) 立刻飞书/钉钉; 停下没人回则延时升级 @你; 可选 tier-3 飞书电话语音。用户说「配置空闲提醒 / 设置离开提醒 / 人不在时通知我 / 看门狗提醒 / idle alert / dead man switch / 配一下飞书提醒 / 配飞书打电话提醒 / 配钉钉提醒」时触发。本 skill 收集 webhook(及可选电话凭据) + 自检; 运行时机制由插件 hooks 自动接线 (装插件即生效, 不改 settings.json)。
---

# idle-alert — 提醒配置向导

帮当前用户在**本机**填好 webhook, 让本插件的提醒生效。运行时机制 (即时决策 hook +
延时空闲看门狗) 在**安装插件时已由 `hooks/hooks.json` 自动接线**, 任意项目都生效,
**不需要改任何项目的 settings.json**。本 skill 只做: **收集配置 → 写本地配置文件 → 自检**。

> 覆盖:
> - **即时**: Claude 问你问题 / 计划待审批 / 权限弹窗 → 立刻飞书/钉钉
> - **延时**: Claude 停下没人回 → 2 分钟提醒, 10 分钟升级 @你
> - **可选 tier-3**: 20 分钟还没回 → 飞书电话语音 (仅飞书支持, 需自建应用)

## 职责边界

**做**: 问 webhook/阈值 → 写 `~/.claude/idle-alert/config.sh` (含密钥, 不入库) → 发测试消息
**不做**: ❌ 不碰任何 settings.json (插件自带接线) ❌ 不把 webhook / app_secret 写进任何会入库的文件
❌ 不替用户在飞书后台建应用/开权限 (那是用户在 open.feishu.cn 的操作, 本 skill 只收集已就绪的凭据)

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

一句话说明配什么 (即时飞书/钉钉 + 延时升级), 然后问 (有默认给默认):

| 配置项 | 说明 | 默认 |
|--------|------|------|
| `FEISHU_ENABLED` | 启用飞书通知 (true/false, 至少一个为 true) | false |
| `WEBHOOK_URL` | 飞书自定义机器人 webhook (仅 FEISHU_ENABLED=true 时使用) | 无 |
| `DINGTALK_ENABLED` | 启用钉钉通知 (true/false, 至少一个为 true) | false |
| `DINGTALK_WEBHOOK_URL` | 钉钉自定义机器人 webhook (仅 DINGTALK_ENABLED=true 时使用) | 无 |
| `TIER1_DELAY` | 空闲多少秒发一级提醒 | 120 |
| `TIER2_DELAY` | 空闲多少秒升级 (须 > TIER1) | 600 |
| `AT_OPEN_ID` | 升级时 @ 的飞书 open_id (ou_xxx), 可空 | 空 |
| `KEYWORD` | 飞书自定义关键词 (消息须含) | Claude |

> **拿飞书 webhook**: 飞书群 → 设置 → 群机器人 → 添加「自定义机器人」→ 复制 webhook。
>
> **拿钉钉 webhook** (推荐流程):
>   1. 创建一个钉钉「团队」(如无)
>   2. 在团队内建一个「群」(仅自己用, 如「我的提醒」)
>   3. 群内 → 群设置 → 机器人和集成 → 创建「自定义机器人」→ 复制 webhook
>
> **功能对比**:
> - **飞书**: webhook (tier 0-2) + 可选电话加急 (tier 3, 需自建应用)
> - **钉钉**: webhook (tier 0-2) 仅,暂不支持电话加急

### 第 2.5 步: (可选) tier-3 加急电话

问用户「要不要开『空闲太久自动打电话』? (需飞书自建应用, 个人版也能建, 比 webhook 麻烦)」。
不要 → 跳过, LARK_* 留空即可 (只到 tier-2)。要 → 先确认前置都做好:

- 建「自建应用」(飞书个人版/企业版均可), 拿 `app_id` / `app_secret`
- 开 3 个**「应用」身份**权限并**创建版本→发布**:
  `contact:user.id:readonly` / `im:message:send_as_bot` / `im:message.urgent:phone`
- 账号绑过手机号, 自己在应用可用范围内

然后收集 `LARK_APP_ID` / `LARK_APP_SECRET` / 用户**手机号** / `TIER3_DELAY`(默认 1200)。
**open_id 不用手填**, 用 app 凭据 + 手机号自动查 (下面脚本), 失败多半是权限没发布:

```bash
TOK=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H 'Content-Type: application/json' -d "{\"app_id\":\"<APP_ID>\",\"app_secret\":\"<APP_SECRET>\"}" \
  | jq -r '.tenant_access_token')
curl -s -X POST "https://open.feishu.cn/open-apis/contact/v3/users/batch_get_id?user_id_type=open_id" \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"mobiles\":[\"+86<手机号>\"]}" | jq -r '.data.user_list[0].user_id'
```

把查到的 `ou_xxx` 作为 `LARK_USER_OPEN_ID` 写入配置。

### 第 3 步: 写配置文件

`mkdir -p "$(dirname <CFG>)"`, 把值写到 `<CFG>` (格式见插件内 `scripts/config.example.sh`),
写完 `chmod 600`。若开了 tier-3, 一并写入 `LARK_APP_ID/LARK_APP_SECRET/LARK_USER_OPEN_ID/TIER3_DELAY`。
**绝不**回显 webhook / app_secret 全文 (可只显尾部 4 位确认)。
至少 `FEISHU_ENABLED` 或 `DINGTALK_ENABLED` 之一须为 true (两个都是 false 会整套静默)。

### 第 4 步: 发测试消息自检 (直接 curl, 不依赖插件路径)

```bash
source <CFG>
test_msg="🔔 ${KEYWORD:-Claude} idle-alert 测试 — 配置成功, 提醒已就绪"

# 测试飞书 webhook (若启用)
if [ "${FEISHU_ENABLED:-false}" = "true" ] && [ -n "${WEBHOOK_URL:-}" ]; then
  curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg t "$test_msg" '{msg_type:"text",content:{text:$t}}')"
fi

# 测试钉钉 webhook (若启用)
if [ "${DINGTALK_ENABLED:-false}" = "true" ] && [ -n "${DINGTALK_WEBHOOK_URL:-}" ]; then
  curl -s -X POST "$DINGTALK_WEBHOOK_URL" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg t "$test_msg" '{msgtype:"text",text:{content:$t}}')"
fi
```

让用户分别去飞书群 (若启用) 和钉钉群 (若启用) 确认收到。没收到 → 排查 webhook / 关键词 / 机器人是否被禁 / 服务是否启用。

**若开了 tier-3, 再真打一通测试电话**(直接调插件脚本, 会真的响):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/*}"/scripts/urgent_phone.sh "$PWD"
```

让用户确认电话接到。报 `99991672 缺权限` → 那个权限没发布; 报别的 → 按 msg 排查。

### 第 5 步: 收尾

- 提醒 **Reload Window** (hook 在会话启动时加载; 自定义路径改了 env 也必须 reload)
- 一句话默认行为: "要你拍板 → 立刻飞书/钉钉; 停 2 分钟没回 → 提醒, 10 分钟 → 升级@, 20 分钟 → 打电话(仅飞书, 若开了 tier-3)"

## 设计原则

- 密钥只落 `~/.claude/idle-alert/config.sh`, 永不入库/回显全文
- 两个服务都禁用 (FEISHU_ENABLED=false 和 DINGTALK_ENABLED=false) → 整套静默, 任意项目零副作用
- 至少一个服务须启用才能生效
- 本 skill 只配置不改逻辑; 逻辑在插件 `scripts/`
