#!/usr/bin/env bash
# arm.sh — idle-alert watchdog "arm"
#
# Trigger: Stop / Notification (registered in hooks/hooks.json)
# Purpose: when Claude stops / needs input, record a per-session nonce and spawn a watcher in the background.
#          If the user replies within the TIER1/TIER2 window (UserPromptSubmit → disarm.sh),
#          the watcher wakes up, finds the nonce changed/deleted, and gives up without alerting.
# Design: not configured (~/.claude/idle-alert/config.sh missing or WEBHOOK_URL empty) → silent exit 0, zero side effects.
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

# nonce: changes on every arm (epoch-pid-random, unique even for multiple arms in the same second; not using %N since macOS/BSD date lacks it).
# An old watcher that wakes and finds the nonce changed → exits on its own (naturally handles "re-arming").
nonce="$(date +%s)-$$-${RANDOM:-0}"
printf '%s\n' "$nonce" > "$STATE_DIR/$sid.nonce" 2>/dev/null || exit 0

# Spawn the watcher in the background, detached from the current hook process (a hook must return immediately and not block)
nohup bash "$DIR/watcher.sh" "$sid" "$nonce" "$cwd" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
