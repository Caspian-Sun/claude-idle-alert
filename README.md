<p align="right">
  <strong>English</strong> ·
  <a href="https://github.com/Caspian-Sun/claude-idle-alert/blob/zh/README.md">中文</a>
</p>

# claude-idle-alert

**📞 Away too long while Claude waits on you? It pings Feishu / DingTalk first, then @-mentions you, and if there's still no reply after 20 minutes — it calls your phone and reads the message aloud.**

> A Claude Code **away-from-keyboard alert** plugin: when Claude needs your decision it pings Feishu / DingTalk **instantly**; if it stops and nobody replies it **escalates on a delay**, and can even **call your phone**.
> Install once, works in **every project**, **without touching any settings.json**.

## Quick start (4 steps, usable right after install)

```bash
# 1. Add the marketplace (use the full HTTPS URL; the owner/repo shorthand defaults to SSH and fails without a key)
claude plugin marketplace add https://github.com/Caspian-Sun/claude-idle-alert.git

# 2. Install the plugin (hooks are wired up automatically; your project's settings.json is untouched)
claude plugin install claude-idle-alert

# 3. In Claude Code, type /idle-alert and follow the prompts to fill in your Feishu / DingTalk webhooks (configure tier-3 too if you want phone calls)

# 4. Reload Window
```

That's all 4 steps. Configuration only asks for your webhooks; the plugin wires up the runtime mechanics itself.

> Prerequisites: `jq` + `curl` (usually preinstalled on macOS/Linux; if `jq` is missing, run `brew install jq`).
> Update: `claude plugin marketplace update claude-idle-alert && claude plugin install claude-idle-alert`
> Uninstall: `claude plugin uninstall claude-idle-alert`

---

## What it does

When you step away and Claude pops a Yes/No or asks a question mid-run, it just sits there and nobody knows. Tiered alerts solve this:

| Tier | When it fires | How |
|------|---------------|-----|
| **Instant** | Claude asks you / plan awaiting approval / permission prompt | Feishu + DingTalk text (both if configured) |
| **Tier 1 / Tier 2** | 2 / 10 min with no reply *while Claude is blocked on that decision* | Feishu + DingTalk text / text + @mention |
| **Tier 3 (optional)** | Still no reply after 20 min | **Feishu phone call only** (voice reads the message aloud), see below |

> **Note**: DingTalk currently supports only webhook text notifications (tier 0-2). Feishu supports both webhooks (tier 0-2) and optional phone urgency (tier 3).

> Signal sources: both layers fire on the same genuine "needs you" signals — `PreToolUse(AskUserQuestion\|ExitPlanMode)` (fires in any environment) + `Notification(permission_prompt)`. The instant layer pings right away; the delayed layer arms a watchdog on the same events and escalates if you don't respond. A plain `Stop` (Claude just finished a turn) does **not** arm anything, so normal completions never trigger an idle alert. Responding (answering the question / a tool completing / typing) disarms it.

---

## Configuration

Real config lives in `~/.claude/idle-alert/config.sh` (**personal, local, never committed**) and applies to all projects.
The easiest way is to run `/idle-alert` and let the wizard write it; you can also copy [`scripts/config.example.sh`](scripts/config.example.sh) by hand:

| Key | Description | Default |
|-----|-------------|---------|
| `FEISHU_ENABLED` | Enable Feishu notifications (true/false, **at least one must be true**) | false |
| `WEBHOOK_URL` | Feishu custom-bot webhook (only used if FEISHU_ENABLED=true) | none |
| `DINGTALK_ENABLED` | Enable DingTalk notifications (true/false, **at least one must be true**) | false |
| `DINGTALK_WEBHOOK_URL` | DingTalk custom-bot webhook (only used if DINGTALK_ENABLED=true) | none |
| `TIER1_DELAY` | Seconds idle before the tier-1 alert | 120 |
| `TIER2_DELAY` | Seconds idle before escalation (must be > TIER1) | 600 |
| `AT_OPEN_ID` | Feishu open_id to @ on escalation (optional) | empty |
| `KEYWORD` | Feishu custom keyword (must appear in the message) | Claude |

