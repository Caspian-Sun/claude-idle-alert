#!/usr/bin/env bash
# decision.sh — instant decision alert (when Claude needs your call right now, ping Feishu immediately)
#
# Triggers (registered in hooks/hooks.json):
#   - PreToolUse(AskUserQuestion|ExitPlanMode): Claude wants to ask you / a plan is awaiting approval
#     → tool calls always go through PreToolUse, fires in any environment, the most reliable "needs you" signal.
#   - Notification(permission_prompt): permission prompt (extra coverage in terminal environments; in the VSCode
#     extension this event may not fire, so it's only supplementary — PreToolUse is the workhorse).
# Relation to the watcher: this one "rings right away", watcher.sh "escalates on a delay if you don't reply"; they complement each other.
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

# Infer "why it needs you" — send only the event type, never the question/plan content (secure default)
reason="needs your decision"
case "$tool" in
  AskUserQuestion) reason="is asking you a question" ;;
  ExitPlanMode)    reason="plan awaiting approval" ;;
esac
[ "$evt" = "Notification" ] && reason="permission/action awaiting approval"

bash "$DIR/notify.sh" 0 "decision" "$cwd" 0 "$reason" || true
exit 0
