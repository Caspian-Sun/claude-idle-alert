#!/usr/bin/env bash
# watcher.sh — idle-alert background watchdog (not a hook; spawned in the background by arm.sh)
#
# Args: $1=session_id  $2=nonce  $3=cwd
# Logic: sleep until TIER1 → if still armed (nonce unchanged and not disarmed) send the tier-1 alert;
#        sleep until TIER2 → if still armed send the tier-2 escalation.
#        Any time it wakes and finds the nonce changed (re-armed) or the file gone (disarmed/user back) → exit immediately, no alert.
set -u

sid="${1:-default}"; nonce="${2:-}"; cwd="${3:-$PWD}"
DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"

[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG" 2>/dev/null || exit 0
[ -n "${WEBHOOK_URL:-}" ] || exit 0

TIER1="${TIER1_DELAY:-120}"
TIER2="${TIER2_DELAY:-600}"
NONCE_FILE="$HOME/.claude/idle-alert/state/$sid.nonce"

still_armed() {
  local cur
  cur="$(cat "$NONCE_FILE" 2>/dev/null || true)"
  [ -n "$cur" ] && [ "$cur" = "$nonce" ]
}

sleep "$TIER1" 2>/dev/null || exit 0
still_armed || exit 0
bash "$DIR/notify.sh" 1 "$sid" "$cwd" "$TIER1" || true

gap=$(( TIER2 - TIER1 ))
[ "$gap" -gt 0 ] || gap=1
sleep "$gap" 2>/dev/null || exit 0
still_armed || exit 0
bash "$DIR/notify.sh" 2 "$sid" "$cwd" "$TIER2" || true

# ── tier-3: urgent phone call (only when a Feishu custom app is configured: LARK_APP_ID + TIER3_DELAY > TIER2) ──
if [ -n "${LARK_APP_ID:-}" ] && [ -n "${TIER3_DELAY:-}" ]; then
  gap3=$(( TIER3_DELAY - TIER2 ))
  if [ "$gap3" -gt 0 ]; then
    sleep "$gap3" 2>/dev/null || exit 0
    still_armed || exit 0
    bash "$DIR/urgent_phone.sh" "$cwd" || true
  fi
fi

exit 0
