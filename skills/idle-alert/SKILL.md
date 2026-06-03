---
name: idle-alert
description: Configure Claude Code idle/decision alerts (dead-man's switch). When Claude needs your call (a question / plan awaiting approval / permission prompt) it pings Feishu instantly; if it stops and nobody replies it escalates on a delay and @s you; optional tier-3 Feishu voice phone call. Triggers when the user says "configure idle alert / set up away notification / notify me when I'm away / watchdog reminder / idle alert / dead man switch / set up Feishu alerts / set up a Feishu phone-call alert". This skill collects the webhook (and optional phone-call credentials) + self-checks; the runtime mechanics are auto-wired by the plugin hooks (active the moment the plugin is installed, no settings.json changes).
---

# idle-alert — alert setup wizard

Help the current user fill in the webhook on **their machine** so this plugin's alerts work. The runtime mechanics (instant
decision hook + delayed idle watchdog) are **already auto-wired by `hooks/hooks.json` at install time**, active in any project,
**with no need to change any project's settings.json**. This skill only does: **collect config → write the local config file → self-check**.

> Coverage:
> - **Instant**: Claude asks you a question / plan awaiting approval / permission prompt → ping Feishu immediately
> - **Delayed**: Claude stops and nobody replies → reminder at 2 min, escalation @you at 10 min
> - **Optional tier-3**: still no reply at 20 min → Feishu voice phone call (needs an enterprise custom app)

## Scope of responsibility

**Do**: ask for webhook/thresholds → write `~/.claude/idle-alert/config.sh` (contains secrets, not committed) → send a test message
**Don't**: ❌ touch any settings.json (the plugin wires itself) ❌ write the webhook / app_secret into any file that gets committed
❌ create the app / enable permissions in the Feishu console for the user (that's the user's action on open.feishu.cn; this skill only collects ready credentials)

## Execution flow

### Step 1: choose the config file location (ask the user)

**First ask the user where to put the config file**, with two options:

1. **Default (recommended)**: `~/.claude/idle-alert/config.sh`
   — separate from the install dir, so `plugin update`/reinstall won't lose it; most people pick this.
2. **Custom directory**: the user gives a path (e.g. a team shared drive / another directory).
   When choosing this you **must** do one extra step: write the environment variable into the `env` block of the user-level `~/.claude/settings.json`,
   so hooks in all projects can find it:
   ```jsonc
   { "env": { "CLAUDE_IDLE_CONFIG": "<absolute path the user gave>" } }
   ```
   (Merge into the existing `env`, don't overwrite other keys.) This step changes settings, so it **requires a Reload to take effect**.

Record the final path as `<CFG>` for the following steps (the default is `~/.claude/idle-alert/config.sh`).

### Step 2: collect config

Explain in one line what's being configured (instant Feishu + delayed escalation), then ask (use defaults where given):

| Key | Description | Default |
|-----|-------------|---------|
| `WEBHOOK_URL` | Feishu custom-bot webhook (required) | none |
| `TIER1_DELAY` | seconds idle before the tier-1 alert | 120 |
| `TIER2_DELAY` | seconds idle before escalation (must be > TIER1) | 600 |
| `AT_OPEN_ID` | Feishu open_id (ou_xxx) to @ on escalation, optional | empty |
| `KEYWORD` | Feishu custom keyword (must appear in the message) | Claude |

> Get the webhook: Feishu group → Settings → Group Bots → Add a "Custom Bot" → copy the webhook.

### Step 2.5: (optional) tier-3 urgent phone call

Ask the user "Want to enable 'auto phone call when idle too long'? (needs a Feishu custom app — a personal account can create one too, more work than a webhook)".
No → skip, just leave LARK_* empty (stops at tier-2). Yes → first confirm the prerequisites are in place:

- Create a "custom app" (Feishu personal or enterprise both work), get `app_id` / `app_secret`
- Enable 3 **"application"-identity** permissions and **create a version → publish**:
  `contact:user.id:readonly` / `im:message:send_as_bot` / `im:message.urgent:phone`
- The account has a bound phone number and is within the app's availability scope

Then collect `LARK_APP_ID` / `LARK_APP_SECRET` / the user's **phone number** / `TIER3_DELAY` (default 1200).
**The open_id doesn't need to be typed by hand** — look it up automatically from the app credentials + phone number (script below); failures are usually unpublished permissions:

```bash
TOK=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H 'Content-Type: application/json' -d "{\"app_id\":\"<APP_ID>\",\"app_secret\":\"<APP_SECRET>\"}" \
  | jq -r '.tenant_access_token')
curl -s -X POST "https://open.feishu.cn/open-apis/contact/v3/users/batch_get_id?user_id_type=open_id" \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"mobiles\":[\"+86<phone>\"]}" | jq -r '.data.user_list[0].user_id'
```

Write the resulting `ou_xxx` into the config as `LARK_USER_OPEN_ID`.

### Step 3: write the config file

`mkdir -p "$(dirname <CFG>)"`, write the values to `<CFG>` (format per `scripts/config.example.sh` in the plugin),
then `chmod 600`. If tier-3 is enabled, also write `LARK_APP_ID/LARK_APP_SECRET/LARK_USER_OPEN_ID/TIER3_DELAY`.
**Never** echo the full webhook / app_secret (you may show just the last 4 chars to confirm).

### Step 4: send a test message to self-check (direct curl, no dependency on plugin paths)

```bash
source <CFG>
curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg t "🔔 ${KEYWORD:-Claude} idle-alert test — config succeeded, alerts are ready" '{msg_type:"text",content:{text:$t}}')"
```

Have the user confirm receipt in the Feishu group. Not received → check the webhook / keyword / whether the bot is disabled.

**If tier-3 is enabled, place a real test call** (call the plugin script directly; it really rings):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/claude-idle-alert/claude-idle-alert/*}"/scripts/urgent_phone.sh "$PWD"
```

Have the user confirm they got the call. Reports `99991672 missing permission` → that permission isn't published; other errors → debug per the message.

### Step 5: wrap up

- Remind to **Reload Window** (hooks load at session start; if you changed env for a custom path, you must reload too)
- One-line default behavior: "needs your call → ping Feishu instantly; stops 2 min no reply → reminder, 10 min → escalation @, 20 min → phone call (if tier-3 enabled)"

## Design principles

- Secrets only land in `~/.claude/idle-alert/config.sh`, never committed/echoed in full
- No webhook configured → everything stays silent, zero side effects on any project
- This skill only configures, it doesn't change logic; the logic lives in the plugin's `scripts/`
