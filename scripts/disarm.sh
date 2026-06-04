#!/usr/bin/env bash
# disarm.sh — idle-alert 看门狗「撤防」
#
# 触发: UserPromptSubmit / PostToolUse (在 hooks/hooks.json 注册)
#       = 你敲了字, 或某个工具完成 (你答完了问题 / 批准了, Claude 继续干活)。
# 作用: 删掉本 session 的 nonce 文件。正在 sleep 的 watcher 醒来后发现 nonce 不匹配,
#       自动放弃升级。这是 dead-man's switch 的"喂狗"动作。
set -u

CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"
[ -f "$CONFIG" ] || exit 0

payload="$(cat 2>/dev/null || true)"
sid=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
fi
[ -n "$sid" ] || sid="default"

rm -f "$HOME/.claude/idle-alert/state/$sid.nonce" 2>/dev/null || true
exit 0
