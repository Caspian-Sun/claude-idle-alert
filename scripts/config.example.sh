# idle-alert config template
#
# Usage: copy to ~/.claude/idle-alert/config.sh and fill in. Or just run the skill `/idle-alert`,
#        which asks you item by item and writes ~/.claude/idle-alert/config.sh for you.
#
# Why the real config lives in ~/.claude (not the plugin dir or a project):
#   Webhooks are secrets, never committed. This template holds no secret and ships with the plugin as a sample.
#   Everyone's real webhooks/thresholds are personal local config, kept in ~/.claude/idle-alert/config.sh,
#   shared across all projects (the plugin reads this single file no matter which project it runs in).

# ───────── Feishu ─────────
# Enable Feishu notifications (true/false)
FEISHU_ENABLED=false

# Feishu custom-bot webhook (only used if FEISHU_ENABLED=true)
WEBHOOK_URL=""

# ───────── DingTalk ─────────
# Enable DingTalk notifications (true/false)
DINGTALK_ENABLED=false

# DingTalk custom-bot webhook (only used if DINGTALK_ENABLED=true)
DINGTALK_WEBHOOK_URL=""

# How many "seconds" idle before the tier-1 alert (default 120 = 2 minutes).
# Set 0 = fire the instant Claude stops (noisier; good if you're away from the computer most of the time).
TIER1_DELAY=120

# How many "seconds" idle before the tier-2 escalation (default 600 = 10 minutes). Must be > TIER1_DELAY.
TIER2_DELAY=600

# Optional: the Feishu open_id to @ on tier-2 escalation (looks like ou_xxxx). Empty = no @.
AT_OPEN_ID=""

# If the Feishu bot has the "custom keyword" security setting on, the message text must contain that word (default Claude).
KEYWORD="Claude"

# ───────── tier-3: urgent phone call (optional, off by default) ─────────
# Feishu "phone urgency" = the Feishu system calls the phone number bound to your account and reads the message aloud (a real call, not in-app VoIP).
# Requires a "custom app" (a Feishu personal account can create one too; a webhook bot can't do this). Leave LARK_APP_ID empty to disable; it then stops at the tier-2 text.
# The app needs 3 "application"-identity permissions and a published version:
#   contact:user.id:readonly / im:message:send_as_bot / im:message.urgent:phone
LARK_APP_ID=""           # custom app app_id (cli_xxx)
LARK_APP_SECRET=""       # custom app app_secret
LARK_USER_OPEN_ID=""     # who to call: your own open_id (ou_xxx), and that account must have a bound phone number
TIER3_DELAY=900          # how many seconds idle before calling (must be > TIER2_DELAY, default 900=15 minutes)
