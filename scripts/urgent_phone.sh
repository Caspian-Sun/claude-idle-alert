#!/usr/bin/env bash
# urgent_phone.sh — tier-3: 飞书「加急电话」(需企业自建应用, 不是 webhook 机器人)
#
# 参数: $1=cwd (用于项目名)
# 三步流程 (飞书服务端 API):
#   1) 用 app_id/app_secret 换 tenant_access_token
#   2) 用 app 给你本人 (open_id) 发一条单聊消息, 拿到 message_id
#   3) 对该 message_id 调 urgent_phone, 触发电话 (飞书会打电话念这条消息)
# 仅当配齐 LARK_APP_ID/SECRET/USER_OPEN_ID 才动作; 否则静默 exit 0。
#
# 前置 (在飞书开放平台 open.feishu.cn 配好, 全部选「应用」身份权限, 加完要「创建版本→发布」):
#   - 建「企业自建应用」, 拿 app_id / app_secret
#   - 开权限 (实测可用的确切标识):
#       contact:user.id:readonly      (用手机号查 open_id)
#       im:message:send_as_bot        (以应用身份发消息)
#       im:message.urgent:phone       (电话加急 ← 注意是这个, 不是 status:write)
#   - 发布应用并让你自己在可用范围内; 你的飞书账号要绑过手机号
#   - 拿到你自己的 open_id (ou_xxx)
set -u

cwd="${1:-$PWD}"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"
[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0
[ -n "${LARK_APP_ID:-}" ] && [ -n "${LARK_APP_SECRET:-}" ] && [ -n "${LARK_USER_OPEN_ID:-}" ] || exit 0
command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

base="https://open.feishu.cn/open-apis"
proj="$(basename "$cwd" 2>/dev/null)"; [ -n "$proj" ] || proj="(unknown)"
kw="${KEYWORD:-Claude}"
text="${kw} 长时间无响应, 项目【${proj}】急需你处理 (电话加急)"

# 1) tenant_access_token
tok="$(curl -s -X POST "$base/auth/v3/tenant_access_token/internal" \
  -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg a "$LARK_APP_ID" --arg s "$LARK_APP_SECRET" '{app_id:$a,app_secret:$s}')" \
  2>/dev/null | jq -r '.tenant_access_token // empty' 2>/dev/null)"
[ -n "$tok" ] || exit 0

# 2) 发消息拿 message_id (content 必须是「字符串化的 JSON」, 用 --arg 让 jq 自动转义)
inner="$(jq -nc --arg t "$text" '{text:$t}')"
msg_id="$(curl -s -X POST "$base/im/v1/messages?receive_id_type=open_id" \
  -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg r "$LARK_USER_OPEN_ID" --arg c "$inner" '{receive_id:$r,msg_type:"text",content:$c}')" \
  2>/dev/null | jq -r '.data.message_id // empty' 2>/dev/null)"
[ -n "$msg_id" ] || exit 0

# 3) urgent_phone — 触发电话
curl -s -X PATCH "$base/im/v1/messages/$msg_id/urgent_phone?user_id_type=open_id" \
  -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg u "$LARK_USER_OPEN_ID" '{user_id_list:[$u]}')" >/dev/null 2>&1 || true

exit 0
