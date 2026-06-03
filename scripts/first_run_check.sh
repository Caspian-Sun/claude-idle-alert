#!/usr/bin/env bash
# first_run_check.sh — SessionStart: when the plugin is installed but the webhook isn't configured yet, actively remind the user to run /idle-alert
#
# Because Claude Code plugins have no "auto-popup after install" mechanism (no post-install hook), this uses SessionStart
# to check on each session start: if not configured, inject an additionalContext so the assistant reminds the user to configure.
# Already configured (webhook filled in) → silent. Reminds at most once a day to avoid spamming every session start.
set -u

CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

# Already configured (has a real webhook) → don't disturb
if [ -f "$CONFIG" ] && grep -q 'WEBHOOK_URL="http' "$CONFIG" 2>/dev/null; then
  exit 0
fi

# Remind at most once a day
STATE_DIR="$HOME/.claude/idle-alert"
STAMP="$STATE_DIR/.nudged"
today="$(date +%Y-%m-%d)"
[ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$today" ] && exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s\n' "$today" > "$STAMP" 2>/dev/null || true

# SessionStart injects a hint via additionalContext (the assistant reminds the user based on it)
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Note to the assistant: the idle-alert plugin is installed but the webhook is not configured yet (idle/decision alerts will not be sent). Please proactively remind the user to run /idle-alert to finish setup — it first asks whether to put the config file in the default location (~/.claude/idle-alert/config.sh) or a custom directory, then collects the Feishu webhook."}}
JSON
exit 0
