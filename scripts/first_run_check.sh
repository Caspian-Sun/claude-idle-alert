#!/usr/bin/env bash
# first_run_check.sh — SessionStart: 装了插件但还没配 webhook 时, 主动提醒去跑 /idle-alert
#
# 因为 Claude Code 插件没有"安装后自动弹窗"机制 (无 post-install hook), 这里用 SessionStart
# 在每次开会话时检查: 若未配置, 注入一条 additionalContext, 让助手提醒用户配置。
# 已配置 (webhook 已填) → 静默。每天最多提醒一次, 避免每次开会话都刷。
set -u

CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

# 已配置 (有真实 webhook) → 不打扰
if [ -f "$CONFIG" ] && grep -q 'WEBHOOK_URL="http' "$CONFIG" 2>/dev/null; then
  exit 0
fi

# 每天最多提醒一次
STATE_DIR="$HOME/.claude/idle-alert"
STAMP="$STATE_DIR/.nudged"
today="$(date +%Y-%m-%d)"
[ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$today" ] && exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s\n' "$today" > "$STAMP" 2>/dev/null || true

# SessionStart 用 additionalContext 注入提示 (助手会据此提醒用户)
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"提示给助手: idle-alert 插件已安装但尚未配置 webhook (空闲/决策提醒当前不会发)。请主动提醒用户运行 /idle-alert 完成配置 —— 它会先问配置文件放默认位置 (~/.claude/idle-alert/config.sh) 还是自定义目录, 再填飞书 webhook。"}}
JSON
exit 0
