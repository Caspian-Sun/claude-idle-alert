#!/usr/bin/env bash
# arm.sh — idle-alert 看门狗「布防」
#
# 触发: PreToolUse(AskUserQuestion|ExitPlanMode) / Notification(permission_prompt) (在 hooks/hooks.json 注册)
# 作用: 仅当 Claude 真的卡住等你拍板时 (问你问题 / 计划待审批 / 权限弹窗), 记一个 per-session nonce
#       并在后台拉起一个 watcher。普通 Stop (Claude 只是答完一轮) 不布防, 所以正常结束不会误报空闲。
#       若你在 TIER1/TIER2 时限内响应 (PostToolUse / UserPromptSubmit → disarm.sh 撤防),
#       watcher 醒来发现 nonce 已变/已删, 自动放弃, 不发提醒。
# 设计: 未配置 (~/.claude/idle-alert/config.sh 缺失或 WEBHOOK_URL 空) → 静默 exit 0, 零副作用。
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0
[ -n "${WEBHOOK_URL:-}" ] || exit 0

payload="$(cat 2>/dev/null || true)"
sid=""; cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -n "$sid" ] || sid="default"
[ -n "$cwd" ] || cwd="$PWD"

STATE_DIR="$HOME/.claude/idle-alert/state"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# nonce: 每次布防都换 (epoch-pid-random, 同一秒内多次布防也唯一; 不用 %N 因 macOS/BSD date 不支持)。
# 旧 watcher 醒来发现 nonce 变了 → 自动退出 (天然处理"重新布防")。
nonce="$(date +%s)-$$-${RANDOM:-0}"
printf '%s\n' "$nonce" > "$STATE_DIR/$sid.nonce" 2>/dev/null || exit 0

# 后台拉起 watcher 并脱离当前 hook 进程 (hook 必须立刻返回, 不能阻塞)
nohup bash "$DIR/watcher.sh" "$sid" "$nonce" "$cwd" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
