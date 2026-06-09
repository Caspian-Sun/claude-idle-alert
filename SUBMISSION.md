# Claude Code Plugin Submission Document

## Plugin Information

- **Plugin Name**: claude-idle-alert
- **GitHub Repository**: https://github.com/Caspian-Sun/claude-idle-alert
- **Current Version**: 1.0.8
- **Author**: Caspian-Sun
- **License**: MIT

## Overview

Claude Code **away-from-keyboard alert plugin** (dead-man's switch). When Claude needs your decision (asking a question, awaiting plan approval, or permission prompt), it immediately notifies you via **Feishu or DingTalk**. If you don't respond within 2/10 minutes, it escalates the reminder. Optional tier-3 feature supports Feishu phone urgency for critical notifications.

## Core Features

✅ **Tier 0-2: Text Notifications**
- Instant: Immediate notification when Claude needs your decision
- Tier 1: Reminder after 2 minutes of inactivity
- Tier 2: Escalation with @mention after 10 minutes

✅ **Tier 3: Feishu Phone Urgency** (Optional)
- Automatic phone call after 20 minutes of inactivity
- Requires Feishu custom app setup

✅ **Multi-Channel Support**
- Feishu: webhook + phone urgency
- DingTalk: webhook only

✅ **Zero-Config Installation**
- Auto-wired hooks on install
- No settings.json modifications needed
- Works across all projects with single configuration

## Technical Details

| Aspect | Details |
|--------|---------|
| Language | Bash Shell Script |
| Size | ~10KB core code |
| Dependencies | jq, curl (standard tools) |
| Compatibility | macOS, Linux |
| Installation | Claude Code Plugin Marketplace |

## Submission Checklist

### Code Quality
- ✅ Syntax validation passed
- ✅ SemVer versioning standard
- ✅ Comprehensive comments and documentation
- ✅ Security: No credentials stored in code
- ✅ MIT License

### Documentation Completeness
- ✅ README.md (English main branch)
- ✅ README.md (Chinese zh branch)
- ✅ RELEASE.md (Release process & versioning)
- ✅ SKILL.md (Configuration wizard guide)
- ✅ plugin.json (Complete metadata)

### Feature Completeness
- ✅ Feishu webhook notifications
- ✅ DingTalk webhook notifications
- ✅ Feishu phone urgency (tier-3)
- ✅ Interactive configuration wizard (/idle-alert skill)
- ✅ Automated release script (./scripts/release.sh)
- ✅ Configuration migration tool

### User Experience
- ✅ 4-step quick start
- ✅ No settings.json modifications required
- ✅ Automatic configuration backup
- ✅ Colored CLI output
- ✅ Complete troubleshooting guide

## Installation Instructions

```bash
# Users can install with:
claude plugin marketplace add https://github.com/Caspian-Sun/claude-idle-alert.git
claude plugin install claude-idle-alert
```

After installation, run `/idle-alert` for interactive configuration.

## Development Workflow

- **Version Control**: Git + GitHub
- **Release Automation**: ./scripts/release.sh (one-command releases)
- **Testing**: Interactive skill testing + manual verification
- **Documentation**: Markdown (README, RELEASE, SKILL)
- **Internationalization**: English (main) + Chinese (zh branch)

## Expected Impact

- **Target Users**: Claude Code users needing away-from-keyboard notifications
- **Internationalization**: Bilingual support (English + Chinese)
- **Update Frequency**: Regular iterations based on user feedback
- **Community**: Open source with active issue tracking

## Future Roadmap

- Regular updates to Feishu/DingTalk APIs
- Additional notification channels (WeCom, Telegram, Bark)
- User feedback integration and UX improvements
- Security updates and bug fixes

## Contact & Resources

- **GitHub Repository**: https://github.com/Caspian-Sun/claude-idle-alert
- **Issues & Support**: https://github.com/Caspian-Sun/claude-idle-alert/issues
- **Documentation**: Complete bilingual docs in repository

---

**Submission Date**: June 9, 2026  
**Author**: Caspian-Sun  
**Status**: ✅ Production Ready - Complete and ready for submission
