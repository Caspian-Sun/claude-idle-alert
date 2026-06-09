#!/usr/bin/env bash
# notify.sh — idle-alert notification sender (Feishu + DingTalk custom-bot webhooks)
#
# Args: $1=tier(0|1|2)  $2=session_id  $3=cwd  $4=elapsed_seconds  $5=reason(tier0 only)
#   tier 0 = instant decision alert (called by decision.sh)  1 = idle tier-1  2 = idle tier-2 escalation
# Privacy: only sends "project name + idle duration/reason type + tier". Never sends conversation content / transcript / full path.
#
# Extension point (tier-3 urgent phone call): if you later build a Feishu custom app, you can append logic
#       after tier=2 to call the urgent_phone API (needs app_id/app_secret + your user_id). See the note at the end of this file.
set -u

tier="${1:-1}"; sid="${2:-default}"; cwd="${3:-$PWD}"; elapsed="${4:-0}"; reason="${5:-}"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0

feishu_on="${FEISHU_ENABLED:-false}"
dingtalk_on="${DINGTALK_ENABLED:-false}"
[ "$feishu_on" = "true" ] || [ "$dingtalk_on" = "true" ] || exit 0

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

proj="$(basename "$cwd" 2>/dev/null)"; [ -n "$proj" ] || proj="(unknown)"
mins=$(( elapsed / 60 ))
kw="${KEYWORD:-Claude}"

# Only the tier-2 escalation @s a person (instant/tier-1 shouldn't nag too hard)
at=""
if [ "$tier" = "2" ] && [ -n "${AT_OPEN_ID:-}" ]; then
  at="<at user_id=\"${AT_OPEN_ID}\"></at> "
fi

case "$tier" in
  0) text="🔔 ${kw} needs you${reason:+ (${reason})} — project [${proj}]" ;;
  2) text="🚨🚨 ${kw} has been idle ${mins} min with still no response! ${at}project [${proj}] is stuck waiting on your decision, please reply." ;;
  *) text="🔔 ${kw} idle ${mins} min with no response — project [${proj}] may be waiting for you to click Yes/No." ;;
esac

# Send to Feishu
if [ "$feishu_on" = "true" ] && [ -n "${WEBHOOK_URL:-}" ]; then
  body="$(jq -nc --arg t "$text" '{msg_type:"text",content:{text:$t}}')"
  curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' -d "$body" >/dev/null 2>&1 || true
fi

# Send to DingTalk
if [ "$dingtalk_on" = "true" ] && [ -n "${DINGTALK_WEBHOOK_URL:-}" ]; then
  body="$(jq -nc --arg t "$text" '{msgtype:"text",text:{content:$t}}')"
  curl -s -X POST "$DINGTALK_WEBHOOK_URL" -H 'Content-Type: application/json' -d "$body" >/dev/null 2>&1 || true
fi

# ── tier-3 extension point (off by default) ──
# if [ "$tier" = "2" ] && [ -n "${LARK_APP_ID:-}" ] && [ -n "${LARK_USER_ID:-}" ]; then
#   bash "$(dirname "$0")/urgent_phone.sh" "$LARK_USER_ID" "$text" || true
# fi

exit 0
