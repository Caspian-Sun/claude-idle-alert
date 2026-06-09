#!/bin/bash
# migrate-config.sh - 迁移旧配置到新格式
# 用法: ./scripts/migrate-config.sh

set -e

CONFIG_FILE="${CLAUDE_IDLE_CONFIG:-$HOME/.claude/idle-alert/config.sh}"
BACKUP_FILE="$CONFIG_FILE.backup.$(date +%s)"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ 配置文件不存在: $CONFIG_FILE"
  exit 1
fi

echo "📋 发现配置文件: $CONFIG_FILE"
echo "📝 创建备份: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

echo ""
echo "🔄 检查配置格式..."

# 检查是否已经是新格式
if grep -q "FEISHU_ENABLED" "$CONFIG_FILE"; then
  echo "✅ 配置已经是新格式，无需迁移"
  exit 0
fi

echo "⚠️  发现旧格式配置，开始迁移..."
echo ""

# 读取旧配置
WEBHOOK_URL=$(grep "^WEBHOOK_URL=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
TIER1_DELAY=$(grep "^TIER1_DELAY=" "$CONFIG_FILE" | cut -d'=' -f2)
TIER2_DELAY=$(grep "^TIER2_DELAY=" "$CONFIG_FILE" | cut -d'=' -f2)
AT_OPEN_ID=$(grep "^AT_OPEN_ID=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
KEYWORD=$(grep "^KEYWORD=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
LARK_APP_ID=$(grep "^LARK_APP_ID=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
LARK_APP_SECRET=$(grep "^LARK_APP_SECRET=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
LARK_USER_OPEN_ID=$(grep "^LARK_USER_OPEN_ID=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
TIER3_DELAY=$(grep "^TIER3_DELAY=" "$CONFIG_FILE" | cut -d'=' -f2)

# 判断是否启用飞书（旧版本如果有 WEBHOOK_URL 就启用飞书）
if [ -n "$WEBHOOK_URL" ]; then
  FEISHU_ENABLED="true"
else
  FEISHU_ENABLED="false"
fi

echo "迁移内容:"
echo "  FEISHU_ENABLED: $FEISHU_ENABLED"
echo "  DINGTALK_ENABLED: false (保留默认)"
echo "  TIER1_DELAY: $TIER1_DELAY"
echo "  TIER2_DELAY: $TIER2_DELAY"
echo ""

# 生成新配置
cat > "$CONFIG_FILE" << EOF
# idle-alert config template (v1.0.8+)
#
# Usage: copy to ~/.claude/idle-alert/config.sh and fill in. Or just run the skill \`/idle-alert\`,
#        which asks you item by item and writes ~/.claude/idle-alert/config.sh for you.
#
# Why the real config lives in ~/.claude (not the plugin dir or a project):
#   Webhooks are secrets, never committed. This template holds no secret and ships with the plugin as a sample.
#   Everyone's real webhooks/thresholds are personal local config, kept in ~/.claude/idle-alert/config.sh,
#   shared across all projects (the plugin reads this single file no matter which project it runs in).

# ───────── Feishu ─────────
# Enable Feishu notifications (true/false)
FEISHU_ENABLED=$FEISHU_ENABLED

# Feishu custom-bot webhook (only used if FEISHU_ENABLED=true)
WEBHOOK_URL="$WEBHOOK_URL"

# ───────── DingTalk ─────────
# Enable DingTalk notifications (true/false)
DINGTALK_ENABLED=false

# DingTalk custom-bot webhook (only used if DINGTALK_ENABLED=true)
DINGTALK_WEBHOOK_URL=""

# How many "seconds" idle before the tier-1 alert (default 120 = 2 minutes).
# Set 0 = fire the instant Claude stops (noisier; good if you're away from the computer most of the time).
TIER1_DELAY=$TIER1_DELAY

# How many "seconds" idle before the tier-2 escalation (default 600 = 10 minutes). Must be > TIER1_DELAY.
TIER2_DELAY=$TIER2_DELAY

# Optional: the Feishu open_id to @ on tier-2 escalation (looks like ou_xxxx). Empty = no @.
AT_OPEN_ID="$AT_OPEN_ID"

# If the Feishu bot has the "custom keyword" security setting on, the message text must contain that word (default Claude).
KEYWORD="${KEYWORD:-Claude}"

# ───────── tier-3: urgent phone call (optional, off by default) ─────────
# Feishu "phone urgency" = the Feishu system calls the phone number bound to your account and reads the message aloud (a real call, not in-app VoIP).
# Requires a "custom app" (a Feishu personal account can create one too; a webhook bot can't do this). Leave LARK_APP_ID empty to disable; it then stops at the tier-2 text.
# The app needs 3 "application"-identity permissions and a published version:
#   contact:user.id:readonly / im:message:send_as_bot / im:message.urgent:phone
LARK_APP_ID="$LARK_APP_ID"           # custom app app_id (cli_xxx)
LARK_APP_SECRET="$LARK_APP_SECRET"       # custom app app_secret
LARK_USER_OPEN_ID="$LARK_USER_OPEN_ID"     # who to call: your own open_id (ou_xxx), and that account must have a bound phone number
TIER3_DELAY=${TIER3_DELAY:-900}          # how many seconds idle before calling (must be > TIER2_DELAY, default 900=15 minutes)
EOF

chmod 600 "$CONFIG_FILE"

echo "✅ 配置已迁移到新格式"
echo ""
echo "📝 备份文件: $BACKUP_FILE"
echo "📂 配置文件: $CONFIG_FILE"
echo ""
echo "💡 下一步:"
echo "   1. 检查配置文件内容: cat $CONFIG_FILE"
echo "   2. 如果需要启用钉钉，编辑文件并设置: DINGTALK_ENABLED=true"
echo "   3. 在 Claude Code 中 Reload Window"
