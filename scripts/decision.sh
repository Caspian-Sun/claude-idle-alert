#!/usr/bin/env bash
# decision.sh — 即时决策提醒 (Claude 当下需要你拍板时, 立刻发飞书)
#
# 触发 (在 hooks/hooks.json 注册):
#   - PreToolUse(AskUserQuestion|ExitPlanMode): Claude 要问你问题 / 计划待审批
#     → 工具调用必走 PreToolUse, 任何环境都触发, 是最可靠的"需要你"信号。
#   - Notification(permission_prompt): 权限弹窗 (终端环境额外覆盖; VSCode 插件环境
#     此事件可能不触发, 故仅作补充, 主力是 PreToolUse)。
# 与 watcher 的关系: 这个是"立刻响一声", watcher.sh 是"你没回再延时升级", 二者互补。
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0
[ -n "${WEBHOOK_URL:-}" ] || exit 0

payload="$(cat 2>/dev/null || true)"
evt=""; tool=""; cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  evt="$(printf '%s'  "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)"
  cwd="$(printf '%s'  "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -n "$cwd" ] || cwd="$PWD"

# 推断"为什么需要你" — 只发事件类型, 不发问题/计划内容 (安全默认)
reason="需要你拍板"
case "$tool" in
  AskUserQuestion) reason="在问你问题" ;;
  ExitPlanMode)    reason="计划待审批" ;;
esac
[ "$evt" = "Notification" ] && reason="权限/操作待批准"

bash "$DIR/notify.sh" 0 "decision" "$cwd" 0 "$reason" || true
exit 0
