# idle-alert 配置模板
#
# 用法: 复制到 ~/.claude/idle-alert/config.sh 后填写。或直接运行 skill `/idle-alert`,
#       它会逐项问你并自动写好 ~/.claude/idle-alert/config.sh。
#
# 为什么真实配置放 ~/.claude (而不是插件目录或某个项目):
#   WEBHOOK_URL 是密钥, 绝不入库。本模板不含密钥, 随插件分发当样例。
#   每个人的真实 webhook/阈值是个人本地配置, 放 ~/.claude/idle-alert/config.sh,
#   对所有项目通用 (插件在任意项目运行时都读这一份)。

# 飞书自定义机器人 webhook (必填)。
# 留空 → 整套 idle-alert 静默不工作, 对任何项目零副作用。
WEBHOOK_URL=""

# 空闲多少「秒」后发一级提醒 (默认 120 = 2 分钟)。
# 设 0 = Claude 一停下就立刻发 (会比较吵, 适合你大部分时间不在电脑前)。
TIER1_DELAY=120

# 空闲多少「秒」后二级升级 (默认 600 = 10 分钟)。必须 > TIER1_DELAY。
TIER2_DELAY=600

# 可选: 二级升级时 @ 你的飞书 open_id (形如 ou_xxxx)。空 = 不 @。
AT_OPEN_ID=""

# 飞书机器人若开了「自定义关键词」安全设置, 消息文字必须含该词 (默认 Claude)。
KEYWORD="Claude"
