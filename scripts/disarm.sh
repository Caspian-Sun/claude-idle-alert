#!/usr/bin/env bash
# disarm.sh — idle-alert watchdog "disarm"
#
# Trigger: UserPromptSubmit (the user typed something = they're back, registered in hooks/hooks.json)
# Purpose: delete this session's nonce file. A watcher still sleeping wakes up, finds the nonce mismatched,
#          and gives up on escalating. This is the "feed the dog" action of the dead-man's switch.
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
