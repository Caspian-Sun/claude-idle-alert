#!/usr/bin/env bash
# watcher.sh — idle-alert 后台看门狗 (非 hook, 由 arm.sh 在后台拉起)
#
# 参数: $1=session_id  $2=nonce  $3=cwd
# 逻辑: 睡到 TIER1 → 若仍布防 (nonce 未变且未撤防) 发一级提醒;
#       再睡到 TIER2 → 仍布防发二级升级。
#       任意一次醒来发现 nonce 变了 (重新布防) 或文件没了 (撤防/用户回来) → 立即退出, 不发。
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

exit 0
