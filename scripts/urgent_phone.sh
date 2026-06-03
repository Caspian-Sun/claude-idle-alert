#!/usr/bin/env bash
# urgent_phone.sh — tier-3: Feishu "urgent phone call" (needs a custom app, not a webhook bot)
#
# Args: $1=cwd (used for the project name)
# Three-step flow (Feishu server-side API):
#   1) exchange app_id/app_secret for a tenant_access_token
#   2) use the app to send yourself (open_id) a direct message, getting a message_id
#   3) call urgent_phone on that message_id to trigger the call (Feishu calls and reads this message aloud)
# Acts only when LARK_APP_ID/SECRET/USER_OPEN_ID are all set; otherwise silent exit 0.
#
# Prerequisites (set up on the Feishu open platform open.feishu.cn, all with "application"-identity permissions; after adding them you must "create a version → publish"):
#   - Create a "custom app" (Feishu personal or enterprise both work), get app_id / app_secret
#   - Enable permissions (the exact identifiers, verified working):
#       contact:user.id:readonly      (look up open_id by phone number)
#       im:message:send_as_bot        (send messages as the app)
#       im:message.urgent:phone       (phone urgency ← note it's this one, not status:write)
#   - Publish the app and make sure you're in its availability scope; your Feishu account must have a bound phone number
#   - Obtain your own open_id (ou_xxx)
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
text="${kw} has been unresponsive for a long time; project [${proj}] urgently needs your attention (phone urgency)"

# 1) tenant_access_token
tok="$(curl -s -X POST "$base/auth/v3/tenant_access_token/internal" \
  -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg a "$LARK_APP_ID" --arg s "$LARK_APP_SECRET" '{app_id:$a,app_secret:$s}')" \
  2>/dev/null | jq -r '.tenant_access_token // empty' 2>/dev/null)"
[ -n "$tok" ] || exit 0

# 2) send a message to get message_id (content must be "stringified JSON"; --arg lets jq escape it automatically)
inner="$(jq -nc --arg t "$text" '{text:$t}')"
msg_id="$(curl -s -X POST "$base/im/v1/messages?receive_id_type=open_id" \
  -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg r "$LARK_USER_OPEN_ID" --arg c "$inner" '{receive_id:$r,msg_type:"text",content:$c}')" \
  2>/dev/null | jq -r '.data.message_id // empty' 2>/dev/null)"
[ -n "$msg_id" ] || exit 0

# 3) urgent_phone — trigger the call
curl -s -X PATCH "$base/im/v1/messages/$msg_id/urgent_phone?user_id_type=open_id" \
  -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg u "$LARK_USER_OPEN_ID" '{user_id_list:[$u]}')" >/dev/null 2>&1 || true

exit 0