**No service enabled → silent `exit 0` throughout, zero side effects** — so installing without configuring won't disturb anyone.
At least one service (set `FEISHU_ENABLED=true` or `DINGTALK_ENABLED=true`) should be enabled for alerts to work.
If installed but not yet configured, every session (once per day) will **actively remind** you to run `/idle-alert` (SessionStart check).

**Custom config location**: defaults to `~/.claude/idle-alert/config.sh` (separate from the install dir, so it survives upgrades).
To change the path: pick "custom directory" when running `/idle-alert`, or manually add to your user-level `~/.claude/settings.json`:
`{ "env": { "CLAUDE_IDLE_CONFIG": "/your/path/config.sh" } }` (changing env requires a Reload).

---

## How it works (dead-man's switch)

```
PreToolUse(AskUserQuestion|ExitPlanMode) / Notification(permission_prompt)
   ├──► decision.sh ──► send Feishu immediately (instant layer)
   └──► arm.sh ─────► write per-session nonce + background watcher.sh
                                        │ (sleep TIER1)
You respond (PostToolUse / UserPromptSubmit) ─► disarm.sh ─► delete nonce
                                        ▼
              watcher wakes: nonce still there and unchanged? ──no──► exit (you responded / re-armed)
                                        │yes → send tier 1, then sleep until TIER2
                          still armed? ──yes──► send tier-2 escalation (@you)

A plain Stop (Claude just finished a turn, nothing pending) arms nothing → no idle alert.
```

- **Per-session**: the nonce is keyed by `session_id`, so multiple sessions don't interfere.
- **Re-arming naturally invalidates old watchers**: each arm writes a fresh nonce; an old watcher that wakes up and finds a mismatch just exits — no need to kill processes.
- **Metadata only**: notifications contain only the project name + idle duration/reason type, **never any conversation content**.

---

## Privacy

- The webhook is stored only in `~/.claude/idle-alert/config.sh`; never committed, never transmitted.
- Notification text contains only "project name + duration + tier"; it never reads or sends the transcript / conversation content.
- Conversation content never leaves your machine (unlike approaches that mirror sessions to the cloud).

---

## File layout

```
claude-idle-alert/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # marketplace manifest (for marketplace add)
├── hooks/hooks.json         # hook wiring (auto-registered on install, ${CLAUDE_PLUGIN_ROOT})
├── scripts/                 # runtime scripts
│   ├── decision.sh          # instant decision alert
│   ├── arm.sh / disarm.sh   # arm / disarm
│   ├── watcher.sh           # background watchdog (two tiers)
│   ├── notify.sh            # Feishu sender (tier 0/1/2)
│   └── config.example.sh    # config template
└── skills/idle-alert/SKILL.md  # config wizard (/idle-alert)
```

---

## Tier-3: urgent phone call (optional)

Feishu "phone urgency" = the Feishu system **calls the phone number bound to your account** and reads the message aloud via synthesized voice (a real phone call, not in-app VoIP).
This requires a **Feishu custom app** (**a personal account can create one too** — an enterprise plan isn't required; a webhook bot can't do this). Once you've filled in
`LARK_APP_ID/SECRET/USER_OPEN_ID` in `config.sh`, if idle exceeds `TIER3_DELAY` (default 20 min) with no reply → it calls you automatically.
Flow: `tenant_access_token → send message to get message_id → urgent_phone` (see `scripts/urgent_phone.sh`).

Feishu-side prerequisites (grant all permissions with the **"application" identity**; after adding them you must **create a version → publish** for them to take effect):
1. Go to open.feishu.cn and create a "custom app" (**personal or enterprise both work**) → get `app_id` / `app_secret`
2. Enable 3 permissions (exact identifiers, verified working):
   - `contact:user.id:readonly` (look up open_id by phone number)
   - `im:message:send_as_bot` (send messages)
   - `im:message.urgent:phone` (phone urgency)
3. Publish a version → ensure you're in the availability scope → your account has a bound phone number → obtain your `open_id` (ou_xxx)

## Roadmap

- [x] Tier-3 urgent phone call (Feishu custom app `urgent_phone`)
- [x] DingTalk support — send to both Feishu and DingTalk webhooks
- [ ] Multi-channel (WeCom / Telegram / Bark) — just change the payload in `notify.sh`

## License

MIT
