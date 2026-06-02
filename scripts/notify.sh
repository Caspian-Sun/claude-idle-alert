#!/usr/bin/env bash
# notify.sh — idle-alert 通知发送器 (飞书自定义机器人 webhook)
#
# 参数: $1=tier(0|1|2)  $2=session_id  $3=cwd  $4=elapsed_seconds  $5=reason(仅 tier0)
#   tier 0 = 即时决策提醒 (decision.sh 调)  1 = 空闲一级  2 = 空闲二级升级
# 隐私: 只外发「项目名 + 空闲时长/原因类型 + 档位」。绝不发对话内容 / transcript / 路径全文。
#
# 扩展点 (tier-3 加急电话): 若以后建了飞书自建应用, 可在 tier=2 之后追加调 urgent_phone
#       接口的逻辑 (需 app_id/app_secret + 你的 user_id)。位置见文末注释。
set -u

tier="${1:-1}"; sid="${2:-default}"; cwd="${3:-$PWD}"; elapsed="${4:-0}"; reason="${5:-}"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0
[ -n "${WEBHOOK_URL:-}" ] || exit 0
command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

proj="$(basename "$cwd" 2>/dev/null)"; [ -n "$proj" ] || proj="(unknown)"
mins=$(( elapsed / 60 ))
kw="${KEYWORD:-Claude}"

# 只有二级升级才 @ 人 (即时/一级不打扰太狠)
at=""
if [ "$tier" = "2" ] && [ -n "${AT_OPEN_ID:-}" ]; then
  at="<at user_id=\"${AT_OPEN_ID}\"></at> "
fi

case "$tier" in
  0) text="🔔 ${kw} 需要你决策${reason:+(${reason})} — 项目【${proj}】" ;;
  2) text="🚨🚨 ${kw} 已空闲 ${mins} 分钟仍无响应！${at}项目【${proj}】卡在等你决策, 速回。" ;;
  *) text="🔔 ${kw} 空闲 ${mins} 分钟未响应 — 项目【${proj}】可能在等你点 Yes/No。" ;;
esac

body="$(jq -nc --arg t "$text" '{msg_type:"text",content:{text:$t}}')"
curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' -d "$body" >/dev/null 2>&1 || true

# ── tier-3 扩展点 (默认关闭) ──
# if [ "$tier" = "2" ] && [ -n "${LARK_APP_ID:-}" ] && [ -n "${LARK_USER_ID:-}" ]; then
#   bash "$(dirname "$0")/urgent_phone.sh" "$LARK_USER_ID" "$text" || true
# fi

exit 0
